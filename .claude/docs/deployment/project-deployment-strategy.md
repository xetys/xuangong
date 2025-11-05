# Xuan Gong Project-Wide Deployment Strategy

**Version**: 1.0.0
**Last Updated**: 2025-11-03
**Status**: Living Document

---

## Table of Contents

1. [Overview](#overview)
2. [Infrastructure Architecture](#infrastructure-architecture)
3. [Versioning Strategy](#versioning-strategy)
4. [Environment Management](#environment-management)
5. [Build & Release Process](#build--release-process)
6. [Deployment Workflows](#deployment-workflows)
7. [Database Management](#database-management)
8. [Security & Compliance](#security--compliance)
9. [Monitoring & Observability](#monitoring--observability)
10. [Disaster Recovery](#disaster-recovery)
11. [CI/CD Pipeline](#cicd-pipeline)
12. [Troubleshooting](#troubleshooting)
13. [Future Roadmap](#future-roadmap)

---

## Overview

### Project Components

Xuan Gong consists of two primary deployable components:

1. **Backend API** (`xuangong-backend`)
   - Technology: Go 1.24
   - Database: PostgreSQL (Bitnami subchart)
   - Repository: `ghcr.io/xetys/xuangong/api`
   - Helm Chart: `backend/helm/xuangong-backend`

2. **Frontend Application** (`xuangong-app`)
   - Technology: Flutter (mobile + web)
   - Web Server: nginx (Alpine-based)
   - Repository: `ghcr.io/xetys/xuangong/app`
   - Helm Chart: `app/helm/xuangong-app`

### Deployment Philosophy

- **Simplicity First**: Avoid over-engineering; use straightforward tools
- **Reliability**: Zero-downtime deployments with automated rollback
- **Security**: Non-root containers, TLS everywhere, secrets management
- **Consistency**: Same workflow for all components
- **Observability**: Monitor everything, debug quickly

---

## Infrastructure Architecture

### Kubernetes Cluster

**Provider**: Stytex Cloud Managed Kubernetes
**Kubeconfig**: `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`

**Cluster Characteristics**:
- **Platform**: `linux/amd64`
- **Ingress Controller**: nginx-ingress-controller
- **Certificate Management**: cert-manager with Let's Encrypt
- **Storage**: Default StorageClass (provider-managed)
- **Metrics**: metrics-server (for HPA)

### Namespaces

| Namespace | Purpose | Components |
|-----------|---------|------------|
| `xuangong-prod` | Production environment | Backend API, Frontend App, PostgreSQL |
| `xuangong-dev` | Development/staging | (Future) Development deployments |
| `xuangong-system` | Infrastructure | (Future) Monitoring, logging |

### Network Architecture

```
Internet
    ↓
[Let's Encrypt TLS]
    ↓
[nginx Ingress Controller]
    ↓
    ├── xuangong-prod.stytex.cloud → Backend API (ClusterIP)
    │                                      ↓
    │                                PostgreSQL (ClusterIP)
    │
    └── app.xuangong-prod.stytex.cloud → Frontend App (ClusterIP)
```

### DNS & Domains

| Domain | Target | TLS Certificate |
|--------|--------|-----------------|
| `xuangong-prod.stytex.cloud` | Backend API | Let's Encrypt (cert-manager) |
| `app.xuangong-prod.stytex.cloud` | Frontend Web | Let's Encrypt (cert-manager) |

### Registry

**GitHub Container Registry (GHCR)**:
- Registry: `ghcr.io`
- Organization: `xetys`
- Backend Images: `ghcr.io/xetys/xuangong/api`
- Frontend Images: `ghcr.io/xetys/xuangong/app`

**Authentication**:
- Local: `docker login ghcr.io` with Personal Access Token
- Kubernetes: `regcred` ImagePullSecret in `xuangong-prod` namespace

---

## Versioning Strategy

### Version Format

**Pattern**: `v<YEAR>.<MAJOR>.<MINOR>-<STAGE><NUMBER>`

**Examples**:
- `v2025.1.0-alpha1`, `v2025.1.0-alpha2`, ..., `v2025.1.0-alpha12`
- `v2025.1.0-beta1`, `v2025.1.0-beta2`
- `v2025.1.0` (stable release)
- `v2025.1.1` (patch release)
- `v2025.2.0` (feature release)

### Release Stages

1. **Alpha** (`-alphaN`)
   - Internal testing
   - Breaking changes allowed
   - Frequent releases
   - Current stage for MVP development

2. **Beta** (`-betaN`)
   - Feature complete
   - User acceptance testing
   - Bug fixes only, no new features
   - API stabilization

3. **Stable** (no suffix)
   - Production ready
   - Public release
   - Semantic versioning for patches/features

### Component Versioning

**Independent Versioning**:
- Backend and Frontend can have different version numbers
- Backend: Currently `v2025.1.0-alpha3`
- Frontend: Currently `v2025.1.0-alpha11`

**Why Independent?**:
- Components evolve at different rates
- Frontend may iterate faster (UI changes)
- Backend may be more stable (API contracts)

**Synchronized Releases** (Future):
- For major releases (v2025.1.0 stable), coordinate versions
- Tag repository with combined version
- Create GitHub Release with both components

### Git Tagging Strategy

**Current** (Alpha):
```bash
# Tag individual component releases
git tag -a app/v2025.1.0-alpha12 -m "Flutter app alpha12 release"
git tag -a backend/v2025.1.0-alpha3 -m "Backend API alpha3 release"
git push origin --tags
```

**Future** (Beta/Stable):
```bash
# Tag synchronized releases
git tag -a v2025.1.0-beta1 -m "Xuan Gong Beta 1\n\nBackend: v2025.1.0-beta1\nFrontend: v2025.1.0-beta1"
git push origin v2025.1.0-beta1

# Create GitHub Release with release notes
gh release create v2025.1.0-beta1 \
  --title "Xuan Gong Beta 1" \
  --notes-file RELEASE_NOTES.md
```

---

## Environment Management

### Production Environment

**Namespace**: `xuangong-prod`

**Backend Configuration**:
- Replicas: 3 (autoscaling 3-20)
- Resources: 200m CPU / 256Mi memory (requests), 1000m CPU / 1Gi memory (limits)
- Database: PostgreSQL with 20Gi persistent volume
- JWT: 15m access tokens, 7d refresh tokens
- Rate Limiting: 100 req/min per IP
- CORS: Restricted to production domains

**Frontend Configuration**:
- Replicas: 2 (autoscaling 2-10)
- Resources: 50m CPU / 64Mi memory (requests), 200m CPU / 256Mi memory (limits)
- API URL: https://xuangong-prod.stytex.cloud

**High Availability**:
- Pod Anti-Affinity: Required (different nodes)
- Pod Disruption Budget: Backend min 2, Frontend min 1
- HPA: CPU and memory-based autoscaling
- ReadinessProbe: Health checks before traffic routing
- LivenessProbe: Container health monitoring

### Development Environment (Future)

**Namespace**: `xuangong-dev`

**Planned Configuration**:
- Replicas: 1 (no autoscaling)
- Reduced resource limits
- In-cluster PostgreSQL (no persistence)
- Permissive CORS
- No TLS (optional)
- Local domain: `xuangong.dev.local`

**Values Files**:
- `backend/helm/xuangong-backend/values-development.yaml`
- `app/helm/xuangong-app/values-development.yaml`

### Local Development

**Backend**:
```bash
cd backend
make docker-up          # Start PostgreSQL in Docker
make migrate-up         # Run migrations
make seed              # Seed test data
make dev               # Start with hot reload (air)
```

**Frontend**:
```bash
cd app
flutter run -d chrome  # Web development
flutter run           # Mobile (simulator/emulator)
```

**Environment Variables**:
- Development: Use `.env` files (NOT committed to git)
- Production: Use Kubernetes ConfigMaps and Secrets

---

## Build & Release Process

### Build Platform Considerations

**Development Machine**:
- Platform: macOS (darwin/arm64)
- Target Platform: Kubernetes nodes (linux/amd64)
- Solution: Docker buildx with `--platform linux/amd64`

### Backend Build Process

**1. Build Binary**:
```bash
cd backend
make build  # Local testing

# Or build directly with Go
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/api cmd/api/main.go
```

**2. Build Docker Image**:
```bash
cd backend
make docker-build-prod TAG=v2025.1.0-alpha4

# This runs:
# docker buildx build \
#   --platform linux/amd64 \
#   --tag ghcr.io/xetys/xuangong/api:v2025.1.0-alpha4 \
#   --load .
```

**Multi-Stage Dockerfile**:
- **Stage 1** (Builder): golang:1.24-alpine
  - Install build dependencies
  - Download Go modules
  - Build static binary (CGO_ENABLED=0)
- **Stage 2** (Runtime): alpine:latest
  - Minimal image (ca-certificates only)
  - Non-root user (appuser:1000)
  - Copy binary and migrations

**3. Push to Registry**:
```bash
cd backend
make docker-push-prod TAG=v2025.1.0-alpha4

# Requires: docker login ghcr.io
```

### Frontend Build Process

**1. Build Flutter Web**:
```bash
cd app
flutter build web --release

# Output: app/build/web/
```

**2. Build Docker Image**:
```bash
cd app
make docker-build-prod TAG=v2025.1.0-alpha13

# This runs:
# docker buildx build \
#   --platform linux/amd64 \
#   --tag ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13 \
#   --load .
```

**Multi-Stage Dockerfile**:
- **Stage 1** (Builder): ghcr.io/cirruslabs/flutter:stable
  - Install Flutter dependencies
  - Build Flutter web release
  - Output: /app/build/web
- **Stage 2** (Runtime): nginx:alpine
  - Non-root nginx user (uid 101)
  - Port 8080 (non-privileged)
  - envsubst script for runtime API URL injection
  - Security headers, gzip compression

**3. Push to Registry**:
```bash
cd app
make docker-push-prod TAG=v2025.1.0-alpha13
```

### Build Automation

**Makefile Targets**:
- `make docker-build-prod TAG=<version>` - Build production image
- `make docker-push-prod TAG=<version>` - Push to registry
- `make help` - Show available targets

**Best Practices**:
- Always specify explicit tags (no `latest` in production)
- Tag format: `v2025.1.0-alphaN`
- Test image locally before pushing: `docker run --rm -p 8080:8080 <image>`
- Verify image exists: `docker images | grep xuangong`

---

## Deployment Workflows

### Unified Deployment Workflow

This workflow applies to **both** backend and frontend deployments.

#### Prerequisites

**Local Environment**:
```bash
# 1. Docker Desktop running
docker --version

# 2. Logged into GHCR
docker login ghcr.io

# 3. kubectl configured
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
kubectl config current-context

# 4. Helm 3 installed
helm version

# 5. Verify cluster access
kubectl get pods -n xuangong-prod
```

#### Step 1: Determine Version Number

**Versioning Rules**:
- Increment alpha number for each release
- Backend example: alpha3 → alpha4
- Frontend example: alpha12 → alpha13
- Check current version:
  ```bash
  # Backend
  grep "tag:" backend/helm/xuangong-backend/values-production.yaml

  # Frontend
  grep "tag:" app/helm/xuangong-app/values-production.yaml
  ```

#### Step 2: Build Docker Image

**Backend**:
```bash
cd backend
export NEW_VERSION=v2025.1.0-alpha4
make docker-build-prod TAG=$NEW_VERSION
```

**Frontend**:
```bash
cd app
export NEW_VERSION=v2025.1.0-alpha13
make docker-build-prod TAG=$NEW_VERSION
```

**Time Estimate**: 5-10 minutes (depends on Docker cache)

#### Step 3: Test Image Locally (Optional but Recommended)

**Backend**:
```bash
docker run --rm -p 8080:8080 \
  -e DATABASE_URL=postgres://user:pass@host/db \
  -e JWT_SECRET=test \
  ghcr.io/xetys/xuangong/api:$NEW_VERSION

# Test in another terminal
curl http://localhost:8080/api/v1/health
# Expected: {"status":"healthy"}
```

**Frontend**:
```bash
docker run --rm -p 8080:8080 \
  -e API_URL=https://xuangong-prod.stytex.cloud \
  ghcr.io/xetys/xuangong/app:$NEW_VERSION

# Test in another terminal
curl http://localhost:8080
# Expected: HTTP 200, HTML content
```

#### Step 4: Push Image to Registry

**Backend**:
```bash
cd backend
make docker-push-prod TAG=$NEW_VERSION
```

**Frontend**:
```bash
cd app
make docker-push-prod TAG=$NEW_VERSION
```

**Verification**:
- Visit: https://github.com/xetys/xuangong/pkgs/container/xuangong%2Fapi (backend)
- Visit: https://github.com/xetys/xuangong/pkgs/container/xuangong%2Fapp (frontend)
- Confirm new tag is visible

**Time Estimate**: 3-5 minutes (upload time)

#### Step 5: Update Helm Values File

**Backend**:
```bash
# Edit values-production.yaml
# Change: tag: "v2025.1.0-alpha3"
# To:     tag: "v2025.1.0-alpha4"

cd backend
sed -i '' 's/v2025.1.0-alpha3/v2025.1.0-alpha4/' \
  helm/xuangong-backend/values-production.yaml

# Verify
grep "tag:" helm/xuangong-backend/values-production.yaml
```

**Frontend**:
```bash
cd app
sed -i '' 's/v2025.1.0-alpha12/v2025.1.0-alpha13/' \
  helm/xuangong-app/values-production.yaml

# Verify
grep "tag:" helm/xuangong-app/values-production.yaml
```

#### Step 6: Verify Helm Chart

**Backend**:
```bash
cd backend
helm template xuangong-backend ./helm/xuangong-backend \
  -f ./helm/xuangong-backend/values-production.yaml \
  -n xuangong-prod | grep "image:"

# Expected: image: "ghcr.io/xetys/xuangong/api:v2025.1.0-alpha4"
```

**Frontend**:
```bash
cd app
helm template xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod | grep "image:"

# Expected: image: "ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13"
```

#### Step 7: Deploy to Kubernetes

**Set KUBECONFIG**:
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
kubectl config current-context
```

**Backend Deployment**:
```bash
cd backend
helm upgrade xuangong-backend ./helm/xuangong-backend \
  -f ./helm/xuangong-backend/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 10m

# Note: Longer timeout for backend due to database migrations
```

**Frontend Deployment**:
```bash
cd app
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 5m
```

**Deployment Strategy**:
- Rolling Update (default)
- MaxUnavailable: 25%
- MaxSurge: 25%
- Gradual rollout with health checks

**Time Estimate**: 2-10 minutes (backend slower due to migrations)

#### Step 8: Verify Deployment

**Check Pod Status**:
```bash
# Backend
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend

# Frontend
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# Expected: All pods Running and Ready
```

**Check Rollout Status**:
```bash
# Backend
kubectl rollout status deployment/xuangong-backend -n xuangong-prod

# Frontend
kubectl rollout status deployment/xuangong-app -n xuangong-prod

# Expected: "successfully rolled out"
```

**Verify Image Tags**:
```bash
# Backend
kubectl get deployment xuangong-backend -n xuangong-prod -o yaml | grep "image:"

# Frontend
kubectl get deployment xuangong-app -n xuangong-prod -o yaml | grep "image:"
```

**Check Logs**:
```bash
# Backend (check migrations ran successfully)
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend --tail=100

# Frontend (check API URL injection)
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=50
```

#### Step 9: Functional Testing

**Backend**:
```bash
# Health check
curl https://xuangong-prod.stytex.cloud/api/v1/health

# Expected: {"status":"healthy"}

# Database connectivity
curl https://xuangong-prod.stytex.cloud/api/v1/programs

# Expected: JSON array (requires auth, may be empty/401)
```

**Frontend**:
```bash
# HTTP status
curl -I https://app.xuangong-prod.stytex.cloud

# Expected: HTTP/2 200

# API URL injection check
curl -s https://app.xuangong-prod.stytex.cloud | grep "API_URL"

# Expected: Should NOT see "$API_URL" placeholder

# Open in browser
open https://app.xuangong-prod.stytex.cloud

# Manual checks:
# 1. App loads without errors
# 2. Login works
# 3. No console errors in DevTools
# 4. API calls succeed (check Network tab)
```

**Integration Testing**:
```bash
# Test frontend → backend communication
# 1. Open app: https://app.xuangong-prod.stytex.cloud
# 2. Login with test account
# 3. Navigate to programs
# 4. Verify data loads from backend
# 5. Check browser DevTools → Network tab
# 6. Verify requests go to: https://xuangong-prod.stytex.cloud
```

#### Step 10: Monitor Deployment

**Watch for Issues** (first 15 minutes):
```bash
# Pod health
kubectl get pods -n xuangong-prod -w

# Events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp' | tail -20

# Resource usage
kubectl top pods -n xuangong-prod

# HPA status
kubectl get hpa -n xuangong-prod
```

**Monitor Logs**:
```bash
# Backend logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend -f

# Frontend logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app -f
```

#### Step 11: Post-Deployment Tasks

**1. Update Documentation**:
```bash
# Update recent-work.md
# Add deployment entry with version, date, changes

nano .claude/tasks/context/recent-work.md
```

**2. Create Session Log** (if significant changes):
```bash
# Format: YYYY-MM-DD_topic-slug.md
touch .claude/tasks/sessions/2025-11-03_alpha4-deployment.md
```

**3. Git Commit**:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong

# Add changed files
git add backend/helm/xuangong-backend/values-production.yaml
git add app/helm/xuangong-app/values-production.yaml
git add .claude/tasks/context/recent-work.md

# Commit
git commit -m "Deploy backend v2025.1.0-alpha4 and frontend v2025.1.0-alpha13

- Updated Helm values files with new image tags
- Deployed to xuangong-prod namespace
- Verified successful rollout

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# Push
git push origin main
```

**4. Tag Release**:
```bash
# Backend
git tag -a backend/v2025.1.0-alpha4 -m "Backend API alpha4 release"

# Frontend
git tag -a app/v2025.1.0-alpha13 -m "Flutter app alpha13 release"

# Push tags
git push origin --tags
```

### Rollback Procedures

#### Quick Rollback (Recommended)

**Backend**:
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

helm rollback xuangong-backend -n xuangong-prod

# Verify
kubectl rollout status deployment/xuangong-backend -n xuangong-prod
kubectl get deployment xuangong-backend -n xuangong-prod -o yaml | grep "image:"
```

**Frontend**:
```bash
helm rollback xuangong-app -n xuangong-prod

# Verify
kubectl rollout status deployment/xuangong-app -n xuangong-prod
kubectl get deployment xuangong-app -n xuangong-prod -o yaml | grep "image:"
```

**Rollback to Specific Revision**:
```bash
# List revisions
helm history xuangong-backend -n xuangong-prod

# Rollback to specific revision
helm rollback xuangong-backend <revision> -n xuangong-prod
```

#### Manual Rollback

If Helm rollback fails:

**Backend**:
```bash
# Edit values file back to previous version
cd backend
sed -i '' 's/v2025.1.0-alpha4/v2025.1.0-alpha3/' \
  helm/xuangong-backend/values-production.yaml

# Redeploy
helm upgrade xuangong-backend ./helm/xuangong-backend \
  -f ./helm/xuangong-backend/values-production.yaml \
  -n xuangong-prod --wait
```

**Frontend**:
```bash
cd app
sed -i '' 's/v2025.1.0-alpha13/v2025.1.0-alpha12/' \
  helm/xuangong-app/values-production.yaml

helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod --wait
```

#### Emergency Rollback

Direct kubectl patch (last resort):

**Backend**:
```bash
kubectl set image deployment/xuangong-backend \
  xuangong-backend=ghcr.io/xetys/xuangong/api:v2025.1.0-alpha3 \
  -n xuangong-prod

kubectl rollout status deployment/xuangong-backend -n xuangong-prod
```

**Frontend**:
```bash
kubectl set image deployment/xuangong-app \
  xuangong-app=ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12 \
  -n xuangong-prod

kubectl rollout status deployment/xuangong-app -n xuangong-prod
```

### Coordinated Deployment (Backend + Frontend)

When deploying **both** components together:

**1. Deploy Backend First**:
```bash
# Backend deployment (Steps 1-9 above)
cd backend
make docker-build-prod TAG=v2025.1.0-alpha4
make docker-push-prod TAG=v2025.1.0-alpha4
# ... update values, deploy, verify
```

**2. Wait for Backend Stabilization**:
```bash
# Ensure backend is healthy before deploying frontend
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend
curl https://xuangong-prod.stytex.cloud/api/v1/health
```

**3. Deploy Frontend**:
```bash
cd app
make docker-build-prod TAG=v2025.1.0-alpha13
make docker-push-prod TAG=v2025.1.0-alpha13
# ... update values, deploy, verify
```

**4. Integration Testing**:
```bash
# Test full stack
open https://app.xuangong-prod.stytex.cloud
# Login, test all features, verify API calls work
```

**Why Backend First?**:
- Frontend depends on backend API
- Backend changes may include new endpoints
- Ensures API compatibility before frontend update

---

## Database Management

### Database Architecture

**PostgreSQL Deployment**:
- Deployed as Bitnami PostgreSQL subchart
- Managed by backend Helm chart
- Single primary instance (no replication yet)
- Persistent volume: 20Gi (default storage class)

**Access**:
- Internal DNS: `xuangong-prod-postgresql.xuangong-prod.svc.cluster.local`
- Port: 5432
- Database: `xuangong_production`
- User: `xuangong`

### Migration Strategy

**Framework**: golang-migrate

**Migration Lifecycle**:
1. Developer creates migration: `make migrate-create name=add_video_table`
2. Migration files created in `backend/migrations/`
   - `000001_add_video_table.up.sql` (apply)
   - `000001_add_video_table.down.sql` (rollback)
3. Migrations bundled into Docker image (`COPY migrations ./migrations`)
4. Backend runs migrations on startup (automatic)

**Migration Execution**:
- **Automatic**: Backend application runs pending migrations on startup
- **Manual**: `kubectl exec` into backend pod, run migrate command

**Best Practices**:
- Always write both `up` and `down` migrations
- Test migrations locally before deploying
- Never edit applied migrations (create new ones)
- Idempotent migrations (safe to run multiple times)
- Add indexes in separate migration from table creation

### Database Backup

**Current State**: No automated backups (⚠️ HIGH PRIORITY)

**Planned Backup Strategy**:

**1. PostgreSQL WAL Archiving**:
```yaml
postgresql:
  backup:
    enabled: true
    cronjob:
      schedule: "0 2 * * *"  # Daily at 2 AM
      storage:
        existingClaim: backup-pvc
        size: 100Gi
```

**2. Manual Backup**:
```bash
# Port-forward to PostgreSQL
kubectl port-forward -n xuangong-prod svc/xuangong-prod-postgresql 5432:5432

# Backup with pg_dump
PGPASSWORD=<password> pg_dump \
  -h localhost \
  -U xuangong \
  -d xuangong_production \
  > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
PGPASSWORD=<password> psql \
  -h localhost \
  -U xuangong \
  -d xuangong_production \
  < backup_20251103_140000.sql
```

**3. Velero Cluster Backup** (Future):
- Full cluster backup including PVs
- Scheduled snapshots
- Point-in-time recovery

### Database Operations

**Access Database**:
```bash
# Get PostgreSQL password
kubectl get secret xuangong-backend -n xuangong-prod -o jsonpath='{.data.database-password}' | base64 -d

# Port-forward
kubectl port-forward -n xuangong-prod svc/xuangong-prod-postgresql 5432:5432

# Connect with psql
PGPASSWORD=<password> psql -h localhost -U xuangong -d xuangong_production
```

**Check Migration Status**:
```bash
# View schema_migrations table
kubectl exec -it -n xuangong-prod <backend-pod> -- ./main migrate version

# Or connect and query
PGPASSWORD=<password> psql -h localhost -U xuangong -d xuangong_production \
  -c "SELECT * FROM schema_migrations ORDER BY version;"
```

**Manual Migration**:
```bash
# If automatic migration fails, run manually
kubectl exec -it -n xuangong-prod <backend-pod> -- \
  migrate -path migrations -database "$DATABASE_URL" up
```

**Rollback Migration**:
```bash
# Rollback last migration
kubectl exec -it -n xuangong-prod <backend-pod> -- \
  migrate -path migrations -database "$DATABASE_URL" down 1
```

---

## Security & Compliance

### Container Security

**Non-Root Containers**:
- ✅ Backend: Runs as `appuser` (uid 1000)
- ✅ Frontend: Runs as `nginx` (uid 101)
- ✅ PostgreSQL: Runs as `postgres` (uid 1001)

**Security Context**:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
```

**Read-Only Root Filesystem**:
- Backend: ✅ Enabled
- Frontend: ⚠️ Disabled (envsubst requires write access to `/usr/share/nginx/html`)
  - Mitigated by: non-root user, minimal permissions, restricted volume mounts

### Network Security

**TLS/HTTPS**:
- ✅ All ingress traffic encrypted (Let's Encrypt)
- ✅ Automatic certificate renewal (cert-manager)
- ✅ TLS 1.2+ only
- ✅ HTTP → HTTPS redirect

**CORS Configuration**:
```yaml
# Production: Restricted origins
cors:
  allowedOrigins:
    - "https://xuangong-prod.stytex.cloud"
    - "https://app.xuangong-prod.stytex.cloud"
```

**Rate Limiting**:
- Backend API: 100 requests/minute per IP
- Ingress: nginx rate limiting annotations

**Security Headers**:
```nginx
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer-when-downgrade
```

### Secrets Management

**Current State**: Kubernetes Secrets

**Backend Secrets**:
```yaml
# backend/helm/xuangong-backend/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: xuangong-backend
type: Opaque
data:
  database-password: <base64>
  jwt-secret: <base64>
```

**Frontend Secrets**:
```yaml
# app/helm/xuangong-app/templates/configmap.yaml
# Note: API URL is NOT sensitive, stored in ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: xuangong-app
data:
  API_URL: "https://xuangong-prod.stytex.cloud"
```

**Best Practices**:
- ⚠️ **NEVER commit secrets to git**
- ⚠️ **NEVER hardcode secrets in values files**
- ✅ Use `--set secrets.databasePassword=xxx` during Helm install/upgrade
- ✅ Or use Helm secrets plugin (sops, sealed-secrets)

**Future: External Secrets Operator**:
```yaml
# Reference secrets from external vault (AWS Secrets Manager, HashiCorp Vault)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: xuangong-backend
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: xuangong-backend
  data:
    - secretKey: database-password
      remoteRef:
        key: /xuangong/prod/db-password
```

### Image Security

**Registry Authentication**:
```bash
# ImagePullSecret in Kubernetes
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<PAT> \
  -n xuangong-prod
```

**Image Scanning** (Future):
- Trivy: Scan images for CVEs
- GitHub Container Registry: Built-in vulnerability scanning
- Snyk: Continuous monitoring

**Image Provenance**:
- Built on trusted base images (golang:alpine, nginx:alpine)
- Multi-stage builds (minimal attack surface)
- Regular base image updates

### Pod Security Standards

**Pod Security Admission** (Future):
```yaml
# Namespace labels
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

**Currently**: Baseline security (non-root, no privilege escalation)

---

## Monitoring & Observability

### Current State

**Logs**:
- Backend: stdout/stderr → kubectl logs
- Frontend: nginx access/error logs → kubectl logs
- Database: PostgreSQL logs → kubectl logs

**Metrics**:
- Kubernetes metrics-server: CPU, memory usage
- HPA uses metrics for autoscaling
- `kubectl top pods` for manual checks

**Health Checks**:
- Backend: `/api/v1/health` endpoint
- Frontend: nginx default root `/`
- Kubernetes readiness/liveness probes

### Planned Observability Stack

**1. Logging: Loki + Promtail**
```yaml
# Log aggregation
- Promtail: DaemonSet to collect logs
- Loki: Central log storage
- Grafana: Log visualization and queries
```

**Benefits**:
- Centralized log search
- Log retention policies
- Correlate logs across services
- Alerts on log patterns (errors, warnings)

**2. Metrics: Prometheus + Grafana**
```yaml
# Metrics collection
- Prometheus: Scrape metrics from pods
- Grafana: Dashboards and visualization
- AlertManager: Alert routing and notifications
```

**Key Metrics to Monitor**:
- Backend:
  - Request rate, latency, error rate (RED metrics)
  - Database connection pool usage
  - JWT token validation rate
  - API endpoint response times
- Frontend:
  - Page load time
  - JavaScript errors
  - API call success/failure rate
- Database:
  - Connection count
  - Query latency
  - Table sizes
  - Replication lag (future)

**3. Tracing: Jaeger/Tempo**
```yaml
# Distributed tracing
- OpenTelemetry: Instrumentation
- Jaeger/Tempo: Trace storage and visualization
```

**Benefits**:
- End-to-end request tracing (frontend → backend → database)
- Performance bottleneck identification
- Dependency mapping

**4. Alerting**
```yaml
# Alert rules
- High error rate (> 5%)
- High response latency (p95 > 500ms)
- Database connection errors
- Pod restart loops
- PVC storage > 80% full
- Certificate expiration < 7 days
```

**Alert Channels**:
- Slack (preferred)
- Email
- PagerDuty (for production incidents)

### Dashboard Examples

**Backend API Dashboard**:
- Request rate (by endpoint)
- Response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Database queries/sec
- Active connections
- Pod CPU/memory usage

**Frontend Dashboard**:
- Page views
- Unique users
- JavaScript errors
- API call latency
- nginx response times

**Infrastructure Dashboard**:
- Cluster CPU/memory
- Node count
- Pod count by namespace
- PVC usage
- Ingress traffic

### Error Tracking

**Sentry Integration** (Future):
```go
// Backend
import "github.com/getsentry/sentry-go"

sentry.Init(sentry.ClientOptions{
    Dsn: os.Getenv("SENTRY_DSN"),
    Environment: "production",
})

// Capture errors
sentry.CaptureException(err)
```

```dart
// Frontend
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = 'https://...';
    options.environment = 'production';
  },
  appRunner: () => runApp(MyApp()),
);
```

---

## Disaster Recovery

### Backup Strategy

**What to Backup**:
1. **PostgreSQL Database** - Critical (user data, programs, sessions)
2. **Kubernetes manifests** - Important (infrastructure as code)
3. **Docker images** - Nice to have (can rebuild from source)
4. **Source code** - Critical (git repository)

### Recovery Time Objective (RTO)

**Target**: 1 hour to restore service

**Procedure**:
1. Provision new Kubernetes cluster (30 min)
2. Restore PostgreSQL from backup (10 min)
3. Deploy applications with Helm (10 min)
4. Update DNS if necessary (5 min)
5. Verify and test (5 min)

### Recovery Point Objective (RPO)

**Target**: 24 hours of data loss acceptable (alpha stage)

**Future**: 1 hour (continuous WAL archiving)

### Disaster Scenarios

**Scenario 1: Database Corruption**
```bash
# 1. Scale backend to 0 (stop writes)
kubectl scale deployment xuangong-backend -n xuangong-prod --replicas=0

# 2. Restore from backup
kubectl exec -it -n xuangong-prod <postgresql-pod> -- \
  psql -U xuangong -d xuangong_production < backup.sql

# 3. Scale backend back up
kubectl scale deployment xuangong-backend -n xuangong-prod --replicas=3

# 4. Verify data integrity
curl https://xuangong-prod.stytex.cloud/api/v1/health
```

**Scenario 2: Cluster Failure**
```bash
# 1. Provision new cluster
# 2. Install cert-manager, nginx-ingress
# 3. Restore from Velero backup
velero restore create --from-backup xuangong-prod-20251103

# 4. Update DNS to new cluster IP
# 5. Verify services
```

**Scenario 3: Accidental Deletion**
```bash
# Helm keeps release history
helm history xuangong-backend -n xuangong-prod

# Rollback to last working version
helm rollback xuangong-backend <revision> -n xuangong-prod
```

**Scenario 4: Bad Deployment**
```bash
# Quick rollback (see Rollback Procedures above)
helm rollback xuangong-backend -n xuangong-prod
helm rollback xuangong-app -n xuangong-prod
```

### Data Export

**Export Database**:
```bash
# Automated daily export
kubectl create cronjob pg-backup \
  --image=postgres:16-alpine \
  --schedule="0 2 * * *" \
  -- /bin/sh -c "pg_dump ... > /backup/db.sql"
```

**Export Application State**:
```bash
# Export all Kubernetes resources
kubectl get all -n xuangong-prod -o yaml > xuangong-prod-snapshot.yaml
```

---

## CI/CD Pipeline

### Current State: Manual Deployment

Currently, deployments are manual using the workflow described above.

**Benefits**:
- Full control over deployment timing
- Careful review before production
- Simple workflow during alpha stage

**Drawbacks**:
- Manual steps prone to human error
- Slower release cycle
- No automated testing gate

### Planned CI/CD Pipeline

**Platform**: GitHub Actions

**Workflow Stages**:
```
Code Push → Build → Test → Deploy
```

#### Stage 1: Build & Test (PR)

**Trigger**: Pull request opened/updated

```yaml
# .github/workflows/pr-check.yml
name: PR Checks

on:
  pull_request:
    branches: [ main ]

jobs:
  backend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'
      - name: Run tests
        run: |
          cd backend
          go test -v ./...
      - name: Lint
        run: |
          cd backend
          golangci-lint run

  frontend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      - name: Run tests
        run: |
          cd app
          flutter test
      - name: Analyze
        run: |
          cd app
          flutter analyze
```

**Checks**:
- ✅ Unit tests pass
- ✅ Linting/analysis clean
- ✅ Code formatting
- ✅ No security vulnerabilities

#### Stage 2: Build & Push (Merge to Main)

**Trigger**: Push to main branch

```yaml
# .github/workflows/build.yml
name: Build & Push

on:
  push:
    branches: [ main ]

jobs:
  build-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set version
        id: version
        run: echo "VERSION=v2025.1.0-alpha$(date +%Y%m%d%H%M)" >> $GITHUB_OUTPUT

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          platforms: linux/amd64
          push: true
          tags: ghcr.io/xetys/xuangong/api:${{ steps.version.outputs.VERSION }}

  build-frontend:
    # Similar to backend
```

**Outputs**:
- Docker images pushed to GHCR
- Image tags: `v2025.1.0-alpha<timestamp>`

#### Stage 3: Deploy (Manual Approval)

**Trigger**: Manual workflow dispatch

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  workflow_dispatch:
    inputs:
      backend_version:
        description: 'Backend version (e.g., v2025.1.0-alpha4)'
        required: true
      frontend_version:
        description: 'Frontend version (e.g., v2025.1.0-alpha13)'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # GitHub environment with approvals
    steps:
      - uses: actions/checkout@v4

      - name: Install kubectl
        uses: azure/setup-kubectl@v4

      - name: Install Helm
        uses: azure/setup-helm@v3

      - name: Setup kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config

      - name: Update backend values
        run: |
          cd backend
          sed -i "s/tag: \".*\"/tag: \"${{ inputs.backend_version }}\"/" \
            helm/xuangong-backend/values-production.yaml

      - name: Deploy backend
        run: |
          cd backend
          helm upgrade xuangong-backend ./helm/xuangong-backend \
            -f ./helm/xuangong-backend/values-production.yaml \
            -n xuangong-prod --wait --timeout 10m

      - name: Update frontend values
        run: |
          cd app
          sed -i "s/tag: \".*\"/tag: \"${{ inputs.frontend_version }}\"/" \
            helm/xuangong-app/values-production.yaml

      - name: Deploy frontend
        run: |
          cd app
          helm upgrade xuangong-app ./helm/xuangong-app \
            -f ./helm/xuangong-app/values-production.yaml \
            -n xuangong-prod --wait --timeout 5m

      - name: Smoke tests
        run: |
          curl -f https://xuangong-prod.stytex.cloud/api/v1/health
          curl -f https://app.xuangong-prod.stytex.cloud
```

**Features**:
- Manual approval required (GitHub Environments)
- Automated health checks after deployment
- Automatic rollback on failure
- Deployment notifications (Slack)

#### Stage 4: Post-Deployment Tests

**Trigger**: After successful deployment

```yaml
# .github/workflows/e2e-tests.yml
name: E2E Tests

on:
  workflow_run:
    workflows: ["Deploy to Production"]
    types: [completed]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Playwright tests
        run: |
          # Test critical user flows
          npx playwright test tests/e2e/login.spec.ts
          npx playwright test tests/e2e/practice-session.spec.ts
```

### GitOps Approach (Future)

**FluxCD or ArgoCD**:
- Git repository as single source of truth
- Automatic sync of Kubernetes state
- Declarative configuration
- Rollback = revert git commit

**Example**:
```yaml
# flux-system/xuangong-backend.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: xuangong-backend
  namespace: xuangong-prod
spec:
  chart:
    spec:
      chart: ./backend/helm/xuangong-backend
      sourceRef:
        kind: GitRepository
        name: xuangong
  values:
    image:
      tag: v2025.1.0-alpha4
```

**Benefits**:
- No manual kubectl/helm commands
- Audit trail (git history)
- Easy rollback (git revert)
- Multi-cluster management

---

## Troubleshooting

### Common Issues

#### Issue: ImagePullBackOff

**Symptoms**:
```bash
kubectl get pods -n xuangong-prod
# NAME                    READY   STATUS             RESTARTS
# xuangong-backend-xxx    0/1     ImagePullBackOff   0
```

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n xuangong-prod
# Events: Failed to pull image ... unauthorized
```

**Causes & Solutions**:

1. **Image doesn't exist**:
   ```bash
   # Verify image exists
   docker pull ghcr.io/xetys/xuangong/api:v2025.1.0-alpha4

   # If fails, rebuild and push
   cd backend
   make docker-build-prod TAG=v2025.1.0-alpha4
   make docker-push-prod TAG=v2025.1.0-alpha4
   ```

2. **Registry authentication issue**:
   ```bash
   # Check ImagePullSecret exists
   kubectl get secret regcred -n xuangong-prod

   # If missing, recreate
   kubectl create secret docker-registry regcred \
     --docker-server=ghcr.io \
     --docker-username=<username> \
     --docker-password=<PAT> \
     -n xuangong-prod
   ```

3. **Wrong image tag in values file**:
   ```bash
   # Check values file
   grep "tag:" backend/helm/xuangong-backend/values-production.yaml

   # Fix and redeploy
   ```

#### Issue: CrashLoopBackOff

**Symptoms**:
```bash
kubectl get pods -n xuangong-prod
# NAME                    READY   STATUS             RESTARTS
# xuangong-backend-xxx    0/1     CrashLoopBackOff   5
```

**Diagnosis**:
```bash
# Check logs from crashed container
kubectl logs <pod-name> -n xuangong-prod --previous

# Common errors:
# - Database connection failed
# - Missing environment variables
# - Migration errors
# - Configuration errors
```

**Solutions**:

1. **Database connection failed**:
   ```bash
   # Check database pod is running
   kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=postgresql

   # Check database credentials in secret
   kubectl get secret xuangong-backend -n xuangong-prod -o yaml

   # Test database connection
   kubectl exec -it <backend-pod> -n xuangong-prod -- \
     psql -h xuangong-prod-postgresql -U xuangong -d xuangong_production
   ```

2. **Migration errors**:
   ```bash
   # Check migration logs
   kubectl logs <pod-name> -n xuangong-prod | grep migrate

   # Fix migration (rollback or force version)
   kubectl exec -it <backend-pod> -n xuangong-prod -- \
     migrate -path migrations -database "$DATABASE_URL" force <version>
   ```

3. **Missing environment variables**:
   ```bash
   # Check pod environment
   kubectl describe pod <pod-name> -n xuangong-prod

   # Verify ConfigMap and Secret
   kubectl get configmap xuangong-backend -n xuangong-prod -o yaml
   kubectl get secret xuangong-backend -n xuangong-prod -o yaml
   ```

#### Issue: 502 Bad Gateway

**Symptoms**:
```bash
curl https://xuangong-prod.stytex.cloud
# 502 Bad Gateway
```

**Diagnosis**:
```bash
# Check backend pods are running
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend

# Check service endpoints
kubectl get endpoints xuangong-backend -n xuangong-prod

# Check ingress
kubectl get ingress xuangong-backend -n xuangong-prod
kubectl describe ingress xuangong-backend -n xuangong-prod
```

**Solutions**:

1. **Backend pods not ready**:
   ```bash
   # Check readiness probe
   kubectl describe pod <pod-name> -n xuangong-prod

   # Check health endpoint
   kubectl exec -it <pod-name> -n xuangong-prod -- \
     curl localhost:8080/api/v1/health
   ```

2. **Service misconfiguration**:
   ```bash
   # Verify service selector matches pod labels
   kubectl get service xuangong-backend -n xuangong-prod -o yaml
   kubectl get pods -n xuangong-prod --show-labels
   ```

3. **Ingress misconfiguration**:
   ```bash
   # Check ingress controller logs
   kubectl logs -n ingress-nginx <ingress-controller-pod>

   # Verify ingress annotations
   kubectl get ingress xuangong-backend -n xuangong-prod -o yaml
   ```

#### Issue: High Memory Usage / OOMKilled

**Symptoms**:
```bash
kubectl get pods -n xuangong-prod
# NAME                    READY   STATUS      RESTARTS
# xuangong-backend-xxx    0/1     OOMKilled   3
```

**Diagnosis**:
```bash
# Check resource usage
kubectl top pods -n xuangong-prod

# Check events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp'
```

**Solutions**:

1. **Increase memory limits**:
   ```yaml
   # Edit values-production.yaml
   resources:
     limits:
       memory: 2Gi  # Increase from 1Gi
     requests:
       memory: 512Mi  # Increase from 256Mi
   ```

2. **Optimize application**:
   - Check for memory leaks
   - Optimize database queries
   - Reduce connection pool size
   - Enable request timeout

3. **Add memory monitoring**:
   ```bash
   # Watch memory usage over time
   watch kubectl top pods -n xuangong-prod
   ```

#### Issue: Certificate Expired

**Symptoms**:
```bash
curl https://xuangong-prod.stytex.cloud
# SSL certificate problem: certificate has expired
```

**Diagnosis**:
```bash
# Check certificate
kubectl get certificate -n xuangong-prod
kubectl describe certificate xuangong-backend-tls-prod -n xuangong-prod

# Check cert-manager logs
kubectl logs -n cert-manager <cert-manager-pod>
```

**Solutions**:

1. **Trigger renewal**:
   ```bash
   # Delete certificate (will auto-recreate)
   kubectl delete certificate xuangong-backend-tls-prod -n xuangong-prod

   # Wait for cert-manager to recreate
   kubectl get certificaterequest -n xuangong-prod -w
   ```

2. **Check cert-manager configuration**:
   ```bash
   # Verify ClusterIssuer
   kubectl get clusterissuer letsencrypt-prod -o yaml
   ```

### Debug Commands Cheat Sheet

```bash
# Pods
kubectl get pods -n xuangong-prod
kubectl describe pod <pod-name> -n xuangong-prod
kubectl logs <pod-name> -n xuangong-prod
kubectl logs <pod-name> -n xuangong-prod --previous
kubectl exec -it <pod-name> -n xuangong-prod -- /bin/sh

# Deployments
kubectl get deployment -n xuangong-prod
kubectl describe deployment <deployment-name> -n xuangong-prod
kubectl rollout status deployment/<deployment-name> -n xuangong-prod
kubectl rollout history deployment/<deployment-name> -n xuangong-prod

# Services
kubectl get svc -n xuangong-prod
kubectl describe svc <service-name> -n xuangong-prod
kubectl get endpoints <service-name> -n xuangong-prod

# Ingress
kubectl get ingress -n xuangong-prod
kubectl describe ingress <ingress-name> -n xuangong-prod

# Resources
kubectl top pods -n xuangong-prod
kubectl top nodes

# Events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp'

# Helm
helm list -n xuangong-prod
helm history <release-name> -n xuangong-prod
helm get values <release-name> -n xuangong-prod

# Database
kubectl exec -it <postgresql-pod> -n xuangong-prod -- \
  psql -U xuangong -d xuangong_production -c "SELECT version();"
```

---

## Future Roadmap

### Phase 1: Stability & Observability (Q1 2025)

**Monitoring**:
- [ ] Deploy Prometheus + Grafana
- [ ] Create dashboards for backend, frontend, database
- [ ] Set up Sentry for error tracking
- [ ] Configure alerting (Slack integration)

**Database**:
- [ ] Implement automated backups (daily)
- [ ] Set up WAL archiving
- [ ] Test restore procedures
- [ ] Document disaster recovery

**CI/CD**:
- [ ] GitHub Actions for automated builds
- [ ] Automated tests in PR checks
- [ ] Automated deployment to staging
- [ ] Manual approval for production

### Phase 2: Scalability & Performance (Q2 2025)

**Database**:
- [ ] PostgreSQL replication (primary + replica)
- [ ] Connection pooling (PgBouncer)
- [ ] Read replicas for analytics

**Caching**:
- [ ] Deploy Redis for session storage
- [ ] Cache frequently accessed data
- [ ] CDN for frontend static assets

**Performance**:
- [ ] Database query optimization
- [ ] API response time improvements
- [ ] Frontend bundle size optimization

### Phase 3: Multi-Region & HA (Q3 2025)

**Infrastructure**:
- [ ] Multi-region Kubernetes clusters
- [ ] Global load balancing
- [ ] Database replication across regions
- [ ] Failover automation

**Availability**:
- [ ] 99.9% uptime SLA
- [ ] Automated failover testing
- [ ] Chaos engineering (chaos monkey)

### Phase 4: Advanced Features (Q4 2025)

**GitOps**:
- [ ] FluxCD or ArgoCD deployment
- [ ] Declarative infrastructure
- [ ] Automated drift detection

**Security**:
- [ ] External Secrets Operator (AWS Secrets Manager)
- [ ] Pod Security Standards (restricted)
- [ ] Network policies
- [ ] Image scanning in CI/CD

**Observability**:
- [ ] Distributed tracing (Jaeger/Tempo)
- [ ] Log aggregation (Loki)
- [ ] Service mesh (Istio/Linkerd)

---

## Appendix

### Quick Reference Commands

**Full Deployment Workflow**:
```bash
# Backend
cd backend
make docker-build-prod TAG=v2025.1.0-alpha4
make docker-push-prod TAG=v2025.1.0-alpha4
sed -i '' 's/alpha3/alpha4/' helm/xuangong-backend/values-production.yaml
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
helm upgrade xuangong-backend ./helm/xuangong-backend \
  -f ./helm/xuangong-backend/values-production.yaml \
  -n xuangong-prod --wait --timeout 10m
kubectl get pods -n xuangong-prod
curl https://xuangong-prod.stytex.cloud/api/v1/health

# Frontend
cd app
make docker-build-prod TAG=v2025.1.0-alpha13
make docker-push-prod TAG=v2025.1.0-alpha13
sed -i '' 's/alpha12/alpha13/' helm/xuangong-app/values-production.yaml
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod --wait --timeout 5m
kubectl get pods -n xuangong-prod
curl https://app.xuangong-prod.stytex.cloud
```

**Rollback**:
```bash
helm rollback xuangong-backend -n xuangong-prod
helm rollback xuangong-app -n xuangong-prod
```

### Environment Variables Reference

**Backend**:
| Variable | Source | Example |
|----------|--------|---------|
| `DATABASE_URL` | Secret | `postgres://user:pass@host/db` |
| `JWT_SECRET` | Secret | `base64-encoded-secret` |
| `SERVER_PORT` | ConfigMap | `8080` |
| `SERVER_ENV` | ConfigMap | `production` |
| `CORS_ALLOWED_ORIGINS` | ConfigMap | `https://app.xuangong-prod.stytex.cloud` |

**Frontend**:
| Variable | Source | Example |
|----------|--------|---------|
| `API_URL` | ConfigMap | `https://xuangong-prod.stytex.cloud` |

### Port Reference

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| Backend API | 8080 | HTTP | API endpoints |
| Frontend Web | 8080 | HTTP | nginx web server |
| PostgreSQL | 5432 | TCP | Database |
| Prometheus | 9090 | HTTP | Metrics (future) |
| Grafana | 3000 | HTTP | Dashboards (future) |

### Contact & Resources

**Infrastructure**:
- Cluster Provider: Stytex Cloud
- Registry: GitHub Container Registry (ghcr.io)
- Domain: stytex.cloud

**Documentation**:
- Architecture: `.claude/tasks/context/architecture.md`
- Features: `.claude/tasks/context/features.md`
- Recent Work: `.claude/tasks/context/recent-work.md`
- Decisions: `.claude/tasks/context/decisions.md`

**Tools**:
- kubectl: https://kubernetes.io/docs/reference/kubectl/
- Helm: https://helm.sh/docs/
- Docker: https://docs.docker.com/
- Flutter: https://flutter.dev/docs
- Go: https://go.dev/doc/

---

**End of Project-Wide Deployment Strategy**

This living document should be updated as the deployment process evolves, new tools are adopted, and lessons are learned from production operations.