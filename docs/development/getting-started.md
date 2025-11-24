# Getting Started with Local Development

## Prerequisites

**This project is designed for AI-assisted development.** Containerized agents are mandatory.

### Required Setup

**VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)**

The devcontainer provides:
- Ubuntu 24.04 sandbox with safe sudo access for AI agents
- Pre-installed: JDK 24, Node.js, Maven, Docker CLI, Git
- Workspace-wide access to all repositories
- Isolation from your host system

**Host machine tools:**
- Docker ([installation guide](https://docs.docker.com/get-docker/))
- Kind (local Kubernetes cluster)
- kubectl (Kubernetes CLI)
- Helm (for installing Envoy Gateway)
- Tilt (development workflow orchestration)
- mkcert (for local HTTPS certificates)

**Not supported**:
- **Cursor**: Closed source
- **IntelliJ IDEA**: No containerized agent support
- **Any editor without containerized agent architecture**

Check host prerequisites:
```bash
./scripts/dev/check-tilt-prerequisites.sh
```

> **Note**: You can work on this codebase without AI using any IDE, but that's not the focus of this project. This is an AI-first learning resource for architects exploring AI-assisted development.

## Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/budgetanalyzer/orchestration.git
cd orchestration
./setup.sh
```

The setup script will:
- Clone all service repositories
- Create Kind cluster with correct port mappings
- Configure DNS in `/etc/hosts`
- Install Gateway API and Envoy Gateway
- Generate TLS certificates
- Create `.env` from template

### 2. Configure External Services

Edit `.env` with your credentials:

```bash
vi .env
```

**Required:**
- **Auth0**: See [../setup/auth0-setup.md](../setup/auth0-setup.md)
- **FRED API**: See [../setup/fred-api-setup.md](../setup/fred-api-setup.md)

### 3. Start All Services

```bash
tilt up
```

This will:
- Build all service images
- Deploy to local Kind cluster
- Set up Envoy Gateway for SSL termination
- Configure NGINX for JWT validation and routing
- Start PostgreSQL, Redis, RabbitMQ

### 5. Access the Application

- **Tilt UI**: http://localhost:10350 (logs, status, buttons)
- **Application**: https://app.budgetanalyzer.localhost
- **API Documentation**: https://api.budgetanalyzer.localhost/api/docs
- **OpenAPI JSON**: https://api.budgetanalyzer.localhost/api/docs/openapi.json

**Architecture Flow:**
```
Browser → Envoy Gateway (443) → Session Gateway (8081) → Envoy Gateway → NGINX (8080) → Backend Services
         SSL/HTTPS             OAuth2/Session                            JWT Validation    Business Logic
```

## Tilt UI Overview

The Tilt UI at http://localhost:10350 provides:

- **Resource Status**: Real-time status of all services
- **Logs**: Live logs from all pods
- **Buttons**: Quick actions for development

**Key Resources:**
- `service-common-publish` - Builds shared library
- `service-common-compile` - Compiles service-common (special behavior, see below)
- `*-compile` - Compiles each service

### Localhost CI/CD

**service-common has special behavior**: When you click the `service-common-compile` button in the Tilt UI, it automatically triggers recompilation of all downstream services that depend on it (transaction-service, currency-service, permission-service, session-gateway, token-validation-service).

This is **localhost CI/CD** - simulating a CI/CD pipeline dependency graph locally. When the shared library changes, all consumers rebuild automatically, just like a real CI/CD system would do.

**Current state**: This is as far as the localhost CI/CD implementation goes. The foundation is there (dependency tracking, automatic downstream triggers), but it didn't get taken further. Think of it as CI/CD-lite for local development.

## Access Patterns

### Browser Access (via Envoy/Session Gateway)

All browser requests go through **Envoy Gateway** at `https://app.budgetanalyzer.localhost`:

**Frontend:**
- Application: `https://app.budgetanalyzer.localhost/`
- Login: `https://app.budgetanalyzer.localhost/oauth2/authorization/auth0`
- Logout: `https://app.budgetanalyzer.localhost/logout`

**API Endpoints (authenticated, requires login):**
- Transactions: `https://app.budgetanalyzer.localhost/api/v1/transactions`
- Currencies: `https://app.budgetanalyzer.localhost/api/v1/currencies`
- Exchange Rates: `https://app.budgetanalyzer.localhost/api/v1/exchange-rates`

### Internal/Development Access

**Direct Service Access (for debugging only):**
- Transaction Service Swagger: `http://localhost:8082/swagger-ui.html`
- Currency Service Swagger: `http://localhost:8084/swagger-ui.html`
- Transaction Service Health: `http://localhost:8082/actuator/health`
- Currency Service Health: `http://localhost:8084/actuator/health`
- Token Validation Service Health: `http://localhost:8088/actuator/health`

**Note**: Direct service access bypasses authentication - only for local development debugging.

## Troubleshooting

### Check Pod Status

```bash
# View all pods
kubectl get pods -n budget-analyzer

# View infrastructure pods
kubectl get pods -n infrastructure
```

### View Logs

```bash
# Via Tilt UI (recommended)
# http://localhost:10350 → Click on resource

# Via kubectl
kubectl logs -n budget-analyzer deployment/transaction-service
kubectl logs -n budget-analyzer deployment/nginx-gateway
kubectl logs -n envoy-gateway-system deployment/envoy-gateway
```

### Common Issues

**Service not starting:**
- Check Tilt UI for error messages
- Verify `service-common-publish` completed successfully
- Check compile step completed

**502 Bad Gateway:**
- Check if target service pod is running
- View NGINX logs for routing errors
- Verify Kubernetes service exists

**SSL Certificate Errors:**
- Re-run `./scripts/dev/setup-k8s-tls.sh` on host
- Restart browser

## Next Steps

- **Database Configuration**: See [database-setup.md](database-setup.md)
- **Development Workflows**: See [local-environment.md](local-environment.md)
- **NGINX Gateway Configuration**: See [../../nginx/README.md](../../nginx/README.md)

## Stopping Services

```bash
# Stop all services
tilt down

# Delete Kind cluster completely (removes all data)
kind delete cluster
```
