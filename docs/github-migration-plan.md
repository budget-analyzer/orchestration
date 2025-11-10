# GitHub Organization Migration Plan

## Overview

This document provides step-by-step instructions for migrating the Budget Analyzer project from personal GitHub account (`bleurubin`) to the `budget-analyzer` organization, including repository renaming and Java package refactoring.

## Migration Summary

### Repository Changes
| Current Name | New Name | New URL |
|--------------|----------|---------|
| `bleurubin/budget-analyzer` | `budget-analyzer/orchestration` | `git@github.com:budget-analyzer/orchestration.git` |
| `bleurubin/budget-analyzer-api` | `budget-analyzer/transaction-service` | `git@github.com:budget-analyzer/transaction-service.git` |
| `bleurubin/budget-analyzer-web` | `budget-analyzer/budget-analyzer-web` | `git@github.com:budget-analyzer/budget-analyzer-web.git` |
| `bleurubin/currency-service` | `budget-analyzer/currency-service` | `git@github.com:budget-analyzer/currency-service.git` |
| `bleurubin/service-common` | `budget-analyzer/service-common` | `git@github.com:budget-analyzer/service-common.git` |

### Package Changes
| Service | Current Package | New Package |
|---------|----------------|-------------|
| transaction-service | `com.bleurubin.*` | `org.budgetanalyzer.transaction.*` |
| currency-service | `com.bleurubin.*` | `org.budgetanalyzer.currency.*` |
| service-common | `com.bleurubin.*` | `org.budgetanalyzer.common.*` |

---

## Phase 1: GitHub Organization Migration

### Prerequisites
- ✅ GitHub organization `budget-analyzer` created
- 🔐 Admin access to all repositories under `bleurubin`
- 💾 All local changes committed and pushed

### Step 1.1: Transfer Repositories to Organization

For each repository, perform the following in the GitHub web interface:

1. Navigate to the repository (e.g., `https://github.com/bleurubin/budget-analyzer`)
2. Click **Settings** (top right)
3. Scroll to bottom → **Danger Zone** → **Transfer ownership**
4. Enter new owner: `budget-analyzer`
5. Confirm transfer

**Repeat for all 5 repositories:**
- [ ] `budget-analyzer`
- [ ] `budget-analyzer-api`
- [ ] `budget-analyzer-web`
- [ ] `currency-service`
- [ ] `service-common`

### Step 1.2: Rename Repositories in Organization

After transfer, rename repositories in GitHub:

1. **orchestration** (formerly `budget-analyzer`):
   - Go to `https://github.com/budget-analyzer/budget-analyzer`
   - Settings → Repository name → Change to `orchestration`
   - Save

2. **transaction-service** (formerly `budget-analyzer-api`):
   - Go to `https://github.com/budget-analyzer/budget-analyzer-api`
   - Settings → Repository name → Change to `transaction-service`
   - Save

3. Keep these names as-is:
   - [ ] `budget-analyzer-web` (no rename)
   - [ ] `currency-service` (no rename)
   - [ ] `service-common` (no rename)

---

## Phase 2: Update Local Git Remotes

### Step 2.1: Update orchestration Repository

```bash
# Navigate to orchestration repo
cd /workspace/budget-analyzer

# Verify current remote
git remote -v

# Update remote URL
git remote set-url origin git@github.com:budget-analyzer/orchestration.git

# Verify change
git remote -v

# Test connection
git fetch origin
```

### Step 2.2: Update transaction-service Repository

```bash
# Navigate to transaction-service repo (adjust path as needed)
cd /path/to/budget-analyzer-api

# Update remote URL
git remote set-url origin git@github.com:budget-analyzer/transaction-service.git

# Verify and test
git remote -v
git fetch origin
```

### Step 2.3: Update Other Repositories

```bash
# currency-service
cd /path/to/currency-service
git remote set-url origin git@github.com:budget-analyzer/currency-service.git
git remote -v && git fetch origin

# service-common
cd /path/to/service-common
git remote set-url origin git@github.com:budget-analyzer/service-common.git
git remote -v && git fetch origin

# budget-analyzer-web
cd /path/to/budget-analyzer-web
git remote set-url origin git@github.com:budget-analyzer/budget-analyzer-web.git
git remote -v && git fetch origin
```

---

## Phase 3: Update Documentation (orchestration repo)

### Step 3.1: Update CLAUDE.md

File: `/workspace/budget-analyzer/CLAUDE.md`

**Lines 215-218** - Update repository URLs:

```markdown
## Service Repositories

Each microservice is maintained in its own repository:
- **service-common**: [https://github.com/budget-analyzer/service-common]
- **transaction-service**: [https://github.com/budget-analyzer/transaction-service]
- **currency-service**: [https://github.com/budget-analyzer/currency-service]
- **budget-analyzer-web**: [https://github.com/budget-analyzer/budget-analyzer-web]
```

Also update any references to "budget-analyzer-api" → "transaction-service" throughout the document.

### Step 3.2: Update OpenAPI Documentation (Optional)

**Decision needed:** Do you want to update these now or later?

Files to update if changing from `bleurubin.com` domain:
- `docs-aggregator/openapi.yaml`
- `docs-aggregator/openapi.json`
- `scripts/generate-unified-api-docs.sh`

Current values:
- Contact email: `support@bleurubin.com`
- Production API: `https://api.bleurubin.com`

**If updating**, change to:
- Contact email: `support@budgetanalyzer.com` (or desired email)
- Production API: `https://api.budgetanalyzer.com` (or desired domain)

### Step 3.3: Commit Documentation Changes

```bash
cd /workspace/budget-analyzer

# Stage changes
git add CLAUDE.md
git add docs-aggregator/  # if updated
git add scripts/generate-unified-api-docs.sh  # if updated

# Commit
git commit -m "Update repository URLs for GitHub organization migration

- Migrate from bleurubin to budget-analyzer organization
- Update service repository references
- Rename budget-analyzer-api to transaction-service"

# Push to new remote
git push origin main
```

---

## Phase 4: Java Package Refactoring

This phase must be done for each Java-based service.

### Step 4.1: Refactor service-common

**This must be done FIRST** as other services depend on it.

```bash
cd /path/to/service-common
```

#### 4.1.1: Rename Package Directories

```bash
# Create new package structure
mkdir -p src/main/java/org/budgetanalyzer/common
mkdir -p src/test/java/org/budgetanalyzer/common

# Move files (adjust based on actual structure)
# Manual step: Use IDE refactoring or move files manually
```

#### 4.1.2: Update Package Declarations

Find and replace in all `.java` files:
- `package com.bleurubin` → `package org.budgetanalyzer.common`
- `import com.bleurubin` → `import org.budgetanalyzer.common`

#### 4.1.3: Update Maven/Gradle Configuration

**If using Maven (`pom.xml`):**
```xml
<groupId>org.budgetanalyzer</groupId>
<artifactId>service-common</artifactId>
```

**If using Gradle (`build.gradle`):**
```gradle
group = 'org.budgetanalyzer'
```

#### 4.1.4: Update Application Properties

Check `src/main/resources/application.properties` or `application.yml` for any package references.

#### 4.1.5: Build and Test

```bash
# Maven
./mvnw clean install

# Or Gradle
./gradlew clean build

# Verify tests pass
./mvnw test
# or
./gradlew test
```

#### 4.1.6: Commit and Push

```bash
git add .
git commit -m "Refactor packages from com.bleurubin to org.budgetanalyzer.common"
git push origin main
```

### Step 4.2: Refactor transaction-service

```bash
cd /path/to/transaction-service
```

Follow same steps as service-common:
1. Create `org/budgetanalyzer/transaction` directory structure
2. Move files
3. Update package declarations: `com.bleurubin.*` → `org.budgetanalyzer.transaction.*`
4. Update imports from service-common: `com.bleurubin.common.*` → `org.budgetanalyzer.common.*`
5. Update `pom.xml` or `build.gradle`:
   ```xml
   <groupId>org.budgetanalyzer</groupId>
   <artifactId>transaction-service</artifactId>
   ```
6. Update service-common dependency to use new groupId:
   ```xml
   <dependency>
       <groupId>org.budgetanalyzer</groupId>
       <artifactId>service-common</artifactId>
       <version>1.0.0</version>
   </dependency>
   ```
7. Build and test: `./mvnw clean install && ./mvnw test`
8. Commit: `git commit -m "Refactor packages from com.bleurubin to org.budgetanalyzer.transaction"`
9. Push: `git push origin main`

### Step 4.3: Refactor currency-service

```bash
cd /path/to/currency-service
```

Follow same steps:
1. Create `org/budgetanalyzer/currency` directory structure
2. Move files
3. Update package declarations: `com.bleurubin.*` → `org.budgetanalyzer.currency.*`
4. Update imports from service-common: `com.bleurubin.common.*` → `org.budgetanalyzer.common.*`
5. Update `pom.xml` or `build.gradle`:
   ```xml
   <groupId>org.budgetanalyzer</groupId>
   <artifactId>currency-service</artifactId>
   ```
6. Update service-common dependency
7. Build and test: `./mvnw clean install && ./mvnw test`
8. Commit: `git commit -m "Refactor packages from com.bleurubin to org.budgetanalyzer.currency"`
9. Push: `git push origin main`

### Step 4.4: Update budget-analyzer-web (if needed)

If the web app has any hardcoded references to old package names or repository URLs:

```bash
cd /path/to/budget-analyzer-web

# Search for any references
grep -r "com.bleurubin" .
grep -r "bleurubin/budget-analyzer" .

# Update as needed
# Commit and push
```

---

## Phase 5: Update Docker and Development Environment

### Step 5.1: Rebuild Docker Images

After package refactoring, rebuild all service images:

```bash
cd /workspace/budget-analyzer

# Stop running containers
docker-compose down

# Remove old images (optional, to ensure clean build)
docker images | grep budget-analyzer
docker rmi <image-ids>  # if needed

# Rebuild services
docker-compose build --no-cache

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f
```

### Step 5.2: Verify Services Are Running

```bash
# Check container status
docker-compose ps

# Test health endpoints
curl http://localhost:8080/health
curl http://localhost:8082/actuator/health  # transaction-service
curl http://localhost:8084/actuator/health  # currency-service

# Test API endpoints
curl http://localhost:8080/api/transactions
curl http://localhost:8080/api/currencies
```

### Step 5.3: Verify NGINX Routing

The NGINX configuration should still work without changes, but verify:

```bash
# Check NGINX config is valid
docker exec api-gateway nginx -t

# Test routing through gateway
curl http://localhost:8080/api/transactions
curl http://localhost:8080/api/currencies
```

---

## Phase 6: Verification Checklist

### GitHub Verification
- [ ] All 5 repositories transferred to `budget-analyzer` organization
- [ ] `orchestration` renamed successfully
- [ ] `transaction-service` renamed successfully
- [ ] All repositories accessible at new URLs
- [ ] Local git remotes updated for all repos

### Code Verification
- [ ] service-common builds successfully
- [ ] transaction-service builds successfully
- [ ] currency-service builds successfully
- [ ] All tests pass in service-common
- [ ] All tests pass in transaction-service
- [ ] All tests pass in currency-service

### Documentation Verification
- [ ] CLAUDE.md updated with new URLs
- [ ] OpenAPI specs updated (if applicable)
- [ ] No broken links in documentation

### Runtime Verification
- [ ] Docker Compose starts all services
- [ ] NGINX gateway routes requests correctly
- [ ] transaction-service responds to API calls
- [ ] currency-service responds to API calls
- [ ] Frontend can communicate with backend through gateway
- [ ] No errors in docker-compose logs

### Database Verification (if applicable)
- [ ] Database migrations still work
- [ ] Data persistence works after restart
- [ ] No schema issues from package refactoring

---

## Rollback Plan

If issues arise, you can rollback:

### Rollback Git Remotes
```bash
# Per repository
git remote set-url origin git@github.com:bleurubin/<old-repo-name>.git
```

### Rollback GitHub Transfer
1. Transfer repositories back to `bleurubin` account (Settings → Transfer)
2. Rename back to original names

### Rollback Code Changes
```bash
# Per repository
git log  # Find commit before refactoring
git revert <commit-hash>
# Or
git reset --hard <commit-before-refactoring>
git push -f origin main  # Use with caution!
```

---

## Post-Migration Tasks

### Update CI/CD (when implemented)
- [ ] Update GitHub Actions workflow references
- [ ] Update Docker Hub repository names (if applicable)
- [ ] Update deployment scripts

### Update Team Access (if applicable)
- [ ] Add collaborators to organization
- [ ] Set up teams in organization
- [ ] Configure branch protection rules

### Update External Services
- [ ] Update webhook URLs (if any)
- [ ] Update API documentation sites (if any)
- [ ] Update monitoring/alerting services (if any)

### Communication
- [ ] Update README badges (if any)
- [ ] Notify collaborators (if any)
- [ ] Update personal documentation

---

## Common Issues and Solutions

### Issue: "Repository not found" after transfer
**Solution:** GitHub may need a few minutes to propagate. Wait and retry. Clear DNS cache if needed.

### Issue: Package refactoring breaks compilation
**Solution:** Ensure all imports are updated. Use IDE's "Find and Replace in Files" with regex if needed.

### Issue: Docker build fails after package rename
**Solution:**
- Clear Docker build cache: `docker builder prune`
- Rebuild with `--no-cache` flag
- Check Dockerfile COPY paths are correct

### Issue: Tests fail after refactoring
**Solution:**
- Check test resource files for package references
- Update `@SpringBootTest` annotations
- Verify test configuration files

### Issue: Services can't find each other
**Solution:**
- Check docker-compose service names unchanged
- Verify NGINX upstream configurations
- Check application.properties for hardcoded URLs

---

## Timeline Estimate

- **Phase 1 (GitHub Migration)**: 30 minutes
- **Phase 2 (Local Remotes)**: 15 minutes
- **Phase 3 (Documentation)**: 15 minutes
- **Phase 4 (Package Refactoring)**: 2-4 hours (depends on codebase size)
- **Phase 5 (Docker/Testing)**: 30 minutes
- **Phase 6 (Verification)**: 30 minutes

**Total estimated time**: 4-6 hours

---

## Notes

- This migration can be done incrementally (one repo at a time)
- Recommend doing service-common first, then dependent services
- Keep old repository URLs bookmarked until fully verified
- Document any deviations from this plan
- Update this document with any lessons learned

---

**Migration Date**: _________________

**Performed By**: _________________

**Status**: ⬜ Not Started | ⬜ In Progress | ⬜ Completed | ⬜ Rolled Back
