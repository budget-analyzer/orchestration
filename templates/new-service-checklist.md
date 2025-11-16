# New Spring Boot Service Checklist

Use this checklist when creating a new Spring Boot microservice for the Budget Analyzer application.

## Repository Setup

- [ ] Create repo in budget-analyzer org: `{domain}-service`
- [ ] Copy `.gitignore` from template
- [ ] Set up branch protection on main
- [ ] Add repo to `scripts/repo-config.sh` (if exists)

## Code Structure

- [ ] Inherit from service-common in `pom.xml`
- [ ] Follow package structure: `com.budgetanalyzer.{domain}.{layer}`
- [ ] Create standard layers: controller, service, repository, dto
- [ ] Add TestContainers for integration tests
- [ ] Create health check endpoint (`/actuator/health`)

## Documentation

- [ ] Create `CLAUDE.md` from template (`templates/service-CLAUDE.md`)
- [ ] Create `README.md` with service overview
- [ ] Create `docs/api/openapi.yaml` (OpenAPI 3.0 spec)
- [ ] Create `docs/domain-model.md`
- [ ] Create `docs/database-schema.md` (if applicable)
- [ ] Update `orchestration/docs/architecture/system-overview.md`

## Integration

- [ ] Add service to `orchestration/docker-compose.yml`
  - [ ] Define service with appropriate ports
  - [ ] Add depends_on for required infrastructure (postgres, redis, etc.)
  - [ ] Add health check configuration
- [ ] Add routes to `orchestration/nginx/nginx.dev.conf`
  - [ ] Follow resource-based routing pattern
  - [ ] Use `/api/v1/{resource}` format
  - [ ] Test routing through gateway
- [ ] Add routes to `orchestration/nginx/nginx.prod.conf` (if different)

## Configuration

- [ ] Create `application.yml` with sensible defaults
- [ ] Add environment-specific configs (application-dev.yml, application-prod.yml)
- [ ] Configure database connection (if applicable)
- [ ] Configure service discovery/registry (if applicable)
- [ ] Add logging configuration

## CI/CD

- [ ] Set up GitHub Actions workflow (or your CI/CD tool)
- [ ] Add build pipeline
  - [ ] Maven build
  - [ ] Run tests
  - [ ] Build Docker image
- [ ] Add test pipeline
  - [ ] Unit tests
  - [ ] Integration tests
- [ ] Configure deployment
  - [ ] Docker image push
  - [ ] Kubernetes deployment (if applicable)

## Testing

- [ ] Write unit tests for services
- [ ] Write integration tests with TestContainers
- [ ] Add API contract tests (if applicable)
- [ ] Verify test coverage meets standards

## Validation

- [ ] Run `scripts/validate-repos.sh` (if exists)
- [ ] Run `scripts/validate-claude-context.sh`
- [ ] Test local development setup:
  ```bash
  cd orchestration
  docker compose up -d
  cd ../{service-name}
  ./mvnw spring-boot:run
  ```
- [ ] Verify Swagger UI works: `http://localhost:{PORT}/swagger-ui.html`
- [ ] Test through NGINX gateway: `http://localhost:8080/api/v1/{resource}`
- [ ] Run all tests: `./mvnw test`

## Security

- [ ] Review dependencies for vulnerabilities
- [ ] Configure Spring Security (if needed)
- [ ] Add authentication/authorization checks
- [ ] Review API endpoints for security concerns
- [ ] Add rate limiting configuration (if applicable)

## Observability

- [ ] Add actuator endpoints
- [ ] Configure metrics export (if using Prometheus/etc)
- [ ] Add structured logging
- [ ] Configure distributed tracing (if applicable)

## Database (if applicable)

- [ ] Create initial Flyway migration
- [ ] Add database indexes
- [ ] Document schema in `docs/database-schema.md`
- [ ] Test migrations on clean database

## Final Steps

- [ ] Update orchestration README.md if needed
- [ ] Announce new service to team
- [ ] Add service to deployment pipeline
- [ ] Update architecture diagrams
- [ ] Schedule post-launch review

## Quick Start Commands

```bash
# Clone template (if exists)
git clone https://github.com/budgetanalyzer/service-template.git {service-name}
cd {service-name}

# Or start from scratch
mkdir {service-name}
cd {service-name}

# Copy CLAUDE.md template
cp ../orchestration/templates/service-CLAUDE.md ./CLAUDE.md

# Initialize Maven project
mvn archetype:generate \
  -DgroupId=com.budgetanalyzer.{domain} \
  -DartifactId={service-name} \
  -DarchetypeArtifactId=maven-archetype-quickstart

# Update pom.xml to inherit from service-common
# (see service-common/README.md for parent POM setup)
```

## Notes

- **Service Naming**: Use `{domain}-service` format (e.g., `payment-service`, `notification-service`)
- **Port Assignment**: Use 8082+ for backend services, avoid conflicts (check docker-compose.yml)
- **Resource Naming**: Use RESTful resource names in routes (e.g., `/payments`, not `/payment-service`)
- **Documentation**: Keep CLAUDE.md thin, put details in docs/ directory
- **Testing**: Follow patterns in service-common/docs/testing-patterns.md

## References

- [service-common/CLAUDE.md](../service-common/CLAUDE.md) - Spring Boot conventions
- [orchestration/CLAUDE.md](../CLAUDE.md) - Architecture patterns
- [docs/architecture/resource-routing-pattern.md](../docs/architecture/resource-routing-pattern.md) - API gateway routing
- [docs/decisions/003-pattern-based-claude-md.md](../docs/decisions/003-pattern-based-claude-md.md) - Documentation strategy
