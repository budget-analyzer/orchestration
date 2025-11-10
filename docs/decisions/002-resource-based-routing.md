# 002. Resource-Based API Gateway Routing

**Date:** 2025-11-10
**Status:** Accepted
**Deciders:** Budget Analyzer Team

## Context

Frontend needs to call backend microservices through NGINX gateway. We must decide how to structure routes:
- Service-based: `/api/transaction-service/transactions`, `/api/currency-service/currencies`
- Resource-based: `/api/v1/transactions`, `/api/v1/currencies`

Moving resources between services (e.g., splitting transaction-service) should not require frontend changes.

## Decision

Use **resource-based routing** at the NGINX gateway:
- Frontend calls clean paths: `/api/v1/transactions`, `/api/v1/currencies`
- NGINX routes to appropriate backend service
- Backend services can use any internal path structure
- Moving a resource to a different service requires only NGINX config change

## Alternatives Considered

### Alternative 1: Service-Based Routing
Frontend calls `/api/{service-name}/{resource}`

**Pros:**
- Clear which service handles request
- Easy to debug (service name in URL)
- No ambiguity in routing

**Cons:**
- Frontend tightly coupled to service topology
- Moving resource to different service breaks frontend
- Service names exposed to frontend (implementation detail leakage)
- Refactoring services requires frontend changes

### Alternative 2: Backend for Frontend (BFF)
Create aggregation layer that composes multiple services.

**Pros:**
- Frontend has single tailored API
- Can aggregate multiple backend calls
- Hides backend complexity

**Cons:**
- Adds complexity (another service to maintain)
- Can become bloated "god service"
- Increases latency (extra hop)
- Requires careful API design

## Consequences

**Positive:**
- Frontend decoupled from service topology
- Can refactor/split services without frontend impact
- Clean, RESTful API paths
- API versioning at gateway level (`/api/v1/`, `/api/v2/`)
- Simpler frontend code (no service names)

**Negative:**
- NGINX config is critical path (must be correct)
- Less obvious which service handles request (need docs or logs)
- NGINX becomes single point of configuration change

**Neutral:**
- NGINX configuration grows as resources added
- Need documentation to map resources → services

## Implementation Notes

Example NGINX configuration:
```nginx
location /api/v1/transactions {
    proxy_pass http://transaction-service:8082/transactions;
}

location /api/v1/currencies {
    proxy_pass http://currency-service:8084/currencies;
}
```

If we later move currency conversion to a new service, only NGINX changes:
```nginx
location /api/v1/currencies {
    proxy_pass http://currency-service-v2:8085/currencies;
}
```

Frontend code unchanged.

## References
- [nginx/nginx.dev.conf](../../nginx/nginx.dev.conf) - Current routing configuration
- [nginx/README.md](../../nginx/README.md) - NGINX setup guide
