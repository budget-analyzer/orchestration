# Budget Analyzer - Orchestration

> **⚠️ Work in Progress**: This project is under active development. Features and documentation are subject to change.

Orchestration repository for Budget Analyzer - a microservices-based personal finance management tool built with Spring Boot and React.

## Overview

This repository coordinates the deployment and local development environment for the Budget Analyzer application. Individual service code lives in separate repositories.

## Architecture

The application follows a microservices architecture with BFF (Backend for Frontend) pattern:

- **Frontend**: React 19 + TypeScript web application
- **Session Gateway (BFF)**: Spring Cloud Gateway for browser authentication and session management
- **Backend Services**: Spring Boot REST APIs
  - Transaction Service - Manages financial transactions
  - Currency Service - Handles currencies and exchange rates
  - Token Validation Service - JWT validation for NGINX
- **Ingress**: Envoy Gateway for SSL termination
- **API Gateway**: NGINX reverse proxy for request routing and JWT validation
- **Infrastructure**: PostgreSQL, Redis, RabbitMQ
- **Development**: Tilt + Kind (local Kubernetes)

## Quick Start

### Prerequisites

- Docker (for building images)
- Kind (local Kubernetes cluster)
- kubectl (Kubernetes CLI)
- Helm (for installing Envoy Gateway)
- Tilt (development workflow orchestration)
- JDK 24 (for local Spring Boot development)
- Node.js 18+ (for local React development)
- mkcert (for local HTTPS certificates)

**Check prerequisites**: Run `./scripts/dev/check-tilt-prerequisites.sh`

**First-time setup**: Run `./scripts/dev/setup-k8s-tls.sh` to generate trusted HTTPS certificates, then see [docs/development/getting-started.md](docs/development/getting-started.md)

### Running the Application

```bash
# Start all services with Tilt
tilt up

# Access Tilt UI for logs and status
# Browser: http://localhost:10350

# Stop all services
tilt down
```

The application will be available at `https://app.budgetanalyzer.localhost`

> **Note**: This local development setup uses HTTPS with mkcert-generated certificates and runs on a local Kind Kubernetes cluster managed by Tilt.

### Service Ports

- Envoy Gateway: `443` (HTTPS - browser entry point for app. and api. subdomains)
- NGINX Gateway: `8080` (internal, JWT validation and routing)
- Session Gateway (BFF): `8081` (internal)
- Token Validation Service: `8088` (internal)
- PostgreSQL: `5432`
- Redis: `6379`
- RabbitMQ: `5672` (Management UI: `15672`)

## Project Structure

```
orchestration/
├── Tiltfile              # Development workflow orchestration
├── tilt/                 # Tilt configuration modules
├── kubernetes/           # Kubernetes manifests
├── nginx/                # API gateway configuration
├── postgres-init/        # Database initialization scripts
├── scripts/              # Automation tools
└── docs/                 # Cross-service documentation
```

## Service Repositories

Each microservice is maintained in its own repository:

- **service-common**: https://github.com/budgetanalyzer/service-common
- **transaction-service**: https://github.com/budgetanalyzer/transaction-service
- **currency-service**: https://github.com/budgetanalyzer/currency-service
- **budget-analyzer-web**: https://github.com/budgetanalyzer/budget-analyzer-web
- **session-gateway**: https://github.com/budgetanalyzer/session-gateway
- **token-validation-service**: https://github.com/budgetanalyzer/token-validation-service
- **permission-service**: https://github.com/budgetanalyzer/permission-service
- **basic-repository-template**: https://github.com/budgetanalyzer/basic-repository-template

## Development

For detailed development instructions including:
- API gateway routing patterns
- Adding new services
- Troubleshooting
- Cross-service documentation standards

See [CLAUDE.md](CLAUDE.md)

## Technology Stack

- **Backend**: Spring Boot 3.x, Java 24
- **Frontend**: React 19, TypeScript, Vite
- **Session Management**: Spring Cloud Gateway, Redis
- **Authentication**: Auth0 (OAuth2/OIDC)
- **Database**: PostgreSQL
- **Cache**: Redis
- **Message Queue**: RabbitMQ
- **Ingress**: Envoy Gateway (Kubernetes Gateway API)
- **API Gateway**: NGINX
- **Development**: Tilt + Kind (local Kubernetes)

## License

MIT

## Contributing

This project is currently in early development. Contributions, issues, and feature requests are welcome as we build toward a stable release.
