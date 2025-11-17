# Add-On: RabbitMQ + Spring Cloud Stream

## Purpose
Event-driven messaging and asynchronous communication between microservices using RabbitMQ
and Spring Cloud Stream. Enables loose coupling, scalability, and event-driven architectures.

## Use Cases
- Event-driven communication between microservices
- Asynchronous processing (background jobs, batch operations)
- Domain event publishing and subscription
- Event sourcing and CQRS patterns
- Audit logging across services
- Notification and alerting systems
- Workflow orchestration

## Benefits
- **Decoupling**: Services communicate through events, not direct calls
- **Reliability**: Message persistence ensures delivery even if consumers are down
- **Scalability**: Multiple consumers can process messages in parallel
- **Resilience**: Failed message processing can be retried automatically
- **Spring Integration**: Auto-configuration with Spring Cloud Stream
- **Event-Driven Architecture**: Natural fit for domain-driven design
- **Spring Modulith**: Module boundaries enforced with event publication

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│  Publisher      │         │  Subscriber     │
│  Service        │         │  Service        │
│                 │         │                 │
│  @Component     │         │  @Component     │
│  publishEvent() │         │  @EventListener │
└────────┬────────┘         └────────▲────────┘
         │                           │
         │  Domain Event             │
         ▼                           │
┌─────────────────────────────────────────────┐
│  Spring Modulith Event Publication         │
│  (Transactional Outbox Pattern)            │
└─────────────────┬───────────────────────────┘
                  │
                  │  JPA Event Registry
                  ▼
         ┌────────────────┐
         │   RabbitMQ     │
         │   Exchange     │
         │   + Queue      │
         └────────────────┘
```

## Dependencies

### Step 1: Add to `gradle/libs.versions.toml`

```toml
[versions]
springCloud = "2024.0.0"
springModulith = "1.3.1"

[libraries]
# Add to existing libraries section
spring-cloud-starter-stream-rabbit = { module = "org.springframework.cloud:spring-cloud-starter-stream-rabbit" }
spring-modulith-events-api = { module = "org.springframework.modulith:spring-modulith-events-api", version.ref = "springModulith" }
spring-modulith-events-jpa = { module = "org.springframework.modulith:spring-modulith-events-jpa", version.ref = "springModulith" }

# Test
spring-cloud-stream-test-binder = { module = "org.springframework.cloud:spring-cloud-stream-test-binder" }
testcontainers-rabbitmq = { module = "org.testcontainers:rabbitmq", version.ref = "testcontainers" }
```

### Step 2: Add Spring Cloud BOM to `build.gradle.kts`

```kotlin
plugins {
    // ... existing plugins
    alias(libs.plugins.spring.dependency.management)
}

dependencyManagement {
    imports {
        mavenBom("org.springframework.cloud:spring-cloud-dependencies:${libs.versions.springCloud.get()}")
    }
}

dependencies {
    // ... existing dependencies

    // RabbitMQ + Spring Cloud Stream
    implementation(libs.spring.cloud.starter.stream.rabbit)
    implementation(libs.spring.modulith.events.api)
    implementation(libs.spring.modulith.events.jpa)

    // Test
    testImplementation(libs.spring.cloud.stream.test.binder)
    testImplementation(libs.testcontainers.rabbitmq)
}
```

## Configuration

### application.yml

```yaml
spring:
  application:
    name: {SERVICE_NAME}

  rabbitmq:
    host: ${RABBITMQ_HOST:localhost}
    port: ${RABBITMQ_PORT:5672}
    username: ${RABBITMQ_USERNAME:budget_analyzer}
    password: ${RABBITMQ_PASSWORD:budget_analyzer}
    virtual-host: ${RABBITMQ_VHOST:/}

    # Connection settings
    connection-timeout: 10000
    requested-heartbeat: 60

    # Publisher confirms for reliability
    publisher-confirm-type: correlated
    publisher-returns: true

    # Connection recovery
    template:
      retry:
        enabled: true
        initial-interval: 1000
        max-attempts: 3
        multiplier: 2

  cloud:
    stream:
      # Default binder
      default-binder: rabbit

      # Function bindings (recommended over deprecated channel names)
      function:
        definition: processEvent  # Matches bean name of Consumer<Message>

      bindings:
        # Output binding (producer)
        processEvent-out-0:
          destination: budget-analyzer.events
          binder: rabbit
          producer:
            required-groups: ${spring.application.name}

        # Input binding (consumer)
        processEvent-in-0:
          destination: budget-analyzer.events
          group: ${spring.application.name}
          binder: rabbit
          consumer:
            max-attempts: 3
            back-off-initial-interval: 1000
            back-off-multiplier: 2.0

      rabbit:
        bindings:
          processEvent-out-0:
            producer:
              exchange-type: topic
              routing-key-expression: headers['eventType']

          processEvent-in-0:
            consumer:
              exchange-type: topic
              binding-routing-key: '#'  # Subscribe to all event types
              acknowledge-mode: auto
              durable-subscription: true
              requeue-rejected: false  # Dead letter rejected messages

  # Spring Modulith event publication
  modulith:
    events:
      # Use JPA-based event registry (requires PostgreSQL)
      jdbc-schema-initialization:
        enabled: true
      # Republish incomplete events on startup
      republish-outstanding-events-on-restart: true
```

### Test Configuration (src/test/resources/application.yml)

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672  # Will be overridden by TestContainers

  cloud:
    stream:
      function:
        definition: processEvent
```

## Directory Structure

```
src/
├── main/
│   ├── java/org/budgetanalyzer/{DOMAIN_NAME}/
│   │   ├── config/
│   │   │   └── RabbitMqConfig.java  # Optional custom config
│   │   ├── events/
│   │   │   ├── DomainEvent.java            # Base event interface/class
│   │   │   ├── ExampleCreatedEvent.java    # Specific event
│   │   │   └── ExampleUpdatedEvent.java    # Specific event
│   │   ├── publisher/
│   │   │   └── EventPublisher.java         # Event publisher service
│   │   └── subscriber/
│   │       └── EventSubscriber.java        # Event listener
│   └── resources/
│       └── db/migration/
│           └── V2__add_event_publication_registry.sql
└── test/
    └── java/org/budgetanalyzer/{DOMAIN_NAME}/
        └── events/
            └── EventPublisherTest.java
```

## Database Migration for Event Registry

Spring Modulith uses a JPA-based event registry to track published events (transactional outbox pattern).

Create `src/main/resources/db/migration/V2__add_event_publication_registry.sql`:

```sql
-- Spring Modulith Event Publication Registry
-- Stores events until they are successfully published to RabbitMQ

CREATE TABLE IF NOT EXISTS event_publication (
    id UUID PRIMARY KEY,
    listener_id VARCHAR(512) NOT NULL,
    event_type VARCHAR(512) NOT NULL,
    serialized_event TEXT NOT NULL,
    publication_date TIMESTAMP NOT NULL,
    completion_date TIMESTAMP
);

CREATE INDEX idx_event_publication_listener ON event_publication(listener_id);
CREATE INDEX idx_event_publication_completion ON event_publication(completion_date);
CREATE INDEX idx_event_publication_date ON event_publication(publication_date);
```

## Code Examples

### Domain Event Classes

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/events/DomainEvent.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.events;

import java.time.Instant;
import java.util.UUID;

/**
 * Base class for all domain events.
 * All events should be immutable and serializable.
 */
public abstract class DomainEvent {
  private final String eventId;
  private final Instant occurredAt;
  private final String eventType;

  protected DomainEvent(String eventType) {
    this.eventId = UUID.randomUUID().toString();
    this.occurredAt = Instant.now();
    this.eventType = eventType;
  }

  public String getEventId() {
    return eventId;
  }

  public Instant getOccurredAt() {
    return occurredAt;
  }

  public String getEventType() {
    return eventType;
  }
}
```

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/events/ExampleCreatedEvent.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.events;

/**
 * Event published when an example entity is created.
 * Events should be immutable and contain all necessary data.
 */
public class ExampleCreatedEvent extends DomainEvent {
  private final Long entityId;
  private final String name;
  private final String createdBy;

  public ExampleCreatedEvent(Long entityId, String name, String createdBy) {
    super("ExampleCreated");
    this.entityId = entityId;
    this.name = name;
    this.createdBy = createdBy;
  }

  public Long getEntityId() {
    return entityId;
  }

  public String getName() {
    return name;
  }

  public String getCreatedBy() {
    return createdBy;
  }

  @Override
  public String toString() {
    return "ExampleCreatedEvent{"
        + "eventId='" + getEventId() + '\''
        + ", entityId=" + entityId
        + ", name='" + name + '\''
        + ", createdBy='" + createdBy + '\''
        + ", occurredAt=" + getOccurredAt()
        + '}';
  }
}
```

### Event Publisher

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/publisher/EventPublisher.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.publisher;

import org.budgetanalyzer.{DOMAIN_NAME}.events.DomainEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * Service for publishing domain events.
 * Uses Spring's ApplicationEventPublisher with Spring Modulith for transactional outbox.
 */
@Component
public class EventPublisher {
  private static final Logger log = LoggerFactory.getLogger(EventPublisher.class);

  private final ApplicationEventPublisher applicationEventPublisher;

  public EventPublisher(ApplicationEventPublisher applicationEventPublisher) {
    this.applicationEventPublisher = applicationEventPublisher;
  }

  /**
   * Publish a domain event.
   * Event will be stored in the event registry and published to RabbitMQ asynchronously.
   * This is transactional - if the database transaction rolls back, the event is not published.
   */
  public void publish(DomainEvent event) {
    log.info("Publishing event: {}", event);
    applicationEventPublisher.publishEvent(event);
  }
}
```

### Using Event Publisher in Service

```java
package org.budgetanalyzer.{DOMAIN_NAME}.service;

import org.budgetanalyzer.{DOMAIN_NAME}.domain.ExampleEntity;
import org.budgetanalyzer.{DOMAIN_NAME}.events.ExampleCreatedEvent;
import org.budgetanalyzer.{DOMAIN_NAME}.publisher.EventPublisher;
import org.budgetanalyzer.{DOMAIN_NAME}.repository.ExampleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExampleService {
  private final ExampleRepository repository;
  private final EventPublisher eventPublisher;

  public ExampleService(ExampleRepository repository, EventPublisher eventPublisher) {
    this.repository = repository;
    this.eventPublisher = eventPublisher;
  }

  /**
   * Create entity and publish event in the same transaction.
   * If transaction fails, event is not published (transactional outbox pattern).
   */
  @Transactional
  public ExampleEntity create(String name, String createdBy) {
    ExampleEntity entity = new ExampleEntity(name);
    entity = repository.save(entity);

    // Publish domain event
    ExampleCreatedEvent event = new ExampleCreatedEvent(
        entity.getId(),
        entity.getName(),
        createdBy
    );
    eventPublisher.publish(event);

    return entity;
  }
}
```

### Event Subscriber

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/subscriber/EventSubscriber.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.subscriber;

import org.budgetanalyzer.{DOMAIN_NAME}.events.ExampleCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.modulith.events.ApplicationModuleListener;
import org.springframework.stereotype.Component;

/**
 * Subscribes to domain events.
 * Uses @ApplicationModuleListener for transactional event processing with Spring Modulith.
 */
@Component
public class EventSubscriber {
  private static final Logger log = LoggerFactory.getLogger(EventSubscriber.class);

  /**
   * Listen for ExampleCreatedEvent.
   * This method is called asynchronously after the event is published.
   * Exceptions will cause the event to be retried (based on Spring Cloud Stream config).
   */
  @ApplicationModuleListener
  public void handleExampleCreated(ExampleCreatedEvent event) {
    log.info("Received ExampleCreatedEvent: {}", event);

    // Process event (e.g., send notification, update cache, etc.)
    try {
      processEvent(event);
      log.info("Successfully processed event: {}", event.getEventId());
    } catch (Exception e) {
      log.error("Failed to process event: {}", event.getEventId(), e);
      // Exception will trigger retry based on Spring Cloud Stream configuration
      throw new RuntimeException("Event processing failed", e);
    }
  }

  private void processEvent(ExampleCreatedEvent event) {
    // Business logic here
    // Examples:
    // - Send email notification
    // - Update search index
    // - Invalidate cache
    // - Trigger workflow
    log.info("Processing created entity: {} by {}", event.getName(), event.getCreatedBy());
  }
}
```

## Testing

### TestContainers Setup

Create base test class with RabbitMQ container:

```java
package org.budgetanalyzer.{DOMAIN_NAME};

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.RabbitMQContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest
@Testcontainers
public abstract class BaseMessagingTest {

  @Container
  private static final RabbitMQContainer rabbitMQContainer =
      new RabbitMQContainer(DockerImageName.parse("rabbitmq:3.13-management-alpine"))
          .withReuse(true);

  @DynamicPropertySource
  static void rabbitMqProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.rabbitmq.host", rabbitMQContainer::getHost);
    registry.add("spring.rabbitmq.port", rabbitMQContainer::getAmqpPort);
    registry.add("spring.rabbitmq.username", rabbitMQContainer::getAdminUsername);
    registry.add("spring.rabbitmq.password", rabbitMQContainer::getAdminPassword);
  }
}
```

### Event Publishing Test

```java
package org.budgetanalyzer.{DOMAIN_NAME}.publisher;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import java.time.Duration;
import org.budgetanalyzer.{DOMAIN_NAME}.BaseMessagingTest;
import org.budgetanalyzer.{DOMAIN_NAME}.events.ExampleCreatedEvent;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.SpyBean;

class EventPublisherTest extends BaseMessagingTest {

  @Autowired
  private EventPublisher eventPublisher;

  @SpyBean  // Spy to verify event handling
  private EventSubscriber eventSubscriber;

  @Test
  void shouldPublishAndReceiveEvent() {
    // Given
    ExampleCreatedEvent event = new ExampleCreatedEvent(1L, "Test Entity", "test-user");

    // When
    eventPublisher.publish(event);

    // Then - wait for async event processing
    await()
        .atMost(Duration.ofSeconds(5))
        .untilAsserted(() -> {
          // Verify event was received by subscriber
          verify(eventSubscriber).handleExampleCreated(any(ExampleCreatedEvent.class));
        });
  }
}
```

## Docker Compose Integration

Add RabbitMQ to `docker-compose.yml`:

```yaml
services:
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    container_name: rabbitmq
    ports:
      - "5672:5672"    # AMQP port
      - "15672:15672"  # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: budget_analyzer
      RABBITMQ_DEFAULT_PASS: budget_analyzer
      RABBITMQ_DEFAULT_VHOST: /
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    networks:
      - budget-analyzer-network
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  rabbitmq-data:

networks:
  budget-analyzer-network:
    driver: bridge
```

Access RabbitMQ Management UI at: `http://localhost:15672` (username: `budget_analyzer`, password: `budget_analyzer`)

## Event Design Best Practices

1. **Events are Immutable**: Once created, events should never be modified
2. **Events Contain All Necessary Data**: Subscribers shouldn't need to query the publisher
3. **Past Tense Naming**: Events represent things that have happened (`ExampleCreated`, not `CreateExample`)
4. **Include Metadata**: Event ID, timestamp, correlation ID
5. **Versioning**: Plan for event schema evolution
6. **Idempotent Handlers**: Event handlers should be idempotent (safe to process multiple times)
7. **Small Events**: Keep events focused on a single domain concept
8. **Avoid Circular Dependencies**: Be careful with event chains that could loop

## Message Patterns

### 1. Domain Event Pattern (Used Here)

Publish events after state changes. Subscribers react asynchronously.

**Use when**: Loose coupling desired, multiple subscribers, eventual consistency acceptable

### 2. Command Pattern

Send commands to specific services (not implemented in this guide).

**Use when**: Direct service-to-service communication needed, immediate response required

### 3. Event Sourcing Pattern

Store all state changes as events (not implemented in this guide).

**Use when**: Full audit trail needed, time travel required, event replay needed

## Monitoring

Add RabbitMQ metrics to actuator:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,rabbitmq
  metrics:
    export:
      prometheus:
        enabled: true
```

Monitor:
- Message publish rate
- Message consumption rate
- Queue depth
- Failed deliveries
- Event publication registry size

## Common Pitfalls

1. **Not Making Events Immutable**: Can lead to race conditions
2. **Events Too Large**: Keep events small, avoid embedding large objects
3. **Missing Error Handling**: Always handle exceptions in event handlers
4. **Circular Event Chains**: Service A triggers B triggers A... infinite loop
5. **No Idempotency**: Event reprocessing causes duplicate side effects
6. **Blocking Operations in Handlers**: Keep event handlers fast and async
7. **Not Monitoring Queue Depth**: Can indicate slow consumers or failures

## Official Documentation

- [Spring Cloud Stream](https://spring.io/projects/spring-cloud-stream)
- [Spring Modulith Events](https://docs.spring.io/spring-modulith/reference/events.html)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [Spring AMQP](https://spring.io/projects/spring-amqp)

## Related Add-Ons

- **postgresql-flyway.md**: Event registry requires database (V2 migration)
- **testcontainers.md**: Integration testing with real RabbitMQ
- **spring-modulith.md**: Module boundaries and event-driven architecture
