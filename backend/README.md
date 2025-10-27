# Xuan Gong Backend API

Production-ready Go backend for the Xuan Gong martial arts training application.

## Tech Stack

- **Language**: Go 1.21+
- **Web Framework**: Gin
- **Database**: PostgreSQL 15+ with pgx driver
- **Authentication**: JWT (golang-jwt/jwt/v5)
- **Migrations**: golang-migrate
- **Configuration**: Viper
- **Validation**: go-playground/validator/v10

## Project Structure

```
backend/
├── cmd/
│   ├── api/          # Main application entry point
│   └── seed/         # Database seeding tool
├── internal/
│   ├── config/       # Configuration management
│   ├── database/     # Database connection and migrations
│   ├── handlers/     # HTTP request handlers
│   ├── middleware/   # HTTP middleware
│   ├── models/       # Domain models
│   ├── repositories/ # Data access layer
│   ├── services/     # Business logic layer
│   └── validators/   # Request validation structs
├── migrations/       # SQL migration files
├── pkg/
│   ├── auth/         # Authentication utilities
│   └── errors/       # Custom error types
├── docker-compose.yml
├── Dockerfile
└── Makefile
```

## Quick Start

### Prerequisites

- Go 1.21 or higher
- Docker and Docker Compose
- Make (optional, but recommended)

### Installation

1. **Clone the repository**
   ```bash
   cd backend
   ```

2. **Install development tools**
   ```bash
   make install-tools
   ```

3. **Start the database**
   ```bash
   make docker-up
   ```

4. **Run migrations**
   ```bash
   make migrate-up
   ```

5. **Seed the database**
   ```bash
   make seed
   ```

6. **Start the development server**
   ```bash
   make dev
   ```

The API will be available at `http://localhost:8080`

### Test Accounts

After seeding, you can use these accounts:

- **Admin**: `admin@xuangong.local` / `admin123`
- **Student**: `student@xuangong.local` / `student123`

## Development

### Running Locally

```bash
# Start with hot reload (recommended)
make dev

# Or run directly
make run

# Or build and run
make build
./bin/api
```

### Environment Variables

Copy `.env.example` to `.env.development` and configure:

```env
DATABASE_URL=postgres://xuangong:xuangong@localhost:5432/xuangong_db?sslmode=disable
JWT_SECRET=your-secret-key-here
PORT=8080
ENV=development
```

### Database Management

```bash
# Run migrations
make migrate-up

# Rollback last migration
make migrate-down

# Create new migration
make migrate-create name=add_users_table

# Seed database with test data
make seed

# Reset database (WARNING: deletes all data)
make db-reset
```

### Docker

```bash
# Start all services
make docker-up

# Stop all services
make docker-down

# View logs
make docker-logs

# Rebuild images
make docker-build
```

Access Adminer (database UI) at `http://localhost:8081`

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Logout (requires auth)

### Programs

- `GET /api/v1/programs` - List programs
- `GET /api/v1/programs/:id` - Get program details
- `POST /api/v1/programs` - Create program (admin only)
- `PUT /api/v1/programs/:id` - Update program (admin only)
- `DELETE /api/v1/programs/:id` - Delete program (admin only)
- `POST /api/v1/programs/:id/assign` - Assign program to users (admin only)

### User Programs

- `GET /api/v1/my-programs` - Get assigned programs

### Sessions

- `GET /api/v1/sessions` - List practice sessions
- `GET /api/v1/sessions/:id` - Get session details
- `POST /api/v1/sessions/start` - Start new session
- `PUT /api/v1/sessions/:id/exercise/:exercise_id` - Log exercise completion
- `PUT /api/v1/sessions/:id/complete` - Complete session
- `GET /api/v1/sessions/stats` - Get practice statistics

### Health Check

- `GET /health` - Health check endpoint

## Authentication

All protected endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Example Login

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@xuangong.local",
    "password": "student123"
  }'
```

Response:
```json
{
  "user": {
    "id": "uuid",
    "email": "student@xuangong.local",
    "full_name": "Li Wei",
    "role": "student"
  },
  "tokens": {
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc...",
    "expires_in": 86400
  }
}
```

## Error Handling

All errors follow a consistent format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "User-friendly error message",
    "details": {
      "field": "additional context"
    }
  }
}
```

### Error Codes

- `VALIDATION_ERROR` - Invalid input data
- `AUTHENTICATION_ERROR` - Invalid credentials or token
- `AUTHORIZATION_ERROR` - Insufficient permissions
- `NOT_FOUND` - Resource not found
- `CONFLICT` - Resource already exists
- `INTERNAL_ERROR` - Server error
- `BAD_REQUEST` - Malformed request
- `RATE_LIMIT_EXCEEDED` - Too many requests

## Database Schema

The database includes the following main tables:

- `users` - User accounts (admin/student)
- `programs` - Training programs
- `exercises` - Exercises within programs
- `exercise_variations` - Different intensity levels (light/medium/intensive)
- `user_programs` - Program assignments
- `practice_sessions` - Training session logs
- `exercise_logs` - Individual exercise completions
- `video_submissions` - Student video uploads
- `feedback` - Instructor feedback

See `migrations/000001_init_schema.up.sql` for the complete schema.

## Testing

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage
```

## Code Quality

```bash
# Format code
make fmt

# Run linter
make lint

# Tidy dependencies
make tidy
```

## Deployment

### Building for Production

```bash
# Build binary
make build

# Build Docker image
docker build -t xuangong-api .
```

### Environment Variables for Production

Ensure these are set in production:

- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Strong secret key (min 32 characters)
- `ENV=production`
- `ALLOWED_ORIGINS` - Comma-separated list of allowed origins
- `PORT` - Server port (default: 8080)

### Security Checklist

- [ ] Use strong JWT secret (min 32 characters)
- [ ] Enable SSL/TLS for database connections
- [ ] Configure CORS for your domain only
- [ ] Set appropriate rate limits
- [ ] Use environment variables for secrets
- [ ] Enable PostgreSQL SSL mode in production
- [ ] Review and adjust database connection pool settings

## Architecture

### Layered Architecture

1. **Handlers** - HTTP request/response handling
2. **Services** - Business logic and orchestration
3. **Repositories** - Data access and queries
4. **Models** - Domain entities

### Middleware Chain

1. Recovery - Panic recovery
2. Logger - Request logging
3. CORS - Cross-origin resource sharing
4. RateLimit - Rate limiting per IP
5. Auth - JWT validation (protected routes only)

## Database Migrations

Migrations use [golang-migrate](https://github.com/golang-migrate/migrate).

### Creating Migrations

```bash
make migrate-create name=add_new_table
```

This creates two files:
- `migrations/XXXXXX_add_new_table.up.sql`
- `migrations/XXXXXX_add_new_table.down.sql`

### Best Practices

- Always include both `up` and `down` migrations
- Test migrations on a copy of production data
- Keep migrations small and focused
- Never modify existing migrations that have been deployed

## Troubleshooting

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps

# View PostgreSQL logs
docker-compose logs postgres

# Restart database
docker-compose restart postgres
```

### Migration Issues

```bash
# Check current migration version
migrate -path migrations -database "$DATABASE_URL" version

# Force to specific version (use with caution)
make migrate-force version=1
```

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

## Performance Considerations

- Database connection pool is configured for optimal performance
- Rate limiting prevents abuse
- Indexes are created on frequently queried columns
- Prepared statements prevent SQL injection
- Context timeouts prevent hung requests

## Future Enhancements

- [ ] Add video submission endpoints
- [ ] Add feedback endpoints
- [ ] Add exercise CRUD endpoints
- [ ] Implement token blacklisting for logout
- [ ] Add request validation middleware
- [ ] Add Swagger/OpenAPI documentation
- [ ] Add integration tests
- [ ] Add metrics and monitoring
- [ ] Add structured logging with levels
- [ ] Add file upload support for videos

## License

Proprietary - Xuan Gong Fu Academy

## Support

For issues or questions, contact the development team.
