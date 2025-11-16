# Microservice Template Plan - Comprehensive Update (Option A)

## Overview
Update the microservice template plan to fix critical issues, standardize patterns, and align with actual implementation patterns. This is a 1-2 day documentation and existing service update effort.

## Critical Issues Addressed

This update resolves the following critical issues identified in the original plan:

1. **Package Naming Mismatch** - Plan assumed incorrect package structure
2. **Session-Gateway Architecture Incompatibility** - Servlet template incompatible with reactive Spring Cloud Gateway
3. **Configuration Namespace Inconsistencies** - Mixed use of `budget-analyzer` vs `budgetanalyzer`
4. **Java Version Management** - Hardcoded vs libs.versions.toml inconsistency
5. **Missing Configuration Patterns** - JVM args, context-path, logging, Jackson
6. **WebFlux Add-On Misnaming** - Actually WebClient for HTTP client usage
7. **Incomplete Add-On Coverage** - Missing TestContainers, Spring Modulith, Scheduling

---

## Phase 1: Fix Existing Services (FIRST PRIORITY)

### 1.1 Fix Transaction-Service Configuration Namespaces

**Objective**: Standardize to `budgetanalyzer.*` root namespace (no hyphens)

**Changes Required:**

Update `src/main/resources/application.yml`:
```yaml
# FROM:
budget-analyzer:
  service:
    http-logging:
      ...
  transaction-service:
    csv-config-map:
      ...

# TO:
budgetanalyzer:
  service:
    http-logging:
      ...
  transaction-service:
    csv-config-map:
      ...
```

Update `src/test/resources/application.yml`:
```yaml
# FROM:
budget-analyzer:
  transaction-service:
    csv-config-map:
      ...

# TO:
budgetanalyzer:
  transaction-service:
    csv-config-map:
      ...
```

**Code Changes:**
- Update `@ConfigurationProperties` classes to match new namespace
- Search for `@ConfigurationProperties(prefix = "budget-analyzer.*")`
- Replace with `@ConfigurationProperties(prefix = "budgetanalyzer.*")`

**Verification:**
```bash
# Test that configuration still loads correctly
./gradlew test
```

---

### 1.2 Standardize Java Version Management

**Objective**: Move Java version to libs.versions.toml for centralized management

**Changes Required in Both Services:**

**Step 1**: Add to `gradle/libs.versions.toml`:
```toml
[versions]
java = "24"
# ... existing versions
```

**Step 2**: Update `build.gradle.kts`:
```kotlin
// FROM:
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(24))
    }
}

// TO:
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(libs.versions.java.get().toInt()))
    }
}
```

**Apply to:**
- `/workspace/transaction-service/gradle/libs.versions.toml` and `build.gradle.kts`
- `/workspace/currency-service/gradle/libs.versions.toml` and `build.gradle.kts`

**Verification:**
```bash
# Verify Java version is correctly applied
./gradlew properties | grep JavaVersion
```

---

### 1.3 Verify Existing Patterns

**Objective**: Document current patterns for template inclusion

**Tasks:**

1. **Audit service-common autoconfiguration**:
   - Verify `@ConditionalOnWebApplication` on `DefaultApiExceptionHandler`
   - Verify `@ConditionalOnProperty` on `HttpLoggingConfig`
   - Document any other conditional configurations

2. **Document JVM args pattern**:
   - Both services use identical JVM args for Java 24 compatibility:
   ```kotlin
   val jvmArgsList = listOf(
       "--add-opens=java.base/java.nio=ALL-UNNAMED",
       "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED",
       "--enable-native-access=ALL-UNNAMED"
   )
   ```
   - Must be included in template

3. **Document .editorconfig**:
   - Extract content from transaction-service/.editorconfig
   - Include in template repository

4. **Document checkstyle.xml**:
   - Both services use identical 28KB Google Java Style checkstyle.xml
   - Include in template repository or reference centralized location

---

## Phase 2: Update Template Plan Document

### 2.1 Fix Critical Issues

#### Package Naming Pattern

**Problem**: Plan assumed `org.budgetanalyzer.sessiongateway` for session-gateway service, but existing services use only domain word (transaction, currency).

**Solution**: Add new placeholder system

**Placeholders:**
- `{SERVICE_NAME}` = Full service name in kebab-case (e.g., `session-gateway`, `currency-service`)
- `{DOMAIN_NAME}` = Domain/package name (e.g., `session`, `currency`)
  - Default: First word of service name
  - User can override during script execution

**Package Structure:**
```
src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/
```

**Examples:**
- `currency-service` → `org.budgetanalyzer.currency`
- `transaction-service` → `org.budgetanalyzer.transaction`
- `session-gateway` → `org.budgetanalyzer.session` (if using template, which it shouldn't)

**Update Appendix B** with corrected replacement algorithm

---

#### Configuration Namespace Standard

**Established Pattern:**

**Root Namespace**: `budgetanalyzer` (no hyphens)

**Service-Common Configurations:**
```yaml
budgetanalyzer:
  service:
    http-logging:
      enabled: true
      log-level: DEBUG
      # ... etc
```

**App-Specific Configurations:**
```yaml
budgetanalyzer:
  {SERVICE_NAME}:  # e.g., transaction-service, currency-service
    # Service-specific properties
```

**Example (Transaction Service):**
```yaml
budgetanalyzer:
  service:
    http-logging:
      enabled: true
  transaction-service:
    csv-config-map:
      capital-one:
        # ... config
```

**Template Placeholders:**
- `budgetanalyzer.service.*` - Used as-is for service-common configs
- `budgetanalyzer.{SERVICE_NAME}.*` - Replaced with actual service name

---

#### Remove Session-Gateway References

**Problem**: Session-gateway is Spring Cloud Gateway (reactive/WebFlux architecture), fundamentally incompatible with servlet-based template.

**Changes:**

1. **Remove from all examples**: Delete session-gateway references throughout plan
2. **Update Phase 7**: Change title to "Post-Template Development"
3. **Add Exception Note**:

```markdown
### Note on Session-Gateway

The session-gateway service uses Spring Cloud Gateway, a reactive (WebFlux-based)
framework that is architecturally incompatible with this servlet-based microservice
template.

**Architecture Differences:**
- Template services: Spring Boot Web (servlet-based, blocking I/O)
- Session-gateway: Spring Cloud Gateway (reactive, non-blocking I/O)

**Implication**: Session-gateway must be created manually using Spring Cloud Gateway
patterns and documentation. Do not attempt to use this template for session-gateway.

**Future Consideration**: If additional reactive services are needed, consider creating
a separate "Spring Cloud Gateway Template" or "Reactive Microservice Template."
```

4. **Update Appendix D** (Example Service Requirements): Remove session-gateway section entirely

---

#### Database Naming Pattern

**Established Pattern**: Dedicated database per service

**Default Behavior:**
- Database name = `{DOMAIN_NAME}` (e.g., `currency`, `session`)
- User can override during script execution

**Special Case - Transaction Service:**
- Uses shared database `budget_analyzer`
- Reason: Avoid confusion with SQL "transaction" concept
- Document as exception, not recommended pattern

**Script Behavior:**
```bash
# Prompt during execution:
Database name (default: {DOMAIN_NAME}, or specify custom):
```

**Template Configuration:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/{DATABASE_NAME}
```

---

### 2.2 Add Missing Configuration Patterns to Template

#### Minimal application.yml Enhancements

**Current State**: Plan shows very minimal application.yml

**Required Additions**: Include standard configurations that ALL services need

**Enhanced Minimal application.yml:**

```yaml
spring:
  application:
    name: {SERVICE_NAME}

  datasource:
    url: jdbc:postgresql://localhost:5432/{DATABASE_NAME}
    username: ${DB_USERNAME:postgres}
    password: ${DB_PASSWORD:postgres}

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false

  flyway:
    enabled: true
    locations: classpath:db/migration

  mvc:
    servlet:
      path: /{SERVICE_NAME}  # Context path

  jackson:
    default-property-inclusion: non_null
    serialization:
      indent-output: true
      write-dates-as-timestamps: false
    date-format: com.fasterxml.jackson.databind.util.StdDateFormat

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized

logging:
  level:
    root: WARN
    org.budgetanalyzer: TRACE

budgetanalyzer:
  service:
    http-logging:
      enabled: true
      log-level: DEBUG
      include-request-body: true
      include-response-body: true
      max-body-size: 10000
      exclude-patterns:
        - /actuator/**
        - /swagger-ui/**
        - /v3/api-docs/**
```

**Rationale**: These are baseline configurations present in all existing services and required for production readiness.

---

#### Minimal build.gradle.kts Enhancements

**Required Additions:**

**1. JVM Arguments for Java 24 Compatibility:**

```kotlin
val jvmArgsList = listOf(
    "--add-opens=java.base/java.nio=ALL-UNNAMED",
    "--add-opens=java.base/sun.nio.ch=ALL-UNNAMED",
    "--enable-native-access=ALL-UNNAMED"
)

tasks.withType<Test> {
    jvmArgs = jvmArgsList
}

tasks.withType<JavaExec> {
    jvmArgs = jvmArgsList
}

tasks.named<org.springframework.boot.gradle.tasks.run.BootRun>("bootRun") {
    jvmArgs = jvmArgsList
}
```

**2. Java Version from libs.versions.toml:**

```kotlin
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(libs.versions.java.get().toInt()))
    }
}
```

---

### 2.3 Fix Add-On Documentation

#### Rename webflux.md → webclient.md

**Problem**: Name implies full reactive web support, but currency-service only uses WebClient for HTTP client calls in servlet application.

**Solution**: Rename and clarify scope

**New File**: `docs/add-ons/webclient.md`

**Content Structure:**
```markdown
# Add-On: WebClient (Spring WebFlux HTTP Client)

## Purpose
Adds Spring WebFlux's `WebClient` for making HTTP requests to external APIs.
This does NOT convert your service to reactive architecture - it only adds
the HTTP client capability.

## Use Case
- Calling external REST APIs (e.g., FRED API in currency-service)
- Modern replacement for RestTemplate
- Non-blocking HTTP client in servlet applications

## Important Notes
- Your service remains servlet-based (Spring Boot Web)
- Only WebClient is used, NOT reactive web controllers
- You CANNOT mix reactive controllers with servlet controllers

## Dependencies
[... show dependencies and configuration ...]
```

---

#### Add New Add-Ons Based on Currency-Service

**1. testcontainers.md**

```markdown
# Add-On: TestContainers

## Purpose
Integration testing with real PostgreSQL database using Docker containers

## Dependencies
- TestContainers Core
- TestContainers PostgreSQL
- TestContainers JUnit Jupiter

## Configuration
[... show test configuration, examples ...]
```

**2. spring-modulith.md**

```markdown
# Add-On: Spring Modulith

## Purpose
Define application module boundaries and enable event-driven communication
between modules

## Use Cases
- Domain-driven design enforcement
- Internal event publishing/subscribing
- Module dependency management

## Dependencies
[... show dependencies and configuration ...]
```

**3. scheduling.md**

```markdown
# Add-On: Task Scheduling

## Purpose
Enable scheduled tasks using `@Scheduled` annotation

## Use Cases
- Periodic data imports (e.g., currency-service exchange rate import)
- Cleanup jobs
- Report generation

## Configuration
- Enable with `@EnableScheduling`
- Configure thread pool
- Cron expression examples

[... show configuration and examples ...]
```

---

#### Enhance postgresql-flyway.md

**Current State**: Basic PostgreSQL + Flyway setup

**Required Additions**:

**Section: Base Entity Classes**

```markdown
## Using Service-Common Base Entity Classes

Service-common provides base entity classes for common patterns:

### AuditableEntity
Automatically tracks creation and modification timestamps.

```java
public abstract class AuditableEntity {
    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;
}
```

**Usage:**
```java
@Entity
@Table(name = "transactions")
public class Transaction extends AuditableEntity {
    // Your fields here
    // createdAt and updatedAt inherited
}
```

### SoftDeletableEntity
Extends AuditableEntity with soft-delete support.

```java
public abstract class SoftDeletableEntity extends AuditableEntity {
    private Boolean deleted = false;
    private Instant deletedAt;
}
```

**Migration Template with Auditable Columns:**

```sql
CREATE TABLE example_table (
    id BIGSERIAL PRIMARY KEY,

    -- Your business columns
    name VARCHAR(255) NOT NULL,

    -- Audit columns (if extending AuditableEntity)
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Soft delete columns (if extending SoftDeletableEntity)
    deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP
);

-- Indexes for soft-delete queries
CREATE INDEX idx_example_table_deleted ON example_table(deleted);
```

## JPA Repository Patterns

For soft-deletable entities, use the `SoftDeleteOperations` interface from service-common:

```java
@Repository
public interface ExampleRepository extends JpaRepository<Example, Long>,
                                           SoftDeleteOperations<Example> {
    // Inherits soft-delete methods
}
```
```

---

#### Enhance springdoc-openapi.md

**Required Addition**:

```markdown
## Using BaseOpenApiConfig from Service-Common

Service-common provides `BaseOpenApiConfig` with standard OpenAPI configuration.

### Extending BaseOpenApiConfig

```java
@Configuration
public class OpenApiConfig extends BaseOpenApiConfig {

    @Override
    protected Info apiInfo() {
        return new Info()
            .title("{SERVICE_NAME} API")
            .description("API documentation for {SERVICE_NAME}")
            .version("1.0.0")
            .contact(new Contact()
                .name("Budget Analyzer Team")
                .email("team@budgetanalyzer.org"));
    }
}
```

### What BaseOpenApiConfig Provides
- Standard security schemes
- Common response codes
- Server configuration
- OpenAPI 3.0 spec generation

### Customization Points
- API info (title, description, version)
- Custom security requirements
- Additional servers
- Global operation filters
```

---

### 2.4 Include Actual Config Files in Template

**Objective**: Template should include complete, working configuration files

**Files to Include:**

1. **`.editorconfig`**
   - Source: `/workspace/transaction-service/.editorconfig`
   - Action: Copy complete content to template
   - No placeholders needed

2. **`config/checkstyle/checkstyle.xml`**
   - Source: `/workspace/transaction-service/config/checkstyle/checkstyle.xml`
   - Action: Copy complete 28KB Google Java Style file to template
   - Alternative: Reference centralized location if available

3. **Test Configuration Examples**

   **`src/test/resources/application.yml`**:
   ```yaml
   spring:
     datasource:
       url: jdbc:postgresql://localhost:5432/test_{DATABASE_NAME}
     jpa:
       hibernate:
         ddl-auto: create-drop
     flyway:
       enabled: false

   logging:
     level:
       org.budgetanalyzer: DEBUG

   budgetanalyzer:
     {SERVICE_NAME}:
       # Service-specific test properties
   ```

4. **Example Test Classes**

   **`src/test/java/org/budgetanalyzer/{DOMAIN_NAME}/ApplicationTests.java`**:
   ```java
   @SpringBootTest
   class ApplicationTests {
       @Test
       void contextLoads() {
       }
   }
   ```

---

### 2.5 Update Phase 1 Tasks in Plan

**Current Phase 1 (in original plan)**: "Service-Common Evaluation & Refactoring"

**Problem**: Tasks assume discovery work, but service-common already has established patterns

**Updated Phase 1 Title**: "Service-Common Audit & Standardization"

**Updated Tasks:**

1. ~~Identify which require Web/JPA dependencies~~ → **Audit existing conditional autoconfiguration**
   - Verify `@ConditionalOnWebApplication` on `DefaultApiExceptionHandler`
   - Verify `@ConditionalOnProperty` on `HttpLoggingConfig`
   - Document any other conditional patterns

2. ~~Document autoconfiguration patterns~~ → **Document established autoconfiguration patterns**
   - Already implemented, need to document for template users

3. **NEW: Migrate existing services to standardized patterns**
   - Fix transaction-service configuration namespace (budget-analyzer → budgetanalyzer)
   - Update both services to use libs.versions.toml for Java version
   - Verify consistency across services

4. Test service-common compilation modes → **Keep as-is**

5. **NEW: Extract and document existing config files**
   - .editorconfig from transaction-service
   - checkstyle.xml from transaction-service
   - JVM args pattern
   - Test configuration patterns

**Timeline Adjustment**: Phase 1 remains 1-2 days but with different focus

---

## Phase 3: Enhance Robustness & Documentation

### 3.1 Improve Placeholder Replacement Algorithm

**Current State (Appendix B)**: Uses bash `sed` commands

**Issues Identified:**
1. GNU sed syntax may not work on macOS (requires `sed -i ''` vs `sed -i`)
2. No error handling for partial replacements
3. Could corrupt binary files (gradlew, gradle-wrapper.jar)
4. No validation that all placeholders were replaced

**Improvements:**

**1. Add Platform Detection:**
```bash
# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE="sed -i ''"
else
    SED_INPLACE="sed -i"
fi
```

**2. Exclude Binary Files:**
```bash
# Find text files only, exclude binaries
find . -type f \
    ! -path "*/gradle-wrapper.jar" \
    ! -path "*/gradlew" \
    ! -path "*/gradlew.bat" \
    ! -path "*/.git/*" \
    -exec grep -Il . {} \; | while read file; do
    # Apply replacements only to text files
    $SED_INPLACE "s/{SERVICE_NAME}/$SERVICE_NAME/g" "$file"
done
```

**3. Add Validation:**
```bash
# Verify all placeholders were replaced
REMAINING=$(grep -r "\{SERVICE_NAME\}\|\{DOMAIN_NAME\}\|\{DATABASE_NAME\}" . \
    --exclude-dir=.git \
    --exclude="gradlew*" \
    --exclude="*.jar" || true)

if [[ -n "$REMAINING" ]]; then
    echo "ERROR: Unreplaced placeholders found:"
    echo "$REMAINING"
    exit 1
fi
```

**4. Add Rollback Capability:**
```bash
# Create backup before replacement
BACKUP_DIR="/tmp/template-backup-$(date +%s)"
cp -r "$REPO_DIR" "$BACKUP_DIR"

echo "Backup created at: $BACKUP_DIR"
echo "To rollback: rm -rf $REPO_DIR && mv $BACKUP_DIR $REPO_DIR"
```

---

### 3.2 Add Missing Documentation Sections

#### Prerequisites Enhancement

**Current State**: Lists git, gh CLI, Java, Gradle

**Required Additions:**

```markdown
## Prerequisites

### Required Tools
- **Git** (2.30+): Version control
- **GitHub CLI** (2.0+): Repository creation
  - Must be authenticated: `gh auth login`
  - Requires `GITHUB_TOKEN` for API access
- **Java** (JDK 24+): Development
- **Gradle** (8.5+): Build tool (or use wrapper)
- **Docker** (20.10+): Running services locally
- **Docker Compose** (2.0+): Orchestration
- **PostgreSQL Client** (14+): Database testing
  - `psql` command must be available
- **Bash** (4.0+): Script execution
  - Note: macOS ships with Bash 3.2, may need to upgrade

### Environment Variables
- `GITHUB_TOKEN`: GitHub API token (auto-set by `gh auth login`)
- Optional: `DB_USERNAME`, `DB_PASSWORD` for PostgreSQL

### Verification Commands
```bash
# Verify prerequisites
git --version                # Should be 2.30+
gh --version                 # Should be 2.0+
java -version                # Should be JDK 24+
gradle --version             # Should be 8.5+
docker --version             # Should be 20.10+
docker compose version       # Should be 2.0+
psql --version              # Should be 14+
bash --version              # Should be 4.0+
```

### Prerequisites Check Script
The creation script includes an automatic prerequisites check that will
verify all required tools before proceeding.
```

---

#### Template Versioning Strategy

**Add New Section to Phase 5 Documentation:**

```markdown
## Template Versioning Strategy

### Semantic Versioning
The template repository follows semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes requiring manual migration
- **MINOR**: New features, add-ons, non-breaking enhancements
- **PATCH**: Bug fixes, documentation updates

### Version Tags
Template versions are tagged in the GitHub repository:
```bash
git tag -a v1.0.0 -m "Initial microservice template"
git push origin v1.0.0
```

### Changelog Format
All changes documented in `CHANGELOG.md`:

```markdown
## [1.1.0] - 2024-XX-XX
### Added
- TestContainers add-on documentation
- Spring Modulith add-on documentation

### Changed
- Enhanced PostgreSQL add-on with base entity documentation

### Fixed
- Corrected package naming in placeholder examples
```

### Template Updates Communication
- Major version changes: Email to team + ADR document
- Minor version changes: Slack announcement + changelog link
- Patch version changes: Changelog update only

### Upgrading Services to Newer Templates
**Important**: Services generated from template are independent. Template
updates do NOT automatically apply to existing services.

**To apply template improvements to existing service:**
1. Review changelog for desired changes
2. Manually apply relevant updates to service
3. Test thoroughly before deploying

**Future Consideration**: Template upgrade automation script
```

---

#### Configuration Namespace Standard Documentation

**Add to Phase 5 Documentation:**

```markdown
## Configuration Namespace Standard

All Budget Analyzer microservices follow a consistent configuration namespace pattern.

### Root Namespace: `budgetanalyzer`
All configuration properties use `budgetanalyzer` (no hyphens) as the root namespace.

### Service-Common Configurations
Properties that configure service-common features use:
```yaml
budgetanalyzer:
  service:
    {feature-name}:
      # Configuration properties
```

**Example - HTTP Logging (from service-common):**
```yaml
budgetanalyzer:
  service:
    http-logging:
      enabled: true
      log-level: DEBUG
      include-request-body: true
      include-response-body: true
      max-body-size: 10000
      exclude-patterns:
        - /actuator/**
```

### Service-Specific Configurations
Properties specific to individual services use:
```yaml
budgetanalyzer:
  {service-name}:
    # Service-specific properties
```

**Example - Transaction Service:**
```yaml
budgetanalyzer:
  transaction-service:
    csv-config-map:
      capital-one:
        date-column: "Transaction Date"
        description-column: "Description"
        # ...
```

**Example - Currency Service:**
```yaml
budgetanalyzer:
  currency-service:
    exchange-rate-import:
      cron: "0 0 23 * * ?"
      import-on-startup: true
      fred:
        base-url: "https://api.stlouisfed.org/fred"
        api-key: ${FRED_API_KEY}
```

### Java Configuration Properties Classes

**Service-Common Feature:**
```java
@ConfigurationProperties(prefix = "budgetanalyzer.service.http-logging")
public class HttpLoggingProperties {
    // Properties
}
```

**Service-Specific Feature:**
```java
@ConfigurationProperties(prefix = "budgetanalyzer.currency-service.exchange-rate-import")
public class ExchangeRateImportProperties {
    // Properties
}
```

### Why This Pattern?
1. **Consistent**: All services use same root namespace
2. **Clear Ownership**: `budgetanalyzer.service.*` = shared, `budgetanalyzer.{service}.*` = specific
3. **Prevents Collisions**: Service-specific configs namespaced by service name
4. **IDE Support**: Auto-completion works across all services
```

---

### 3.3 Add Test Structure Details

**Add to Phase 2 Documentation:**

```markdown
## Test Structure and Conventions

### Test Directory Structure
```
src/test/
├── java/org/budgetanalyzer/{DOMAIN_NAME}/
│   ├── ApplicationTests.java                    # Context load test
│   ├── controller/
│   │   └── {Resource}ControllerTest.java       # Controller tests
│   ├── service/
│   │   └── {Feature}ServiceTest.java           # Service tests
│   └── repository/
│       └── {Entity}RepositoryTest.java         # Repository tests
└── resources/
    ├── application.yml                          # Test configuration
    └── db/
        └── test-data.sql                        # Optional test data
```

### Test Naming Conventions

**Unit Tests:**
- `{ClassName}Test.java` for unit tests
- Example: `TransactionServiceTest.java`

**Integration Tests:**
- `{ClassName}IntegrationTest.java` for integration tests
- Example: `TransactionRepositoryIntegrationTest.java`

**Controller Tests:**
- `{ResourceName}ControllerTest.java`
- Example: `TransactionControllerTest.java`

### Test Configuration (application.yml)

Standard test configuration that overrides production settings:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/test_{DATABASE_NAME}

  jpa:
    hibernate:
      ddl-auto: create-drop  # Recreate schema for each test
    show-sql: true           # Show SQL in test output

  flyway:
    enabled: false           # Disable for unit tests, enable for integration

logging:
  level:
    org.budgetanalyzer: DEBUG
    org.springframework.web: DEBUG

budgetanalyzer:
  {SERVICE_NAME}:
    # Service-specific test overrides
```

### Example Test Classes

**Context Load Test:**
```java
package org.budgetanalyzer.{DOMAIN_NAME};

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ApplicationTests {

    @Test
    void contextLoads() {
        // Verifies Spring context loads successfully
    }
}
```

**Repository Test (with TestContainers):**
```java
package org.budgetanalyzer.{DOMAIN_NAME}.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@DataJpaTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class ExampleRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private ExampleRepository repository;

    @Test
    void testFindAll() {
        // Test repository methods
    }
}
```

**Service Test:**
```java
package org.budgetanalyzer.{DOMAIN_NAME}.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ExampleServiceTest {

    @Mock
    private ExampleRepository repository;

    @InjectMocks
    private ExampleService service;

    @Test
    void testBusinessLogic() {
        // Test service methods with mocked dependencies
    }
}
```
```

---

## Deliverables

### 1. Fixed Transaction-Service
- ✅ Configuration namespaces standardized to `budgetanalyzer.*`
- ✅ Java version managed in `libs.versions.toml`
- ✅ All tests passing
- ✅ Configuration properties classes updated

### 2. Fixed Currency-Service
- ✅ Java version managed in `libs.versions.toml`
- ✅ Configuration already uses correct `budgetanalyzer.*` namespace
- ✅ All tests passing

### 3. Updated Template Plan Document
- ✅ All critical issues resolved
- ✅ Package naming pattern corrected
- ✅ Session-gateway removed with explanation
- ✅ Configuration namespace standard documented
- ✅ Database naming pattern clarified

### 4. Enhanced Add-On Documentation
- ✅ `webclient.md` (renamed from webflux.md)
- ✅ `testcontainers.md` (new)
- ✅ `spring-modulith.md` (new)
- ✅ `scheduling.md` (new)
- ✅ Enhanced `postgresql-flyway.md` with base entity documentation
- ✅ Enhanced `springdoc-openapi.md` with BaseOpenApiConfig usage

### 5. Improved Robustness
- ✅ Platform-aware sed commands (macOS/Linux)
- ✅ Binary file exclusions
- ✅ Placeholder validation
- ✅ Rollback capability
- ✅ Comprehensive prerequisites check
- ✅ Template versioning strategy

### 6. Complete Configuration Files
- ✅ .editorconfig content included
- ✅ checkstyle.xml included
- ✅ Test configuration examples
- ✅ Example test classes

---

## Estimated Timeline

### Phase 1: Fix Existing Services (4-6 hours)
- Fix transaction-service namespace: 2 hours
- Update both services Java version management: 1 hour
- Verify and test: 1-2 hours
- Document patterns: 1 hour

### Phase 2: Update Plan Document (6-8 hours)
- Fix critical issues section: 2 hours
- Add missing configuration patterns: 2 hours
- Update/create add-on documentation: 2-3 hours
- Include config files and examples: 1 hour

### Phase 3: Enhancements (2-4 hours)
- Improve placeholder replacement: 1 hour
- Add missing documentation sections: 1-2 hours
- Add test structure details: 1 hour

**Total: 12-18 hours (1.5-2 days)**

---

## Success Criteria

### Quantitative
- ✅ Both services use `budgetanalyzer.*` root namespace consistently
- ✅ Both services use `libs.versions.toml` for Java version
- ✅ Zero critical issues remaining in template plan
- ✅ All add-ons referenced in plan have documentation
- ✅ 100% of configuration patterns documented
- ✅ All test suites passing after changes

### Qualitative
- ✅ Template plan accurately reflects existing service patterns
- ✅ Session-gateway exception clearly documented
- ✅ Add-on coverage matches actual currency-service usage
- ✅ Placeholder replacement is robust and cross-platform
- ✅ Template versioning strategy is clear and actionable
- ✅ Configuration namespace standard is well-documented with examples

---

## Risks and Mitigation

### Risk 1: Configuration Changes Break Services
**Likelihood**: Medium
**Impact**: High
**Mitigation**:
- Run full test suite after configuration changes
- Test locally with docker-compose before committing
- Make changes in feature branch, review before merge

### Risk 2: Existing Services Diverge Further During Update
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Complete Phase 1 quickly (within 1 day)
- Coordinate with team to pause service development during standardization

### Risk 3: Template Plan Update Introduces New Inconsistencies
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Cross-reference all changes against both existing services
- Have second reviewer validate plan before implementation

---

## Next Steps After Completion

1. **Communicate Changes**: Announce configuration namespace standardization to team
2. **Begin Template Implementation**: Start Phase 2 of original plan (GitHub Template Repository Creation)
3. **Document Lessons Learned**: Create ADR documenting standardization decisions
4. **Plan Future Work**: Consider creating reactive microservice template for gateway services

---

## Appendix: File Checklist

### Files to Modify in Transaction-Service
- [ ] `src/main/resources/application.yml`
- [ ] `src/test/resources/application.yml`
- [ ] `@ConfigurationProperties` classes
- [ ] `gradle/libs.versions.toml`
- [ ] `build.gradle.kts`

### Files to Modify in Currency-Service
- [ ] `gradle/libs.versions.toml`
- [ ] `build.gradle.kts`

### Files to Extract for Template
- [ ] `transaction-service/.editorconfig`
- [ ] `transaction-service/config/checkstyle/checkstyle.xml`

### Plan Document Sections to Update
- [ ] Package naming pattern (add `{DOMAIN_NAME}`)
- [ ] Configuration namespace standard
- [ ] Session-gateway removal
- [ ] Database naming pattern
- [ ] Minimal application.yml
- [ ] Minimal build.gradle.kts
- [ ] Add-on documentation (rename/add files)
- [ ] Phase 1 tasks
- [ ] Placeholder replacement algorithm
- [ ] Prerequisites section
- [ ] Template versioning section
- [ ] Configuration namespace documentation
- [ ] Test structure documentation
