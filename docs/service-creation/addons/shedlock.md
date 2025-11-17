# Add-On: ShedLock

## Purpose
Distributed scheduled task locking to ensure scheduled tasks run only once across multiple instances
of a service. ShedLock prevents duplicate execution of scheduled jobs in clustered/scaled environments.

## Use Cases
- Scheduled jobs that should run only once (e.g., daily reports, batch processing)
- Preventing duplicate task execution in multi-instance deployments
- Ensuring scheduled data imports run on only one instance
- Coordinating scheduled maintenance tasks across clusters
- Rate-limited operations that should execute exactly once per time window

## Benefits
- **Prevents Duplicate Execution**: Only one instance executes the scheduled task
- **Database-Backed**: Uses existing PostgreSQL database (no additional infrastructure)
- **Lock Timeout**: Automatic lock release prevents stuck locks
- **Simple Integration**: Works with Spring's `@Scheduled` annotation
- **Multiple Backends**: Supports PostgreSQL, Redis, MongoDB, and more
- **Non-Invasive**: Minimal code changes to existing scheduled tasks

## When to Use

### Use ShedLock When:
- Your service is deployed with **multiple instances** (horizontal scaling)
- You have scheduled tasks that should run **exactly once** per schedule
- Tasks modify shared state or external systems

### Don't Use ShedLock When:
- Service runs as a **single instance** (no need for distributed locking)
- Tasks are **idempotent** and duplicate execution is harmless
- Tasks are already coordinated through message queues

## Dependencies

### Step 1: Add to `gradle/libs.versions.toml`

```toml
[versions]
shedlock = "5.17.1"

[libraries]
# Add to existing libraries section
shedlock-spring = { module = "net.javacrumbs.shedlock:shedlock-spring", version.ref = "shedlock" }
shedlock-provider-jdbc-template = { module = "net.javacrumbs.shedlock:shedlock-provider-jdbc-template", version.ref = "shedlock" }
```

### Step 2: Add to `build.gradle.kts`

```kotlin
dependencies {
    // ... existing dependencies

    // ShedLock (requires PostgreSQL + Flyway addon)
    implementation(libs.shedlock.spring)
    implementation(libs.shedlock.provider.jdbc.template)
}
```

## Configuration

### Enable Scheduling and ShedLock

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/config/SchedulingConfig.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.config;

import javax.sql.DataSource;
import net.javacrumbs.shedlock.core.LockProvider;
import net.javacrumbs.shedlock.provider.jdbctemplate.JdbcTemplateLockProvider;
import net.javacrumbs.shedlock.spring.annotation.EnableSchedulerLock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Configuration for scheduled tasks with distributed locking.
 * ShedLock ensures scheduled tasks run only once across multiple instances.
 */
@Configuration
@EnableScheduling
@EnableSchedulerLock(defaultLockAtMostFor = "10m")  // Default max lock duration
public class SchedulingConfig {

  /**
   * Lock provider using PostgreSQL database.
   * ShedLock stores lock information in the 'shedlock' table.
   */
  @Bean
  public LockProvider lockProvider(DataSource dataSource) {
    return new JdbcTemplateLockProvider(
        JdbcTemplateLockProvider.Configuration.builder()
            .withJdbcTemplate(new JdbcTemplate(dataSource))
            .usingDbTime()  // Use database time for consistency across instances
            .build()
    );
  }
}
```

### application.yml

No additional configuration needed. ShedLock uses existing Spring scheduling configuration:

```yaml
spring:
  task:
    scheduling:
      pool:
        size: 5  # Number of threads for scheduled tasks
      thread-name-prefix: scheduling-
```

## Database Migration

ShedLock requires a database table to store lock information.

Create `src/main/resources/db/migration/V3__add_shedlock_table.sql`:

```sql
-- ShedLock table for distributed task locking
-- Prevents duplicate execution of scheduled tasks across multiple instances

CREATE TABLE IF NOT EXISTS shedlock (
    name VARCHAR(64) PRIMARY KEY,          -- Unique task name
    lock_until TIMESTAMP NOT NULL,         -- Lock expiration time
    locked_at TIMESTAMP NOT NULL,          -- When lock was acquired
    locked_by VARCHAR(255) NOT NULL        -- Instance/host that acquired lock
);

-- Index for efficient lock queries
CREATE INDEX IF NOT EXISTS idx_shedlock_lock_until ON shedlock(lock_until);

-- Helpful comment
COMMENT ON TABLE shedlock IS 'ShedLock distributed task locking table';
COMMENT ON COLUMN shedlock.name IS 'Unique identifier for the scheduled task';
COMMENT ON COLUMN shedlock.lock_until IS 'Timestamp when lock expires (UTC)';
COMMENT ON COLUMN shedlock.locked_at IS 'Timestamp when lock was acquired (UTC)';
COMMENT ON COLUMN shedlock.locked_by IS 'Instance identifier (hostname) that owns the lock';
```

## Directory Structure

```
src/
└── main/
    ├── java/org/budgetanalyzer/{DOMAIN_NAME}/
    │   ├── config/
    │   │   └── SchedulingConfig.java      # ShedLock + Scheduling config
    │   └── scheduler/
    │       └── ExampleScheduler.java      # Scheduled tasks
    └── resources/
        └── db/migration/
            └── V3__add_shedlock_table.sql  # ShedLock table migration
```

## Code Examples

### Basic Scheduled Task with ShedLock

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/scheduler/ExampleScheduler.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.scheduler;

import java.time.Instant;
import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Example scheduled tasks using ShedLock for distributed locking.
 */
@Component
public class ExampleScheduler {
  private static final Logger log = LoggerFactory.getLogger(ExampleScheduler.class);

  /**
   * Daily data import task - runs at 11 PM every day.
   * ShedLock ensures only ONE instance executes this task.
   *
   * @SchedulerLock parameters:
   * - name: Unique task identifier (must be unique across all scheduled tasks)
   * - lockAtMostFor: Maximum lock duration (prevents stuck locks if instance crashes)
   * - lockAtLeastFor: Minimum lock duration (prevents rapid re-execution)
   */
  @Scheduled(cron = "0 0 23 * * ?")  // 11:00 PM daily
  @SchedulerLock(
      name = "dailyDataImport",
      lockAtMostFor = "10m",   // Lock expires after 10 minutes (safety timeout)
      lockAtLeastFor = "30s"   // Lock held for at least 30 seconds (prevents immediate re-run)
  )
  public void importDailyData() {
    log.info("Starting daily data import at {}", Instant.now());
    try {
      // Perform data import
      performDataImport();
      log.info("Daily data import completed successfully");
    } catch (Exception e) {
      log.error("Daily data import failed", e);
      throw e;  // Let scheduler retry based on configuration
    }
  }

  /**
   * Hourly cache refresh - runs every hour at minute 15.
   */
  @Scheduled(cron = "0 15 * * * ?")  // Every hour at :15 minutes
  @SchedulerLock(
      name = "hourlyCacheRefresh",
      lockAtMostFor = "5m",
      lockAtLeastFor = "10s"
  )
  public void refreshCache() {
    log.info("Starting hourly cache refresh at {}", Instant.now());
    // Refresh cache logic
  }

  /**
   * Fixed rate task - runs every 5 minutes.
   * Note: Fixed rate starts next execution 5 minutes after PREVIOUS START.
   */
  @Scheduled(fixedRate = 300000)  // Every 5 minutes (300,000 ms)
  @SchedulerLock(
      name = "statusCheck",
      lockAtMostFor = "2m",
      lockAtLeastFor = "5s"
  )
  public void checkStatus() {
    log.info("Checking system status at {}", Instant.now());
    // Status check logic
  }

  /**
   * Fixed delay task - runs 10 minutes after PREVIOUS COMPLETION.
   */
  @Scheduled(fixedDelay = 600000)  // 10 minutes after previous completion
  @SchedulerLock(
      name = "cleanup",
      lockAtMostFor = "15m",
      lockAtLeastFor = "1m"
  )
  public void cleanupOldRecords() {
    log.info("Starting cleanup at {}", Instant.now());
    // Cleanup logic
  }

  /**
   * Initial delay task - runs 1 minute after startup, then every hour.
   */
  @Scheduled(initialDelay = 60000, fixedRate = 3600000)  // 1 min delay, then hourly
  @SchedulerLock(
      name = "healthCheck",
      lockAtMostFor = "2m",
      lockAtLeastFor = "10s"
  )
  public void performHealthCheck() {
    log.info("Performing health check at {}", Instant.now());
    // Health check logic
  }

  private void performDataImport() {
    // Actual import logic
  }
}
```

### Conditional Scheduling (Enable/Disable via Config)

Make scheduled tasks configurable:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.scheduler;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Conditional scheduled task - enabled/disabled via configuration.
 */
@Component
@ConditionalOnProperty(
    value = "budgetanalyzer.{SERVICE_NAME}.scheduling.data-import.enabled",
    havingValue = "true",
    matchIfMissing = true  // Default: enabled
)
public class ConditionalScheduler {
  private static final Logger log = LoggerFactory.getLogger(ConditionalScheduler.class);

  @Scheduled(cron = "${budgetanalyzer.{SERVICE_NAME}.scheduling.data-import.cron}")
  @SchedulerLock(name = "conditionalImport", lockAtMostFor = "10m", lockAtLeastFor = "30s")
  public void importData() {
    log.info("Running conditional data import");
    // Import logic
  }
}
```

**application.yml**:

```yaml
budgetanalyzer:
  {SERVICE_NAME}:
    scheduling:
      data-import:
        enabled: true
        cron: "0 0 23 * * ?"  # 11 PM daily
```

### Real-World Example: Currency Exchange Rate Import

Based on `currency-service` pattern:

```java
package org.budgetanalyzer.currency.scheduler;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;
import org.budgetanalyzer.currency.service.ExchangeRateImportService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Scheduled task for importing exchange rates from external API.
 * ShedLock ensures only one instance imports rates, preventing duplicate API calls.
 */
@Component
@ConditionalOnProperty(
    value = "budgetanalyzer.currency-service.exchange-rate-import.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class ExchangeRateImportScheduler {
  private static final Logger log = LoggerFactory.getLogger(ExchangeRateImportScheduler.class);

  private final ExchangeRateImportService importService;

  public ExchangeRateImportScheduler(ExchangeRateImportService importService) {
    this.importService = importService;
  }

  /**
   * Import exchange rates daily at 11 PM.
   * Cron expression configurable via application.yml.
   */
  @Scheduled(cron = "${budgetanalyzer.currency-service.exchange-rate-import.cron}")
  @SchedulerLock(
      name = "importExchangeRates",
      lockAtMostFor = "10m",   // API call + database insert should finish in 10 minutes
      lockAtLeastFor = "30s"   // Prevent rapid re-execution
  )
  public void importExchangeRates() {
    log.info("Starting scheduled exchange rate import");
    try {
      importService.importLatestRates();
      log.info("Exchange rate import completed successfully");
    } catch (Exception e) {
      log.error("Exchange rate import failed", e);
      // Don't rethrow - log error and continue (will retry next scheduled time)
    }
  }
}
```

## Lock Configuration

### Lock Duration Parameters

```java
@SchedulerLock(
    name = "taskName",
    lockAtMostFor = "10m",    // Maximum lock duration
    lockAtLeastFor = "30s"    // Minimum lock duration
)
```

**`lockAtMostFor`** (Required):
- Maximum time lock can be held
- Prevents stuck locks if instance crashes
- Should be longer than expected task execution time
- Examples: `"10m"`, `"1h"`, `"30s"`

**`lockAtLeastFor`** (Optional):
- Minimum time lock is held
- Prevents immediate re-execution if task finishes quickly
- Useful for rate-limited external API calls
- Examples: `"30s"`, `"1m"`, `"5s"`

### Choosing Lock Durations

**Short Tasks (< 1 minute)**:
```java
lockAtMostFor = "2m"    // 2x expected duration
lockAtLeastFor = "10s"  // Prevent rapid re-runs
```

**Medium Tasks (1-10 minutes)**:
```java
lockAtMostFor = "15m"   // 1.5x expected duration
lockAtLeastFor = "30s"  // Standard minimum
```

**Long Tasks (> 10 minutes)**:
```java
lockAtMostFor = "30m"   // Generous timeout
lockAtLeastFor = "1m"   // Prevent overlaps
```

## Testing

### Testing Scheduled Tasks

```java
package org.budgetanalyzer.{DOMAIN_NAME}.scheduler;

import static org.mockito.Mockito.*;

import org.budgetanalyzer.{DOMAIN_NAME}.service.ExampleService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

/**
 * Test scheduled tasks (without waiting for schedule).
 * ShedLock is disabled in tests by default.
 */
@SpringBootTest
class ExampleSchedulerTest {

  @Autowired
  private ExampleScheduler scheduler;

  @MockBean
  private ExampleService exampleService;

  @Test
  void shouldExecuteScheduledTask() {
    // When - directly invoke scheduled method
    scheduler.importDailyData();

    // Then - verify service was called
    verify(exampleService, times(1)).performImport();
  }

  @Test
  void shouldHandleErrors() {
    // Given - service throws exception
    doThrow(new RuntimeException("Import failed"))
        .when(exampleService).performImport();

    // When/Then - exception is propagated
    assertThrows(RuntimeException.class, () -> scheduler.importDailyData());
  }
}
```

### Testing ShedLock Behavior

To test distributed locking behavior, you need multiple instances:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.scheduler;

import static org.awaitility.Awaitility.await;
import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Integration test for ShedLock behavior.
 * Verifies that only one task execution occurs even when invoked concurrently.
 */
@SpringBootTest
class ShedLockIntegrationTest {

  @Autowired
  private ExampleScheduler scheduler;

  @Autowired
  private JdbcTemplate jdbcTemplate;

  @Test
  void shouldPreventConcurrentExecution() throws Exception {
    AtomicInteger executionCount = new AtomicInteger(0);
    CountDownLatch latch = new CountDownLatch(3);

    // Simulate 3 instances trying to execute the same task
    for (int i = 0; i < 3; i++) {
      new Thread(() -> {
        try {
          scheduler.importDailyData();
          executionCount.incrementAndGet();
        } catch (Exception e) {
          // Lock not acquired - expected for 2 out of 3 instances
        } finally {
          latch.countDown();
        }
      }).start();
    }

    // Wait for all threads to complete
    latch.await();

    // Only one execution should have succeeded
    assertThat(executionCount.get()).isEqualTo(1);

    // Verify lock was recorded in database
    Integer lockCount = jdbcTemplate.queryForObject(
        "SELECT COUNT(*) FROM shedlock WHERE name = 'dailyDataImport'",
        Integer.class
    );
    assertThat(lockCount).isEqualTo(1);
  }
}
```

## Monitoring

### Check Active Locks

Query the `shedlock` table to see active locks:

```sql
-- View all active locks
SELECT name, locked_at, lock_until, locked_by
FROM shedlock
WHERE lock_until > NOW();

-- View lock history
SELECT name, locked_at, lock_until, locked_by
FROM shedlock
ORDER BY locked_at DESC
LIMIT 10;
```

### Stuck Lock Detection

Detect locks that may be stuck:

```sql
-- Find locks held longer than expected
SELECT name, locked_at, lock_until, locked_by,
       EXTRACT(EPOCH FROM (NOW() - locked_at)) as held_seconds
FROM shedlock
WHERE lock_until > NOW()
  AND EXTRACT(EPOCH FROM (NOW() - locked_at)) > 600;  -- Held for > 10 minutes
```

### Manual Lock Release

If a lock is stuck (shouldn't happen with proper `lockAtMostFor`):

```sql
-- Release specific lock
DELETE FROM shedlock WHERE name = 'taskName';

-- Release all expired locks (cleanup)
DELETE FROM shedlock WHERE lock_until < NOW();
```

## Best Practices

1. **Unique Task Names**: Each `@SchedulerLock` must have a unique `name` across all tasks
2. **Set lockAtMostFor**: Always set to prevent stuck locks (1.5-2x expected duration)
3. **Consider lockAtLeastFor**: Use for rate-limited APIs or to prevent rapid re-runs
4. **Idempotent Tasks**: Tasks should be safe to run multiple times (in case of retries)
5. **Monitor Lock Table**: Watch for stuck locks or high frequency
6. **Use Database Time**: `usingDbTime()` ensures consistent time across instances
7. **Log Lock Acquisition**: Log when lock is acquired for debugging
8. **Graceful Degradation**: Don't fail service startup if lock table is unavailable

## Common Pitfalls

1. **lockAtMostFor Too Short**: Task killed mid-execution, leaves partial state
2. **Duplicate Task Names**: Different tasks share same lock, causing unexpected behavior
3. **No lockAtMostFor**: Risk of stuck locks if instance crashes
4. **Forgetting Migration**: ShedLock won't work without the `shedlock` table
5. **Testing with Single Instance**: Doesn't catch distributed locking issues
6. **Long-Running Tasks**: Should use longer `lockAtMostFor` or break into smaller tasks
7. **Not Monitoring**: Stuck locks can silently prevent task execution

## Comparison with Other Solutions

| Feature | ShedLock | Quartz Scheduler | Spring Cloud Task |
|---------|----------|------------------|-------------------|
| Setup Complexity | Simple | Complex | Medium |
| Infrastructure | Database (existing) | Database (dedicated) | Database |
| Distributed | Yes | Yes | Yes |
| Task Coordination | Lock-based | Clustered | Event-based |
| Spring Integration | Native | External | Native |
| **Recommendation** | ✅ Best for simple scheduled tasks | For complex workflows | For one-off tasks |

## Official Documentation

- [ShedLock GitHub](https://github.com/lukas-krecan/ShedLock)
- [ShedLock Spring Integration](https://github.com/lukas-krecan/ShedLock#spring-integration)
- [Spring Scheduling](https://docs.spring.io/spring-framework/reference/integration/scheduling.html)

## Related Add-Ons

- **postgresql-flyway.md**: Required for ShedLock table (V3 migration)
- **scheduling.md**: Basic Spring scheduling without distributed locking
- **testcontainers.md**: Integration testing with real database
