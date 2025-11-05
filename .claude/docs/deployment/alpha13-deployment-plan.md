# Alpha 13 Deployment Plan - Flutter Web Application

**Date:** 2025-11-05
**Version:** v2025.1.0-alpha13
**Application:** Xuan Gong Martial Arts Training App (Frontend)

## Overview

This deployment adds YouTube video link support to exercises, utilizing the `youtube_player_iframe` package for web-compatible playback. This is alpha13 following our incremental versioning strategy.

## What's New in Alpha13

- YouTube video links on exercises
- Web-compatible `youtube_player_iframe` package (v5.2.1)
- Enhanced exercise library with embedded video demonstrations
- Updated CORS middleware to support localhost development origins

## Pre-Deployment Checklist

### Environment Verification
- [ ] Local machine: macOS (darwin/arm64)
- [ ] Docker Desktop with buildx installed and running
- [ ] kubectl configured with production kubeconfig
- [ ] Helm 3 installed
- [ ] Access to GitHub Container Registry (ghcr.io/xetys/xuangong)
- [ ] Production kubeconfig at: `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`

### Code Verification
- [ ] YouTube player tested in local development
- [ ] API integration working (backend already deployed at v2025.1.0-alpha3)
- [ ] CORS configured correctly for production domain
- [ ] No console errors in browser developer tools

## Deployment Steps

### Phase 1: Version Update and Build Preparation

#### Step 1.1: Update Application Version
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

# Update pubspec.yaml version from 1.0.0+1 to 0.13.0+13
# This will be done via Edit tool
```

**File:** `/Users/dsteiman/Dev/stuff/xuangong/app/pubspec.yaml`
**Change:** Line 19: `version: 1.0.0+1` → `version: 0.13.0+13`

#### Step 1.2: Update Helm Chart Version
```bash
# Update Helm chart appVersion to match deployment tag
```

**File:** `/Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/Chart.yaml`
**Change:** Line 6: `appVersion: "1.0.0"` → `appVersion: "v2025.1.0-alpha13"`
**Change:** Line 5: `version: 0.1.0` → `version: 0.13.0`

#### Step 1.3: Update Production Values
```bash
# Update production image tag
```

**File:** `/Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/values-production.yaml`
**Change:** Line 8: `tag: "v2025.1.0-alpha12"` → `tag: "v2025.1.0-alpha13"`

### Phase 2: Docker Build (Multi-Platform)

#### Step 2.1: Build Production Image for linux/amd64
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

# Build the Docker image targeting linux/amd64 platform
make docker-build-prod TAG=v2025.1.0-alpha13
```

**What this does:**
- Uses Flutter stable Docker image as builder
- Runs `flutter pub get` to install dependencies (including youtube_player_iframe)
- Builds optimized web release bundle with `flutter build web --release`
- Creates nginx-alpine production image
- Configures nginx to run on port 8080 (non-root)
- Sets up runtime environment variable injection for API_URL
- Total build time: ~5-10 minutes

**Expected Output:**
```
Building production Docker image for linux/amd64...
Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13
[+] Building 300.5s (15/15) FINISHED
...
Successfully built and loaded image
```

#### Step 2.2: Test Image Locally (Optional but Recommended)
```bash
# Test the built image locally
docker run --rm -p 8080:8080 \
  -e API_URL=http://localhost:8080 \
  ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Access http://localhost:8080 in browser
# Verify:
# - App loads correctly
# - YouTube player renders on exercises
# - No console errors
# Stop with Ctrl+C
```

#### Step 2.3: Push to GitHub Container Registry
```bash
# Push the production image
make docker-push-prod TAG=v2025.1.0-alpha13
```

**What this does:**
- Pushes the linux/amd64 image to ghcr.io
- Makes image available to Kubernetes cluster
- Image size: ~50-80MB (nginx + Flutter web bundle)

**Expected Output:**
```
Pushing production Docker image...
Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13
The push refers to repository [ghcr.io/xetys/xuangong/app]
...
v2025.1.0-alpha13: digest: sha256:... size: 1234
```

### Phase 3: Kubernetes Deployment

#### Step 3.1: Set Kubeconfig
```bash
# Point kubectl to production cluster
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
```
Kubernetes control plane is running at https://...
CoreDNS is running at https://...
```

#### Step 3.2: Verify Current Deployment State
```bash
# Check current deployment in xuangong-prod namespace
kubectl get deployments -n xuangong-prod
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# Check current image version
kubectl describe deployment xuangong-app -n xuangong-prod | grep Image:
```

**Expected Output:**
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
xuangong-app   2/2     2            2           15d

Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
```

#### Step 3.3: Deploy with Helm
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

# Upgrade the Helm release
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 5m

# Alternative with dry-run first (recommended):
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --dry-run --debug
```

**What this does:**
- Performs rolling update deployment
- Creates new ReplicaSet with alpha13 image
- Gradually scales up new pods while scaling down old ones
- Waits for all pods to be ready before completing
- Updates ConfigMap with API_URL configuration
- Triggers pod restart due to ConfigMap checksum annotation

**Expected Output:**
```
Release "xuangong-app" has been upgraded. Happy Helming!
NAME: xuangong-app
LAST DEPLOYED: Tue Nov  5 14:30:00 2025
NAMESPACE: xuangong-prod
STATUS: deployed
REVISION: 13
```

### Phase 4: Verification

#### Step 4.1: Monitor Rollout
```bash
# Watch the deployment rollout
kubectl rollout status deployment/xuangong-app -n xuangong-prod

# Check pod status
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app -w
```

**Expected Output:**
```
Waiting for deployment "xuangong-app" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "xuangong-app" rollout to finish: 1 old replicas are pending termination...
deployment "xuangong-app" successfully rolled out

NAME                           READY   STATUS    RESTARTS   AGE
xuangong-app-5d8f9c7b8-abc12   1/1     Running   0          1m
xuangong-app-5d8f9c7b8-def34   1/1     Running   0          30s
```

#### Step 4.2: Verify New Image is Running
```bash
# Confirm alpha13 is deployed
kubectl describe deployment xuangong-app -n xuangong-prod | grep Image:
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Expected Output:**
```
Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13
```

#### Step 4.3: Check Pod Logs
```bash
# Check startup logs from new pods
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=50

# Look for:
# - "Injecting API_URL=https://xuangong-prod.stytex.cloud"
# - "API_URL injection complete"
# - nginx startup messages
```

#### Step 4.4: Test Ingress and Application
```bash
# Check ingress status
kubectl get ingress -n xuangong-prod xuangong-app

# Access the application
# URL: https://app.xuangong-prod.stytex.cloud
```

**Manual Testing Checklist:**
- [ ] Application loads at https://app.xuangong-prod.stytex.cloud
- [ ] No console errors in browser DevTools
- [ ] Login functionality works
- [ ] Navigate to exercise list
- [ ] Click on exercise with YouTube link
- [ ] YouTube player renders correctly
- [ ] Video plays without errors
- [ ] API calls succeed (check Network tab)
- [ ] TLS certificate is valid (green lock icon)

#### Step 4.5: Verify HPA and Resource Usage
```bash
# Check Horizontal Pod Autoscaler status
kubectl get hpa -n xuangong-prod xuangong-app

# Check resource usage
kubectl top pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app
```

**Expected Output:**
```
NAME           REFERENCE                 TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
xuangong-app   Deployment/xuangong-app   15%/70%, 20%/80%  2         10        2          15d

NAME                           CPU(cores)   MEMORY(bytes)
xuangong-app-5d8f9c7b8-abc12   10m          128Mi
xuangong-app-5d8f9c7b8-def34   12m          135Mi
```

### Phase 5: Post-Deployment

#### Step 5.1: Update Deployment Documentation
```bash
# Document this deployment in session logs
# Update .claude/tasks/sessions/ with deployment details
```

#### Step 5.2: Monitor for Issues
```bash
# Set up monitoring for next 24 hours
# Check logs periodically
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --since=1h

# Check for crash loops or restarts
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app
```

#### Step 5.3: Performance Testing (Optional)
```bash
# Load testing recommendations:
# - Concurrent user simulation
# - YouTube player rendering performance
# - API response times
# - Memory usage over time
```

## Rollback Strategy

If issues are discovered after deployment, rollback to alpha12:

### Quick Rollback (Helm)
```bash
# Rollback to previous release
helm rollback xuangong-app -n xuangong-prod

# This will revert to alpha12 automatically
```

### Manual Rollback (Kubernetes)
```bash
# Rollback deployment to previous revision
kubectl rollout undo deployment/xuangong-app -n xuangong-prod

# Or rollback to specific revision
kubectl rollout history deployment/xuangong-app -n xuangong-prod
kubectl rollout undo deployment/xuangong-app -n xuangong-prod --to-revision=12
```

### Verify Rollback
```bash
# Confirm alpha12 is running again
kubectl describe deployment xuangong-app -n xuangong-prod | grep Image:

# Should show: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha12
```

## Deployment Architecture

### Current Infrastructure

**Namespace:** `xuangong-prod`

**Components:**
1. **xuangong-backend** (Go API)
   - Deployment: 3 replicas (auto-scales 3-20)
   - Service: ClusterIP on port 8080
   - Ingress: https://xuangong-prod.stytex.cloud
   - Database: PostgreSQL with 20Gi persistent volume
   - Version: v2025.1.0-alpha3

2. **xuangong-app** (Flutter Web)
   - Deployment: 2 replicas (auto-scales 2-10)
   - Service: ClusterIP on port 80 → target 8080
   - Ingress: https://app.xuangong-prod.stytex.cloud
   - Nginx serving static files
   - Version: v2025.1.0-alpha13 (after this deployment)

**Networking:**
- nginx-ingress-controller handles external traffic
- cert-manager provides TLS certificates (Let's Encrypt)
- CORS configured to allow app.xuangong-prod.stytex.cloud → xuangong-prod.stytex.cloud

**Resource Allocation:**
```yaml
Frontend (per pod):
  Requests: 50m CPU, 64Mi memory
  Limits: 200m CPU, 256Mi memory

Backend (per pod):
  Requests: 200m CPU, 256Mi memory
  Limits: 1000m CPU, 1Gi memory
```

### Deployment Flow

```
Developer (macOS arm64)
    ↓
Flutter build web --release
    ↓
Docker buildx (linux/amd64)
    ↓
GitHub Container Registry (ghcr.io)
    ↓
Helm upgrade
    ↓
Kubernetes Rolling Update
    ↓
nginx pods serving Flutter web app
    ↓
Ingress with TLS
    ↓
Users (https://app.xuangong-prod.stytex.cloud)
```

## Configuration Management

### Runtime Configuration
The Flutter web app receives API URL at runtime via:
1. ConfigMap defines `API_URL: "https://xuangong-prod.stytex.cloud"`
2. Environment variable injected into pod
3. nginx entrypoint script uses `envsubst` to replace `$API_URL` in index.html
4. JavaScript in index.html stores value in localStorage
5. Flutter app reads from localStorage via `api_config_web.dart`

### Environment-Specific Values

**Development** (`values-development.yaml`):
- 1 replica
- No autoscaling
- Lower resource limits
- HTTP ingress (no TLS)
- API URL: http://localhost:8080

**Production** (`values-production.yaml`):
- 2 replicas (min)
- Autoscaling enabled (2-10 pods)
- Higher resource limits
- HTTPS ingress with Let's Encrypt
- API URL: https://xuangong-prod.stytex.cloud
- Pod anti-affinity for HA

## Security Considerations

### Container Security
- Non-root user (nginx:101)
- Read-only root filesystem (where possible)
- Dropped all capabilities
- No privilege escalation
- Alpine base image (minimal attack surface)

### Network Security
- CORS properly configured
- TLS everywhere in production
- No exposed secrets in images
- imagePullSecrets for private registry

### Secrets Management
- API URL via ConfigMap (not sensitive)
- JWT secrets in backend (not exposed to frontend)
- Database credentials in Kubernetes Secrets

## Monitoring and Observability

### Key Metrics to Watch
- Pod CPU/Memory usage (should stay well below limits)
- HTTP response times (should be <100ms for static files)
- Error rates (4xx/5xx from ingress)
- Pod restart count (should be 0 after deployment)
- HPA scaling events

### Log Locations
```bash
# Application logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# Ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp'
```

## Troubleshooting Guide

### Issue: Pods in CrashLoopBackOff
```bash
# Check pod logs
kubectl logs -n xuangong-prod <pod-name>

# Check events
kubectl describe pod -n xuangong-prod <pod-name>

# Common causes:
# - Image pull failure (check imagePullSecrets)
# - Configuration error (check ConfigMap)
# - Resource limits too low
```

### Issue: ImagePullBackOff
```bash
# Verify image exists in registry
docker pull ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Check imagePullSecret
kubectl get secret regcred -n xuangong-prod

# Recreate secret if needed (requires GitHub PAT)
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<PAT> \
  -n xuangong-prod
```

### Issue: Application Loads but YouTube Player Doesn't Work
```bash
# Check browser console for errors
# Verify:
# - YouTube iframe API is loading
# - No CSP (Content Security Policy) blocking YouTube
# - CORS allows video loading
# - API returns valid YouTube URLs

# Check nginx logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app
```

### Issue: API Calls Failing (CORS errors)
```bash
# Verify backend CORS configuration
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend

# Check if frontend URL is in allowedOrigins
# Backend should allow: https://app.xuangong-prod.stytex.cloud

# Verify API_URL injection
kubectl exec -n xuangong-prod <pod-name> -- cat /usr/share/nginx/html/index.html | grep API_URL
```

### Issue: Deployment Stuck in Progress
```bash
# Check rollout status
kubectl rollout status deployment/xuangong-app -n xuangong-prod

# Check pod readiness
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# Common causes:
# - Readiness probe failing
# - Insufficient cluster resources
# - Image pull issues

# Force rollback if stuck
helm rollback xuangong-app -n xuangong-prod
```

## Success Criteria

Deployment is successful when:
- [ ] All pods are Running and Ready (2/2)
- [ ] New image tag is confirmed in deployment
- [ ] Application accessible at https://app.xuangong-prod.stytex.cloud
- [ ] YouTube player renders and plays videos
- [ ] No console errors in browser
- [ ] API calls succeed (check Network tab)
- [ ] TLS certificate is valid
- [ ] HPA shows normal metrics
- [ ] No pod restarts after 15 minutes

## Timeline Estimate

- Version updates: 5 minutes
- Docker build: 5-10 minutes
- Docker push: 2-5 minutes
- Helm deployment: 2-3 minutes
- Rolling update: 1-2 minutes
- Verification: 5-10 minutes

**Total: 20-35 minutes**

## Notes and Considerations

### YouTube Player Implementation
- Using `youtube_player_iframe` package (v5.2.1)
- Web-compatible implementation
- No native mobile dependencies
- Requires stable internet connection for video streaming
- Respects YouTube's terms of service

### Platform-Specific Build Requirements
- Local development: darwin/arm64 (macOS Apple Silicon)
- Production target: linux/amd64 (Kubernetes nodes)
- Must use `docker buildx build --platform linux/amd64`
- Cannot use regular `docker build` (produces wrong architecture)

### Deployment Strategy
- **Rolling Update:** Default strategy
  - `maxSurge: 25%` - allow 25% extra pods during update
  - `maxUnavailable: 25%` - allow 25% pods to be unavailable
  - Zero downtime deployment
  - Gradual traffic shift to new version

### High Availability
- 2 replicas ensure continuous availability during updates
- Pod anti-affinity spreads pods across nodes
- PodDisruptionBudget ensures min 1 pod always available
- Autoscaling handles traffic spikes (up to 10 pods)

### Future Improvements
- Consider blue-green deployment for large changes
- Add Prometheus metrics for detailed monitoring
- Implement canary releases for safer rollouts
- Add automated smoke tests post-deployment
- Set up Slack/email alerts for deployment events

## References

- Helm Chart: `/Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/`
- Dockerfile: `/Users/dsteiman/Dev/stuff/xuangong/app/Dockerfile`
- Makefile: `/Users/dsteiman/Dev/stuff/xuangong/app/Makefile`
- Backend API: https://xuangong-prod.stytex.cloud
- Frontend App: https://app.xuangong-prod.stytex.cloud
- Kubeconfig: `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`

## Change Log

**Alpha 13 (2025-11-05):**
- Added YouTube video link support to exercises
- Integrated youtube_player_iframe package (v5.2.1)
- Updated CORS configuration for localhost development
- Enhanced exercise library with embedded demonstrations

**Alpha 12 (Previous):**
- Student administration and menu features
- Program repetition tracking
- Session management improvements
