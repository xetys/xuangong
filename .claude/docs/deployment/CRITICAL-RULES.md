# CRITICAL DEPLOYMENT RULES

## ⛔ NEVER MODIFY THESE FILES FOR KUBERNETES/DEPLOYMENT TASKS

When preparing kubernetes deployments, helm charts, or any deployment tasks:

### FORBIDDEN TO MODIFY:
- ❌ **`pubspec.yaml`** - Flutter dependency and version file
- ❌ **`go.mod`** - Go module dependency file
- ❌ **`go.sum`** - Go module checksum file
- ❌ **`package.json`** (if exists) - Node.js dependencies
- ❌ **Any source code files** unless explicitly requested

### ALLOWED TO MODIFY:
- ✅ **ONLY** `values*.yaml` files (image tag)
- ⚠️ **DO NOT MODIFY** `Chart.yaml` (not even version or appVersion)
- ✅ Kubernetes manifest files (`.yaml` in k8s directories) - if needed
- ✅ Dockerfile (if deployment-specific changes needed)
- ✅ CI/CD configuration files
- ✅ Deployment documentation

## The Right Approach

### For Kubernetes Deployments:

**ONLY change the Docker image tag. Nothing else.**

1. **Image Tags** are set in:
   - `helm/xuangong-app/values-production.yaml`
   - `helm/xuangong-app/values-development.yaml`

2. **DO NOT CHANGE**:
   - Chart.yaml (version or appVersion)
   - pubspec.yaml
   - go.mod
   - Any source code files

3. **Application versions** (pubspec.yaml, go.mod) are ONLY changed:
   - By the developer
   - When explicitly requested
   - As part of a feature/code change
   - NEVER as part of deployment preparation

## Example: Correct Alpha13 Deployment

### ❌ WRONG (What NOT to do):
```bash
# DO NOT modify pubspec.yaml
version: 0.13.0+13  # ❌ NEVER DO THIS FOR DEPLOYMENT

# DO NOT modify Chart.yaml
version: 0.13.0  # ❌ NEVER DO THIS FOR DEPLOYMENT
appVersion: v2025.1.0-alpha13  # ❌ NEVER DO THIS FOR DEPLOYMENT
```

### ✅ CORRECT (What TO do):
```yaml
# helm/xuangong-app/values-production.yaml
image:
  tag: v2025.1.0-alpha13  # ✅ ONLY THIS CHANGES

# Everything else stays the same:
# - Chart.yaml: unchanged
# - pubspec.yaml: unchanged
# - go.mod: unchanged
```

## Why This Matters

1. **Image tag** is the ONLY version that matters for deployments (e.g., v2025.1.0-alpha13)
2. **Source code versions** (pubspec.yaml, go.mod) track code changes by developers
3. **Chart versions** (Chart.yaml) are managed separately and independently
4. **Modifying anything other than the image tag** breaks the workflow

## Remember

**For deployment: ONLY change image tag in values-production.yaml**

That's it. Nothing else.
