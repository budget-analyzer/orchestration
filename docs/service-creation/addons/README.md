# Spring Boot Microservice Add-Ons

This directory contains comprehensive guides for adding common functionality to Spring Boot microservices
created from the Budget Analyzer service template.

## Philosophy

The service template provides a **minimal baseline** with only the essential dependencies. Add-ons allow you
to incrementally add functionality based on your service's specific requirements.

**Template Baseline Includes:**
- Spring Boot Web (servlet-based)
- Spring Boot Actuator (health checks, metrics)
- service-common library (shared utilities, logging, exception handling)
- Code quality tools (Checkstyle, Spotless, EditorConfig)
- Gradle build system with version catalog
- Basic configuration (application.yml, logging)

**Everything else is optional** and documented in the add-on guides below.

## Quick Reference

| Add-On | Purpose | When to Use | Complexity |
|--------|---------|-------------|------------|
| [PostgreSQL + Flyway](postgresql-flyway.md) | Database persistence & migrations | Need to store data | ⭐⭐ Medium |
| [Redis](redis.md) | Caching & session storage | Performance optimization | ⭐⭐ Medium |
| [TestContainers](testcontainers.md) | Integration testing with real services | Quality integration tests | ⭐ Easy |
| [WebClient](webclient.md) | HTTP client for external APIs | Call external REST APIs | ⭐ Easy |
| [SpringDoc OpenAPI](springdoc-openapi.md) | API documentation (Swagger UI) | Document REST API | ⭐ Easy |
| [Spring Modulith](spring-modulith.md) | Module boundaries & event-driven | Enforce module structure | ⭐⭐⭐ Advanced |
| [Scheduling](scheduling.md) | Scheduled tasks (single instance) | Periodic background tasks | ⭐ Easy |
| [ShedLock](shedlock.md) | Distributed scheduled task locking | Scheduled tasks in clusters | ⭐⭐ Medium |
| [RabbitMQ + Spring Cloud](rabbitmq-spring-cloud.md) | Event-driven messaging | Async inter-service communication | ⭐⭐⭐ Advanced |
| [Spring Security](spring-security.md) | Authentication & authorization | Secure API endpoints | ⭐⭐⭐ Advanced |

## Add-On Guides

### Data Persistence & Migration

#### [PostgreSQL + Flyway](postgresql-flyway.md)
Database persistence with version-controlled schema migrations.

**Use Cases:**
- Storing transactional data
- Relational data modeling
- Audit trails with timestamps
- Soft-delete patterns

**Dependencies:** PostgreSQL, Flyway, Spring Data JPA, Bean Validation

**Key Features:**
- Version-controlled migrations
- Base entity classes (AuditableEntity, SoftDeletableEntity)
- JPA repositories with soft-delete support
- H2 for testing or TestContainers for integration tests

---

### Caching & Performance

#### [Redis](redis.md)
High-performance in-memory caching and session storage.

**Use Cases:**
- Caching expensive database queries
- Caching external API responses
- Session storage across instances
- Rate limiting
- Distributed locking

**Dependencies:** Redis, Spring Data Redis, Spring Cache

**Key Features:**
- Spring Cache abstraction (@Cacheable, @CachePut, @CacheEvict)
- Manual operations with RedisTemplate
- Configurable TTL per cache
- TestContainers for testing

**Requires:** Redis running (docker-compose.yml)

---

### Testing

#### [TestContainers](testcontainers.md)
Integration testing with real Docker containers for PostgreSQL, Redis, RabbitMQ, etc.

**Use Cases:**
- Testing repository layer with real PostgreSQL
- Testing Redis cache behavior
- Testing message publishing/consumption
- Avoiding mocks for external dependencies

**Dependencies:** TestContainers Core, TestContainers PostgreSQL/Redis/RabbitMQ, JUnit Jupiter

**Key Features:**
- Singleton container pattern for fast tests
- Dynamic property configuration
- Reusable base test classes
- CI/CD compatible

**Recommended:** Use this instead of H2 or embedded Redis for integration tests

---

### HTTP Clients & External APIs

#### [WebClient](webclient.md)
Non-blocking HTTP client for calling external REST APIs (Spring WebFlux).

**Use Cases:**
- Calling external REST APIs
- Microservice-to-microservice communication
- Uploading/downloading files
- Reactive HTTP operations

**Dependencies:** Spring WebFlux (WebClient only, not full reactive stack)

**Key Features:**
- Non-blocking I/O
- Fluent API
- Built-in error handling
- Testing with MockWebServer
- Real example: currency-service FRED API integration

**Note:** Using WebClient doesn't make your service reactive - it's just an HTTP client

---

### API Documentation

#### [SpringDoc OpenAPI](springdoc-openapi.md)
Automatic API documentation generation with Swagger UI.

**Use Cases:**
- Documenting REST API endpoints
- Interactive API testing
- Sharing API contracts with frontend teams
- Auto-generated OpenAPI 3.0 spec

**Dependencies:** SpringDoc OpenAPI

**Key Features:**
- Automatic endpoint discovery
- Annotations for detailed documentation
- Swagger UI at `/swagger-ui.html`
- OpenAPI spec at `/v3/api-docs`
- Customizable via BaseOpenApiConfig (service-common)

**Access:** `http://localhost:{PORT}/swagger-ui.html`

---

### Event-Driven Architecture

#### [Spring Modulith](spring-modulith.md)
Module boundaries and event-driven communication within a modular monolith.

**Use Cases:**
- Enforce module boundaries
- Event-driven communication between modules
- Transactional event publication (outbox pattern)
- Domain event pattern
- Architecture validation

**Dependencies:** Spring Modulith Events API, Spring Modulith Events JPA

**Key Features:**
- @ApplicationModuleListener for event handling
- Transactional event publication
- Event registry (database-backed)
- Module structure verification tests
- Domain event pattern

**Requires:** PostgreSQL + Flyway (for event registry)

**Complexity:** Advanced - requires careful module design

---

#### [RabbitMQ + Spring Cloud Stream](rabbitmq-spring-cloud.md)
Asynchronous messaging and event-driven communication between microservices.

**Use Cases:**
- Asynchronous inter-service communication
- Event-driven architecture across services
- Background job processing
- Event sourcing
- Audit logging

**Dependencies:** Spring Cloud Stream, RabbitMQ, Spring Modulith Events

**Key Features:**
- Spring Cloud Stream abstraction
- Spring Modulith transactional outbox pattern
- Publisher confirms for reliability
- Automatic retry on failure
- TestContainers for testing
- RabbitMQ Management UI

**Requires:** PostgreSQL + Flyway (for event registry), RabbitMQ (docker-compose.yml)

**Complexity:** Advanced - distributed systems complexity

---

### Scheduled Tasks

#### [Scheduling](scheduling.md)
Basic scheduled tasks using Spring's @Scheduled annotation.

**Use Cases:**
- Periodic background tasks (single instance)
- Scheduled data imports
- Cleanup jobs
- Health checks

**Dependencies:** Spring Framework (included in Spring Boot)

**Key Features:**
- Cron expressions
- Fixed rate and fixed delay
- Initial delay
- Configurable thread pool
- Real example: currency-service exchange rate import

**Note:** For multi-instance deployments, use ShedLock (below)

---

#### [ShedLock](shedlock.md)
Distributed scheduled task locking for clustered/multi-instance deployments.

**Use Cases:**
- Scheduled tasks in horizontally scaled services
- Ensuring tasks run exactly once
- Preventing duplicate execution across instances

**Dependencies:** ShedLock Spring, ShedLock JDBC Template

**Key Features:**
- Database-backed locking (PostgreSQL)
- Works with @Scheduled annotation
- Configurable lock duration
- Automatic lock expiration
- No additional infrastructure needed

**Requires:** PostgreSQL + Flyway (for shedlock table), Scheduling

**When to Use:** Only when service runs with **multiple instances**

---

### Security

#### [Spring Security](spring-security.md)
JWT-based authentication and role-based authorization for REST APIs.

**Use Cases:**
- Securing API endpoints
- JWT-based stateless authentication
- Role-based access control (RBAC)
- Method-level security
- OAuth2 resource server

**Dependencies:** Spring Security, JJWT

**Key Features:**
- JWT token validation
- Role-based authorization
- @PreAuthorize for method security
- CORS configuration
- Stateless authentication
- Spring Security Test for testing

**Complexity:** Advanced - requires authentication service integration

**Note:** This guide focuses on **resource server** (validating JWTs), not issuing tokens

---

## Choosing Add-Ons

### Common Combinations

**Simple REST API Service:**
```
✅ PostgreSQL + Flyway
✅ SpringDoc OpenAPI
✅ TestContainers
```

**REST API with Caching:**
```
✅ PostgreSQL + Flyway
✅ Redis
✅ SpringDoc OpenAPI
✅ TestContainers
```

**Service with External API Calls:**
```
✅ PostgreSQL + Flyway
✅ WebClient
✅ Redis (for caching API responses)
✅ SpringDoc OpenAPI
✅ TestContainers
```

**Service with Scheduled Tasks (Single Instance):**
```
✅ PostgreSQL + Flyway
✅ Scheduling
✅ TestContainers
```

**Service with Scheduled Tasks (Multi-Instance):**
```
✅ PostgreSQL + Flyway
✅ Scheduling
✅ ShedLock
✅ TestContainers
```

**Event-Driven Microservice:**
```
✅ PostgreSQL + Flyway
✅ Spring Modulith
✅ RabbitMQ + Spring Cloud Stream
✅ TestContainers
```

**Secured Microservice:**
```
✅ PostgreSQL + Flyway
✅ Spring Security
✅ Redis (for refresh tokens)
✅ SpringDoc OpenAPI
✅ TestContainers
```

### Decision Tree

```
Do you need to store data?
├─ Yes → PostgreSQL + Flyway
│  │
│  └─ Do you need to improve performance?
│     ├─ Yes → Redis
│     └─ No → Skip caching
│
└─ No → Skip PostgreSQL

Do you call external APIs?
├─ Yes → WebClient
└─ No → Skip WebClient

Do you have scheduled tasks?
├─ Yes → Scheduling
│  │
│  └─ Multiple service instances?
│     ├─ Yes → ShedLock
│     └─ No → Skip ShedLock
│
└─ No → Skip Scheduling

Do you need inter-service communication?
├─ Yes → RabbitMQ + Spring Cloud Stream
│  └─ Also add: Spring Modulith (for event patterns)
│
└─ No → Skip Messaging

Do you need to secure endpoints?
├─ Yes → Spring Security
│  └─ Consider: Redis (for refresh tokens)
│
└─ No → Skip Security (use for internal services only)

Do you want API documentation?
├─ Yes → SpringDoc OpenAPI
└─ No → Skip (but recommended for all REST APIs)

Writing integration tests?
└─ Yes → TestContainers (highly recommended)
```

## Add-On Dependencies

Some add-ons require other add-ons:

| Add-On | Requires | Reason |
|--------|----------|--------|
| ShedLock | PostgreSQL + Flyway, Scheduling | Needs database table for locks |
| Spring Modulith | PostgreSQL + Flyway | Needs event registry table |
| RabbitMQ | PostgreSQL + Flyway, Spring Modulith | Transactional outbox pattern |
| Spring Security (with refresh tokens) | Redis (optional) | Store refresh tokens |

## Add-On Installation Process

### Manual Installation (Current)

1. **Choose Add-Ons**: Review guides and decide which features you need
2. **Follow Guide**: Each guide has step-by-step instructions
3. **Add Dependencies**: Update `gradle/libs.versions.toml` and `build.gradle.kts`
4. **Add Configuration**: Update `application.yml`
5. **Add Code**: Create configuration classes, services, etc.
6. **Run Migrations**: If database changes needed (PostgreSQL, ShedLock, Modulith)
7. **Test**: Verify functionality works as expected

### Future: Automated Installation (Phase 4)

The service creation script will support automatic add-on installation:

```bash
./scripts/create-service.sh

# Interactive prompts:
Select add-ons (y/n):
[x] PostgreSQL + Flyway
[x] Redis caching
[ ] RabbitMQ messaging
[x] WebClient
[ ] ShedLock
[x] SpringDoc OpenAPI
[x] TestContainers
[ ] Spring Security
```

Script will automatically:
- Add dependencies to `libs.versions.toml` and `build.gradle.kts`
- Add configuration to `application.yml`
- Create necessary directories
- Generate template code
- Create database migrations

## Best Practices

1. **Start Minimal**: Only add what you need initially
2. **Add Incrementally**: Add add-ons as requirements emerge
3. **Read the Full Guide**: Each guide has important details and pitfalls
4. **Test After Adding**: Verify functionality before moving to next add-on
5. **Follow Examples**: Real-world examples from existing services are included
6. **Check Dependencies**: Some add-ons require others (see table above)
7. **Update Docker Compose**: Add infrastructure services (Redis, RabbitMQ) to `docker-compose.yml`
8. **Use TestContainers**: Better than mocks for integration testing

## Getting Help

- **Check Examples**: currency-service and transaction-service use many of these add-ons
- **Read Official Docs**: Each guide links to official documentation
- **Review ADRs**: Architecture Decision Records explain why we chose these patterns
- **Ask Questions**: Create GitHub issue if something is unclear

## Contributing

Found an issue or want to improve a guide?

1. Each guide follows the same structure:
   - Purpose
   - Use Cases
   - Benefits
   - Dependencies
   - Configuration
   - Code Examples
   - Testing
   - Best Practices
   - Common Pitfalls
   - Official Documentation
   - Related Add-Ons

2. Include real-world examples from existing services when possible
3. Test all code examples before documenting
4. Link to related add-ons and prerequisites

## Version Compatibility

All add-on guides are tested with:
- **Java**: 24
- **Spring Boot**: 3.5.7
- **Gradle**: 8.14.2
- **service-common**: 0.0.1-SNAPSHOT

Check guide headers for version-specific notes.

## Next Steps

1. **Review Guides**: Read through relevant add-on guides
2. **Plan Your Service**: Decide which add-ons you need
3. **Follow Instructions**: Add dependencies and configuration
4. **Test Thoroughly**: Use TestContainers for integration tests
5. **Document Choices**: Note which add-ons you used in service CLAUDE.md

## Related Documentation

- [Service Creation Plan](../microservice-template-plan.md) - Overall template strategy
- [Orchestration CLAUDE.md](../../../CLAUDE.md) - Repository overview
- [service-common](https://github.com/budgetanalyzer/service-common) - Shared library
- [currency-service](https://github.com/budgetanalyzer/currency-service) - Example using WebClient, Scheduling
- [transaction-service](https://github.com/budgetanalyzer/transaction-service) - Example using PostgreSQL, CSV, OpenAPI

---

**Last Updated**: 2025-11-17
**Maintained By**: Architecture Team
