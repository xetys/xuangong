# Quick Deploy Guide - Alpha 13

**Target:** v2025.1.0-alpha13
**Component:** Flutter Web Frontend (xuangong-app)

## Pre-Flight Check

```bash
# Verify you're in the right directory
pwd
# Expected: /Users/dsteiman/Dev/stuff/xuangong/app

# Check Docker is running
docker info

# Check kubectl access
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud
kubectl cluster-info
```

## Deploy Steps (Copy-Paste Ready)

### 1. Build Docker Image
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app
make docker-build-prod TAG=v2025.1.0-alpha13
```

**Wait for:** "Successfully built and loaded image" (~5-10 min)

### 2. Test Locally (Optional)
```bash
docker run --rm -p 8080:8080 \
  -e API_URL=http://localhost:8080 \
  ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Open: http://localhost:8080
# Ctrl+C to stop
```

### 3. Push to Registry
```bash
make docker-push-prod TAG=v2025.1.0-alpha13
```

**Wait for:** "v2025.1.0-alpha13: digest: sha256:..." (~2-5 min)

### 4. Deploy to Kubernetes
```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

# Dry run first (recommended)
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --dry-run --debug

# Actual deployment
helm upgrade xuangong-app ./helm/xuangong-app \
  -f ./helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --wait \
  --timeout 5m
```

**Wait for:** "STATUS: deployed" (~2-3 min)

### 5. Verify Deployment
```bash
# Watch rollout
kubectl rollout status deployment/xuangong-app -n xuangong-prod

# Check pods
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# Verify image tag
kubectl describe deployment xuangong-app -n xuangong-prod | grep Image:
# Expected: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Check logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app --tail=20
```

### 6. Test Application
```bash
# Access: https://app.xuangong-prod.stytex.cloud

# Manual checks:
# [ ] App loads
# [ ] Login works
# [ ] Exercise list shows
# [ ] YouTube player renders on exercises
# [ ] Video plays
# [ ] No console errors
```

## Quick Rollback (If Needed)

```bash
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

# Rollback to previous version
helm rollback xuangong-app -n xuangong-prod

# Or use kubectl
kubectl rollout undo deployment/xuangong-app -n xuangong-prod
```

## Monitoring Commands

```bash
# Watch pods
kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app -w

# Live logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-app -f

# Resource usage
kubectl top pods -n xuangong-prod -l app.kubernetes.io/name=xuangong-app

# HPA status
kubectl get hpa -n xuangong-prod xuangong-app

# Recent events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp' | head -20
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n xuangong-prod <pod-name>
kubectl logs -n xuangong-prod <pod-name>
```

### Image pull issues
```bash
# Verify image exists
docker pull ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Check registry secret
kubectl get secret regcred -n xuangong-prod
```

### Application issues
```bash
# Check if ConfigMap updated
kubectl get configmap xuangong-app -n xuangong-prod -o yaml

# Check ingress
kubectl get ingress -n xuangong-prod xuangong-app

# Check backend connectivity
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=xuangong-backend
```

## Success Criteria

- [ ] All pods Running (2/2)
- [ ] Correct image tag deployed
- [ ] Application accessible
- [ ] YouTube player works
- [ ] No error logs
- [ ] HPA shows normal metrics

## Full Documentation

For detailed information, see:
- `/Users/dsteiman/Dev/stuff/xuangong/.claude/docs/deployment/alpha13-deployment-plan.md`
- `/Users/dsteiman/Dev/stuff/xuangong/.claude/docs/deployment/strategy.md`
