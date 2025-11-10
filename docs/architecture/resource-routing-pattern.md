# Resource-Based Routing Pattern

**Pattern Category:** API Gateway
**Status:** Active
**Related ADR:** [002-resource-based-routing.md](../decisions/002-resource-based-routing.md)

## Overview

Budget Analyzer uses resource-based routing at the NGINX gateway, decoupling the frontend from backend service topology. This pattern allows services to be refactored, split, or merged without requiring frontend changes.

## Pattern Description

### Core Principle

> **Frontend calls resources, not services.**

Routes are organized by REST resource (e.g., `/api/v1/transactions`) rather than by service name (e.g., `/api/transaction-service/transactions`).

### Architecture

```
Frontend Request:
  GET /api/v1/transactions
       ↓
NGINX Gateway (knows topology):
  proxy_pass → http://transaction-service:8082/transactions
       ↓
Backend Service:
  TransactionController handles request
```

Frontend never knows:
- Which service handles the request
- What port the service runs on
- Internal service names

## Configuration

### NGINX Location Blocks

**Pattern:**
```nginx
location /api/v1/{resource} {
    proxy_pass http://{service-host}:{port}/{internal-path};

    # Standard proxy settings
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Current Routes

**Discovery:**
```bash
# List all API routes
grep "location /api" nginx/nginx.dev.conf | grep -v "#"

# Test a route
curl -v http://localhost:8080/api/v1/transactions
```

**Source of truth:** [nginx/nginx.dev.conf](../../nginx/nginx.dev.conf)

## Adding New Routes

### Step 1: Determine Resource Path

Choose RESTful path based on resource, not service:
- ✅ `/api/v1/budgets` (resource-based)
- ❌ `/api/budget-service/budgets` (service-based)

### Step 2: Add Location Block

Edit `nginx/nginx.dev.conf`:
```nginx
location /api/v1/budgets {
    proxy_pass http://host.docker.internal:8082/budgets;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Step 3: Restart Gateway

```bash
docker compose restart api-gateway
```

### Step 4: Test

```bash
# Health check
curl http://localhost:8080/api/v1/budgets/health

# Actual endpoint
curl http://localhost:8080/api/v1/budgets
```

## Refactoring Services

### Scenario: Moving a Resource

**Before:** Transactions in transaction-service
```nginx
location /api/v1/transactions {
    proxy_pass http://host.docker.internal:8082/transactions;
}
```

**After:** Move analytics to new analytics-service
```nginx
location /api/v1/transactions {
    proxy_pass http://host.docker.internal:8082/transactions;
}

location /api/v1/analytics/transactions {
    proxy_pass http://host.docker.internal:8086/transactions/analytics;
}
```

**Frontend changes required:** NONE (if using `/api/v1/analytics/transactions`)

### Scenario: Splitting a Service

**Before:** All currency features in currency-service (port 8084)

**After:** Split into currency-metadata-service (8084) and exchange-rate-service (8085)

**NGINX changes:**
```nginx
# Metadata endpoints
location /api/v1/currencies {
    proxy_pass http://host.docker.internal:8084/currencies;
}

# Exchange rate endpoints
location /api/v1/exchange-rates {
    proxy_pass http://host.docker.internal:8085/exchange-rates;
}
```

**Frontend changes required:** NONE (paths unchanged)

## API Versioning

### Version in Path

All routes include version:
```nginx
location /api/v1/transactions { ... }
location /api/v2/transactions { ... }  # Future version
```

### Version Strategy

- `/api/v1/` - Current stable API
- `/api/v2/` - New version (backward incompatible changes)
- Old versions remain available during transition

## Best Practices

### DO

✅ **Use resource names**
```nginx
location /api/v1/transactions { ... }
location /api/v1/currencies { ... }
```

✅ **Include API version**
```nginx
location /api/v1/transactions { ... }
```

✅ **Use RESTful conventions**
```
GET    /api/v1/transactions      # List
POST   /api/v1/transactions      # Create
GET    /api/v1/transactions/:id  # Read
PUT    /api/v1/transactions/:id  # Update
DELETE /api/v1/transactions/:id  # Delete
```

✅ **Group related resources**
```nginx
location /api/v1/transactions { ... }
location /api/v1/transactions/import { ... }
location /api/v1/transactions/search { ... }
```

### DON'T

❌ **Don't expose service names**
```nginx
# WRONG
location /api/transaction-service/transactions { ... }
```

❌ **Don't use RPC-style paths**
```nginx
# WRONG
location /api/getTransactions { ... }
location /api/createTransaction { ... }
```

❌ **Don't hardcode backends in frontend**
```javascript
// WRONG
fetch('http://localhost:8082/transactions')

// CORRECT
fetch('/api/v1/transactions')
```

## Troubleshooting

### Route Not Found (404)

```bash
# Check if route exists in NGINX config
grep "/api/v1/your-resource" nginx/nginx.dev.conf

# Check if NGINX is running
docker compose ps api-gateway

# View NGINX logs
docker logs api-gateway
```

### Bad Gateway (502)

```bash
# Check if backend service is running
docker compose ps transaction-service

# Check backend service logs
docker logs transaction-service

# Test backend directly (bypass gateway)
curl http://localhost:8082/transactions
```

### NGINX Config Syntax Error

```bash
# Validate NGINX config
docker exec api-gateway nginx -t

# If valid, reload
docker exec api-gateway nginx -s reload
```

## Monitoring

### Access Logs

```bash
# View all gateway traffic
docker logs api-gateway | grep "GET /api"

# View specific resource
docker logs api-gateway | grep "/api/v1/transactions"
```

### Performance

```bash
# Request count per endpoint
docker logs api-gateway | grep "GET /api" | \
  awk '{print $7}' | sort | uniq -c | sort -rn

# Response times (if access_log configured)
docker logs api-gateway | grep "request_time"
```

## References

- **ADR:** [002-resource-based-routing.md](../decisions/002-resource-based-routing.md)
- **Config:** [nginx/nginx.dev.conf](../../nginx/nginx.dev.conf)
- **Guide:** [nginx/README.md](../../nginx/README.md)
- **Architecture:** [system-overview.md](system-overview.md)
