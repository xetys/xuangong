.PHONY: dev run build test migrate-up migrate-down migrate-create seed docker-up docker-down clean install-tools tidy

DOCKER_COMPOSE = docker compose

# Development
dev:
	@echo "Starting development server with hot reload..."
	air -c .air.toml

run:
	@echo "Running application..."
	go run cmd/api/main.go

build:
	@echo "Building application..."
	go build -o bin/api cmd/api/main.go

# Testing
test:
	@echo "Running tests..."
	go test -v ./...

test-coverage:
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out

# Database migrations
migrate-up:
	@echo "Running migrations..."
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	@echo "Rolling back last migration..."
	migrate -path migrations -database "$(DATABASE_URL)" down 1

migrate-create:
	@echo "Creating new migration: $(name)"
	migrate create -ext sql -dir migrations -seq $(name)

migrate-force:
	@echo "Forcing migration version: $(version)"
	migrate -path migrations -database "$(DATABASE_URL)" force $(version)

# Seed data
seed:
	@echo "Seeding database..."
	go run cmd/seed/main.go

# Docker
docker-up:
	@echo "Starting Docker containers..."
	$(DOCKER_COMPOSE) up -d

docker-down:
	@echo "Stopping Docker containers..."
	$(DOCKER_COMPOSE) down

docker-logs:
	@echo "Showing Docker logs..."
	$(DOCKER_COMPOSE) logs -f

docker-build:
	@echo "Building Docker image..."
	$(DOCKER_COMPOSE) build

# Cleanup
clean:
	@echo "Cleaning up..."
	rm -rf bin/ tmp/ coverage.out build-errors.log

# Dependencies
tidy:
	@echo "Tidying dependencies..."
	go mod tidy

install-tools:
	@echo "Installing development tools..."
	go install github.com/air-verse/air@latest
	go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Linting
lint:
	@echo "Running linter..."
	golangci-lint run

fmt:
	@echo "Formatting code..."
	go fmt ./...

# Database
db-reset: docker-down
	@echo "Resetting database..."
	docker volume rm xuangong_postgres_data || true
	$(MAKE) docker-up
	sleep 3
	$(MAKE) migrate-up
	$(MAKE) seed

# Help
help:
	@echo "Available targets:"
	@echo "  dev             - Start development server with hot reload"
	@echo "  run             - Run the application"
	@echo "  build           - Build the application"
	@echo "  test            - Run tests"
	@echo "  test-coverage   - Run tests with coverage report"
	@echo "  migrate-up      - Run database migrations"
	@echo "  migrate-down    - Rollback last migration"
	@echo "  migrate-create  - Create new migration (use: make migrate-create name=create_users)"
	@echo "  seed            - Seed database with test data"
	@echo "  docker-up       - Start Docker containers"
	@echo "  docker-down     - Stop Docker containers"
	@echo "  docker-logs     - Show Docker logs"
	@echo "  clean           - Clean build artifacts"
	@echo "  tidy            - Tidy Go dependencies"
	@echo "  install-tools   - Install development tools"
	@echo "  db-reset        - Reset database (WARNING: deletes all data)"
	@echo "  fmt             - Format code"
	@echo "  help            - Show this help message"
