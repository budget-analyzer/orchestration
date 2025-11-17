# {SERVICE_NAME} - {Brief Domain Description}

**Version**: {VERSION}
**Port**: {SERVICE_PORT}
**Database**: {DATABASE_NAME}

## Service Overview

{2-3 sentences describing business domain and service purpose}

**Domain**: {e.g., "Currency exchange rate management and conversion"}
**Responsibilities**:
- {Key responsibility 1}
- {Key responsibility 2}
- {Key responsibility 3}

## Technology Stack

**Framework**: Spring Boot {SPRING_BOOT_VERSION}
**Java Version**: {JAVA_VERSION}
**Build Tool**: Gradle {GRADLE_VERSION}

**Key Dependencies**:
- `service-web` ({SERVICE_COMMON_VERSION}) - Provides Spring Web, JPA, HTTP logging, error handling, OpenAPI config
{LIST_ADDITIONAL_DEPENDENCIES}

## Architecture Patterns

**This service follows standard Budget Analyzer Spring Boot conventions.**

**Shared Patterns** (via service-web):
- Spring MVC architecture (Controller → Service → Repository)
- JPA entities with audit support (AuditableEntity, SoftDeletableEntity)
- API error handling (GlobalExceptionHandler from service-common)
- HTTP request/response logging (configurable via application.yml)
- SafeLogger with @Sensitive annotation for PII protection
- Configuration namespace: `budgetanalyzer.{service-name}.*`

**See**: [service-common documentation](https://github.com/budgetanalyzer/service-common) for detailed patterns

## Service-Specific Patterns

### Package Structure

```
org.budgetanalyzer.{DOMAIN_NAME}/
├── {ServiceClassName}Application.java       # Main application class
├── api/                                     # REST controllers & DTOs
│   ├── {Domain}Controller.java
│   └── dto/
│       ├── {Domain}Request.java
│       └── {Domain}Response.java
├── config/                                  # Configuration classes
│   └── {Feature}Config.java
├── domain/                                  # JPA entities & enums
│   ├── {Domain}.java
│   └── {Domain}Status.java
├── repository/                              # Data access
│   └── {Domain}Repository.java
└── service/                                 # Business logic
    ├── {Domain}Service.java
    └── impl/
        └── {Domain}ServiceImpl.java
```

### API Contracts

**OpenAPI/Swagger UI**: http://localhost:{SERVICE_PORT}/{SERVICE_NAME}/swagger-ui.html

**Discovery**:
```bash
# Start service with Swagger UI
./gradlew bootRun

# Access Swagger UI
open http://localhost:{SERVICE_PORT}/{SERVICE_NAME}/swagger-ui.html

# View health endpoint
curl http://localhost:{SERVICE_PORT}/{SERVICE_NAME}/actuator/health
```

**Key Endpoints**:
- `GET /{SERVICE_NAME}/api/v1/{resource}` - {Description}
- `POST /{SERVICE_NAME}/api/v1/{resource}` - {Description}
- `PUT /{SERVICE_NAME}/api/v1/{resource}/{id}` - {Description}
- `DELETE /{SERVICE_NAME}/api/v1/{resource}/{id}` - {Description}

### Domain Model

**Key Entities**:
- `{Entity1}` (table: `{table_name}`) - {Brief description}
- `{Entity2}` (table: `{table_name}`) - {Brief description}

**Enums**:
- `{EnumName}` - {Brief description}

### Database Schema

**Database Name**: `{DATABASE_NAME}`

**Key Tables**:
- `{table_name}` - {Brief description}
  - Primary columns: `id`, `created_at`, `updated_at`, `deleted`
  - Indexes: {List key indexes}

**Migrations**: Flyway migrations in `src/main/resources/db/migration/`

**Discovery**:
```bash
# List migrations
ls src/main/resources/db/migration/

# Connect to database
docker exec -it postgres psql -U budget_analyzer -d {DATABASE_NAME}

# View tables
\dt
```

### Configuration

**Configuration Namespace**: `budgetanalyzer.{service-name}.*`

**Key Properties** (in `application.yml`):
```yaml
budgetanalyzer:
  service:
    http-logging:
      enabled: true                    # From service-web
  {service-name}:
    {feature-name}:
      property: value                  # Service-specific config
```

**Environment Variables**:
- `DB_USERNAME` - Database username (default: `postgres`)
- `DB_PASSWORD` - Database password (default: `postgres`)
- `SPRING_PROFILES_ACTIVE` - Active Spring profile (dev, prod)

### {Service-Specific Feature}
{If applicable - document unique concerns only}

**Example**: CSV Import, Scheduled Tasks, External API Integration, etc.

{Description of feature and implementation pattern}

## Running Locally

### Prerequisites
- Docker and Docker Compose
- JDK {JAVA_VERSION}+
- Gradle (wrapper included)

### Start Dependencies

```bash
# Navigate to orchestration repository
cd /workspace/orchestration

# Start PostgreSQL and other infrastructure
docker compose up -d postgres
# Add other dependencies as needed: redis, rabbitmq, etc.

# Verify services are running
docker compose ps
```

### Run Service

```bash
# Navigate to service directory
cd /workspace/{service-name}

# Build service
./gradlew clean build

# Run service
./gradlew bootRun

# Or run with specific profile
SPRING_PROFILES_ACTIVE=dev ./gradlew bootRun
```

### Verify Service

```bash
# Health check
curl http://localhost:{SERVICE_PORT}/{SERVICE_NAME}/actuator/health

# Swagger UI
open http://localhost:{SERVICE_PORT}/{SERVICE_NAME}/swagger-ui.html

# Check logs
tail -f logs/application.log
```

## Testing

### Run All Tests

```bash
./gradlew test
```

### Run Specific Test

```bash
./gradlew test --tests {TestClassName}
```

### Test Categories

- **Unit Tests**: `src/test/java/.../service/` - Business logic tests
- **Repository Tests**: `src/test/java/.../repository/` - Data access tests (uses TestContainers)
- **Controller Tests**: `src/test/java/.../api/` - API endpoint tests (uses MockMvc)
- **Integration Tests**: Tests marked with `@SpringBootTest`

### Test Coverage

```bash
./gradlew test jacocoTestReport

# View report
open build/reports/jacoco/test/html/index.html
```

## Discovery Commands

```bash
# Find all REST endpoints
grep -r "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping" src/main/java

# Find all JPA entities
find src/main/java -name "*Entity.java" -o -name "*.java" | xargs grep "@Entity"

# Find all repositories
find src/main/java -name "*Repository.java"

# View configuration
cat src/main/resources/application.yml

# View test configuration
cat src/test/resources/application.yml

# Check dependencies
./gradlew dependencies

# Check dependency tree
./gradlew dependencies --configuration runtimeClasspath

# List Flyway migrations
ls -la src/main/resources/db/migration/

# Check service version
./gradlew properties | grep version

# Check Java version
./gradlew properties | grep "java ="
```

## Building and Deployment

### Build JAR

```bash
./gradlew clean build

# JAR location
ls -lh build/libs/{service-name}-{VERSION}.jar
```

### Docker Build

```bash
# Build image
docker build -t budgetanalyzer/{service-name}:{VERSION} .

# Run container
docker run -p {SERVICE_PORT}:{SERVICE_PORT} \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DB_USERNAME=budget_analyzer \
  -e DB_PASSWORD=budget_analyzer \
  budgetanalyzer/{service-name}:{VERSION}
```

### Via Docker Compose

```bash
# From orchestration repository
cd /workspace/orchestration

# Build and start service
docker compose up -d {service-name}

# View logs
docker compose logs -f {service-name}

# Stop service
docker compose stop {service-name}
```

## Troubleshooting

### Service Won't Start

**Check database connection**:
```bash
docker compose ps postgres
docker compose logs postgres
```

**Check port availability**:
```bash
lsof -i :{SERVICE_PORT}
```

**Check environment variables**:
```bash
env | grep -E "DB_|SPRING_"
```

### Tests Failing

**TestContainers issues**:
```bash
# Verify Docker is running
docker ps

# Check TestContainers logs
tail -f build/test-results/test/*.xml
```

**Database migration issues**:
```bash
# Check migrations
ls src/main/resources/db/migration/

# Verify migration syntax
cat src/main/resources/db/migration/V1__*.sql
```

### Build Fails

**service-web not found**:
```bash
# Publish service-common to Maven Local
cd /workspace/service-common
./gradlew publishToMavenLocal

cd /workspace/{service-name}
./gradlew clean build
```

**Gradle cache issues**:
```bash
./gradlew clean --refresh-dependencies
```

## AI Assistant Guidelines

When working on this service:

1. **Follow service-web patterns** - See [service-common documentation](https://github.com/budgetanalyzer/service-common)
2. **Use SafeLogger** - Mark sensitive data with `@Sensitive` annotation
3. **Test everything** - Write unit, integration, and API tests
4. **Follow package structure** - Keep controllers in `api/`, services in `service/`, repositories in `repository/`
5. **Use configuration namespaces** - All config under `budgetanalyzer.{service-name}.*`
6. **Document endpoints** - Use SpringDoc annotations (@Operation, @Schema, @Tag)
7. **Follow naming conventions** - Class names: `{Domain}Controller`, `{Domain}Service`, `{Domain}Repository`
8. **Write migrations carefully** - Always create new migration, never edit existing ones
9. **Audit entities** - Extend `AuditableEntity` for automatic timestamp tracking
10. **Soft delete** - Extend `SoftDeletableEntity` for logical deletion support

### Service-Specific Guidelines
{Add service-specific guidelines here}

## Related Documentation

### Service-Common
- [service-common repository](https://github.com/budgetanalyzer/service-common)
- [service-web module documentation](https://github.com/budgetanalyzer/service-common/tree/main/service-web)
- [service-core module documentation](https://github.com/budgetanalyzer/service-common/tree/main/service-core)

### Orchestration
- [Orchestration CLAUDE.md](https://github.com/budgetanalyzer/orchestration/blob/main/CLAUDE.md)
- [Service Creation Guide](https://github.com/budgetanalyzer/orchestration/blob/main/docs/service-creation/README.md)
- [Add-On Documentation](https://github.com/budgetanalyzer/orchestration/tree/main/docs/service-creation/addons)
- [NGINX Configuration](https://github.com/budgetanalyzer/orchestration/blob/main/nginx/README.md)

### Spring Boot Template
- [Template Repository](https://github.com/budgetanalyzer/spring-boot-service-template)
- [Template Usage Guide](https://github.com/budgetanalyzer/spring-boot-service-template/blob/main/TEMPLATE_USAGE.md)

### Architecture Decisions
- [ADR 004: Service-Common Dependency Strategy](https://github.com/budgetanalyzer/orchestration/blob/main/docs/decisions/004-service-common-dependency-strategy.md)
- [ADR 005: Java Version Management](https://github.com/budgetanalyzer/orchestration/blob/main/docs/decisions/005-java-version-management.md)

---

**Last Updated**: {DATE}
**Service Version**: {VERSION}
**Template Version**: 1.0.0
