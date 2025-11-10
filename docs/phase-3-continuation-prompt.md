# Phase 3 Continuation Prompt - CLAUDE.md Reorganization

## Context

We are implementing the CLAUDE.md reorganization plan (see `claude-md-reorganization-plan.md`) to transform from specificity-based to pattern-based documentation. We've completed Phases 1-2 and are partway through Phase 3.

## What Has Been Completed

### Phase 1: De-Specified orchestration/CLAUDE.md ✅
- Transformed from 257 lines → 170 lines (34% reduction)
- Replaced service inventory with discovery patterns
- Replaced route lists with nginx config references
- Replaced technology versions with discovery commands
- All discovery commands tested and working

**File**: `/workspace/orchestration/CLAUDE.md`

### Phase 2: Created service-common/CLAUDE.md ✅
- Transformed from 1,031 lines → 231 lines (78% reduction)
- Created pattern-based CLAUDE.md referencing detailed docs
- Created comprehensive docs structure:
  - `docs/spring-boot-conventions.md` - Architecture layers, naming, base entities, Pure JPA
  - `docs/error-handling.md` - Exception hierarchy, ApiErrorResponse, best practices
  - `docs/testing-patterns.md` - Testing philosophy, TestContainers, mocking, coverage goals
  - `docs/code-quality-standards.md` - Spotless, Checkstyle, var usage, Javadoc, method formatting
  - `docs/common-patterns.md` - SOLID principles, Spring Boot patterns, database patterns, security

**Files**:
- `/workspace/service-common/CLAUDE.md`
- `/workspace/service-common/docs/*.md` (5 comprehensive docs)

### Phase 3: Partial - Extracted Overlapping Content ✅

**Identified massive duplication** between transaction-service and currency-service CLAUDE.md files:
- Code quality standards (Spotless, Checkstyle, Javadoc) - ~200 lines each
- Design principles (SOLID, production-quality code) - ~150 lines each
- Spring Boot patterns (constructor injection, thin controllers) - ~100 lines each
- Testing philosophy - ~50 lines each

**Total duplication eliminated**: ~600-800 lines

**Files created**:
- `/workspace/service-common/docs/code-quality-standards.md`
- `/workspace/service-common/docs/common-patterns.md`

## Current State - Ready for Next Steps

### Phase 3 Remaining Work

Need to transform three service CLAUDE.md files to pattern-based approach:

1. **transaction-service/CLAUDE.md** (currently ~1,167 lines)
   - Remove all content now in service-common docs
   - Keep service-specific content:
     - CSV import system (multi-bank support via configuration)
     - Transaction search with JPA specifications
     - Service layer architecture (services accept/return entities, NOT DTOs)
     - Package structure specific to this service
   - **Target**: ~200-300 lines

2. **currency-service/CLAUDE.md** (currently ~1,718 lines)
   - Remove all content now in service-common docs
   - **IMPORTANT USER FEEDBACK**: Most patterns in currency-service actually belong in service-common
   - Patterns to move to service-common:
     - **Provider abstraction pattern** (external data source integration pattern)
     - **Event-driven messaging with transactional outbox pattern** (Spring Modulith)
     - **Redis caching strategy** (distributed caching pattern)
     - **ShedLock distributed locking** (scheduled task coordination)
     - **Flyway migrations** (database schema versioning)
   - Keep service-specific:
     - FRED API integration specifics
     - Currency/exchange rate domain model
     - Scheduled import configuration
   - **Target**: ~200-300 lines after extracting patterns to service-common

3. **budget-analyzer-web/CLAUDE.md** (need to read this file)
   - React/frontend specific patterns
   - API integration patterns (calling through NGINX gateway)
   - **Target**: ~200-300 lines

### Files to Transform
- `/workspace/transaction-service/CLAUDE.md`
- `/workspace/currency-service/CLAUDE.md`
- `/workspace/budget-analyzer-web/CLAUDE.md`

## Action Items for Continuation

### Step 1: Extract Currency-Service Patterns to service-common

Create new docs in `/workspace/service-common/docs/`:

1. **`advanced-patterns.md`** - Extract from currency-service:
   - Provider abstraction pattern (with FRED as example)
   - Event-driven messaging with Spring Modulith transactional outbox
   - Distributed caching with Redis
   - Distributed locking with ShedLock
   - Database migrations with Flyway

2. **Update `spring-boot-conventions.md`** if needed:
   - Add sections for these advanced patterns
   - Or reference the new `advanced-patterns.md` file

### Step 2: Transform Service CLAUDE.md Files

Transform each service file following the template from the reorganization plan:

**Pattern**:
- Short (200-300 lines)
- Reference service-common for shared patterns
- Document only service-specific concerns
- Use discovery commands
- Include API documentation references

**Template structure** (from plan lines 746-839):
```markdown
# {Service Name} - [Brief Domain Description]

## Service Purpose
[2-3 sentences describing business domain]

## Spring Boot Patterns
**This service follows standard Budget Analyzer Spring Boot conventions.**
See @service-common/CLAUDE.md for: [list patterns]

## Service-Specific Patterns
[Only document patterns UNIQUE to this service]

### API Contracts
Full API specification: @docs/api/openapi.yaml

### Domain Model
See @docs/domain-model.md

### [Service-Specific Concerns]
[Only what's UNIQUE]

## Discovery Commands
[Service-specific discovery]

## AI Assistant Guidelines
[Service-specific guidelines]
```

### Step 3: Create Service-Specific docs/ Directories

For each service, create:
- `docs/api/openapi.yaml` (or document where it should go)
- `docs/domain-model.md` (document business entities)
- `docs/database-schema.md` (if applicable)
- Service-specific feature docs

## Key Principles to Follow

1. **DRY**: Never duplicate content between service-common and service CLAUDE.md files
2. **Reference, Don't Duplicate**: Services reference service-common docs with `@service-common/docs/pattern.md` syntax
3. **Pattern-Based**: Teach discovery, not inventories
4. **Thin CLAUDE.md**: Service CLAUDE.md files should be 200-300 lines max
5. **Service-Specific Only**: Only document what's UNIQUE to that service

## Commands to Test After Changes

```bash
# Verify discovery commands work
cd /workspace/service-common
find src/main/java -type d | grep -E "org/budgetanalyzer" | head -10

cd /workspace/transaction-service
grep -r "@RestController" src/

cd /workspace/currency-service
grep -r "@Service" src/

# Check line counts
wc -l /workspace/*/CLAUDE.md
```

## Important Notes

- All files are in `/workspace/` directory
- Service repositories: orchestration, service-common, transaction-service, currency-service, budget-analyzer-web
- Main plan document: `/workspace/orchestration/docs/claude-md-reorganization-plan.md`
- This continuation prompt: `/workspace/orchestration/docs/phase-3-continuation-prompt.md`

## Success Criteria

When complete:
- [ ] service-common has comprehensive docs for all shared patterns
- [ ] service-common/docs/advanced-patterns.md exists with currency-service patterns
- [ ] transaction-service/CLAUDE.md is ~200-300 lines, references service-common
- [ ] currency-service/CLAUDE.md is ~200-300 lines, references service-common
- [ ] budget-analyzer-web/CLAUDE.md is ~200-300 lines (frontend patterns)
- [ ] No duplicated content between service-common and services
- [ ] All discovery commands tested and working

## Resume Command

To continue this work:

```
Continue with Phase 3 of the CLAUDE.md reorganization. Read the continuation prompt at /workspace/orchestration/docs/phase-3-continuation-prompt.md for full context.

Next steps:
1. Extract currency-service advanced patterns (provider abstraction, event-driven messaging, Redis caching, ShedLock, Flyway) to service-common/docs/advanced-patterns.md
2. Transform transaction-service/CLAUDE.md to pattern-based (reference service-common, keep only CSV import and service-specific content)
3. Transform currency-service/CLAUDE.md to pattern-based (reference service-common, keep only FRED integration specifics)
4. Transform budget-analyzer-web/CLAUDE.md to pattern-based (React/frontend patterns)

Remember: Reference service-common docs, don't duplicate. Target 200-300 lines per service CLAUDE.md.
```
