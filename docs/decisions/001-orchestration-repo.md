# 001. Orchestration Repository Pattern

**Date:** 2025-11-10
**Status:** Accepted
**Deciders:** Budget Analyzer Team

## Context

Budget Analyzer is a microservices architecture with multiple independently deployed services (transaction-service, currency-service, budget-analyzer-web). We need a way to:
- Coordinate local development environment
- Manage shared infrastructure (database, message queue, gateway)
- Document system-wide architecture
- Provide a single entry point for developers

## Decision

Create a dedicated "orchestration" repository that:
- Contains no application code
- Hosts docker compose for local development
- Manages NGINX gateway configuration
- Provides system-wide documentation
- Includes deployment manifests (Kubernetes)
- Coordinates cross-service concerns

## Alternatives Considered

### Alternative 1: Monorepo
Put all services in a single repository.

**Pros:**
- Single clone for entire system
- Atomic cross-service changes
- Simpler dependency management

**Cons:**
- Large repository size
- Couples deployment of all services
- Harder to manage independent service lifecycles
- Team boundaries less clear

### Alternative 2: No Orchestration Repo
Each service self-contains its docker compose and docs.

**Pros:**
- No extra repository
- Each service fully independent

**Cons:**
- Duplicated infrastructure definitions
- No single source of truth for system architecture
- Harder to onboard new developers
- Inconsistent local environments

### Alternative 3: Infrastructure Repo
Similar to orchestration, but focused only on deployment.

**Pros:**
- Clear focus on infrastructure
- Separation of concerns

**Cons:**
- Where do architecture docs go?
- Where does local dev setup live?
- "Infrastructure" implies production, confusing for dev

## Consequences

**Positive:**
- Single place to start for new developers
- Clear separation: orchestration vs. service code
- Easy to coordinate local development environment
- System-wide documentation has a home
- Gateway configuration centralized

**Negative:**
- One more repository to manage
- Developers need to clone orchestration + service repos
- Risk of orchestration/service version mismatches

**Neutral:**
- Introduces new pattern (not common in all organizations)
- Requires discipline to keep orchestration docs updated

## References
- [README.md](../../README.md) in orchestration repo
- [003-pattern-based-claude-md.md](003-pattern-based-claude-md.md) - Documentation strategy
