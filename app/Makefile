.PHONY: run build test clean docker-build-prod docker-push-prod help

# Docker configuration
IMAGE_REPO = ghcr.io/xetys/xuangong/app
TAG ?= latest

# Development
run:
	@echo "Running Flutter web app..."
	flutter run -d chrome

build:
	@echo "Building Flutter web app..."
	flutter build web --release

test:
	@echo "Running tests..."
	flutter test

# Docker
docker-build-prod:
	@echo "Building production Docker image for linux/amd64..."
	@echo "Image: $(IMAGE_REPO):$(TAG)"
	docker buildx build \
		--platform linux/amd64 \
		--tag $(IMAGE_REPO):$(TAG) \
		--file Dockerfile \
		--load \
		.

docker-push-prod:
	@echo "Pushing production Docker image..."
	@echo "Image: $(IMAGE_REPO):$(TAG)"
	docker push $(IMAGE_REPO):$(TAG)

# Cleanup
clean:
	@echo "Cleaning up..."
	flutter clean
	rm -rf build/

# Help
help:
	@echo "Available targets:"
	@echo "  run                - Run Flutter web app in Chrome"
	@echo "  build              - Build Flutter web release"
	@echo "  test               - Run Flutter tests"
	@echo "  docker-build-prod  - Build production Docker image (use: make docker-build-prod TAG=v1.0.0)"
	@echo "  docker-push-prod   - Push production Docker image to registry"
	@echo "  clean              - Clean build artifacts"
	@echo "  help               - Show this help message"
