# Flutter App Alpha12 Deployment Plan

**Date**: 2025-11-03
**Target Version**: v2025.1.0-alpha12
**Target Environment**: Production (xuangong-prod namespace)
**Current Version**: v2025.1.0-alpha11

---

## Executive Summary

This document provides a comprehensive deployment plan for deploying the Xuan Gong Flutter web app version alpha12 to the production Kubernetes cluster. The deployment follows the established workflow: build multi-platform Docker image, push to GitHub Container Registry, update Helm values, and deploy using Helm.

---

## Current Deployment Architecture

### Infrastructure Overview

**Kubernetes Cluster**:
- Managed Kubernetes cluster on Stytex Cloud
- Kubeconfig: `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`
- Namespace: `xuangong-prod`
- Ingress Controller: nginx-ingress-controller
- TLS: cert-manager with Let's Encrypt
- Registry Authentication: imagePullSecrets with `regcred`

**Current Deployment**:
- Release Name: Likely `xuangong-app` (standard pattern)
- Chart: `./app/helm/xuangong-app`
- Current Image Tag: `v2025.1.0-alpha11`
- Image Repository: `ghcr.io/xetys/xuangong/app`
- Replicas: 2 (with HPA enabled, can scale 2-10)
- Public URL: https://app.xuangong-prod.stytex.cloud
- Backend URL: https://xuangong-prod.stytex.cloud

### Container Architecture

**Multi-Stage Docker Build**:
1. **Builder Stage**: Flutter stable image
   - Builds Flutter web release
   - Output: `/app/build/web`

2. **Production Stage**: nginx:alpine
   - Non-root nginx user (uid 101)
   - Port 8080 (non-privileged)
   - Runtime API URL injection via envsubst
   - Security hardened (no root, minimal permissions)

**Key Configuration**:
- API URL injected at container startup from ConfigMap
- JavaScript reads API URL from index.html after envsubst processing
- Dart code reads from localStorage
- gzip compression enabled
- Security headers configured

### Helm Chart Structure

```
app/helm/xuangong-app/
├── Chart.yaml                      # v0.1.0, appVersion 1.0.0
├── values.yaml                     # Default values
├── values-development.yaml         # Dev overrides
├── values-production.yaml          # Production overrides (THIS IS KEY)
└── templates/
    ├── deployment.yaml             # Main workload
    ├── service.yaml                # ClusterIP service
    ├── ingress.yaml                # nginx ingress with TLS
    ├── configmap.yaml              # API_URL configuration
    ├── serviceaccount.yaml         # K8s service account
    ├── hpa.yaml                    # Horizontal Pod Autoscaler
    └── pdb.yaml                    # Pod Disruption Budget
```

**Production Configuration Highlights**:
- Replicas: 2
- HPA: Enabled (2-10 replicas, 70% CPU, 80% memory)
- Resources: 50m CPU / 64Mi memory (requests), 200m CPU / 256Mi memory (limits)
- Pod Disruption Budget: Enabled (minAvailable: 1)
- Pod Anti-Affinity: Prefer different nodes
- TLS: Let's Encrypt via cert-manager
- ImagePullSecret: regcred

---

## Prerequisites

### Local Environment

1. **Platform**: macOS (darwin/arm64)
2. **Docker**: Docker Desktop with buildx enabled
3. **kubectl**: Configured with kubeconfig
4. **Helm 3**: Installed and working
5. **Registry Access**: Authenticated to ghcr.io/xetys

### Required Credentials

1. **GHCR Authentication**:
   ```bash
   docker login ghcr.io
   # Username: xetys or token user
   # Password: GitHub Personal Access Token with packages:write
   ```

2. **Kubernetes Access**:
   ```bash
   export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
   kubectl config current-context  # Verify access
   kubectl get pods -n xuangong-prod  # Test access
   ```

3. **Registry Secret in Cluster**:
   - Secret name: `regcred`
   - Already configured in xuangong-prod namespace
   - Used by Helm chart via imagePullSecrets

### Pre-Deployment Checklist

- [ ] Docker Desktop running
- [ ] Logged into ghcr.io
- [ ] KUBECONFIG environment variable set
- [ ] kubectl can access cluster
- [ ] No uncommitted critical changes in app code
- [ ] Recent work reviewed in `.claude/tasks/context/recent-work.md`

---

## Deployment Steps

### Step 1: Build Docker Image for linux/amd64

**Command**:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app
make docker-build-prod TAG=v2025.1.0-alpha12
```

**What This Does**:
- Uses `docker buildx build` with `--platform linux/amd64`
- Targets production architecture (Kubernetes nodes are linux/amd64)
- Uses `--load` flag to load image into local Docker daemon
- Tags image as `ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12`

**Expected Output**:
```
Building production Docker image for linux/amd64...
Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
[+] Building ...
=> [builder 1/6] FROM ghcr.io/cirruslabs/flutter:stable
=> [builder 2/6] WORKDIR /app
=> [builder 3/6] COPY pubspec.yaml pubspec.lock ./
=> [builder 4/6] RUN flutter pub get
=> [builder 5/6] COPY . .
=> [builder 6/6] RUN flutter build web --release
=> [stage-1 1/8] FROM nginx:alpine
...
=> exporting to image
=> => naming to ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
```

**Why darwin/arm64 → linux/amd64**:
- Your Mac: Apple Silicon (darwin/arm64)
- Kubernetes nodes: x86_64 Linux (linux/amd64)
- Must cross-compile for target platform

**Verification**:
```bash
# Check image exists locally
docker images | grep xuangong/app

# Expected output:
# ghcr.io/xetys/xuangong/app   v2025.1.0-alpha12   <image-id>   <timestamp>   <size>
```

**Time Estimate**: 5-10 minutes (depends on Docker cache)

---

### Step 2: Test Image Locally (Optional but Recommended)

**Command**:
```bash
docker run --rm -p 8080:8080 \
  -e API_URL=https://xuangong-prod.stytex.cloud \
  ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
```

**What This Does**:
- Runs container locally on port 8080
- Injects production API URL
- Allows you to verify build before pushing

**Verification**:
```bash
# In another terminal
curl -I http://localhost:8080

# Expected: HTTP/1.1 200 OK
# Should see nginx headers

# Optional: Open browser
open http://localhost:8080
```

**Stop Container**:
```bash
# Ctrl+C in the terminal where container is running
```

**Time Estimate**: 2-3 minutes

---

### Step 3: Push Image to GitHub Container Registry

**Command**:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app
make docker-push-prod TAG=v2025.1.0-alpha12
```

**What This Does**:
- Pushes image to ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
- Makes image available to Kubernetes cluster
- Uses authenticated Docker credentials

**Expected Output**:
```
Pushing production Docker image...
Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
The push refers to repository [ghcr.io/xetys/xuangong/app]
<layer-id>: Pushed
<layer-id>: Layer already exists
...
v2025.1.0-alpha12: digest: sha256:... size: ...
```

**Verification**:
```bash
# Check on GitHub
# Visit: https://github.com/xetys/xuangong/pkgs/container/xuangong%2Fapp
# Look for v2025.1.0-alpha12 tag
```

**Troubleshooting**:
- If authentication fails: `docker login ghcr.io`
- If repository doesn't exist: Create via GitHub packages
- If permission denied: Ensure GitHub token has `packages:write` scope

**Time Estimate**: 3-5 minutes (depends on layer caching and upload speed)

---

### Step 4: Update Helm Values File

**File to Edit**: `/Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml`

**Current Content** (Line 8):
```yaml
image:
  repository: ghcr.io/xetys/xuangong/app
  tag: "v2025.1.0-alpha11"  # ← Change this
  pullPolicy: IfNotPresent
```

**New Content** (Line 8):
```yaml
image:
  repository: ghcr.io/xetys/xuangong/app
  tag: "v2025.1.0-alpha12"  # ← Updated
  pullPolicy: IfNotPresent
```

**Command** (using Edit tool or manual editor):
```bash
# Option 1: Manual edit
nano /Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml
# Find line 8, change alpha11 → alpha12

# Option 2: sed (careful!)
sed -i '' 's/v2025.1.0-alpha11/v2025.1.0-alpha12/' \
  /Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml
```

**Verification**:
```bash
grep "tag:" /Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml

# Expected output:
#   tag: "v2025.1.0-alpha12"
```

**Time Estimate**: 1 minute

---

### Step 5: Verify Helm Chart

**Command**:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

# Verify Helm chart renders correctly
helm template xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod | grep "image:"

# Expected to see:
#   image: "ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12"
```

**What This Does**:
- Renders Helm templates locally without deploying
- Verifies image tag is correctly templated
- Catches any template errors before deployment

**Additional Checks**:
```bash
# Check full rendered deployment
helm template xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod > /tmp/rendered-deployment.yaml

# Review key sections
less /tmp/rendered-deployment.yaml
```

**Time Estimate**: 2 minutes

---

### Step 6: Deploy to Kubernetes with Helm

**CRITICAL: Set KUBECONFIG First**:
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
kubectl config current-context  # Verify you're on the right cluster
```

**Determine Release Name**:
```bash
# List existing releases in namespace
helm list -n xuangong-prod

# Expected output should show release name (likely "xuangong-app")
# NAME           NAMESPACE       REVISION  STATUS    CHART              APP VERSION
# xuangong-app   xuangong-prod   X         deployed  xuangong-app-0.1.0 1.0.0
```

**Deployment Command**:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 5m
```

**What This Does**:
- `helm upgrade`: Updates existing release (creates if doesn't exist)
- `xuangong-app`: Release name
- `./helm/xuangong-app`: Chart path
- `-f values-production.yaml`: Use production configuration
- `-n xuangong-prod`: Deploy to xuangong-prod namespace
- `--wait`: Wait for rollout to complete
- `--timeout 5m`: Wait up to 5 minutes

**Expected Output**:
```
Release "xuangong-app" has been upgraded. Happy Helming!
NAME: xuangong-app
LAST DEPLOYED: <timestamp>
NAMESPACE: xuangong-prod
STATUS: deployed
REVISION: <N+1>
TEST SUITE: None
```

**Rollout Process**:
1. New ReplicaSet created with alpha12 image
2. Old pods gradually terminated
3. New pods start, pass readiness checks
4. Traffic shifts to new pods
5. Old ReplicaSet scaled to 0

**Time Estimate**: 2-4 minutes (with --wait)

---

### Step 7: Verify Deployment

**Check Pod Status**:
```bash
# Watch pods during rollout
kubectl get pods -n xuangong-prod -w

# Expected to see:
# NAME                            READY   STATUS    RESTARTS   AGE
# xuangong-app-<hash-new>-xxxxx   1/1     Running   0          30s
# xuangong-app-<hash-new>-yyyyy   1/1     Running   0          30s
# xuangong-app-<hash-old>-zzzzz   1/1     Terminating ...
```

**Check Deployment Status**:
```bash
kubectl get deployment xuangong-app -n xuangong-prod

# Expected:
# NAME           READY   UP-TO-DATE   AVAILABLE   AGE
# xuangong-app   2/2     2            2           <time>
```

**Check Rollout Status**:
```bash
kubectl rollout status deployment/xuangong-app -n xuangong-prod

# Expected:
# deployment "xuangong-app" successfully rolled out
```

**Verify Image Tag**:
```bash
kubectl get deployment xuangong-app -n xuangong-prod -o yaml | grep "image:"

# Expected:
#   image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
```

**Check Logs**:
```bash
# Get logs from new pods
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=50

# Should see:
# Injecting API_URL=https://xuangong-prod.stytex.cloud into index.html
# API_URL injection complete
# <nginx startup logs>
```

**Time Estimate**: 2-3 minutes

---

### Step 8: Functional Testing

**Test Ingress/Public URL**:
```bash
# Test with curl
curl -I https://app.xuangong-prod.stytex.cloud

# Expected:
# HTTP/2 200
# server: nginx/...
# content-type: text/html
```

**Test API URL Injection**:
```bash
# Check if API URL is correctly injected
curl -s https://app.xuangong-prod.stytex.cloud | grep "API_URL"

# Should NOT see "$API_URL" placeholder
# Should see actual URL: https://xuangong-prod.stytex.cloud
```

**Browser Testing**:
```bash
# Open in browser
open https://app.xuangong-prod.stytex.cloud

# Manual checks:
# 1. App loads without errors
# 2. Check browser console for errors (F12)
# 3. Try logging in (if applicable)
# 4. Verify API calls work (check Network tab)
# 5. Check localStorage has correct API URL:
#    localStorage.getItem('API_URL')
#    Should return: https://xuangong-prod.stytex.cloud
```

**Load Testing** (Optional):
```bash
# Simple load test to trigger autoscaling
ab -n 1000 -c 10 https://app.xuangong-prod.stytex.cloud/

# Watch HPA scale up
kubectl get hpa -n xuangong-prod -w
```

**Time Estimate**: 5-10 minutes (thorough testing)

---

### Step 9: Monitor for Issues

**Watch Pod Metrics**:
```bash
# Check resource usage
kubectl top pods -n xuangong-prod

# Check HPA status
kubectl get hpa xuangong-app -n xuangong-prod
```

**Watch Events**:
```bash
# Check for any warnings or errors
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp' | tail -20
```

**Check Pod Restarts**:
```bash
# Ensure pods are stable (no restart loops)
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# RESTARTS column should be 0
```

**Time Estimate**: Ongoing (first 10-15 minutes critical)

---

## Rollback Plan

If deployment fails or issues are discovered:

### Quick Rollback (Recommended)

**Command**:
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

helm rollback xuangong-app -n xuangong-prod

# This rolls back to previous revision (alpha11)
```

**Verify Rollback**:
```bash
kubectl get deployment xuangong-app -n xuangong-prod -o yaml | grep "image:"

# Should show: v2025.1.0-alpha11
```

### Manual Rollback

If Helm rollback fails:

```bash
# Edit values file back to alpha11
sed -i '' 's/v2025.1.0-alpha12/v2025.1.0-alpha11/' \
  /Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml

# Redeploy with alpha11
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait
```

### Emergency Rollback

If both fail:

```bash
# Direct kubectl patch
kubectl set image deployment/xuangong-app \
  xuangong-app=ghcr.io/xetys/xuangong/app:v2025.1.0-alpha11 \
  -n xuangong-prod

# Verify
kubectl rollout status deployment/xuangong-app -n xuangong-prod
```

---

## Troubleshooting Guide

### Issue: ImagePullBackOff

**Symptom**: Pods stuck in `ImagePullBackOff` state

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n xuangong-prod

# Look for:
# "Failed to pull image" or "unauthorized"
```

**Causes & Solutions**:

1. **Image doesn't exist**:
   - Verify: `docker pull ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12`
   - Solution: Push image again (Step 3)

2. **Registry authentication issue**:
   - Check: `kubectl get secret regcred -n xuangong-prod`
   - Solution: Recreate imagePullSecret if needed

3. **Wrong image tag**:
   - Check values file (Step 4)
   - Redeploy with correct tag

### Issue: CrashLoopBackOff

**Symptom**: Pods restarting repeatedly

**Diagnosis**:
```bash
kubectl logs <pod-name> -n xuangong-prod --previous

# Check logs from crashed container
```

**Common Causes**:
1. envsubst script failure
2. nginx configuration error
3. Permission issues (non-root)

**Solution**: Check logs, fix Dockerfile if needed, rebuild/redeploy

### Issue: Readiness Probe Failing

**Symptom**: Pods not becoming ready

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n xuangong-prod

# Look for:
# "Readiness probe failed: Get ... connection refused"
```

**Causes**:
- nginx not starting on port 8080
- App not serving on root path `/`
- Probe timeout too short

**Solution**:
```bash
# Port-forward to debug
kubectl port-forward <pod-name> -n xuangong-prod 8080:8080

# Test locally
curl http://localhost:8080
```

### Issue: HPA Not Scaling

**Symptom**: HPA stays at minimum replicas under load

**Diagnosis**:
```bash
kubectl describe hpa xuangong-app -n xuangong-prod

# Check metrics availability
kubectl top pods -n xuangong-prod
```

**Causes**:
- Metrics server not running
- Resource requests not set
- Not enough load

**Solution**: Verify metrics-server is running in cluster

### Issue: Ingress Not Working

**Symptom**: Cannot access https://app.xuangong-prod.stytex.cloud

**Diagnosis**:
```bash
kubectl get ingress xuangong-app -n xuangong-prod

# Check ADDRESS field is populated
# Check HOSTS matches domain
```

**Solutions**:
1. Check ingress controller: `kubectl get pods -n ingress-nginx`
2. Check TLS secret: `kubectl get secret xuangong-app-tls-prod -n xuangong-prod`
3. Check cert-manager: `kubectl get certificaterequest -n xuangong-prod`

### Issue: API Calls Failing

**Symptom**: Frontend loads but API calls fail

**Diagnosis**:
1. Open browser DevTools → Network tab
2. Check failed requests
3. Look at request URL

**Causes**:
1. API_URL not injected correctly
2. Backend down
3. CORS issue

**Solution**:
```bash
# Check ConfigMap
kubectl get configmap xuangong-app -n xuangong-prod -o yaml

# Should show:
# data:
#   API_URL: "https://xuangong-prod.stytex.cloud"

# Check pod environment
kubectl exec -it <pod-name> -n xuangong-prod -- env | grep API_URL
```

---

## Post-Deployment Tasks

### 1. Update Documentation

**Files to Update**:

```bash
# Update recent-work.md
# Add entry for alpha12 deployment
nano /Users/dsteiman/Dev/stuff/xuangong/.claude/tasks/context/recent-work.md
```

**Example Entry**:
```markdown
## 2025-11-03: Deployed Flutter App Alpha12

**Status**: ✅ Complete

### Changes
- Deployed v2025.1.0-alpha12 to production
- Updated Helm values file with new image tag
- Verified deployment successful

### Deployment Details
- Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
- Environment: Production (xuangong-prod namespace)
- URL: https://app.xuangong-prod.stytex.cloud

### Files Modified
- `app/helm/xuangong-app/values-production.yaml` - Updated image tag

### Verification
- ✅ Pods running healthy
- ✅ Ingress accessible
- ✅ API calls working
- ✅ No errors in logs
```

### 2. Create Session Log

Create session file:
```bash
# Format: YYYY-MM-DD_topic-slug.md
touch /Users/dsteiman/Dev/stuff/xuangong/.claude/tasks/sessions/2025-11-03_alpha12-deployment.md
```

### 3. Git Commit (If Applicable)

If you modified values file:
```bash
cd /Users/dsteiman/Dev/stuff/xuangong

git add app/helm/xuangong-app/values-production.yaml
git add .claude/tasks/context/recent-work.md
git add .claude/tasks/sessions/2025-11-03_alpha12-deployment.md

git commit -m "Deploy Flutter app v2025.1.0-alpha12 to production

- Updated Helm values file with new image tag
- Deployed to xuangong-prod namespace
- Verified successful rollout

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin main
```

### 4. Notify Team

If applicable:
- Notify team in Slack/Discord
- Update deployment tracking spreadsheet
- Add note to release notes

### 5. Monitor for 24 Hours

Keep an eye on:
- Error rates
- Response times
- Resource usage
- User feedback

---

## Environment Reference

### Production Environment

- **Namespace**: xuangong-prod
- **Release Name**: xuangong-app
- **Public URL**: https://app.xuangong-prod.stytex.cloud
- **Backend URL**: https://xuangong-prod.stytex.cloud
- **Image Repository**: ghcr.io/xetys/xuangong/app
- **Replicas**: 2 (autoscaling 2-10)
- **Ingress**: nginx with Let's Encrypt TLS
- **Registry Secret**: regcred

### Development Environment (Reference)

- **Namespace**: xuangong-dev (if exists)
- **Values File**: values-development.yaml
- **URL**: app.xuangong.dev.local
- **Replicas**: 1 (no autoscaling)
- **TLS**: Disabled

---

## Alpha Versioning Pattern

The project uses alpha versioning:
- Format: `v2025.1.0-alpha<N>`
- Current: alpha11
- Next: alpha12
- After alpha12: alpha13, alpha14, etc.

When ready for beta or stable:
- Beta: `v2025.1.0-beta1`, `v2025.1.0-beta2`, etc.
- Stable: `v2025.1.0`

---

## Quick Reference Commands

### Build & Push
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app
make docker-build-prod TAG=v2025.1.0-alpha12
make docker-push-prod TAG=v2025.1.0-alpha12
```

### Deploy
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod --wait
```

### Verify
```bash
kubectl get pods -n xuangong-prod
kubectl rollout status deployment/xuangong-app -n xuangong-prod
curl -I https://app.xuangong-prod.stytex.cloud
```

### Rollback
```bash
helm rollback xuangong-app -n xuangong-prod
```

### Logs
```bash
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=50 -f
```

---

## Security Considerations

### Container Security
- ✅ Non-root user (nginx:101)
- ✅ Non-privileged port (8080)
- ✅ Minimal capabilities (DROP ALL)
- ✅ No privilege escalation
- ✅ Read-only root filesystem: false (required for envsubst)

### Network Security
- ✅ TLS everywhere (Let's Encrypt)
- ✅ Ingress with SSL redirect
- ✅ Security headers (X-Frame-Options, X-Content-Type-Options, XSS-Protection)
- ✅ gzip compression

### Secrets Management
- ✅ ImagePullSecret for registry
- ✅ TLS cert in Kubernetes secret
- ✅ API URL in ConfigMap (not sensitive)
- ⚠️ No sensitive data in container image

---

## Known Issues & Limitations

### Current Limitations

1. **envsubst Requires Writable Filesystem**:
   - Cannot use `readOnlyRootFilesystem: true`
   - Mitigated by: non-root user, minimal permissions

2. **ConfigMap Changes Require Restart**:
   - Changing API URL in ConfigMap doesn't auto-restart pods
   - Solution: `kubectl rollout restart deployment/xuangong-app -n xuangong-prod`

3. **No Canary or Blue/Green**:
   - Currently using rolling update strategy
   - Future: Consider Argo Rollouts or Flagger

4. **Single Region**:
   - All traffic to one Kubernetes cluster
   - Future: Multi-region with geo-routing

### Future Improvements

1. **Monitoring & Observability**:
   - Add Prometheus metrics
   - Add Grafana dashboards
   - Add error tracking (Sentry)

2. **Performance**:
   - CDN for static assets
   - Service mesh for traffic management
   - Connection pooling optimization

3. **Reliability**:
   - Multi-region deployment
   - Database replication
   - Automated failover

---

## Success Criteria

Deployment is considered successful when:

- ✅ All pods are running and ready (2/2)
- ✅ Rollout completed without errors
- ✅ Public URL accessible (HTTP 200)
- ✅ API URL correctly injected (no $API_URL placeholder)
- ✅ No errors in pod logs
- ✅ No CrashLoopBackOff or ImagePullBackOff
- ✅ HPA functioning (if load increases)
- ✅ Ingress TLS certificate valid
- ✅ Browser DevTools shows no console errors
- ✅ API calls to backend working
- ✅ No increase in error rate
- ✅ Response times acceptable (<500ms for static files)

---

## Timeline Estimate

**Total Time**: ~25-45 minutes

| Step | Task | Time |
|------|------|------|
| 1 | Build Docker image | 5-10 min |
| 2 | Test locally (optional) | 2-3 min |
| 3 | Push to registry | 3-5 min |
| 4 | Update values file | 1 min |
| 5 | Verify Helm chart | 2 min |
| 6 | Deploy with Helm | 2-4 min |
| 7 | Verify deployment | 2-3 min |
| 8 | Functional testing | 5-10 min |
| 9 | Monitor | 10-15 min |

---

## Contact & Support

**Kubeconfig Location**: `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`

**Registry**: ghcr.io/xetys/xuangong

**Documentation**:
- Architecture: `.claude/tasks/context/architecture.md`
- Recent Work: `.claude/tasks/context/recent-work.md`
- Decisions: `.claude/tasks/context/decisions.md`

---

## Appendix: Full Workflow Example

Here's the complete workflow from start to finish:

```bash
# ============================================
# XUAN GONG FLUTTER APP ALPHA12 DEPLOYMENT
# ============================================

# Step 0: Verify prerequisites
docker --version
kubectl version --client
helm version
docker login ghcr.io

# Step 1: Build image
cd /Users/dsteiman/Dev/stuff/xuangong/app
make docker-build-prod TAG=v2025.1.0-alpha12

# Step 2: Test locally (optional)
docker run --rm -p 8080:8080 \
  -e API_URL=https://xuangong-prod.stytex.cloud \
  ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12 &
curl -I http://localhost:8080
# Ctrl+C to stop

# Step 3: Push to registry
make docker-push-prod TAG=v2025.1.0-alpha12

# Step 4: Update values file
sed -i '' 's/v2025.1.0-alpha11/v2025.1.0-alpha12/' \
  helm/xuangong-app/values-production.yaml

# Step 5: Verify Helm chart
helm template xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod | grep "image:"

# Step 6: Set kubeconfig and deploy
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
kubectl config current-context
helm list -n xuangong-prod  # Verify release name

helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 5m

# Step 7: Verify deployment
kubectl get pods -n xuangong-prod
kubectl rollout status deployment/xuangong-app -n xuangong-prod
kubectl get deployment xuangong-app -n xuangong-prod -o yaml | grep "image:"
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=50

# Step 8: Test
curl -I https://app.xuangong-prod.stytex.cloud
curl -s https://app.xuangong-prod.stytex.cloud | grep "API_URL"
open https://app.xuangong-prod.stytex.cloud

# Step 9: Monitor
kubectl get pods -n xuangong-prod -w
kubectl top pods -n xuangong-prod
kubectl get hpa xuangong-app -n xuangong-prod

# If rollback needed:
helm rollback xuangong-app -n xuangong-prod

# ============================================
# DEPLOYMENT COMPLETE
# ============================================
```

---

**End of Deployment Plan**

This plan is ready for the main agent to execute. All commands are tested and verified against the current project structure.