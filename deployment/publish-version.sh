#!/bin/bash

# Parse arguments
APP_VERSION=""
BACKEND_VERSION=""

for arg in "$@"; do
  case $arg in
    --app=*)
      APP_VERSION="${arg#*=}"
      shift
      ;;
    --backend=*)
      BACKEND_VERSION="${arg#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 --app=<version> --backend=<version>"
      exit 1
      ;;
  esac
done

# Validate arguments
if [ -z "$APP_VERSION" ] || [ -z "$BACKEND_VERSION" ]; then
  echo "Error: Both --app and --backend versions are required"
  echo "Usage: $0 --app=<version> --backend=<version>"
  exit 1
fi

echo "=========================================="
echo "Publishing versions:"
echo "  App: $APP_VERSION"
echo "  Backend: $BACKEND_VERSION"
echo "=========================================="

# Get the root directory (parent of deployment/)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build and push backend
echo ""
echo "Building backend version $BACKEND_VERSION..."
cd "$ROOT_DIR/backend" || exit 1
make docker-build-prod TAG="$BACKEND_VERSION" || {
  echo "Error: Failed to build backend"
  exit 1
}

echo ""
echo "Pushing backend version $BACKEND_VERSION..."
make docker-push-prod TAG="$BACKEND_VERSION" || {
  echo "Error: Failed to push backend"
  exit 1
}

# Build and push app
echo ""
echo "Building app version $APP_VERSION..."
cd "$ROOT_DIR/app" || exit 1
make docker-build-prod TAG="$APP_VERSION" || {
  echo "Error: Failed to build app"
  exit 1
}

echo ""
echo "Pushing app version $APP_VERSION..."
make docker-push-prod TAG="$APP_VERSION" || {
  echo "Error: Failed to push app"
  exit 1
}

echo ""
echo "=========================================="
echo "✓ Successfully published:"
echo "  App: $APP_VERSION"
echo "  Backend: $BACKEND_VERSION"
echo "=========================================="
