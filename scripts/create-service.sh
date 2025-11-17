#!/bin/bash

################################################################################
# Budget Analyzer - Spring Boot Microservice Creation Script
#
# This script automates the creation of new Spring Boot microservices using
# the standardized template repository.
#
# Usage: ./create-service.sh
#
# The script will:
# 1. Prompt for service details (name, port, domain, etc.)
# 2. Allow selection of add-ons (PostgreSQL, Redis, etc.)
# 3. Clone and customize the template repository
# 4. Apply selected add-ons
# 5. Initialize git repository
# 6. Optionally create GitHub repository
# 7. Validate the generated service builds
#
# Prerequisites:
# - git
# - gh CLI (for GitHub integration)
# - Java 24+
# - Gradle (via wrapper)
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_REPO="https://github.com/budgetanalyzer/spring-boot-service-template.git"
DEFAULT_JAVA_VERSION="24"
DEFAULT_SERVICE_COMMON_VERSION="0.0.1-SNAPSHOT"

# Service configuration (populated by prompts)
SERVICE_NAME=""
DOMAIN_NAME=""
SERVICE_CLASS_NAME=""
SERVICE_PORT=""
DATABASE_NAME=""
JAVA_VERSION=""
SERVICE_COMMON_VERSION=""
SERVICE_DIR=""

# Add-on flags
USE_POSTGRESQL=false
USE_REDIS=false
USE_RABBITMQ=false
USE_WEBFLUX=false
USE_SHEDLOCK=false
USE_SPRINGDOC=false
USE_SECURITY=false

# GitHub integration flags
CREATE_GITHUB_REPO=false
GITHUB_REPO_CREATED=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Budget Analyzer - Spring Boot Microservice Creator${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Validation Functions
################################################################################

validate_service_name() {
    local name="$1"

    # Must be lowercase, alphanumeric + hyphens, start with letter
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        return 1
    fi

    # Must end with -service
    if [[ ! "$name" =~ -service$ ]]; then
        return 1
    fi

    return 0
}

validate_port() {
    local port="$1"

    # Must be a number
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Must be in valid range
    if [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi

    # Check if port is already in use (in docker-compose.yml)
    if grep -q "\"$port:" "$WORKSPACE_DIR/docker-compose.yml" 2>/dev/null; then
        print_warning "Port $port appears to be in use in docker-compose.yml"
        read -p "Continue anyway? (y/n): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || return 1
    fi

    return 0
}

validate_database_name() {
    local name="$1"

    # Allow empty (means shared database)
    if [ -z "$name" ]; then
        return 0
    fi

    # Must be alphanumeric + underscores, start with letter
    if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        return 1
    fi

    return 0
}

validate_version() {
    local version="$1"

    # Basic semantic version check (allows -SNAPSHOT)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Z]+)?$ ]]; then
        return 1
    fi

    return 0
}

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    print_section "Checking Prerequisites"

    local missing_tools=()

    # Check for git
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    else
        print_success "git found: $(git --version)"
    fi

    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        print_warning "gh CLI not found (GitHub integration will be disabled)"
    else
        print_success "gh CLI found: $(gh --version | head -n1)"
    fi

    # Check for Java
    if ! command -v java &> /dev/null; then
        missing_tools+=("java")
    else
        local java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
        print_success "Java found: version $java_version"
    fi

    # Report missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools and try again."
        exit 1
    fi

    echo ""
}

################################################################################
# Interactive Prompts
################################################################################

prompt_service_details() {
    print_section "Service Configuration"

    # Service name
    while true; do
        read -p "Service name (e.g., 'currency-service'): " SERVICE_NAME
        if validate_service_name "$SERVICE_NAME"; then
            break
        else
            print_error "Invalid service name. Must be lowercase, alphanumeric + hyphens, start with letter, and end with '-service'"
        fi
    done

    # Extract default domain name (first word before first hyphen)
    local default_domain=$(echo "$SERVICE_NAME" | sed 's/-service$//' | sed 's/-.*$//')

    # Domain name
    read -p "Domain name [$default_domain] (or specify custom): " DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-$default_domain}

    # Validate domain name
    while [[ ! "$DOMAIN_NAME" =~ ^[a-z][a-z0-9]*$ ]]; do
        print_error "Invalid domain name. Must be lowercase alphanumeric starting with letter"
        read -p "Domain name: " DOMAIN_NAME
    done

    # Generate class name
    SERVICE_CLASS_NAME=$(echo "$DOMAIN_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

    # Service port
    while true; do
        read -p "Service port (e.g., 8082): " SERVICE_PORT
        if validate_port "$SERVICE_PORT"; then
            break
        else
            print_error "Invalid port. Must be a number between 1024-65535 and not in use"
        fi
    done

    # Java version
    read -p "Java version [$DEFAULT_JAVA_VERSION]: " JAVA_VERSION
    JAVA_VERSION=${JAVA_VERSION:-$DEFAULT_JAVA_VERSION}

    # service-common version
    read -p "service-web version [$DEFAULT_SERVICE_COMMON_VERSION]: " SERVICE_COMMON_VERSION
    SERVICE_COMMON_VERSION=${SERVICE_COMMON_VERSION:-$DEFAULT_SERVICE_COMMON_VERSION}

    # Database name
    echo ""
    print_info "PostgreSQL database configuration:"
    print_info "- Leave empty for shared database 'budget_analyzer'"
    print_info "- Default: '$DOMAIN_NAME' (dedicated database)"
    print_info "- Or specify custom database name"
    read -p "Database name (default: $DOMAIN_NAME): " DATABASE_NAME
    DATABASE_NAME=${DATABASE_NAME:-$DOMAIN_NAME}

    while ! validate_database_name "$DATABASE_NAME"; do
        print_error "Invalid database name. Must be lowercase alphanumeric + underscores"
        read -p "Database name: " DATABASE_NAME
    done

    # Set service directory
    SERVICE_DIR="$WORKSPACE_DIR/../$SERVICE_NAME"

    # Summary
    echo ""
    print_section "Configuration Summary"
    echo "Service Name:          $SERVICE_NAME"
    echo "Domain Name:           $DOMAIN_NAME"
    echo "Class Name:            ${SERVICE_CLASS_NAME}Application"
    echo "Service Port:          $SERVICE_PORT"
    echo "Java Version:          $JAVA_VERSION"
    echo "service-web Version:   $SERVICE_COMMON_VERSION"
    echo "Database Name:         $DATABASE_NAME"
    echo "Service Directory:     $SERVICE_DIR"
    echo ""

    read -p "Is this correct? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Configuration rejected. Please restart the script."
        exit 1
    fi
}

prompt_addons() {
    print_section "Add-On Selection"

    echo "Select add-ons to include (y/n):"
    echo ""

    read -p "  PostgreSQL + Flyway (database persistence with migrations) [y/n]: " USE_POSTGRESQL
    [[ "$USE_POSTGRESQL" =~ ^[Yy]$ ]] && USE_POSTGRESQL=true || USE_POSTGRESQL=false

    read -p "  Redis (caching and session storage) [y/n]: " USE_REDIS
    [[ "$USE_REDIS" =~ ^[Yy]$ ]] && USE_REDIS=true || USE_REDIS=false

    read -p "  RabbitMQ + Spring Cloud Stream (event-driven messaging) [y/n]: " USE_RABBITMQ
    [[ "$USE_RABBITMQ" =~ ^[Yy]$ ]] && USE_RABBITMQ=true || USE_RABBITMQ=false

    read -p "  WebFlux WebClient (reactive HTTP client) [y/n]: " USE_WEBFLUX
    [[ "$USE_WEBFLUX" =~ ^[Yy]$ ]] && USE_WEBFLUX=true || USE_WEBFLUX=false

    read -p "  ShedLock (distributed scheduled task locking) [y/n]: " USE_SHEDLOCK
    [[ "$USE_SHEDLOCK" =~ ^[Yy]$ ]] && USE_SHEDLOCK=true || USE_SHEDLOCK=false

    read -p "  SpringDoc OpenAPI (API documentation) [y/n]: " USE_SPRINGDOC
    [[ "$USE_SPRINGDOC" =~ ^[Yy]$ ]] && USE_SPRINGDOC=true || USE_SPRINGDOC=false

    # Spring Security (future)
    # read -p "  Spring Security (authentication and authorization) [y/n]: " USE_SECURITY
    # [[ "$USE_SECURITY" =~ ^[Yy]$ ]] && USE_SECURITY=true || USE_SECURITY=false

    echo ""
    print_section "Selected Add-Ons"
    $USE_POSTGRESQL && echo "  ✓ PostgreSQL + Flyway"
    $USE_REDIS && echo "  ✓ Redis"
    $USE_RABBITMQ && echo "  ✓ RabbitMQ + Spring Cloud Stream"
    $USE_WEBFLUX && echo "  ✓ WebFlux WebClient"
    $USE_SHEDLOCK && echo "  ✓ ShedLock"
    $USE_SPRINGDOC && echo "  ✓ SpringDoc OpenAPI"
    $USE_SECURITY && echo "  ✓ Spring Security"
    echo ""
}

prompt_github_integration() {
    print_section "GitHub Integration"

    if ! command -v gh &> /dev/null; then
        print_warning "gh CLI not found. Skipping GitHub integration."
        CREATE_GITHUB_REPO=false
        return
    fi

    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        print_warning "gh CLI not authenticated. Skipping GitHub integration."
        print_info "Run 'gh auth login' to enable GitHub integration."
        CREATE_GITHUB_REPO=false
        return
    fi

    read -p "Create GitHub repository? (y/n): " CREATE_GITHUB_REPO
    [[ "$CREATE_GITHUB_REPO" =~ ^[Yy]$ ]] && CREATE_GITHUB_REPO=true || CREATE_GITHUB_REPO=false

    echo ""
}

################################################################################
# Template Cloning
################################################################################

clone_template() {
    print_section "Cloning Template Repository"

    # Check if service directory already exists
    if [ -d "$SERVICE_DIR" ]; then
        print_error "Directory $SERVICE_DIR already exists"
        read -p "Delete and continue? (y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        rm -rf "$SERVICE_DIR"
    fi

    # Clone template
    print_info "Cloning template from $TEMPLATE_REPO..."
    if git clone "$TEMPLATE_REPO" "$SERVICE_DIR" --quiet; then
        print_success "Template cloned successfully"
    else
        print_error "Failed to clone template repository"
        exit 1
    fi

    # Remove .git directory
    rm -rf "$SERVICE_DIR/.git"
    print_success "Removed template .git directory"

    echo ""
}

################################################################################
# Placeholder Replacement
################################################################################

replace_placeholders() {
    print_section "Replacing Placeholders"

    print_info "Replacing placeholders in files..."

    # Find all files (excluding binary files) and replace placeholders
    find "$SERVICE_DIR" -type f \( \
        -name "*.java" -o \
        -name "*.kt" -o \
        -name "*.kts" -o \
        -name "*.xml" -o \
        -name "*.yml" -o \
        -name "*.yaml" -o \
        -name "*.properties" -o \
        -name "*.md" -o \
        -name "*.toml" \
    \) -exec sed -i \
        -e "s/{SERVICE_NAME}/$SERVICE_NAME/g" \
        -e "s/{DOMAIN_NAME}/$DOMAIN_NAME/g" \
        -e "s/{ServiceClassName}/$SERVICE_CLASS_NAME/g" \
        -e "s/{SERVICE_PORT}/$SERVICE_PORT/g" \
        -e "s/{DATABASE_NAME}/$DATABASE_NAME/g" \
        -e "s/{SERVICE_COMMON_VERSION}/$SERVICE_COMMON_VERSION/g" \
        -e "s/{JAVA_VERSION}/$JAVA_VERSION/g" \
        {} \;

    print_success "Placeholders replaced in files"

    # Rename directories
    print_info "Renaming package directories..."

    if [ -d "$SERVICE_DIR/src/main/java/org/budgetanalyzer/template" ]; then
        mv "$SERVICE_DIR/src/main/java/org/budgetanalyzer/template" \
           "$SERVICE_DIR/src/main/java/org/budgetanalyzer/$DOMAIN_NAME"
        print_success "Renamed main package directory"
    fi

    if [ -d "$SERVICE_DIR/src/test/java/org/budgetanalyzer/template" ]; then
        mv "$SERVICE_DIR/src/test/java/org/budgetanalyzer/template" \
           "$SERVICE_DIR/src/test/java/org/budgetanalyzer/$DOMAIN_NAME"
        print_success "Renamed test package directory"
    fi

    # Rename Application class files
    print_info "Renaming Application class files..."

    local main_app="$SERVICE_DIR/src/main/java/org/budgetanalyzer/$DOMAIN_NAME/TemplateApplication.java"
    local test_app="$SERVICE_DIR/src/test/java/org/budgetanalyzer/$DOMAIN_NAME/TemplateApplicationTests.java"

    if [ -f "$main_app" ]; then
        mv "$main_app" "$SERVICE_DIR/src/main/java/org/budgetanalyzer/$DOMAIN_NAME/${SERVICE_CLASS_NAME}Application.java"
        print_success "Renamed Application class"
    fi

    if [ -f "$test_app" ]; then
        mv "$test_app" "$SERVICE_DIR/src/test/java/org/budgetanalyzer/$DOMAIN_NAME/${SERVICE_CLASS_NAME}ApplicationTests.java"
        print_success "Renamed ApplicationTests class"
    fi

    echo ""
}

################################################################################
# Add-On Application
################################################################################

apply_postgresql_addon() {
    print_info "Applying PostgreSQL + Flyway add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# PostgreSQL + Flyway
spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
spring-boot-starter-validation = { module = "org.springframework.boot:spring-boot-starter-validation" }
flyway-core = { module = "org.flywaydb:flyway-core" }
flyway-database-postgresql = { module = "org.flywaydb:flyway-database-postgresql" }
postgresql = { module = "org.postgresql:postgresql" }
h2 = { module = "com.h2database:h2" }
EOF

    # Add dependencies to build.gradle.kts (after testRuntimeOnly line)
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // PostgreSQL + Flyway\\
    implementation(libs.spring.boot.starter.data.jpa)\\
    implementation(libs.spring.boot.starter.validation)\\
    implementation(libs.flyway.core)\\
    implementation(libs.flyway.database.postgresql)\\
    runtimeOnly(libs.postgresql)\\
    testImplementation(libs.h2)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    # Add to application.yml
    cat >> "$SERVICE_DIR/src/main/resources/application.yml" <<EOF

  datasource:
    url: jdbc:postgresql://localhost:5432/${DATABASE_NAME}
    username: \${DB_USERNAME:postgres}
    password: \${DB_PASSWORD:postgres}

  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false

  flyway:
    enabled: true
    locations: classpath:db/migration
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

    print_success "PostgreSQL + Flyway add-on applied"
}

apply_redis_addon() {
    print_info "Applying Redis add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# Redis
spring-boot-starter-data-redis = { module = "org.springframework.boot:spring-boot-starter-data-redis" }
spring-boot-starter-cache = { module = "org.springframework.boot:spring-boot-starter-cache" }
EOF

    # Add dependencies to build.gradle.kts
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // Redis\\
    implementation(libs.spring.boot.starter.data.redis)\\
    implementation(libs.spring.boot.starter.cache)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    # Add to application.yml
    cat >> "$SERVICE_DIR/src/main/resources/application.yml" <<EOF

  data:
    redis:
      host: \${REDIS_HOST:localhost}
      port: \${REDIS_PORT:6379}
      password: \${REDIS_PASSWORD:}
      database: 0
      timeout: 2000ms
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 0
          max-wait: -1ms

  cache:
    type: redis
    redis:
      time-to-live: 600000  # 10 minutes
      cache-null-values: false
      use-key-prefix: true
      key-prefix: "${SERVICE_NAME}:"
EOF

    print_success "Redis add-on applied"
}

apply_rabbitmq_addon() {
    print_info "Applying RabbitMQ add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# RabbitMQ + Spring Cloud Stream
springCloudVersion = "2024.0.1"

[libraries]
spring-cloud-stream = { module = "org.springframework.cloud:spring-cloud-stream" }
spring-cloud-stream-binder-rabbit = { module = "org.springframework.cloud:spring-cloud-stream-binder-rabbit" }
spring-modulith-events-amqp = { module = "org.springframework.modulith:spring-modulith-events-amqp" }
EOF

    # Add dependencyManagement to build.gradle.kts (after dependencies block)
    local build_file="$SERVICE_DIR/build.gradle.kts"

    # Add Spring Cloud BOM
    sed -i '/dependencies {/i \dependencyManagement {\n    imports {\n        mavenBom("org.springframework.cloud:spring-cloud-dependencies:2024.0.1")\n    }\n}\n' "$build_file"

    # Add dependencies
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // RabbitMQ + Spring Cloud Stream\\
    implementation(libs.spring.cloud.stream)\\
    implementation(libs.spring.cloud.stream.binder.rabbit)\\
    implementation(libs.spring.modulith.events.amqp)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    # Add to application.yml
    cat >> "$SERVICE_DIR/src/main/resources/application.yml" <<EOF

  rabbitmq:
    host: \${RABBITMQ_HOST:localhost}
    port: \${RABBITMQ_PORT:5672}
    username: \${RABBITMQ_USERNAME:guest}
    password: \${RABBITMQ_PASSWORD:guest}

  cloud:
    stream:
      bindings:
        # Example output channel (publishing events)
        # output-out-0:
        #   destination: ${SERVICE_NAME}.events
        #   content-type: application/json
        # Example input channel (consuming events)
        # input-in-0:
        #   destination: other-service.events
        #   group: ${SERVICE_NAME}
        #   content-type: application/json
EOF

    print_success "RabbitMQ + Spring Cloud Stream add-on applied"
}

apply_webflux_addon() {
    print_info "Applying WebFlux WebClient add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# WebFlux (for WebClient HTTP client)
spring-boot-starter-webflux = { module = "org.springframework.boot:spring-boot-starter-webflux" }
reactor-test = { module = "io.projectreactor:reactor-test" }
EOF

    # Add dependencies to build.gradle.kts
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // WebClient for HTTP calls\\
    implementation(libs.spring.boot.starter.webflux)\\
\\
    // Testing reactive components\\
    testImplementation(libs.reactor.test)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    print_success "WebFlux WebClient add-on applied"
    print_info "Note: Create WebClientConfig in config package to configure WebClient beans"
}

apply_shedlock_addon() {
    print_info "Applying ShedLock add-on..."

    # Check if PostgreSQL add-on is enabled
    if [ "$USE_POSTGRESQL" = false ]; then
        print_error "ShedLock requires PostgreSQL add-on. Please enable PostgreSQL first."
        return 1
    fi

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# ShedLock (distributed scheduled task locking)
shedlock = "5.17.1"

[libraries]
shedlock-spring = { module = "net.javacrumbs.shedlock:shedlock-spring", version.ref = "shedlock" }
shedlock-provider-jdbc-template = { module = "net.javacrumbs.shedlock:shedlock-provider-jdbc-template", version.ref = "shedlock" }
EOF

    # Add dependencies to build.gradle.kts
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // ShedLock (distributed scheduled task locking)\\
    implementation(libs.shedlock.spring)\\
    implementation(libs.shedlock.provider.jdbc.template)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    # Create ShedLock migration
    local migration_file="$SERVICE_DIR/src/main/resources/db/migration/V2__create_shedlock_table.sql"
    cat > "$migration_file" <<'EOF'
-- ShedLock table for distributed scheduled task locking

CREATE TABLE shedlock (
    name VARCHAR(64) NOT NULL PRIMARY KEY,
    lock_until TIMESTAMP NOT NULL,
    locked_at TIMESTAMP NOT NULL,
    locked_by VARCHAR(255) NOT NULL
);

CREATE INDEX idx_shedlock_lock_until ON shedlock(lock_until);
EOF

    print_success "ShedLock add-on applied"
    print_info "Note: Enable with @EnableSchedulerLock in SchedulingConfig class"
}

apply_springdoc_addon() {
    print_info "Applying SpringDoc OpenAPI add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# SpringDoc OpenAPI
springdoc = "2.7.0"

[libraries]
springdoc-openapi-starter-webmvc-ui = { module = "org.springdoc:springdoc-openapi-starter-webmvc-ui", version.ref = "springdoc" }
EOF

    # Add dependencies to build.gradle.kts
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // SpringDoc OpenAPI\\
    implementation(libs.springdoc.openapi.starter.webmvc.ui)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    print_success "SpringDoc OpenAPI add-on applied"
    print_info "Note: Access Swagger UI at http://localhost:$SERVICE_PORT/$SERVICE_NAME/swagger-ui.html"
}

apply_security_addon() {
    print_info "Applying Spring Security add-on..."

    # Add to libs.versions.toml
    cat >> "$SERVICE_DIR/gradle/libs.versions.toml" <<'EOF'

# Spring Security
spring-boot-starter-security = { module = "org.springframework.boot:spring-boot-starter-security" }
spring-security-test = { module = "org.springframework.security:spring-security-test" }
EOF

    # Add dependencies to build.gradle.kts
    local build_file="$SERVICE_DIR/build.gradle.kts"
    local insert_after="testRuntimeOnly(libs.junit.platform.launcher)"
    local new_deps="\\
\\
    // Spring Security\\
    implementation(libs.spring.boot.starter.security)\\
\\
    // Security testing\\
    testImplementation(libs.spring.security.test)"

    sed -i "/$insert_after/a $new_deps" "$build_file"

    print_success "Spring Security add-on applied"
    print_warning "Note: Spring Security is enabled by default. Create SecurityConfig to customize."
}

apply_addons() {
    print_section "Applying Add-Ons"

    $USE_POSTGRESQL && apply_postgresql_addon
    $USE_REDIS && apply_redis_addon
    $USE_RABBITMQ && apply_rabbitmq_addon
    $USE_WEBFLUX && apply_webflux_addon
    $USE_SHEDLOCK && apply_shedlock_addon
    $USE_SPRINGDOC && apply_springdoc_addon
    $USE_SECURITY && apply_security_addon

    echo ""
}

################################################################################
# Git Initialization
################################################################################

initialize_git() {
    print_section "Initializing Git Repository"

    cd "$SERVICE_DIR"

    git init --quiet
    print_success "Git repository initialized"

    git add .
    print_success "Files staged"

    git commit -m "Initial commit from template

Generated by create-service.sh

Service: $SERVICE_NAME
Domain: $DOMAIN_NAME
Port: $SERVICE_PORT
Database: $DATABASE_NAME

🤖 Generated with Budget Analyzer Service Template" --quiet

    print_success "Initial commit created"

    cd - > /dev/null
    echo ""
}

################################################################################
# GitHub Integration
################################################################################

create_github_repository() {
    if [ "$CREATE_GITHUB_REPO" = false ]; then
        return
    fi

    print_section "Creating GitHub Repository"

    cd "$SERVICE_DIR"

    print_info "Creating GitHub repository: budgetanalyzer/$SERVICE_NAME..."

    if gh repo create "budgetanalyzer/$SERVICE_NAME" \
        --private \
        --source=. \
        --remote=origin \
        --push; then
        print_success "GitHub repository created and pushed"
        GITHUB_REPO_CREATED=true
    else
        print_error "Failed to create GitHub repository"
        print_warning "You can create it manually later with: gh repo create budgetanalyzer/$SERVICE_NAME --private --source=. --remote=origin --push"
    fi

    cd - > /dev/null
    echo ""
}

################################################################################
# Build Validation
################################################################################

validate_build() {
    print_section "Validating Build"

    cd "$SERVICE_DIR"

    print_info "Running ./gradlew clean build..."
    echo ""

    if ./gradlew clean build; then
        echo ""
        print_success "Build successful! ✨"
    else
        echo ""
        print_error "Build failed!"
        print_warning "Please check the build output above for errors."
        exit 1
    fi

    cd - > /dev/null
    echo ""
}

################################################################################
# Summary and Next Steps
################################################################################

print_summary() {
    print_section "✨ Service Created Successfully!"

    echo "Service Details:"
    echo "  Name:       $SERVICE_NAME"
    echo "  Domain:     $DOMAIN_NAME"
    echo "  Port:       $SERVICE_PORT"
    echo "  Location:   $SERVICE_DIR"
    echo ""

    if [ "$GITHUB_REPO_CREATED" = true ]; then
        echo "GitHub Repository:"
        echo "  URL: https://github.com/budgetanalyzer/$SERVICE_NAME"
        echo ""
    fi

    echo "Next Steps:"
    echo ""
    echo "1. Review the generated service:"
    echo "   cd $SERVICE_DIR"
    echo ""
    echo "2. Run the service locally:"
    echo "   ./gradlew bootRun"
    echo ""
    echo "3. Add to orchestration docker-compose.yml:"
    echo "   - Add service definition"
    echo "   - Configure environment variables"
    echo "   - Set up database (if using PostgreSQL)"
    echo ""
    echo "4. Configure NGINX routing (if needed):"
    echo "   - Edit nginx/nginx.dev.conf"
    echo "   - Add location blocks for API endpoints"
    echo "   - Restart NGINX container"
    echo ""
    echo "5. Update orchestration documentation:"
    echo "   - Add service to CLAUDE.md"
    echo "   - Document API endpoints"
    echo "   - Update architecture diagrams"
    echo ""
    echo "For add-on configuration details, see:"
    echo "  $WORKSPACE_DIR/docs/service-creation/addons/"
    echo ""

    print_section "Happy coding! 🚀"
}

################################################################################
# Error Handling and Cleanup
################################################################################

cleanup_on_error() {
    print_error "Script failed. Cleaning up..."

    if [ -d "$SERVICE_DIR" ] && [ ! -d "$SERVICE_DIR/.git" ]; then
        print_warning "Removing incomplete service directory: $SERVICE_DIR"
        rm -rf "$SERVICE_DIR"
    fi

    exit 1
}

trap cleanup_on_error ERR

################################################################################
# Main Script Flow
################################################################################

main() {
    print_header

    check_prerequisites
    prompt_service_details
    prompt_addons
    prompt_github_integration

    clone_template
    replace_placeholders
    apply_addons
    initialize_git
    create_github_repository
    validate_build

    print_summary
}

# Run main function
main "$@"
