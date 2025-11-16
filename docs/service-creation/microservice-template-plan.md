# Spring Boot Microservice Template & Creation System - Implementation Plan

**Date**: 2025-11-16
**Status**: Planning
**Author**: Architecture Team

## Executive Summary

This plan outlines the creation of a standardized Spring Boot microservice template and creation system for the Budget Analyzer project. The goal is to reduce service creation time from 2-3 hours to ~15 minutes while ensuring consistency across all microservices.

---

## Decision Points

### 1. Service-Common Dependency Strategy: compileOnly vs implementation

**Decision**: To be evaluated during implementation

**Current State**:
- service-common uses `implementation` for Web, JPA, OpenCSV, SpringDoc
- All consuming services inherit these dependencies transitively
- Forces all services to be web services with JPA, even if not needed

**Options**:

**Option A: Use `compileOnly` (Services Opt-In)**
```kotlin
// service-common/build.gradle.kts
dependencies {
    compileOnly(libs.spring.boot.starter.web)
    compileOnly(libs.spring.boot.starter.data.jpa)
    compileOnly(libs.opencsv)
    compileOnly(libs.springdoc.openapi)
}
```

**Pros**:
- Maximum flexibility - services only get what they need
- True minimal baseline (session-gateway might not need JPA)
- No forced dependencies

**Cons**:
- Services must explicitly declare dependencies
- More verbose service build files
- Potential for missing dependencies

**Option B: Use `implementation` (Current State)**
```kotlin
// service-common/build.gradle.kts
dependencies {
    implementation(libs.spring.boot.starter.web)
    implementation(libs.spring.boot.starter.data.jpa)
}
```

**Pros**:
- Less duplication in service build files
- Services automatically get common dependencies
- Simpler for developers

**Cons**:
- Forces dependencies on all services
- Not all services are web services (e.g., batch processors)
- Cannot create truly minimal services

**Option C: Hybrid Approach**
```kotlin
// service-common/build.gradle.kts
dependencies {
    // Core autoconfiguration dependencies (all services need)
    implementation(libs.spring.boot.starter.actuator)

    // Optional dependencies (services opt-in)
    compileOnly(libs.spring.boot.starter.web)
    compileOnly(libs.spring.boot.starter.data.jpa)
    compileOnly(libs.opencsv)
    compileOnly(libs.springdoc.openapi)
}
```

**Pros**:
- Balance between convenience and flexibility
- Actuator always available (needed for health checks)
- Services choose Web/JPA

**Cons**:
- More complex mental model
- Need to document which are implementation vs compileOnly

**Recommendation**: Evaluate during Phase 1 by:
1. Testing Option A with existing services
2. Measuring impact on service build files
3. Deciding based on actual developer experience

---

### 2. Template Source of Truth: GitHub Template Repository

**Decision**: CONFIRMED - GitHub template repository is the source of truth

**Implementation**:
- Create `budget-analyzer/spring-boot-service-template` repository
- Mark as template repository in GitHub settings
- All changes to template structure go through PR process
- Script reads from template to generate services
- Version template with semantic versioning

**Benefits**:
- Single source of truth
- Version control for template changes
- Easy to see template history
- Can fork/clone for experimentation
- GitHub native "Use this template" button for manual use

**Structure**:
```
budget-analyzer/spring-boot-service-template/
├── README.md (usage instructions)
├── TEMPLATE_USAGE.md (detailed guide)
├── template/ (actual template files with placeholders)
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradle/libs.versions.toml
│   ├── src/...
│   └── ...
└── .github/workflows/ (CI for template validation)
```

---

### 3. Build Order: Full Template System First, Test with session-gateway

**Decision**: CONFIRMED - Build complete template system, then scaffold session-gateway

**Rationale**:
- session-gateway is a real production service, not a test
- Better to validate template thoroughly before using for production
- session-gateway requirements inform template design
- Can iterate on template before committing to structure

**Implementation Order**:
1. Build GitHub template repository
2. Create interactive creation script
3. Document add-on patterns
4. Test template with throwaway test services
5. Scaffold session-gateway using validated template
6. Iterate based on session-gateway learnings

---

## Implementation Phases

### Phase 1: Service-Common Evaluation & Refactoring

**Duration**: 1-2 days

**Tasks**:

1. **Analyze Current Service-Common Usage**
   - List all classes/beans in service-common
   - Identify which require Web/JPA dependencies
   - Document autoconfiguration patterns
   - Review exception handling requirements

2. **Test compileOnly Pattern**
   - Create branch: `experiment/compileonly-deps`
   - Change Web/JPA to `compileOnly`
   - Add `@ConditionalOnClass` to autoconfiguration
   - Build service-common
   - Test with transaction-service (add explicit deps)
   - Test with currency-service (add explicit deps)
   - Measure impact on service build files

3. **Decision**
   - Review pros/cons based on actual experience
   - Choose: Option A (compileOnly), B (implementation), or C (hybrid)
   - Document decision in ADR
   - Implement chosen approach

4. **Deliverables**
   - Updated service-common with chosen pattern
   - ADR: `docs/decisions/005-service-common-dependency-strategy.md`
   - Published service-common to mavenLocal
   - Updated existing services if needed

---

### Phase 2: GitHub Template Repository Creation

**Duration**: 2-3 days

**Tasks**:

1. **Create Repository**
   - Repository name: `budget-analyzer/spring-boot-service-template`
   - Visibility: Private
   - Enable template repository setting
   - Add standard labels, branch protection

2. **Minimal Template Structure**

   **Root files**:
   ```
   .editorconfig
   .gitignore
   LICENSE
   README.md
   CLAUDE.md
   TEMPLATE_USAGE.md
   build.gradle.kts
   settings.gradle.kts
   gradlew
   gradlew.bat
   ```

   **Gradle configuration**:
   ```
   gradle/
   ├── libs.versions.toml (MINIMAL - core versions only)
   └── wrapper/
       ├── gradle-wrapper.jar
       └── gradle-wrapper.properties (Gradle 8.14.2)
   ```

   **Code quality**:
   ```
   config/
   └── checkstyle/
       └── checkstyle.xml
   ```

   **Source structure**:
   ```
   src/
   ├── main/
   │   ├── java/org/budgetanalyzer/{SERVICE_NAME}/
   │   │   ├── {ServiceName}Application.java
   │   │   ├── api/          # Controllers, DTOs
   │   │   ├── config/       # Configuration classes
   │   │   ├── domain/       # Entities, enums
   │   │   ├── repository/   # Data access
   │   │   └── service/      # Business logic
   │   └── resources/
   │       └── application.yml
   └── test/
       ├── java/org/budgetanalyzer/{SERVICE_NAME}/
       │   └── {ServiceName}ApplicationTests.java
       └── resources/
           └── application.yml
   ```

   **GitHub workflows**:
   ```
   .github/
   ├── CODEOWNERS
   ├── PULL_REQUEST_TEMPLATE.md
   ├── dependabot.yml
   └── workflows/
       └── build.yml (validate template builds)
   ```

3. **Placeholder System**

   **Placeholders**:
   - `{SERVICE_NAME}` → kebab-case service name (e.g., `session-gateway`)
   - `{SERVICE_CLASS_NAME}` → PascalCase class name (e.g., `SessionGateway`)
   - `{SERVICE_PORT}` → Port number (e.g., `8083`)
   - `{DATABASE_NAME}` → Database name (e.g., `session_gateway`)
   - `{SERVICE_COMMON_VERSION}` → service-common version (e.g., `0.0.1-SNAPSHOT`)
   - `{JAVA_VERSION}` → Java version (e.g., `24`)

   **Files with placeholders**:
   - `settings.gradle.kts`: rootProject.name
   - `gradle/libs.versions.toml`: serviceCommon version, java version
   - `src/main/resources/application.yml`: server.port, context-path, application.name
   - `src/main/java/.../Application.java`: package, class name
   - `CLAUDE.md`: Service name, port references
   - `README.md`: Service name, descriptions

4. **Minimal Dependencies**

   **libs.versions.toml**:
   ```toml
   [versions]
   java = "{JAVA_VERSION}"
   springBoot = "3.5.7"
   dependencyManagement = "1.1.7"
   spotless = "8.0.0"
   checkstyle = "12.0.1"
   googleJavaFormat = "1.32.0"
   junitPlatform = "1.12.2"
   serviceCommon = "{SERVICE_COMMON_VERSION}"

   [plugins]
   spring-boot = { id = "org.springframework.boot", version.ref = "springBoot" }
   spring-dependency-management = { id = "io.spring.dependency-management", version.ref = "dependencyManagement" }
   spotless = { id = "com.diffplug.spotless", version.ref = "spotless" }

   [libraries]
   # Core dependencies
   spring-boot-starter-actuator = { module = "org.springframework.boot:spring-boot-starter-actuator" }
   service-common = { module = "org.budgetanalyzer:service-common", version.ref = "serviceCommon" }

   # Test dependencies
   spring-boot-starter-test = { module = "org.springframework.boot:spring-boot-starter-test" }
   junit-platform-launcher = { module = "org.junit.platform:junit-platform-launcher", version.ref = "junitPlatform" }

   # Common dependencies (add as needed)
   spring-boot-starter-web = { module = "org.springframework.boot:spring-boot-starter-web" }
   spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
   spring-boot-starter-validation = { module = "org.springframework.boot:spring-boot-starter-validation" }
   ```

   **build.gradle.kts** (absolute minimum):
   ```kotlin
   dependencies {
       implementation(libs.service.common)
       implementation(libs.spring.boot.starter.actuator)

       testImplementation(libs.spring.boot.starter.test)
       testRuntimeOnly(libs.junit.platform.launcher)
   }
   ```

5. **Template Validation**
   - GitHub Actions workflow validates template builds
   - Runs spotlessCheck, checkstyleMain
   - Runs tests
   - Ensures template is always in working state

6. **Documentation**
   - README.md: Template overview, features
   - TEMPLATE_USAGE.md: Detailed usage instructions
   - CLAUDE.md template with placeholder sections
   - CODEOWNERS: Assign template ownership

7. **Deliverables**
   - GitHub template repository created and configured
   - Template builds successfully
   - CI/CD pipeline validates template
   - Documentation complete

---

### Phase 3: Add-On Documentation

**Duration**: 2-3 days

**Location**: `/workspace/orchestration/docs/service-creation/addons/`

**Add-On Guides**:

1. **postgresql-flyway.md**
   - Purpose: Database persistence with schema migration
   - Dependencies to add (libs.versions.toml + build.gradle.kts)
   - Configuration (application.yml)
   - Directory structure (db/migration/)
   - Initial migration template
   - Testing with H2 vs TestContainers
   - Base entity classes (AuditableEntity, SoftDeletableEntity)

2. **redis.md**
   - Purpose: Caching and session storage
   - Dependencies
   - Configuration
   - Cache configuration class
   - Common caching patterns
   - Testing with TestContainers

3. **rabbitmq-spring-cloud.md**
   - Purpose: Event-driven messaging
   - Dependencies (Spring Cloud Stream, Spring Modulith)
   - Configuration (exchanges, bindings)
   - Event publishing patterns
   - Event consumption patterns
   - Testing with TestContainers

4. **webflux.md**
   - Purpose: Reactive programming and external API calls
   - Dependencies
   - WebClient configuration
   - Common patterns (REST calls, error handling)
   - Testing

5. **shedlock.md**
   - Purpose: Distributed scheduled task locking
   - Dependencies
   - Configuration
   - Database migration for shedlock table
   - Usage with @SchedulerLock

6. **springdoc-openapi.md**
   - Purpose: API documentation
   - Dependencies
   - Configuration (OpenApiConfig)
   - Annotations for documentation
   - Accessing Swagger UI

7. **spring-security.md** (future)
   - Purpose: Authentication and authorization
   - Dependencies
   - Security configuration
   - Common patterns

**Each guide includes**:
- Use cases and when to use
- Step-by-step dependency addition
- Configuration examples
- Code examples
- Testing approach
- Links to official documentation

**Deliverables**:
- All add-on guides completed
- Index document: `addons/README.md`
- Reviewed and validated

---

### Phase 4: Interactive Creation Script

**Duration**: 3-4 days

**Script**: `/workspace/orchestration/scripts/create-service.sh`

**Features**:

1. **Interactive Prompts**
   ```bash
   Service name (e.g., 'session-gateway'):
   Service port (e.g., 8083):
   Java version [24]:
   service-common version [0.0.1-SNAPSHOT]:
   PostgreSQL database name (leave empty for shared 'budget_analyzer'):
   ```

2. **Add-On Selection**
   ```bash
   Select add-ons (y/n):
   [ ] PostgreSQL + Flyway
   [ ] Redis caching
   [ ] RabbitMQ messaging (includes Spring Cloud/Modulith)
   [ ] WebFlux (reactive HTTP client)
   [ ] ShedLock (distributed scheduling)
   [ ] SpringDoc OpenAPI
   [ ] Spring Security (future)
   ```

3. **Validation**
   - Service name: lowercase, alphanumeric + hyphens, starts with letter
   - Port: number between 1024-65535, not already in use
   - Database name: valid PostgreSQL identifier
   - Versions: semantic version format

4. **Generation Process**
   ```bash
   1. Clone GitHub template repository
   2. Replace all placeholders in files
   3. Rename directories (org/budgetanalyzer/{SERVICE_NAME})
   4. Apply selected add-ons:
      - Add dependencies to libs.versions.toml
      - Add dependencies to build.gradle.kts
      - Add configuration to application.yml
      - Create necessary directories (db/migration, etc.)
      - Create template files (migrations, configs, etc.)
   5. Initialize git repository
   6. Create initial commit
   7. Optionally create GitHub repository
   8. Run build validation (./gradlew clean build)
   9. Report success/failure
   ```

5. **GitHub Integration**
   - Use `gh` CLI for repository creation
   - Set repository to private
   - Push initial commit
   - Set up branch protection (optional)

6. **Post-Generation**
   - Print summary of created service
   - Show next steps (add to docker-compose.yml, configure nginx, etc.)
   - Provide links to relevant documentation

7. **Error Handling**
   - Validate all inputs before proceeding
   - Check prerequisites (git, gh CLI, Java, Gradle)
   - Rollback on failure (clean up generated files)
   - Provide helpful error messages

**Deliverables**:
- Fully functional create-service.sh script
- Script tested with multiple scenarios
- Error handling comprehensive
- Documentation for script usage

---

### Phase 5: Documentation & ADRs

**Duration**: 1-2 days

**Documents to Create**:

1. **ADR: Service-Common Dependency Strategy**
   - File: `docs/decisions/005-service-common-dependency-strategy.md`
   - Content: Decision from Phase 1, rationale, consequences

2. **ADR: Java Version Management**
   - File: `docs/decisions/006-java-version-management.md`
   - Content: Using libs.versions.toml for Java version
   - Upgrade process documentation

3. **Service Creation Guide**
   - File: `docs/service-creation/README.md`
   - Content: Complete guide to creating services
   - When to use script vs manual template
   - Common patterns and best practices

4. **Update Orchestration CLAUDE.md**
   - Add "Service Creation Workflow" section
   - Link to template repository
   - Link to add-on documentation
   - Quick reference for common operations

5. **Standardized CLAUDE.md Template**
   - File: `templates/CLAUDE.md.template`
   - Standard sections all services should have
   - Placeholder-driven for easy customization

**Deliverables**:
- All documentation complete
- Cross-references validated
- Discovery commands tested
- Reviewed for clarity

---

### Phase 6: Testing & Validation

**Duration**: 2-3 days

**Test Scenarios**:

1. **Minimal Service**
   ```bash
   ./create-service.sh
   # Name: test-minimal
   # Port: 9990
   # Add-ons: None
   ```
   - Verify builds
   - Verify runs (./gradlew bootRun)
   - Verify actuator endpoints work
   - Verify service-common autoconfiguration works

2. **PostgreSQL Service**
   ```bash
   ./create-service.sh
   # Name: test-postgresql
   # Port: 9991
   # Add-ons: PostgreSQL + Flyway
   ```
   - Verify database connection
   - Verify Flyway migrations run
   - Verify JPA repositories work
   - Verify soft-delete pattern works

3. **Full-Featured Service**
   ```bash
   ./create-service.sh
   # Name: test-full
   # Port: 9992
   # Add-ons: All
   ```
   - Verify all dependencies resolve
   - Verify builds successfully
   - Verify all autoconfiguration activates
   - Verify no conflicts between add-ons

4. **Manual Template Usage**
   - Use GitHub "Use this template" button
   - Clone repository
   - Manually replace placeholders
   - Verify builds

5. **GitHub Template Validation**
   - Verify CI/CD pipeline passes
   - Verify template repository builds
   - Verify no broken links in documentation

6. **Code Quality**
   - Run spotlessCheck on generated services
   - Run checkstyleMain on generated services
   - Verify no warnings/errors

**Deliverables**:
- All test scenarios pass
- Issues documented and fixed
- Template validated as production-ready

---

### Phase 7: session-gateway Scaffolding

**Duration**: 1 day

**Process**:

1. **Run Creation Script**
   ```bash
   cd /workspace/orchestration
   ./scripts/create-service.sh
   ```

2. **Configuration**
   - Service name: `session-gateway`
   - Port: `8083`
   - Java version: `24`
   - service-common version: `0.0.1-SNAPSHOT`
   - Database: `budget_analyzer` (shared)
   - Add-ons:
     - ✓ PostgreSQL + Flyway (for session storage)
     - ✓ Redis (for token caching)
     - ✓ SpringDoc OpenAPI (for API docs)
     - ? WebFlux (for OAuth HTTP calls - TBD)
     - ? Spring Security (for auth - TBD)

3. **Validation**
   - Review generated structure
   - Verify builds successfully
   - Verify runs locally
   - Run tests

4. **Integration**
   - Add to orchestration docker-compose.yml
   - Configure nginx routing (if needed)
   - Update orchestration documentation

5. **Implementation**
   - Implement session management logic
   - Add OAuth flow handling
   - Add token storage/retrieval
   - Add session cookie management
   - Write tests

6. **Learnings**
   - Document any template improvements needed
   - Update template based on experience
   - Update documentation based on gaps found

**Deliverables**:
- session-gateway service scaffolded and functional
- Integrated into orchestration
- Template updated based on learnings

---

## Success Criteria

### Quantitative Metrics

1. **Service Creation Time**
   - Baseline: 2-3 hours (manual setup)
   - Target: < 15 minutes (with script)

2. **Template Consistency**
   - All new services use template: 100%
   - Code quality checks pass: 100%
   - Build success rate: 100%

3. **Documentation Coverage**
   - All add-ons documented: 100%
   - All discovery commands tested: 100%
   - No broken links: 100%

### Qualitative Metrics

1. **Developer Experience**
   - Survey rating: > 4.5/5
   - Ease of use: High
   - Documentation clarity: High

2. **Maintainability**
   - Template ownership assigned
   - Update process documented
   - Version control in place

3. **Adoption**
   - session-gateway uses template
   - All future services use template
   - Team trained on process

---

## Risks & Mitigation

### Risk 1: service-common Breaking Changes

**Impact**: Existing services fail to build

**Likelihood**: Medium

**Mitigation**:
- Semantic versioning for service-common
- Test with all existing services before publishing
- Document migration path
- Maintain backward compatibility where possible

### Risk 2: Template Drift

**Impact**: Template becomes outdated

**Likelihood**: High (over time)

**Mitigation**:
- Assign template owner
- Regular review cadence (quarterly)
- Update template when patterns change
- Version template with changelog

### Risk 3: Script Bugs

**Impact**: Generated services don't work

**Likelihood**: Medium

**Mitigation**:
- Comprehensive testing before production use
- Build validation in script
- Error handling and rollback
- Manual template option available

### Risk 4: Add-On Conflicts

**Impact**: Some add-on combinations don't work together

**Likelihood**: Low

**Mitigation**:
- Test common combinations
- Document known conflicts
- Validation in script for incompatible combinations

---

## Timeline

**Total Duration**: 2-3 weeks

```
Week 1:
├── Phase 1: Service-Common Evaluation (2 days)
├── Phase 2: GitHub Template Creation (3 days)

Week 2:
├── Phase 3: Add-On Documentation (3 days)
├── Phase 4: Creation Script (2 days)

Week 3:
├── Phase 4: Script Testing (2 days)
├── Phase 5: Documentation (2 days)
├── Phase 6: Testing & Validation (2 days)
├── Phase 7: session-gateway Scaffolding (1 day)
```

**Critical Path**: Phase 1 → Phase 2 → Phase 4 → Phase 7

**Parallel Work**: Phase 3 can happen alongside Phase 4

---

## Next Steps

1. **Review this plan** with team and stakeholders
2. **Prioritize phases** based on immediate needs
3. **Assign ownership** for each phase
4. **Begin Phase 1**: Service-Common evaluation
5. **Schedule reviews** at end of each phase
6. **Iterate** based on learnings

---

## Appendix A: Java Version Management Strategy

**Current State**:
- All services use Java 24
- Specified in each service's build.gradle.kts
- Gradle toolchain manages JDK

**Proposed Strategy**:

1. **Define in libs.versions.toml**:
   ```toml
   [versions]
   java = "24"
   ```

2. **Reference in build.gradle.kts**:
   ```kotlin
   java {
       toolchain {
           languageVersion = JavaLanguageVersion.of(libs.versions.java.get().toInt())
       }
   }
   ```

3. **Upgrade Process**:
   - Update `java` version in libs.versions.toml
   - Test service builds
   - Test service runs
   - Update JVM args if needed (--add-opens, etc.)
   - Commit change

**Benefits**:
- Single source of truth per service
- Easy to see current version
- Simple upgrade process
- Can upgrade services individually or all at once

**Note**: This is per-service versioning. Cross-service version management would require shared version catalog or composite build (future enhancement).

---

## Appendix B: Placeholder Replacement Algorithm

**String Replacement**:
```bash
# Service name conversions
SERVICE_NAME="session-gateway"
SERVICE_CLASS_NAME=$(echo $SERVICE_NAME | sed -r 's/(^|-)([a-z])/\U\2/g')  # SessionGateway
SERVICE_PACKAGE=$(echo $SERVICE_NAME | tr '-' '')  # sessiongateway

# File content replacement
find "$SERVICE_DIR" -type f -exec sed -i \
    -e "s/{SERVICE_NAME}/$SERVICE_NAME/g" \
    -e "s/{SERVICE_CLASS_NAME}/$SERVICE_CLASS_NAME/g" \
    -e "s/{SERVICE_PACKAGE}/$SERVICE_PACKAGE/g" \
    -e "s/{SERVICE_PORT}/$SERVICE_PORT/g" \
    -e "s/{DATABASE_NAME}/$DATABASE_NAME/g" \
    -e "s/{SERVICE_COMMON_VERSION}/$SERVICE_COMMON_VERSION/g" \
    -e "s/{JAVA_VERSION}/$JAVA_VERSION/g" \
    {} \;
```

**Directory Renaming**:
```bash
# Rename Java package directories
mv "$SERVICE_DIR/src/main/java/org/budgetanalyzer/template" \
   "$SERVICE_DIR/src/main/java/org/budgetanalyzer/$SERVICE_PACKAGE"

mv "$SERVICE_DIR/src/test/java/org/budgetanalyzer/template" \
   "$SERVICE_DIR/src/test/java/org/budgetanalyzer/$SERVICE_PACKAGE"
```

**File Renaming**:
```bash
# Rename Application class
mv "$SERVICE_DIR/src/main/java/org/budgetanalyzer/$SERVICE_PACKAGE/TemplateApplication.java" \
   "$SERVICE_DIR/src/main/java/org/budgetanalyzer/$SERVICE_PACKAGE/${SERVICE_CLASS_NAME}Application.java"

mv "$SERVICE_DIR/src/test/java/org/budgetanalyzer/$SERVICE_PACKAGE/TemplateApplicationTests.java" \
   "$SERVICE_DIR/src/test/java/org/budgetanalyzer/$SERVICE_PACKAGE/${SERVICE_CLASS_NAME}ApplicationTests.java"
```

---

## Appendix C: Add-On Application Logic

**PostgreSQL + Flyway Add-On**:
```bash
if [[ $USE_POSTGRESQL =~ ^[Yy]$ ]]; then
    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<EOF

# PostgreSQL + Flyway
spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
spring-boot-starter-validation = { module = "org.springframework.boot:spring-boot-starter-validation" }
flyway-core = { module = "org.flywaydb:flyway-core" }
flyway-database-postgresql = { module = "org.flywaydb:flyway-database-postgresql" }
postgresql = { module = "org.postgresql:postgresql" }
h2 = { module = "com.h2database:h2" }
EOF

    # Add to build.gradle.kts dependencies block
    sed -i '/testRuntimeOnly(libs.junit.platform.launcher)/a \    \n    // PostgreSQL + Flyway\n    implementation(libs.spring.boot.starter.data.jpa)\n    implementation(libs.spring.boot.starter.validation)\n    implementation(libs.flyway.core)\n    implementation(libs.flyway.database.postgresql)\n    runtimeOnly(libs.postgresql)\n    testImplementation(libs.h2)' \
        "$SERVICE_DIR/build.gradle.kts"

    # Add to application.yml
    cat >> "$SERVICE_DIR/src/main/resources/application.yml" <<EOF

spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/${DATABASE_NAME}
    username: budget_analyzer
    password: budget_analyzer
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    database-platform: org.hibernate.dialect.PostgreSQLDialect

  flyway:
    enabled: true
    locations: classpath:db/migration
    validate-on-migrate: true
EOF

    # Create migration directory
    mkdir -p "$SERVICE_DIR/src/main/resources/db/migration"

    # Create initial migration
    cat > "$SERVICE_DIR/src/main/resources/db/migration/V1__initial_schema.sql" <<EOF
-- Initial schema for ${SERVICE_NAME}

-- Example table (customize as needed)
-- CREATE TABLE example (
--     id BIGSERIAL PRIMARY KEY,
--     created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     deleted BOOLEAN NOT NULL DEFAULT FALSE
-- );
EOF
fi
```

**Similar logic for other add-ons**: Redis, RabbitMQ, WebFlux, ShedLock, SpringDoc

---

## Appendix D: session-gateway Specific Requirements

Based on the authentication implementation plan, session-gateway needs:

**Core Functionality**:
- OAuth flow management (authorization code flow)
- Token storage (access + refresh tokens in Redis)
- Session cookie issuance
- Token refresh logic
- Session validation

**Dependencies Needed**:
- ✓ PostgreSQL + Flyway (for session metadata, audit logs)
- ✓ Redis (for token storage, session cache)
- ✓ WebFlux (for OAuth HTTP calls to authorization server)
- ✓ SpringDoc OpenAPI (for API documentation)
- ? Spring Security OAuth2 Client (for OAuth flows)
- ? Spring Session (for session management)

**Port**: 8083

**Key Endpoints**:
- `POST /auth/login` - Initiate OAuth flow
- `GET /auth/callback` - OAuth callback handler
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Invalidate session
- `GET /auth/validate` - Validate session

**Integration Points**:
- NGINX gateway (proxy OAuth flows)
- Redis (shared instance)
- PostgreSQL (shared database or dedicated)
- External OAuth provider (Google, GitHub, etc.)

---

## Conclusion

This plan provides a comprehensive roadmap for creating a standardized Spring Boot microservice template and creation system. The approach prioritizes:

1. **Minimal baseline** with optional add-ons
2. **GitHub template repository** as source of truth
3. **Interactive creation script** for automation
4. **Comprehensive documentation** for all patterns
5. **session-gateway as validation** of the template system

Implementation will proceed in phases, with each phase building on the previous one. The plan balances immediate needs (session-gateway scaffolding) with long-term maintainability (template repository, documentation, automation).

**Key Success Factor**: Completing Phase 1 (service-common evaluation) is critical for determining the final template structure.
