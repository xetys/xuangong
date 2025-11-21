# Deployment Scripts

This directory contains deployment automation scripts for the Xuan Gong application.

## Files

- **versions.yaml** - Version configuration for different environments
- **publish-version.sh** - Build and push Docker images
- **upgrade.sh** - Deploy to Kubernetes using Helm
- **helm-values/** - Environment-specific Helm values files

## Usage

### 1. Publish New Versions

Build and push Docker images for app and backend:

```bash
./deployment/publish-version.sh --app=v2025.1.0-beta2 --backend=v2025.1.0-beta2
```

### 2. Update versions.yaml

Edit `deployment/versions.yaml` to specify which versions should be deployed to each environment:

```yaml
xuangong-prod:
  domain: xuangong-prod.stytex.cloud
  appVersion: v2025.1.0-beta2
  backendVersion: v2025.1.0-beta2
```

### 3. Deploy to Kubernetes

Deploy the versions specified in versions.yaml to the target environment:

```bash
./deployment/upgrade.sh xuangong-prod
```

The script will:
1. Verify the namespace exists in the current k8s cluster
2. Create/update Helm values files in `helm-values/` directory
3. Deploy backend and app using Helm
4. Verify the deployment

## Requirements

- Docker
- kubectl (configured with cluster access)
- Helm 3.x
- yq (for YAML parsing)
  ```bash
  brew install yq
  ```

## Environment Configuration

Each environment in `versions.yaml` requires:
- **domain** - Base domain for the environment
- **appVersion** - Docker image tag for the frontend app
- **backendVersion** - Docker image tag for the backend API

The scripts will automatically configure:
- Image tags
- Ingress domains (app.{domain} for frontend, {domain} for backend)
- CORS origins
- TLS certificate names

## Helm Values Files

Environment-specific Helm values are stored in `helm-values/`:
- `helm-app-<env-name>.yaml` - App-specific values
- `helm-backend-<env-name>.yaml` - Backend-specific values

These files are automatically created from the production templates on first run and can be manually customized as needed.

## Example Workflow

Complete deployment workflow:

```bash
# 1. Build and publish new versions
./deployment/publish-version.sh --app=v2025.1.0-beta2 --backend=v2025.1.0-beta2

# 2. Update versions.yaml with new versions
# (Edit deployment/versions.yaml)

# 3. Set kubectl context
export KUBECONFIG=~/Downloads/kubeconfig-admin-mqwtngwgph-stytex-cloud

# 4. Deploy to environment
./deployment/upgrade.sh xuangong-prod
```
