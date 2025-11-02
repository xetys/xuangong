# Xuan Gong Frontend Web App - Helm Chart

This Helm chart deploys the Xuan Gong Flutter web application to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- nginx ingress controller (for ingress)
- cert-manager (for TLS certificates in production)

## Installing the Chart

### Development

```bash
helm install xuangong-app ./helm/xuangong-app \
  -f helm/xuangong-app/values-development.yaml \
  -n xuangong-dev \
  --create-namespace
```

### Production

```bash
helm install xuangong-app ./helm/xuangong-app \
  -f helm/xuangong-app/values-production.yaml \
  -n xuangong-prod \
  --create-namespace
```

## Upgrading the Chart

```bash
# Development
helm upgrade xuangong-app ./helm/xuangong-app \
  -f helm/xuangong-app/values-development.yaml \
  -n xuangong-dev

# Production
helm upgrade xuangong-app ./helm/xuangong-app \
  -f helm/xuangong-app/values-production.yaml \
  -n xuangong-prod
```

## Uninstalling the Chart

```bash
helm uninstall xuangong-app -n xuangong-prod
```

## Configuration

The following table lists the configurable parameters and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/xetys/xuangong/app` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `config.apiUrl` | Backend API URL | `http://localhost:8080` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts` | Ingress hosts | `[]` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |

## Architecture

The chart deploys:
- Deployment with Flutter web app served by nginx
- Service (ClusterIP)
- Ingress (optional, with TLS support)
- ConfigMap for API URL configuration
- HorizontalPodAutoscaler (optional)
- PodDisruptionBudget (optional)

## API URL Configuration

The API URL is configured via a ConfigMap and injected at container startup. This allows the same Docker image to be used across different environments.

In production:
```yaml
config:
  apiUrl: "https://xuangong-prod.stytex.cloud"
```

In development:
```yaml
config:
  apiUrl: "http://xuangong-backend:8080"
```

## Security

The application runs as a non-root user (nginx user, uid 101) with the following security context:
- Read-only root filesystem: false (nginx needs write access for temp files)
- No privilege escalation
- All capabilities dropped
- Non-root user enforcement

## High Availability

Production deployment includes:
- Multiple replicas (2+)
- Pod anti-affinity rules (prefer different nodes)
- HorizontalPodAutoscaler (2-10 replicas)
- PodDisruptionBudget (minimum 1 available)
- Liveness and readiness probes

## Ingress and TLS

Production uses cert-manager with Let's Encrypt for automatic TLS certificate provisioning:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: app.xuangong-prod.stytex.cloud
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: xuangong-app-tls-prod
      hosts:
        - app.xuangong-prod.stytex.cloud
```

## Monitoring

The application exposes HTTP endpoints that can be monitored:
- `/` - Main application (used for liveness/readiness probes)

Probe configuration:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```
