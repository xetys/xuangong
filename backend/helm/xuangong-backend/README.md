# Xuan Gong Backend Helm Chart

This Helm chart deploys the Xuan Gong Backend API, a specialized training application for traditional martial arts practice.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PostgreSQL database (external or using subchart)
- PersistentVolume provisioner support (if using PostgreSQL subchart)

## Installing the Chart

### Basic Installation

```bash
# Add your Helm repository (if applicable)
helm repo add xuangong https://charts.xuangong.example.com
helm repo update

# Install the chart
helm install xuangong-backend xuangong/xuangong-backend \
  --namespace xuangong \
  --create-namespace
```

### Installation with Custom Values

```bash
# Create a custom values file
cat > my-values.yaml <<EOF
secrets:
  databasePassword: "my-secure-password"
  jwtSecret: "my-secure-jwt-secret-at-least-32-characters"

ingress:
  enabled: true
  hosts:
    - host: api.xuangong.mycompany.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: xuangong-backend-tls
      hosts:
        - api.xuangong.mycompany.com

config:
  database:
    host: my-postgres.database.example.com
    port: 5432
    name: xuangong_prod
    user: xuangong_user
EOF

# Install with custom values
helm install xuangong-backend xuangong/xuangong-backend \
  --namespace xuangong \
  --create-namespace \
  --values my-values.yaml
```

### Installation with PostgreSQL Subchart

```bash
helm install xuangong-backend xuangong/xuangong-backend \
  --namespace xuangong \
  --create-namespace \
  --set postgresql.enabled=true \
  --set postgresql.auth.password=secure-password \
  --set config.database.host=xuangong-backend-postgresql
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `image.repository` | Image repository | `xuangong/backend` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Service Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.hosts[0].host` | Ingress hostname | `api.xuangong.example.com` |
| `ingress.tls` | TLS configuration | `[]` |

### Application Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.server.env` | Server environment | `production` |
| `config.server.port` | Server port | `8080` |
| `config.database.host` | Database host | `postgresql` |
| `config.database.port` | Database port | `5432` |
| `config.database.name` | Database name | `xuangong` |
| `config.database.user` | Database user | `xuangong` |
| `config.jwt.accessExpiry` | JWT access token expiry | `15m` |
| `config.jwt.refreshExpiry` | JWT refresh token expiry | `7d` |

### Secrets

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.databasePassword` | Database password | `changeme` |
| `secrets.jwtSecret` | JWT secret key | `changeme-generate-secure-random-string` |

**⚠️ WARNING**: Always change the default secrets in production!

### Resource Limits

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |

### Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `2` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `80` |

## Database Migrations

Database migrations are handled automatically by the backend application on startup. No separate migration job is required.

## Upgrading

```bash
# Upgrade to a new version
helm upgrade xuangong-backend xuangong/xuangong-backend \
  --namespace xuangong \
  --values my-values.yaml

# Upgrade with specific values
helm upgrade xuangong-backend xuangong/xuangong-backend \
  --namespace xuangong \
  --set image.tag=v1.2.0 \
  --reuse-values
```

## Uninstalling

```bash
helm uninstall xuangong-backend --namespace xuangong
```

## Production Checklist

Before deploying to production, ensure:

- [ ] Change default database password
- [ ] Generate secure JWT secret (minimum 32 characters)
- [ ] Configure proper resource limits
- [ ] Enable ingress with TLS
- [ ] Set up proper CORS origins
- [ ] Configure external PostgreSQL database
- [ ] Enable autoscaling if needed
- [ ] Set up monitoring and logging
- [ ] Configure backup strategy for database
- [ ] Review security contexts and policies

## Generating Secure Secrets

```bash
# Generate a secure database password
openssl rand -base64 32

# Generate a secure JWT secret
openssl rand -base64 64
```

## Monitoring

The application exposes a health endpoint at `/health` which can be used for:

- Kubernetes liveness probes
- Kubernetes readiness probes
- External monitoring systems

## Troubleshooting

### Pods not starting

Check pod status and logs:

```bash
kubectl get pods -n xuangong
kubectl describe pod <pod-name> -n xuangong
kubectl logs <pod-name> -n xuangong
```

### Database connection issues

Verify database configuration and connectivity:

```bash
# Get the secret
kubectl get secret xuangong-backend -n xuangong -o yaml

# Test database connection from a pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql postgresql://user:password@host:5432/database
```

### Permission errors

Check security contexts and service account permissions:

```bash
kubectl describe pod <pod-name> -n xuangong
kubectl get serviceaccount -n xuangong
```

## Support

For issues and questions:
- GitHub: https://github.com/xuangong/backend
- Email: support@xuangong.example.com
- Documentation: https://docs.xuangong.example.com

## License

Copyright © Xuan Gong Fu Academy
