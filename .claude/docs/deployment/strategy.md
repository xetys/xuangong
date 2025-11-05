# Kubernetes Deployment Strategy - Xuan Gong Project

**Last Updated:** 2025-11-05
**Maintainer:** DevOps / Deployment Team

## Overview

This document defines the standard deployment strategy for the Xuan Gong martial arts training application. All deployments should follow these patterns unless explicitly documented otherwise.

## Environment Architecture

### Local Development Machine
- **Platform:** macOS (darwin/arm64) - Apple Silicon
- **Tools Required:**
  - Docker Desktop with buildx (multi-platform support)
  - kubectl with production kubeconfig
  - Helm 3.x
  - Make
  - Flutter SDK (for app development)
  - Go 1.21+ (for backend development)

### Production Kubernetes Cluster
- **Provider:** Managed Kubernetes (Stytex Cloud)
- **Kubeconfig:** `~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud`
- **Namespace:** `xuangong-prod`
- **Ingress Controller:** nginx-ingress-controller
- **Certificate Manager:** cert-manager with Let's Encrypt (letsencrypt-prod issuer)
- **Container Registry:** GitHub Container Registry (ghcr.io/xetys/xuangong)
- **Registry Authentication:** imagePullSecrets named `regcred`

## Application Components

### 1. Frontend - Flutter Web Application
- **Name:** xuangong-app
- **Repository:** ghcr.io/xetys/xuangong/app
- **Helm Chart:** `/Users/dsteiman/Dev/stuff/xuangong/app/helm/xuangong-app/`
- **Current Version:** v2025.1.0-alpha13
- **Namespace:** xuangong-prod
- **Ingress:** https://app.xuangong-prod.stytex.cloud
- **Technology Stack:**
  - Flutter web (Dart)
  - nginx:alpine (static file serving)
  - Non-root container (user: 101)
  - Port: 8080
- **Configuration:**
  - Runtime API URL injection via ConfigMap
  - Environment-specific values files

### 2. Backend - Go REST API
- **Name:** xuangong-backend
- **Repository:** ghcr.io/xetys/xuangong/api
- **Helm Chart:** `/Users/dsteiman/Dev/stuff/xuangong/backend/helm/xuangong-backend/`
- **Current Version:** v2025.1.0-alpha3
- **Namespace:** xuangong-prod
- **Ingress:** https://xuangong-prod.stytex.cloud
- **Technology Stack:**
  - Go 1.21+
  - PostgreSQL 15+ (via Bitnami subchart)
  - JWT authentication
  - RESTful API
- **Database:**
  - Persistent volume: 20Gi
  - Name: xuangong_production
  - Connection pooling configured

## Versioning Strategy

### Version Format
We use **calendar-based alpha versioning**:
```
v2025.1.0-alpha{N}
```

Where:
- `2025.1.0` = Year.Quarter.Patch
- `alpha{N}` = Incremental alpha number (alpha1, alpha2, alpha13, etc.)

### Version Mapping
- **Docker Image Tag:** `v2025.1.0-alpha13`
- **Helm Chart Version:** `0.13.0` (matches alpha number)
- **Helm appVersion:** `v2025.1.0-alpha13` (matches image tag)
- **Flutter pubspec.yaml:** `0.13.0+13` (version+build number)

### When to Increment
- New feature: Increment alpha number
- Bug fix: Increment alpha number
- Configuration change: Increment alpha number
- No change to code: Reuse same alpha, update deployment revision

## Docker Build Strategy

### Multi-Platform Requirements

**Critical:** Local machine is darwin/arm64, but Kubernetes nodes are linux/amd64.

**Always use:**
```bash
docker buildx build --platform linux/amd64 ...
```

**Never use:**
```bash
docker build ...  # This produces darwin/arm64 images on Mac!
```

### Frontend Build Process
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/app

# Build for production (linux/amd64)
make docker-build-prod TAG=v2025.1.0-alpha13

# Test locally (optional)
docker run --rm -p 8080:8080 \
  -e API_URL=http://localhost:8080 \
  ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13

# Push to registry
make docker-push-prod TAG=v2025.1.0-alpha13
```

**Build Process:**
1. **Builder Stage:**
   - Uses `ghcr.io/cirruslabs/flutter:stable`
   - Runs `flutter pub get`
   - Builds optimized web bundle: `flutter build web --release`
   - Output: `/app/build/web/`

2. **Production Stage:**
   - Base: `nginx:alpine`
   - Installs `gettext` for envsubst
   - Configures nginx for non-root (user 101)
   - Port: 8080 (non-privileged)
   - Copies Flutter web bundle
   - Creates entrypoint script for API_URL injection
   - Runtime environment variable substitution

**Image Size:** ~50-80MB (optimized)

### Backend Build Process
```bash
cd /Users/dsteiman/Dev/stuff/xuangong/backend

# Build for production (linux/amd64)
make docker-build-prod TAG=v2025.1.0-alpha{N}

# Push to registry
make docker-push-prod TAG=v2025.1.0-alpha{N}
```

## Helm Deployment Pattern

### Standard Workflow

1. **Update Version Numbers**
   - `pubspec.yaml` (Flutter app) or version file (Go app)
   - `helm/*/Chart.yaml` - version and appVersion
   - `helm/*/values-production.yaml` - image tag

2. **Build and Push Docker Image**
   ```bash
   make docker-build-prod TAG=v2025.1.0-alpha{N}
   make docker-push-prod TAG=v2025.1.0-alpha{N}
   ```

3. **Deploy with Helm**
   ```bash
   export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

   # Dry run (recommended)
   helm upgrade <release-name> ./helm/<chart-name> \
     -f ./helm/<chart-name>/values-production.yaml \
     -n xuangong-prod \
     --dry-run --debug

   # Actual deployment
   helm upgrade <release-name> ./helm/<chart-name> \
     -f ./helm/<chart-name>/values-production.yaml \
     -n xuangong-prod \
     --wait \
     --timeout 5m
   ```

4. **Verify Deployment**
   ```bash
   kubectl rollout status deployment/<name> -n xuangong-prod
   kubectl get pods -n xuangong-prod -l app.kubernetes.io/name=<name>
   kubectl logs -n xuangong-prod -l app.kubernetes.io/name=<name>
   ```

### Helm Chart Structure

```
helm/<app-name>/
├── Chart.yaml              # Chart metadata (version, appVersion)
├── values.yaml             # Default values
├── values-development.yaml # Dev environment overrides
├── values-production.yaml  # Production environment overrides
└── templates/
    ├── _helpers.tpl        # Template helpers
    ├── deployment.yaml     # Main workload
    ├── service.yaml        # ClusterIP service
    ├── ingress.yaml        # Ingress with TLS
    ├── configmap.yaml      # Configuration
    ├── serviceaccount.yaml # Service account
    ├── hpa.yaml            # Horizontal Pod Autoscaler
    └── pdb.yaml            # Pod Disruption Budget
```

### Values File Philosophy

**Minimal and Focused:**
- Keep templates simple and readable
- Use values files for environment differences
- Don't over-abstract with complex conditionals
- Document required values clearly

**Environment-Specific Values:**
- `values.yaml` - Safe defaults for any environment
- `values-development.yaml` - Dev overrides (lower resources, no TLS)
- `values-production.yaml` - Production config (HA, autoscaling, TLS)

## Deployment Strategy Details

### Rolling Update (Default)

Used for all standard deployments. Provides zero-downtime updates.

**Configuration:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 25%        # Allow 25% extra pods during update
    maxUnavailable: 25%  # Allow 25% pods unavailable during update
```

**Process:**
1. Create new ReplicaSet with updated image
2. Scale up new pods gradually
3. Wait for new pods to be Ready (readiness probe)
4. Scale down old pods gradually
5. Complete when all old pods terminated

**Advantages:**
- Zero downtime
- Gradual traffic shift
- Easy to monitor
- Automatic rollback on failure

**Use Cases:**
- Feature releases
- Bug fixes
- Configuration updates
- Version upgrades

### Rollback Strategy

**Automatic Rollback:**
- If readiness probes fail on new pods
- If insufficient cluster resources
- Kubernetes automatically halts rollout

**Manual Rollback:**
```bash
# Helm rollback (recommended)
helm rollback <release-name> -n xuangong-prod

# Kubernetes rollback
kubectl rollout undo deployment/<name> -n xuangong-prod

# Rollback to specific revision
kubectl rollout history deployment/<name> -n xuangong-prod
kubectl rollout undo deployment/<name> -n xuangong-prod --to-revision=N
```

## Health Checks

### Liveness Probe
Determines if container is healthy. Kubernetes restarts unhealthy containers.

**Frontend:**
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Backend:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness Probe
Determines if container is ready to receive traffic.

**Frontend:**
```yaml
readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**Backend:**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

## Resource Management

### Frontend Resources
```yaml
resources:
  requests:
    cpu: 50m      # Guaranteed CPU
    memory: 64Mi  # Guaranteed memory
  limits:
    cpu: 200m     # Maximum CPU
    memory: 256Mi # Maximum memory
```

**Rationale:**
- Static file serving is lightweight
- Nginx is very efficient
- 2 replicas provide redundancy
- Autoscaling handles traffic spikes

### Backend Resources
```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

**Rationale:**
- Go API handles dynamic requests
- Database connections require memory
- JWT token processing uses CPU
- Higher limits for bursts

### Horizontal Pod Autoscaling

**Frontend HPA:**
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

**Backend HPA:**
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

**Behavior:**
- Scales up when CPU/memory exceeds targets
- Scales down when below targets (with cooldown)
- Respects min/max replica limits
- Works with PodDisruptionBudget

## High Availability

### Pod Anti-Affinity

Spreads pods across different nodes for resilience.

**Frontend (Preferred):**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - xuangong-app
          topologyKey: kubernetes.io/hostname
```

**Backend (Required):**
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - xuangong-backend
        topologyKey: kubernetes.io/hostname
```

### Pod Disruption Budget

Ensures minimum availability during voluntary disruptions (upgrades, drains).

**Frontend:**
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**Backend:**
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

## Security Configuration

### Container Security

**Security Context (Frontend & Backend):**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101  # nginx/app user
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
  allowPrivilegeEscalation: false
```

### Network Security

**CORS Configuration (Backend):**
```yaml
cors:
  allowedOrigins:
    - "https://xuangong-prod.stytex.cloud"
    - "https://app.xuangong-prod.stytex.cloud"
  allowedMethods:
    - "GET"
    - "POST"
    - "PUT"
    - "DELETE"
    - "OPTIONS"
  allowedHeaders:
    - "Origin"
    - "Content-Type"
    - "Authorization"
  allowCredentials: true
  maxAge: 12h
```

**TLS Configuration:**
- cert-manager with Let's Encrypt
- Automatic certificate renewal
- TLS 1.2+ enforced
- HTTPS redirect enabled

### Secrets Management

**ImagePullSecrets:**
```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<github-pat> \
  -n xuangong-prod
```

**Application Secrets:**
- Database passwords: Kubernetes Secrets
- JWT secrets: Kubernetes Secrets
- API keys: Kubernetes Secrets
- Never commit secrets to Git
- Never embed secrets in Docker images

## Configuration Management

### Frontend Configuration

**Runtime API URL Injection:**

1. **ConfigMap** defines API_URL:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: xuangong-app
   data:
     API_URL: "https://xuangong-prod.stytex.cloud"
   ```

2. **Environment Variable** in Pod:
   ```yaml
   env:
   - name: API_URL
     valueFrom:
       configMapKeyRef:
         name: xuangong-app
         key: API_URL
   ```

3. **Docker Entrypoint** (envsubst):
   ```bash
   envsubst '$API_URL' < /usr/share/nginx/html/index.html > /tmp/index.html
   cat /tmp/index.html > /usr/share/nginx/html/index.html
   ```

4. **JavaScript in index.html**:
   ```javascript
   const apiUrl = '$API_URL';
   if (apiUrl && apiUrl !== '$' + 'API_URL') {
     localStorage.setItem('API_URL', apiUrl);
   }
   ```

5. **Flutter App** reads from localStorage:
   ```dart
   // lib/config/api_config_web.dart
   String getApiUrl() {
     return html.window.localStorage['API_URL'] ?? 'http://localhost:8080';
   }
   ```

### Backend Configuration

**ConfigMap-Based:**
- Server settings (port, environment)
- Database connection parameters
- JWT expiry times
- CORS rules
- Rate limiting

**Secret-Based:**
- Database passwords
- JWT signing keys
- Third-party API keys

## Monitoring and Observability

### Key Metrics

**Pod-Level:**
- CPU usage (vs limits)
- Memory usage (vs limits)
- Restart count
- Ready status
- Age

**Deployment-Level:**
- Available replicas
- Updated replicas
- Rollout status
- Revision number

**Application-Level:**
- HTTP response codes (2xx, 4xx, 5xx)
- Request latency
- Concurrent connections
- Error rates

### Monitoring Commands

```bash
# Pod status
kubectl get pods -n xuangong-prod

# Resource usage
kubectl top pods -n xuangong-prod

# Logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=<name> --tail=100

# Live logs
kubectl logs -n xuangong-prod -l app.kubernetes.io/name=<name> -f

# Events
kubectl get events -n xuangong-prod --sort-by='.lastTimestamp'

# HPA status
kubectl get hpa -n xuangong-prod

# Ingress status
kubectl get ingress -n xuangong-prod
```

## Troubleshooting Checklist

### Deployment Issues

**Problem:** Pods in CrashLoopBackOff
- Check logs: `kubectl logs -n xuangong-prod <pod>`
- Check events: `kubectl describe pod -n xuangong-prod <pod>`
- Common causes:
  - Configuration error
  - Missing environment variables
  - Resource limits too low
  - Application bug

**Problem:** ImagePullBackOff
- Verify image exists: `docker pull <image>`
- Check imagePullSecret: `kubectl get secret regcred -n xuangong-prod`
- Verify registry authentication
- Check image tag spelling

**Problem:** Deployment stuck in progress
- Check rollout: `kubectl rollout status deployment/<name> -n xuangong-prod`
- Check pod readiness: `kubectl get pods -n xuangong-prod`
- Common causes:
  - Readiness probe failing
  - Insufficient cluster resources
  - PodDisruptionBudget blocking

### Application Issues

**Problem:** 502 Bad Gateway
- Check backend pods are Running
- Check readiness probe status
- Verify service endpoints: `kubectl get endpoints -n xuangong-prod`
- Check ingress logs

**Problem:** CORS errors
- Verify allowedOrigins in backend config
- Check browser developer tools
- Confirm frontend URL matches CORS rules

**Problem:** TLS certificate errors
- Check cert-manager logs
- Verify cluster issuer exists
- Check certificate status: `kubectl get certificate -n xuangong-prod`

## Best Practices

### Development
- Test locally before building Docker image
- Use dry-run for Helm deployments
- Review diff before applying changes
- Keep values files in version control

### Deployment
- Always build for linux/amd64 (not darwin/arm64)
- Use semantic versioning
- Document changes in session logs
- Monitor deployment for 15 minutes after completion
- Keep rollback plan ready

### Security
- Never commit secrets
- Use least privilege principle
- Keep base images updated
- Scan images for vulnerabilities
- Rotate secrets regularly

### Operations
- Monitor resource usage trends
- Set up alerts for anomalies
- Document incidents and resolutions
- Review and update resource limits quarterly
- Keep Helm charts simple and maintainable

## Future Improvements

### Planned Enhancements
- [ ] Blue-green deployment option
- [ ] Canary releases with traffic splitting
- [ ] Automated smoke tests post-deployment
- [ ] Prometheus metrics integration
- [ ] Grafana dashboards
- [ ] Slack deployment notifications
- [ ] Automated rollback on error rate spike
- [ ] Multi-region deployment
- [ ] Database backup automation
- [ ] Disaster recovery procedures

### Under Consideration
- GitOps workflow with ArgoCD
- Service mesh (Istio/Linkerd)
- Distributed tracing (Jaeger)
- Log aggregation (ELK stack)
- Secrets management (Vault)
- Infrastructure as Code (Terraform)

## References

### Internal Documentation
- [Alpha 13 Deployment Plan](/Users/dsteiman/Dev/stuff/xuangong/.claude/docs/deployment/alpha13-deployment-plan.md)
- [Project README](/Users/dsteiman/Dev/stuff/xuangong/CLAUDE.md)
- [Tasks & Sessions](/Users/dsteiman/Dev/stuff/xuangong/.claude/tasks/)

### External Resources
- [Kubernetes Rolling Update Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Docker Multi-Platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

## Contacts

**Kubernetes Cluster:** Stytex Cloud Managed Kubernetes
**Registry:** GitHub Container Registry (ghcr.io)
**Support:** DevOps team / Infrastructure team

---

**Document Version:** 1.0
**Effective Date:** 2025-11-05
**Review Frequency:** Quarterly or after major infrastructure changes
