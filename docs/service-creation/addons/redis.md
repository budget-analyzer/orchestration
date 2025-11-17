# Add-On: Redis

## Purpose
Caching and session storage using Redis, an in-memory data structure store. Redis provides
high-performance caching, session management, and distributed locking capabilities.

## Use Cases
- Application-level caching (method results, database queries)
- Session storage and management
- Distributed locking across multiple instances
- Rate limiting
- Temporary data storage with TTL
- Pub/Sub messaging patterns

## Benefits
- **Performance**: In-memory storage for sub-millisecond access times
- **Scalability**: Reduces database load through effective caching
- **Distributed Support**: Works across multiple service instances
- **Spring Integration**: Auto-configuration with Spring Boot
- **Flexible Data Structures**: Strings, hashes, lists, sets, sorted sets
- **TTL Support**: Automatic expiration of cached data

## Dependencies

### Step 1: Add to `gradle/libs.versions.toml`

```toml
[libraries]
# Add to existing libraries section
spring-boot-starter-data-redis = { module = "org.springframework.boot:spring-boot-starter-data-redis" }
spring-boot-starter-cache = { module = "org.springframework.boot:spring-boot-starter-cache" }
```

### Step 2: Add to `build.gradle.kts`

```kotlin
dependencies {
    // ... existing dependencies

    // Redis
    implementation(libs.spring.boot.starter.data.redis)
    implementation(libs.spring.boot.starter.cache)
}
```

## Configuration

### application.yml

```yaml
spring:
  application:
    name: {SERVICE_NAME}

  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
      database: 0  # Redis database index (0-15)
      timeout: 2000ms

      # Connection pool settings
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 0
          max-wait: -1ms

  cache:
    type: redis
    redis:
      time-to-live: 600000  # Default TTL: 10 minutes (in milliseconds)
      cache-null-values: false
      use-key-prefix: true
      key-prefix: "{SERVICE_NAME}:"
```

### Test Configuration (src/test/resources/application.yml)

```yaml
spring:
  data:
    redis:
      # Use embedded Redis or TestContainers for testing
      host: localhost
      port: 6379

  cache:
    type: redis
    redis:
      time-to-live: 60000  # Shorter TTL for tests: 1 minute
```

## Directory Structure

No additional directories required. Configuration classes go in existing structure:

```
src/
├── main/
│   └── java/org/budgetanalyzer/{DOMAIN_NAME}/
│       └── config/
│           └── RedisConfig.java  # Cache configuration
└── test/
    └── java/org/budgetanalyzer/{DOMAIN_NAME}/
        └── config/
            └── RedisConfigTest.java
```

## Code Examples

### Cache Configuration Class

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/config/RedisConfig.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@Configuration
@EnableCaching
public class RedisConfig {

  /**
   * Configure Redis template with JSON serialization.
   * Use this for manual Redis operations (RedisTemplate).
   */
  @Bean
  public RedisTemplate<String, Object> redisTemplate(
      RedisConnectionFactory connectionFactory, ObjectMapper objectMapper) {
    RedisTemplate<String, Object> template = new RedisTemplate<>();
    template.setConnectionFactory(connectionFactory);

    // Use String serializer for keys
    StringRedisSerializer stringSerializer = new StringRedisSerializer();
    template.setKeySerializer(stringSerializer);
    template.setHashKeySerializer(stringSerializer);

    // Use JSON serializer for values
    GenericJackson2JsonRedisSerializer jsonSerializer =
        new GenericJackson2JsonRedisSerializer(objectMapper);
    template.setValueSerializer(jsonSerializer);
    template.setHashValueSerializer(jsonSerializer);

    template.afterPropertiesSet();
    return template;
  }

  /**
   * Configure cache manager with multiple caches and custom TTLs.
   * Use this for @Cacheable, @CachePut, @CacheEvict annotations.
   */
  @Bean
  public CacheManager cacheManager(
      RedisConnectionFactory connectionFactory, ObjectMapper objectMapper) {
    GenericJackson2JsonRedisSerializer serializer =
        new GenericJackson2JsonRedisSerializer(objectMapper);

    // Default cache configuration
    RedisCacheConfiguration defaultConfig =
        RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10)) // Default TTL: 10 minutes
            .serializeKeysWith(
                RedisSerializationContext.SerializationPair.fromSerializer(
                    new StringRedisSerializer()))
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair.fromSerializer(serializer))
            .disableCachingNullValues();

    return RedisCacheManager.builder(connectionFactory)
        .cacheDefaults(defaultConfig)
        // Define custom caches with specific TTLs
        .withCacheConfiguration(
            "short-term-cache",
            defaultConfig.entryTtl(Duration.ofMinutes(5))) // 5 minutes
        .withCacheConfiguration(
            "long-term-cache",
            defaultConfig.entryTtl(Duration.ofHours(1))) // 1 hour
        .withCacheConfiguration(
            "permanent-cache",
            defaultConfig.entryTtl(Duration.ofDays(1))) // 1 day
        .build();
  }
}
```

### Using @Cacheable Annotation

```java
package org.budgetanalyzer.{DOMAIN_NAME}.service;

import org.budgetanalyzer.{DOMAIN_NAME}.domain.ExampleEntity;
import org.budgetanalyzer.{DOMAIN_NAME}.repository.ExampleRepository;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.CachePut;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

@Service
public class ExampleService {

  private final ExampleRepository repository;

  public ExampleService(ExampleRepository repository) {
    this.repository = repository;
  }

  /**
   * Cache the result using the default cache configuration.
   * Key is generated from method parameters (id).
   */
  @Cacheable(value = "short-term-cache", key = "#id")
  public ExampleEntity findById(Long id) {
    return repository.findById(id)
        .orElseThrow(() -> new RuntimeException("Not found: " + id));
  }

  /**
   * Update cache after modification.
   * Ensures cache stays synchronized with database.
   */
  @CachePut(value = "short-term-cache", key = "#result.id")
  public ExampleEntity save(ExampleEntity entity) {
    return repository.save(entity);
  }

  /**
   * Evict cache entry after deletion.
   */
  @CacheEvict(value = "short-term-cache", key = "#id")
  public void deleteById(Long id) {
    repository.deleteById(id);
  }

  /**
   * Clear entire cache.
   */
  @CacheEvict(value = "short-term-cache", allEntries = true)
  public void clearCache() {
    // Cache cleared automatically by Spring
  }

  /**
   * Custom cache key using SpEL expression.
   */
  @Cacheable(value = "long-term-cache", key = "#userId + ':' + #year")
  public List<ExampleEntity> findByUserAndYear(Long userId, int year) {
    return repository.findByUserIdAndYear(userId, year);
  }
}
```

### Manual Redis Operations with RedisTemplate

```java
package org.budgetanalyzer.{DOMAIN_NAME}.service;

import java.time.Duration;
import java.util.concurrent.TimeUnit;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class RateLimiterService {

  private final RedisTemplate<String, Object> redisTemplate;

  public RateLimiterService(RedisTemplate<String, Object> redisTemplate) {
    this.redisTemplate = redisTemplate;
  }

  /**
   * Simple rate limiting using Redis.
   * Returns true if action is allowed, false if rate limit exceeded.
   */
  public boolean isAllowed(String userId, int maxRequests, Duration window) {
    String key = "rate-limit:" + userId;
    Long count = redisTemplate.opsForValue().increment(key);

    if (count == null) {
      return false;
    }

    // Set TTL on first request
    if (count == 1) {
      redisTemplate.expire(key, window);
    }

    return count <= maxRequests;
  }

  /**
   * Store temporary data with expiration.
   */
  public void storeTemporaryData(String key, Object value, Duration ttl) {
    redisTemplate.opsForValue().set(key, value, ttl);
  }

  /**
   * Retrieve temporary data.
   */
  public Object getTemporaryData(String key) {
    return redisTemplate.opsForValue().get(key);
  }

  /**
   * Delete data.
   */
  public void deleteData(String key) {
    redisTemplate.delete(key);
  }

  /**
   * Check if key exists.
   */
  public boolean exists(String key) {
    Boolean exists = redisTemplate.hasKey(key);
    return exists != null && exists;
  }

  /**
   * Set expiration on existing key.
   */
  public void setExpiration(String key, Duration ttl) {
    redisTemplate.expire(key, ttl);
  }
}
```

## Testing

### Option 1: TestContainers (Recommended)

Add TestContainers dependency to `gradle/libs.versions.toml`:

```toml
[versions]
testcontainers = "1.20.4"

[libraries]
testcontainers-core = { module = "org.testcontainers:testcontainers", version.ref = "testcontainers" }
testcontainers-junit-jupiter = { module = "org.testcontainers:junit-jupiter", version.ref = "testcontainers" }
```

Add to `build.gradle.kts`:

```kotlin
dependencies {
    // Test dependencies
    testImplementation(libs.testcontainers.core)
    testImplementation(libs.testcontainers.junit.jupiter)
}
```

Create base test class with Redis container:

```java
package org.budgetanalyzer.{DOMAIN_NAME};

import org.junit.jupiter.api.BeforeAll;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest
@Testcontainers
public abstract class BaseRedisTest {

  @Container
  private static final GenericContainer<?> redisContainer =
      new GenericContainer<>(DockerImageName.parse("redis:7-alpine"))
          .withExposedPorts(6379)
          .withReuse(true);  // Reuse container across tests for speed

  @DynamicPropertySource
  static void redisProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.data.redis.host", redisContainer::getHost);
    registry.add("spring.data.redis.port", redisContainer::getFirstMappedPort);
  }

  @BeforeAll
  static void setUp() {
    redisContainer.start();
  }
}
```

Example test using TestContainers:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import org.budgetanalyzer.{DOMAIN_NAME}.BaseRedisTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class RateLimiterServiceTest extends BaseRedisTest {

  @Autowired
  private RateLimiterService rateLimiterService;

  @Test
  void shouldAllowRequestsWithinLimit() {
    String userId = "user123";
    int maxRequests = 3;
    Duration window = Duration.ofMinutes(1);

    // First 3 requests should be allowed
    assertThat(rateLimiterService.isAllowed(userId, maxRequests, window)).isTrue();
    assertThat(rateLimiterService.isAllowed(userId, maxRequests, window)).isTrue();
    assertThat(rateLimiterService.isAllowed(userId, maxRequests, window)).isTrue();

    // 4th request should be blocked
    assertThat(rateLimiterService.isAllowed(userId, maxRequests, window)).isFalse();
  }

  @Test
  void shouldStoreAndRetrieveTemporaryData() {
    String key = "test-key";
    String value = "test-value";
    Duration ttl = Duration.ofSeconds(10);

    rateLimiterService.storeTemporaryData(key, value, ttl);
    Object retrieved = rateLimiterService.getTemporaryData(key);

    assertThat(retrieved).isEqualTo(value);
  }
}
```

### Option 2: Embedded Redis (Alternative, Not Recommended for Production)

For simple unit tests, you can use an embedded Redis server:

Add dependency to `gradle/libs.versions.toml`:

```toml
[libraries]
embedded-redis = { module = "it.ozimov:embedded-redis", version = "0.7.3" }
```

Add to `build.gradle.kts`:

```kotlin
dependencies {
    testImplementation(libs.embedded.redis)
}
```

Create test configuration:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.config;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.boot.test.context.TestConfiguration;
import redis.embedded.RedisServer;

@TestConfiguration
public class EmbeddedRedisConfig {

  private RedisServer redisServer;

  @PostConstruct
  public void startRedis() {
    redisServer = new RedisServer(6379);
    redisServer.start();
  }

  @PreDestroy
  public void stopRedis() {
    if (redisServer != null) {
      redisServer.stop();
    }
  }
}
```

## Docker Compose Integration

Ensure Redis is running in your local development environment by adding to `docker-compose.yml`:

```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - budget-analyzer-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  redis-data:

networks:
  budget-analyzer-network:
    driver: bridge
```

## Cache Strategies

### 1. Cache-Aside Pattern (Lazy Loading)

```java
@Cacheable(value = "my-cache", key = "#id")
public ExampleEntity findById(Long id) {
    // Cache miss: load from database
    // Cache hit: return from cache
    return repository.findById(id).orElseThrow();
}
```

### 2. Write-Through Pattern

```java
@CachePut(value = "my-cache", key = "#result.id")
public ExampleEntity save(ExampleEntity entity) {
    // Always update cache after database write
    return repository.save(entity);
}
```

### 3. Write-Behind Pattern

Not directly supported by Spring Cache. Use manual RedisTemplate operations or Spring Integration for asynchronous writes.

### 4. Cache Eviction Pattern

```java
@CacheEvict(value = "my-cache", key = "#id")
public void deleteById(Long id) {
    repository.deleteById(id);
}
```

## Best Practices

1. **Use Meaningful Cache Names**: Name caches by their purpose (e.g., `user-cache`, `product-cache`)
2. **Set Appropriate TTLs**: Balance freshness vs performance based on data volatility
3. **Don't Cache Everything**: Only cache expensive operations (database queries, API calls)
4. **Use Cache Keys Wisely**: Include all parameters that affect the result
5. **Monitor Cache Hit Rates**: Use Spring Boot Actuator metrics
6. **Handle Cache Failures Gracefully**: Don't let Redis outages break your service
7. **Test With Real Redis**: Use TestContainers, not mocks
8. **Use JSON Serialization**: For complex objects, JSON is more maintainable than Java serialization
9. **Namespace Your Keys**: Prefix cache keys with service name to avoid collisions
10. **Consider Cache Warming**: Pre-populate cache on startup for critical data

## Monitoring

Add actuator dependencies and expose cache metrics:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,caches
  metrics:
    cache:
      instrument-cache: true
```

Access cache metrics at:
- `http://localhost:{PORT}/actuator/caches` - View all caches
- `http://localhost:{PORT}/actuator/metrics/cache.gets` - Cache get statistics
- `http://localhost:{PORT}/actuator/metrics/cache.puts` - Cache put statistics

## Common Pitfalls

1. **Caching Null Values**: Can lead to cache pollution. Use `disableCachingNullValues()`
2. **No TTL**: Data becomes stale. Always set appropriate TTL
3. **Cache Key Collisions**: Use compound keys with all relevant parameters
4. **Over-Caching**: Caching everything wastes memory and increases complexity
5. **Not Handling Redis Outages**: Service should degrade gracefully if Redis is unavailable
6. **Testing Without Real Redis**: Mock-based tests miss serialization issues

## Official Documentation

- [Spring Data Redis](https://spring.io/projects/spring-data-redis)
- [Spring Cache Abstraction](https://docs.spring.io/spring-framework/reference/integration/cache.html)
- [Redis Documentation](https://redis.io/docs/)
- [Lettuce (Redis Client)](https://lettuce.io/)

## Related Add-Ons

- **postgresql-flyway.md**: Database persistence that benefits from caching
- **testcontainers.md**: Integration testing with real Redis
- **spring-security.md**: Session storage with Redis
