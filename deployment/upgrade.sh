#!/bin/bash

set -e

# Check if environment name is provided
if [ -z "$1" ]; then
  echo "Error: Environment name is required"
  echo "Usage: $0 <environment-name>"
  echo ""
  echo "Available environments:"
  grep "^[a-zA-Z]" deployment/versions.yaml | sed 's/:$//' | sed 's/^/  - /'
  exit 1
fi

ENV_NAME="$1"

# Get the root directory (parent of deployment/)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENT_DIR="$ROOT_DIR/deployment"
VERSIONS_FILE="$DEPLOYMENT_DIR/versions.yaml"
HELM_VALUES_DIR="$DEPLOYMENT_DIR/helm-values"

# Check if versions.yaml exists
if [ ! -f "$VERSIONS_FILE" ]; then
  echo "Error: versions.yaml not found at $VERSIONS_FILE"
  exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
  echo "Error: yq is not installed. Please install it first:"
  echo "  brew install yq"
  exit 1
fi

# Read configuration from versions.yaml
DOMAIN=$(yq eval ".${ENV_NAME}.domain" "$VERSIONS_FILE")
APP_VERSION=$(yq eval ".${ENV_NAME}.appVersion" "$VERSIONS_FILE")
BACKEND_VERSION=$(yq eval ".${ENV_NAME}.backendVersion" "$VERSIONS_FILE")

# Validate that environment exists in versions.yaml
if [ "$DOMAIN" == "null" ] || [ -z "$DOMAIN" ]; then
  echo "Error: Environment '$ENV_NAME' not found in versions.yaml"
  echo ""
  echo "Available environments:"
  yq eval 'keys | .[]' "$VERSIONS_FILE" | sed 's/^/  - /'
  exit 1
fi

echo "=========================================="
echo "Upgrading environment: $ENV_NAME"
echo "  Domain: $DOMAIN"
echo "  App Version: $APP_VERSION"
echo "  Backend Version: $BACKEND_VERSION"
echo "=========================================="

# Check if namespace exists in Kubernetes
echo ""
echo "Checking if namespace '$ENV_NAME' exists..."
if ! kubectl get namespace "$ENV_NAME" &> /dev/null; then
  echo "Error: Namespace '$ENV_NAME' does not exist in the current Kubernetes cluster"
  echo ""
  echo "Current cluster:"
  kubectl config current-context
  echo ""
  echo "Available namespaces:"
  kubectl get namespaces -o name | sed 's/namespace\///' | sed 's/^/  - /'
  exit 1
fi
echo "✓ Namespace '$ENV_NAME' exists"

# Prepare helm values files
APP_VALUES_FILE="$HELM_VALUES_DIR/helm-app-${ENV_NAME}.yaml"
BACKEND_VALUES_FILE="$HELM_VALUES_DIR/helm-backend-${ENV_NAME}.yaml"

# Check/create app values file
if [ ! -f "$APP_VALUES_FILE" ]; then
  echo ""
  echo "Creating $APP_VALUES_FILE from template..."
  cp "$ROOT_DIR/app/helm/xuangong-app/values-production.yaml" "$APP_VALUES_FILE"

  # Update domain and version in app values
  yq eval -i ".image.tag = \"$APP_VERSION\"" "$APP_VALUES_FILE"
  yq eval -i ".config.apiUrl = \"https://$DOMAIN\"" "$APP_VALUES_FILE"
  yq eval -i ".ingress.hosts[0].host = \"app.$DOMAIN\"" "$APP_VALUES_FILE"
  yq eval -i ".ingress.tls[0].hosts[0] = \"app.$DOMAIN\"" "$APP_VALUES_FILE"
  yq eval -i ".ingress.tls[0].secretName = \"xuangong-app-tls-${ENV_NAME}\"" "$APP_VALUES_FILE"
  echo "✓ Created $APP_VALUES_FILE"
else
  echo ""
  echo "Updating versions in $APP_VALUES_FILE..."
  yq eval -i ".image.tag = \"$APP_VERSION\"" "$APP_VALUES_FILE"
  echo "✓ Updated $APP_VALUES_FILE"
fi

# Check/create backend values file
if [ ! -f "$BACKEND_VALUES_FILE" ]; then
  echo ""
  echo "Creating $BACKEND_VALUES_FILE from template..."
  cp "$ROOT_DIR/backend/helm/xuangong-backend/values-production.yaml" "$BACKEND_VALUES_FILE"

  # Update domain and version in backend values
  yq eval -i ".image.tag = \"$BACKEND_VERSION\"" "$BACKEND_VALUES_FILE"
  yq eval -i ".config.cors.allowedOrigins[0] = \"https://$DOMAIN\"" "$BACKEND_VALUES_FILE"
  yq eval -i ".config.cors.allowedOrigins[1] = \"https://app.$DOMAIN\"" "$BACKEND_VALUES_FILE"
  yq eval -i ".ingress.hosts[0].host = \"$DOMAIN\"" "$BACKEND_VALUES_FILE"
  yq eval -i ".ingress.tls[0].hosts[0] = \"$DOMAIN\"" "$BACKEND_VALUES_FILE"
  yq eval -i ".ingress.tls[0].secretName = \"xuangong-backend-tls-${ENV_NAME}\"" "$BACKEND_VALUES_FILE"
  echo "✓ Created $BACKEND_VALUES_FILE"
else
  echo ""
  echo "Updating versions in $BACKEND_VALUES_FILE..."
  yq eval -i ".image.tag = \"$BACKEND_VERSION\"" "$BACKEND_VALUES_FILE"
  echo "✓ Updated $BACKEND_VALUES_FILE"
fi

# Deploy backend with Helm
echo ""
echo "=========================================="
echo "Deploying backend..."
echo "=========================================="
helm upgrade xuangong-prod "$ROOT_DIR/backend/helm/xuangong-backend" \
  -f "$BACKEND_VALUES_FILE" \
  -n "$ENV_NAME" \
  --wait \
  --timeout 5m

echo "✓ Backend deployed successfully"

# Deploy app with Helm
echo ""
echo "=========================================="
echo "Deploying app..."
echo "=========================================="
helm upgrade xuangong-app "$ROOT_DIR/app/helm/xuangong-app" \
  -f "$APP_VALUES_FILE" \
  -n "$ENV_NAME" \
  --wait \
  --timeout 5m

echo "✓ App deployed successfully"

# Verify deployments
echo ""
echo "=========================================="
echo "Verifying deployments..."
echo "=========================================="

echo ""
echo "Backend pods:"
kubectl get pods -n "$ENV_NAME" -l app.kubernetes.io/name=xuangong-backend

echo ""
echo "App pods:"
kubectl get pods -n "$ENV_NAME" -l app.kubernetes.io/name=xuangong-app

echo ""
echo "Backend image version:"
kubectl get deployment -n "$ENV_NAME" -l app.kubernetes.io/name=xuangong-backend -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "App image version:"
kubectl get deployment -n "$ENV_NAME" -l app.kubernetes.io/name=xuangong-app -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "=========================================="
echo "✓ Deployment complete!"
echo "=========================================="
echo ""
echo "Application URLs:"
echo "  Frontend: https://app.$DOMAIN"
echo "  Backend:  https://$DOMAIN"
echo ""
