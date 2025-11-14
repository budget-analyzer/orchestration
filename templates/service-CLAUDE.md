# {Service Name} - {Brief Domain Description}

## Service Purpose
{2-3 sentences describing business domain}

**Domain**: {e.g., "Payment processing and invoicing"}
**Responsibilities**:
- {Key responsibility 1}
- {Key responsibility 2}
- {Key responsibility 3}

## Spring Boot Patterns

**This service follows standard Budget Analyzer Spring Boot conventions.**

See [../service-common/CLAUDE.md](../service-common/CLAUDE.md) for:
- Architecture layers (Controller → Service → Repository)
- Naming conventions
- Testing patterns
- Error handling
- Logging conventions
- Dependency management

## Service-Specific Patterns

### API Contracts
Full API specification: @docs/api/openapi.yaml

**Discovery**:
```bash
# Start service with Swagger UI
./mvnw spring-boot:run
open http://localhost:{PORT}/swagger-ui.html

# View OpenAPI spec
cat docs/api/openapi.yaml
```

### Domain Model
See @docs/domain-model.md

**Key concepts**:
- {Entity 1}: {Brief description}
- {Entity 2}: {Brief description}

### Database Schema
{If applicable}
See @docs/database-schema.md

**Key tables**:
- `{table_name}`: {Brief description}

**Migrations**: Flyway (see `src/main/resources/db/migration/`)

### {Service-Specific Feature}
{If applicable - document unique concerns only}

See @docs/{feature-name}.md

## Running Locally

```bash
# Start dependencies
cd orchestration/
docker compose up shared-postgres

# Run service
cd {service-name}/
./mvnw spring-boot:run

# Access service
curl http://localhost:{PORT}/actuator/health
```

**See**: [../orchestration/docs/development/local-environment.md](../orchestration/docs/development/local-environment.md)

## Discovery Commands

```bash
# Find all endpoints
grep -r "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping" src/

# View configuration
cat src/main/resources/application.yml

# Check dependencies
./mvnw dependency:tree
```

## AI Assistant Guidelines

1. **Follow service-common patterns** - See [../service-common/CLAUDE.md](../service-common/CLAUDE.md)
2. **Check OpenAPI spec first** - See @docs/api/openapi.yaml
3. **Understand domain** - Read @docs/domain-model.md before changes
4. **Test everything** - Follow [../service-common/docs/testing-patterns.md](../service-common/docs/testing-patterns.md)
5. {Service-specific guideline}

---

## External Links (GitHub Web Viewing)

*The relative paths in this document are optimized for Claude Code. When viewing on GitHub, use these links:*

- [Service-Common Documentation](https://github.com/budget-analyzer/service-common/tree/main/docs)
- [Orchestration Documentation](https://github.com/budget-analyzer/orchestration/tree/main/docs)
