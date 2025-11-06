# TDD Implementation Plan: Admin API Features

**Date**: 2025-11-06
**Status**: Planning Phase
**Author**: go-backend-architect (Claude Code AI)

## Overview

This document provides a comprehensive Test-Driven Development (TDD) plan for implementing three admin-focused backend features with soft delete, session viewing, and role management capabilities.

## User Decisions Summary

1. **Program deletion**: Soft delete (archive) - add `deleted_at` timestamp
2. **Session viewing**: Support both program-specific AND all-sessions filtering
3. **Role promotion**: Any admin can promote users, no super admin restriction

## Features to Implement

### Feature 1: Soft Delete Programs
- **Endpoint**: `DELETE /api/v1/programs/{id}`
- **Database Migration**: Add `deleted_at` timestamp to programs table
- **Behavior**: Mark as deleted instead of removing from DB

### Feature 2: Admin View User Sessions
- **Endpoint**: `GET /api/v1/admin/users/{user_id}/sessions`
- **Query Parameters**: Optional `program_id` for filtering
- **Authorization**: Admin role required

### Feature 3: Update User Role
- **Endpoint**: `PUT /api/v1/users/{id}` (enhance existing)
- **Request Field**: Add `role` field
- **Business Rules**:
  - Admin cannot demote themselves
  - System must have at least one admin

---

## Overall TDD Strategy

### Testing Philosophy
1. **Test-First Approach**: Write failing tests before implementation
2. **Red-Green-Refactor**: Follow strict TDD cycle
3. **Table-Driven Tests**: Use for multiple scenarios (existing pattern)
4. **Comprehensive Coverage**: Test happy paths, errors, edge cases, and authorization

### Test Organization
```
backend/
├── internal/
│   ├── handlers/
│   │   ├── programs_test.go          (NEW)
│   │   ├── users_test.go             (NEW)
│   │   └── sessions_test.go          (NEW)
│   ├── services/
│   │   ├── program_service_test.go   (NEW)
│   │   ├── user_service_test.go      (NEW)
│   │   └── session_service_test.go   (NEW)
│   └── repositories/
│       ├── program_repository_test.go (NEW)
│       ├── user_repository_test.go    (NEW)
│       └── session_repository_test.go (NEW)
└── pkg/
    └── testutil/                      (NEW)
        ├── db.go                      (Test database setup)
        ├── fixtures.go                (Test data fixtures)
        └── mocks.go                   (Mock utilities)
```

### Test Levels

1. **Repository Tests** (Database Layer)
   - Direct database interactions
   - SQL query correctness
   - Transaction handling
   - Use real test database (PostgreSQL in Docker)

2. **Service Tests** (Business Logic Layer)
   - Business rule enforcement
   - Authorization logic
   - Error handling
   - Mock repository dependencies

3. **Handler Tests** (HTTP Layer)
   - HTTP request/response handling
   - Input validation
   - Status codes
   - Mock service dependencies

4. **Integration Tests** (Optional - Phase 2)
   - End-to-end API tests
   - Full stack testing
   - Database + service + handler

---

## Test Infrastructure Setup

### Phase 0: Testing Utilities (Build First)

Before writing feature tests, create foundational testing infrastructure.

#### File: `backend/pkg/testutil/db.go`

**Purpose**: Test database setup and teardown utilities

**Functions**:
```go
// SetupTestDB creates a test database and runs migrations
func SetupTestDB(t *testing.T) *pgxpool.Pool

// TeardownTestDB closes connections and drops test database
func TeardownTestDB(t *testing.T, pool *pgxpool.Pool)

// TruncateTables clears all tables between tests
func TruncateTables(t *testing.T, pool *pgxpool.Pool, tables ...string)

// ExecuteSQL runs raw SQL for test setup
func ExecuteSQL(t *testing.T, pool *pgxpool.Pool, sql string, args ...interface{})
```

**Implementation Approach**:
1. Generate unique database name per test: `xuangong_test_{timestamp}`
2. Create database via admin connection
3. Run all migrations from `migrations/` directory
4. Return connection pool
5. Cleanup: drop database after test completion

#### File: `backend/pkg/testutil/fixtures.go`

**Purpose**: Reusable test data creation

**Functions**:
```go
// CreateTestUser creates a user with given role
func CreateTestUser(t *testing.T, repo *repositories.UserRepository, role models.UserRole) *models.User

// CreateTestAdmin creates an admin user
func CreateTestAdmin(t *testing.T, repo *repositories.UserRepository) *models.User

// CreateTestStudent creates a student user
func CreateTestStudent(t *testing.T, repo *repositories.UserRepository) *models.User

// CreateTestProgram creates a program owned by user
func CreateTestProgram(t *testing.T, repo *repositories.ProgramRepository, ownerID uuid.UUID) *models.Program

// CreateTestSession creates a practice session
func CreateTestSession(t *testing.T, repo *repositories.SessionRepository, userID, programID uuid.UUID) *models.PracticeSession
```

**Implementation Notes**:
- Use deterministic data (not random) for reproducibility
- Include helper for creating complete object graphs
- Use `t.Cleanup()` for automatic resource cleanup

#### File: `backend/pkg/testutil/mocks.go`

**Purpose**: Mock implementations for unit testing

**Mock Types**:
```go
// MockProgramRepository - mock for testing services
type MockProgramRepository struct {
    GetByIDFunc func(ctx context.Context, id uuid.UUID) (*models.Program, error)
    SoftDeleteFunc func(ctx context.Context, id uuid.UUID) error
    // ... other methods
}

// MockUserRepository - mock for testing services
type MockUserRepository struct {
    GetByIDFunc func(ctx context.Context, id uuid.UUID) (*models.User, error)
    UpdateFunc func(ctx context.Context, user *models.User) error
    CountAdminsFunc func(ctx context.Context) (int, error)
}

// MockSessionRepository - mock for admin session viewing
type MockSessionRepository struct {
    ListByUserFunc func(ctx context.Context, userID uuid.UUID, filters ...) ([]models.PracticeSession, error)
}
```

**Implementation Notes**:
- Use function fields for flexible test behavior
- Implement all repository interface methods
- Provide default no-op implementations
- Allow per-test override of specific methods

---

## Feature 1: Soft Delete Programs

### User Story
> As an admin or program owner, I want to archive (soft delete) a program so that it's hidden from normal views but sessions remain intact and can be restored later.

### Database Migration

#### Migration: `000004_add_deleted_at_to_programs.up.sql`

```sql
-- Add deleted_at column for soft delete
ALTER TABLE programs ADD COLUMN deleted_at TIMESTAMP DEFAULT NULL;

-- Create index for filtering active programs
CREATE INDEX idx_programs_deleted_at ON programs(deleted_at)
WHERE deleted_at IS NULL;

-- Add comment for clarity
COMMENT ON COLUMN programs.deleted_at IS
'Timestamp when program was soft deleted (archived). NULL = active';
```

#### Migration: `000004_add_deleted_at_to_programs.down.sql`

```sql
-- Remove index
DROP INDEX IF EXISTS idx_programs_deleted_at;

-- Remove column
ALTER TABLE programs DROP COLUMN IF EXISTS deleted_at;
```

#### Migration Test Strategy

**Test File**: `backend/internal/database/migrations_test.go`

**Test Cases**:
1. Migration applies successfully (up)
2. Migration rolls back successfully (down)
3. Column has correct type and default
4. Index exists after migration
5. Existing programs unaffected by migration

### Repository Layer Tests

#### File: `backend/internal/repositories/program_repository_test.go`

**Test Structure**:
```go
func TestProgramRepository_SoftDelete(t *testing.T) {
    // Table-driven test cases
}

func TestProgramRepository_GetByID_ExcludesDeleted(t *testing.T) {
    // Verify deleted programs not returned by default
}

func TestProgramRepository_List_ExcludesDeleted(t *testing.T) {
    // Verify list query excludes deleted
}
```

**Test Cases for SoftDelete**:

| Test Name | Setup | Action | Expected Result |
|-----------|-------|--------|-----------------|
| `soft_delete_existing_program` | Create program | SoftDelete(programID) | deleted_at set to current time |
| `soft_delete_already_deleted` | Create + soft delete | SoftDelete(programID) again | Updates deleted_at timestamp |
| `soft_delete_nonexistent` | Empty DB | SoftDelete(randomID) | Error: program not found |
| `soft_delete_preserves_data` | Create with exercises | SoftDelete(programID) | All fields unchanged except deleted_at |
| `soft_delete_preserves_sessions` | Program with sessions | SoftDelete(programID) | Sessions remain queryable |

**Test Implementation Example**:
```go
func TestProgramRepository_SoftDelete(t *testing.T) {
    tests := []struct {
        name    string
        setup   func(t *testing.T, repo *ProgramRepository) uuid.UUID
        wantErr bool
    }{
        {
            name: "soft_delete_existing_program",
            setup: func(t *testing.T, repo *ProgramRepository) uuid.UUID {
                program := testutil.CreateTestProgram(t, repo, testutil.CreateTestAdmin(t).ID)
                return program.ID
            },
            wantErr: false,
        },
        // ... more test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            db := testutil.SetupTestDB(t)
            defer testutil.TeardownTestDB(t, db)
            repo := repositories.NewProgramRepository(db)

            programID := tt.setup(t, repo)

            // Act
            err := repo.SoftDelete(context.Background(), programID)

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("SoftDelete() error = %v, wantErr %v", err, tt.wantErr)
            }

            if !tt.wantErr {
                // Verify deleted_at is set
                program, _ := repo.GetByIDIncludingDeleted(context.Background(), programID)
                if program.DeletedAt == nil {
                    t.Error("Expected deleted_at to be set")
                }
            }
        })
    }
}
```

**Test Cases for Query Filtering**:

| Test Name | Setup | Query | Expected Result |
|-----------|-------|-------|-----------------|
| `get_by_id_returns_active_only` | Create program | GetByID(id) | Returns program |
| `get_by_id_excludes_deleted` | Create + soft delete | GetByID(id) | Returns nil (not found) |
| `list_excludes_deleted_programs` | 3 programs (1 deleted) | List(ctx, nil, nil, 10, 0) | Returns 2 programs |
| `get_user_programs_excludes_deleted` | User has 2 programs (1 deleted) | GetUserPrograms(userID) | Returns 1 program |

**New Repository Methods Required**:
```go
// SoftDelete marks program as deleted
func (r *ProgramRepository) SoftDelete(ctx context.Context, id uuid.UUID) error

// GetByIDIncludingDeleted retrieves program even if deleted (for admin restore)
func (r *ProgramRepository) GetByIDIncludingDeleted(ctx context.Context, id uuid.UUID) (*models.Program, error)
```

**Modified Methods** (add WHERE clause):
- `GetByID`: Add `WHERE deleted_at IS NULL`
- `List`: Add `WHERE deleted_at IS NULL`
- `GetUserProgramsWithDetails`: Add `WHERE p.deleted_at IS NULL`

### Service Layer Tests

#### File: `backend/internal/services/program_service_test.go`

**Test Structure**:
```go
func TestProgramService_Delete(t *testing.T) {
    // Tests soft delete business logic
}

func TestProgramService_Delete_Authorization(t *testing.T) {
    // Tests authorization rules
}
```

**Test Cases for Delete Method**:

| Test Name | Setup | Action | Expected Result |
|-----------|-------|--------|-----------------|
| `owner_can_soft_delete_own_program` | Program owned by user | Delete(programID, ownerID) | Success, deleted_at set |
| `admin_can_soft_delete_any_program` | Program owned by student | Delete(programID, adminID) | Success (admin privilege) |
| `student_cannot_delete_others_program` | Program owned by admin | Delete(programID, studentID) | Error: authorization failed |
| `non_owner_non_admin_cannot_delete` | Program owned by user1 | Delete(programID, user2ID) | Error: authorization failed |
| `delete_nonexistent_program` | Empty DB | Delete(randomID, adminID) | Error: not found |
| `delete_already_deleted_program` | Deleted program | Delete(programID, ownerID) | Error: not found (or success idempotent) |

**Mock Setup Example**:
```go
func TestProgramService_Delete(t *testing.T) {
    tests := []struct {
        name           string
        programOwner   uuid.UUID
        requestingUser uuid.UUID
        userRole       models.UserRole
        programExists  bool
        wantErr        bool
        errType        string
    }{
        {
            name:           "owner_can_soft_delete",
            programOwner:   uuid.New(),
            requestingUser: uuid.New(), // same as owner
            userRole:       models.RoleStudent,
            programExists:  true,
            wantErr:        false,
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Create mock repository
            mockRepo := &testutil.MockProgramRepository{
                GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
                    if !tt.programExists {
                        return nil, nil
                    }
                    return &models.Program{
                        ID:      id,
                        OwnedBy: &tt.programOwner,
                    }, nil
                },
                SoftDeleteFunc: func(ctx context.Context, id uuid.UUID) error {
                    return nil // Success
                },
            }

            service := services.NewProgramService(mockRepo, nil)

            // Act
            err := service.Delete(ctx, uuid.New(), tt.requestingUser)

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("Delete() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### Handler Layer Tests

#### File: `backend/internal/handlers/programs_test.go`

**Test Structure**:
```go
func TestProgramHandler_DeleteProgram(t *testing.T) {
    // Tests HTTP endpoint behavior
}
```

**Test Cases for DELETE Endpoint**:

| Test Name | Auth Header | User Role | Program Exists | Expected Status | Response Contains |
|-----------|------------|-----------|----------------|-----------------|-------------------|
| `delete_program_success` | Valid token | Admin | Yes | 200 OK | {"message": "Program deleted successfully"} |
| `delete_program_as_owner` | Valid token | Student (owner) | Yes | 200 OK | Success message |
| `delete_program_unauthorized` | Valid token | Student (not owner) | Yes | 403 Forbidden | Authorization error |
| `delete_program_not_found` | Valid token | Admin | No | 404 Not Found | Program not found error |
| `delete_program_invalid_id` | Valid token | Admin | N/A | 400 Bad Request | Invalid program ID |
| `delete_program_no_auth` | None | N/A | N/A | 401 Unauthorized | Authorization required |

**Handler Test Example**:
```go
func TestProgramHandler_DeleteProgram(t *testing.T) {
    tests := []struct {
        name           string
        programID      string
        userID         string
        userRole       string
        mockSetup      func(*testutil.MockProgramService)
        expectedStatus int
        expectedBody   map[string]interface{}
    }{
        {
            name:      "delete_program_success",
            programID: uuid.New().String(),
            userID:    uuid.New().String(),
            userRole:  "admin",
            mockSetup: func(m *testutil.MockProgramService) {
                m.DeleteFunc = func(ctx, id, userID uuid.UUID) error {
                    return nil
                }
            },
            expectedStatus: http.StatusOK,
            expectedBody:   map[string]interface{}{"message": "Program deleted successfully"},
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup mock service
            mockService := &testutil.MockProgramService{}
            tt.mockSetup(mockService)

            // Create handler
            handler := handlers.NewProgramHandler(mockService)

            // Create test request
            req := httptest.NewRequest("DELETE", "/api/v1/programs/"+tt.programID, nil)
            w := httptest.NewRecorder()

            // Setup Gin context with auth
            c, _ := gin.CreateTestContext(w)
            c.Request = req
            c.Set("user_id", tt.userID)
            c.Set("user_role", tt.userRole)
            c.Params = gin.Params{
                {Key: "id", Value: tt.programID},
            }

            // Execute
            handler.DeleteProgram(c)

            // Assert
            assert.Equal(t, tt.expectedStatus, w.Code)

            var response map[string]interface{}
            json.Unmarshal(w.Body.Bytes(), &response)
            assert.Equal(t, tt.expectedBody, response)
        })
    }
}
```

### Model Changes

#### File: `backend/internal/models/program.go`

Add field:
```go
type Program struct {
    // ... existing fields
    DeletedAt    *time.Time             `json:"deleted_at,omitempty" db:"deleted_at"`
}
```

### Implementation Order (Feature 1)

#### Phase 1: Write Tests (All Should Fail) ❌

1. **Day 1 Morning**: Test infrastructure
   - Write `testutil/db.go` (database utilities)
   - Write `testutil/fixtures.go` (test data helpers)
   - Write `testutil/mocks.go` (mock implementations)
   - Run: `go test ./pkg/testutil/...` → All should pass

2. **Day 1 Afternoon**: Repository tests
   - Write `program_repository_test.go`:
     - `TestProgramRepository_SoftDelete` (5 test cases)
     - `TestProgramRepository_GetByID_ExcludesDeleted` (2 test cases)
     - `TestProgramRepository_List_ExcludesDeleted` (3 test cases)
   - Run: `go test ./internal/repositories/...` → Should FAIL (methods don't exist)

3. **Day 2 Morning**: Service tests
   - Write `program_service_test.go`:
     - `TestProgramService_Delete` (6 test cases)
     - `TestProgramService_Delete_Authorization` (4 test cases)
   - Run: `go test ./internal/services/...` → Should FAIL

4. **Day 2 Afternoon**: Handler tests
   - Write `programs_test.go`:
     - `TestProgramHandler_DeleteProgram` (6 test cases)
   - Run: `go test ./internal/handlers/...` → Should FAIL

#### Phase 2: Implement to Pass Tests ✅

5. **Day 3 Morning**: Database migration
   - Create migration files
   - Test migration: `migrate up` and `migrate down`
   - Update model: add `deleted_at` field

6. **Day 3 Afternoon**: Repository implementation
   - Implement `SoftDelete()` method
   - Implement `GetByIDIncludingDeleted()` method
   - Update `GetByID()` to exclude deleted
   - Update `List()` to exclude deleted
   - Update `GetUserProgramsWithDetails()` to exclude deleted
   - Run repository tests: `go test ./internal/repositories/...` → Should PASS ✅

7. **Day 4 Morning**: Service implementation
   - Update `Delete()` method to call `SoftDelete()`
   - Keep authorization logic (already exists)
   - Run service tests: `go test ./internal/services/...` → Should PASS ✅

8. **Day 4 Afternoon**: Handler implementation
   - Handler already exists, minimal changes
   - Ensure proper error response format
   - Run handler tests: `go test ./internal/handlers/...` → Should PASS ✅

#### Phase 3: Refactor and Polish 🔧

9. **Day 5**: Refactoring
   - Extract common test helpers
   - Improve error messages
   - Add logging
   - Code review readiness
   - Run full test suite: `go test ./...` → All PASS ✅

---

## Feature 2: Admin View User Sessions

### User Story
> As an admin, I want to view any user's practice sessions, optionally filtered by program, so I can monitor student progress and provide guidance.

### API Specification

**Endpoint**: `GET /api/v1/admin/users/{user_id}/sessions`

**Query Parameters**:
- `program_id` (optional): Filter by specific program UUID
- `start_date` (optional): Filter from date (YYYY-MM-DD)
- `end_date` (optional): Filter to date (YYYY-MM-DD)
- `limit` (optional, default: 20): Page size
- `offset` (optional, default: 0): Page offset

**Authorization**: Requires admin role

**Response Format** (same as existing `/sessions`):
```json
{
  "sessions": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "program_id": "uuid",
      "program_name": "Program Name",
      "started_at": "2025-11-06T10:00:00Z",
      "completed_at": "2025-11-06T10:45:00Z",
      "total_duration_seconds": 2700,
      "completion_rate": 95.0,
      "notes": "Good session"
    }
  ],
  "limit": 20,
  "offset": 0
}
```

### Repository Layer Tests

#### File: `backend/internal/repositories/session_repository_test.go`

**Test Structure**:
```go
func TestSessionRepository_ListByUserID(t *testing.T) {
    // Tests querying sessions for specific user
}

func TestSessionRepository_ListByUserID_WithFilters(t *testing.T) {
    // Tests filtering by program_id, dates
}
```

**Test Cases for ListByUserID**:

| Test Name | Setup | Filters | Expected Result |
|-----------|-------|---------|-----------------|
| `list_all_sessions_for_user` | User with 5 sessions | None | Returns all 5 sessions |
| `list_sessions_empty_user` | User with 0 sessions | None | Returns empty array |
| `list_sessions_filter_by_program` | User with sessions from 3 programs | program_id=prog1 | Returns only prog1 sessions |
| `list_sessions_filter_by_date_range` | 10 sessions over 2 weeks | start_date, end_date | Returns sessions in range |
| `list_sessions_pagination` | 50 sessions | limit=10, offset=20 | Returns sessions 21-30 |
| `list_sessions_does_not_return_other_users` | 2 users with sessions | user_id=user1 | Only user1's sessions |
| `list_sessions_program_filter_and_date` | Mixed sessions | program_id + start_date | Returns intersected results |

**Implementation Example**:
```go
func TestSessionRepository_ListByUserID(t *testing.T) {
    tests := []struct {
        name          string
        setup         func(t *testing.T, repo *SessionRepository, userID uuid.UUID)
        programFilter *uuid.UUID
        startDate     *time.Time
        endDate       *time.Time
        limit         int
        offset        int
        wantCount     int
    }{
        {
            name: "list_all_sessions_for_user",
            setup: func(t *testing.T, repo *SessionRepository, userID uuid.UUID) {
                programID := uuid.New()
                for i := 0; i < 5; i++ {
                    testutil.CreateTestSession(t, repo, userID, programID)
                }
            },
            limit:     20,
            offset:    0,
            wantCount: 5,
        },
        {
            name: "list_sessions_filter_by_program",
            setup: func(t *testing.T, repo *SessionRepository, userID uuid.UUID) {
                prog1 := uuid.New()
                prog2 := uuid.New()
                testutil.CreateTestSession(t, repo, userID, prog1)
                testutil.CreateTestSession(t, repo, userID, prog1)
                testutil.CreateTestSession(t, repo, userID, prog2)
            },
            programFilter: func() *uuid.UUID { id := uuid.New(); return &id }(),
            limit:         20,
            wantCount:     2,
        },
        // ... more test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            db := testutil.SetupTestDB(t)
            defer testutil.TeardownTestDB(t, db)
            repo := repositories.NewSessionRepository(db)

            userID := uuid.New()
            tt.setup(t, repo, userID)

            // Act
            sessions, err := repo.ListByUserID(
                context.Background(),
                userID,
                tt.programFilter,
                tt.startDate,
                tt.endDate,
                tt.limit,
                tt.offset,
            )

            // Assert
            if err != nil {
                t.Fatalf("ListByUserID() error = %v", err)
            }
            if len(sessions) != tt.wantCount {
                t.Errorf("got %d sessions, want %d", len(sessions), tt.wantCount)
            }
        })
    }
}
```

**New Repository Method Required**:
```go
// ListByUserID returns sessions for a specific user (used by admin endpoint)
// This is similar to existing List() but takes userID as parameter instead of from auth context
func (r *SessionRepository) ListByUserID(
    ctx context.Context,
    userID uuid.UUID,
    programID *uuid.UUID,
    startDate, endDate *time.Time,
    limit, offset int,
) ([]models.PracticeSession, error)
```

**Note**: Existing `List()` method uses authenticated user from context. New method takes `userID` as parameter for admin use.

### Service Layer Tests

#### File: `backend/internal/services/session_service_test.go`

**Test Structure**:
```go
func TestSessionService_ListUserSessions(t *testing.T) {
    // Tests business logic for admin viewing user sessions
}

func TestSessionService_ListUserSessions_Authorization(t *testing.T) {
    // Verify admin-only access
}
```

**Test Cases for ListUserSessions**:

| Test Name | Requesting User Role | Target User Exists | Expected Result |
|-----------|---------------------|-------------------|-----------------|
| `admin_can_view_any_user_sessions` | Admin | Yes | Returns sessions |
| `student_cannot_view_other_sessions` | Student | Yes | Error: authorization failed |
| `admin_view_nonexistent_user` | Admin | No | Returns empty list (not error) |
| `admin_view_with_valid_filters` | Admin | Yes | Returns filtered sessions |
| `student_cannot_bypass_with_own_id` | Student | Self | Error: must use /sessions endpoint |

**Mock Setup Example**:
```go
func TestSessionService_ListUserSessions_Authorization(t *testing.T) {
    tests := []struct {
        name            string
        requestingRole  models.UserRole
        targetUserID    uuid.UUID
        wantErr         bool
        expectedErrType string
    }{
        {
            name:           "admin_can_view",
            requestingRole: models.RoleAdmin,
            targetUserID:   uuid.New(),
            wantErr:        false,
        },
        {
            name:            "student_cannot_view",
            requestingRole:  models.RoleStudent,
            targetUserID:    uuid.New(),
            wantErr:         true,
            expectedErrType: "authorization",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockRepo := &testutil.MockSessionRepository{
                ListByUserIDFunc: func(ctx context.Context, userID uuid.UUID, ...) ([]models.PracticeSession, error) {
                    return []models.PracticeSession{}, nil
                },
            }

            service := services.NewSessionService(mockRepo)

            // Act - pass role in context
            ctx := context.WithValue(context.Background(), "user_role", tt.requestingRole)
            _, err := service.ListUserSessions(ctx, tt.targetUserID, nil, nil, nil, 20, 0)

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("ListUserSessions() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**New Service Method Required**:
```go
// ListUserSessions returns sessions for a specific user (admin only)
func (s *SessionService) ListUserSessions(
    ctx context.Context,
    userID uuid.UUID,
    programID *uuid.UUID,
    startDate, endDate *time.Time,
    limit, offset int,
) ([]models.PracticeSession, error)
```

### Handler Layer Tests

#### File: `backend/internal/handlers/sessions_test.go`

**Test Structure**:
```go
func TestSessionHandler_AdminListUserSessions(t *testing.T) {
    // Tests new admin endpoint
}
```

**Test Cases for Admin Endpoint**:

| Test Name | Auth | User Role | Path Param | Query Params | Expected Status | Expected Body |
|-----------|------|-----------|------------|--------------|-----------------|---------------|
| `admin_list_user_sessions_success` | Valid | Admin | Valid UUID | None | 200 OK | Sessions array |
| `admin_filter_by_program` | Valid | Admin | Valid UUID | program_id | 200 OK | Filtered sessions |
| `admin_filter_by_date_range` | Valid | Admin | Valid UUID | start_date, end_date | 200 OK | Date-filtered |
| `admin_pagination_works` | Valid | Admin | Valid UUID | limit=5, offset=10 | 200 OK | Paginated results |
| `student_cannot_access` | Valid | Student | Valid UUID | None | 403 Forbidden | Authorization error |
| `invalid_user_id` | Valid | Admin | "not-uuid" | None | 400 Bad Request | Invalid user ID |
| `invalid_program_id_filter` | Valid | Admin | Valid UUID | program_id=invalid | 400 Bad Request | Invalid program ID |
| `no_auth_token` | None | N/A | Valid UUID | None | 401 Unauthorized | Auth required |

**Handler Test Example**:
```go
func TestSessionHandler_AdminListUserSessions(t *testing.T) {
    tests := []struct {
        name           string
        userID         string
        queryParams    map[string]string
        authRole       string
        mockSetup      func(*testutil.MockSessionService)
        expectedStatus int
    }{
        {
            name:   "admin_list_user_sessions_success",
            userID: uuid.New().String(),
            authRole: "admin",
            mockSetup: func(m *testutil.MockSessionService) {
                m.ListUserSessionsFunc = func(ctx, uid uuid.UUID, ...) ([]models.PracticeSession, error) {
                    return []models.PracticeSession{
                        {ID: uuid.New(), UserID: uid},
                    }, nil
                }
            },
            expectedStatus: http.StatusOK,
        },
        {
            name:   "student_cannot_access",
            userID: uuid.New().String(),
            authRole: "student",
            mockSetup: func(m *testutil.MockSessionService) {
                m.ListUserSessionsFunc = func(...) ([]models.PracticeSession, error) {
                    return nil, appErrors.NewAuthorizationError("Admin only")
                }
            },
            expectedStatus: http.StatusForbidden,
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup
            mockService := &testutil.MockSessionService{}
            tt.mockSetup(mockService)
            handler := handlers.NewSessionHandler(mockService)

            // Create request
            url := "/api/v1/admin/users/" + tt.userID + "/sessions"
            if len(tt.queryParams) > 0 {
                // Add query parameters
                params := url.Values{}
                for k, v := range tt.queryParams {
                    params.Add(k, v)
                }
                url += "?" + params.Encode()
            }

            req := httptest.NewRequest("GET", url, nil)
            w := httptest.NewRecorder()

            // Setup Gin context
            c, _ := gin.CreateTestContext(w)
            c.Request = req
            c.Set("user_role", tt.authRole)
            c.Params = gin.Params{{Key: "user_id", Value: tt.userID}}

            // Execute
            handler.AdminListUserSessions(c)

            // Assert
            assert.Equal(t, tt.expectedStatus, w.Code)
        })
    }
}
```

**New Handler Method Required**:
```go
// AdminListUserSessions godoc
// @Summary List sessions for any user (admin only)
// @Tags admin, sessions
// @Produce json
// @Param user_id path string true "User ID"
// @Param program_id query string false "Filter by program ID"
// @Param start_date query string false "Start date (YYYY-MM-DD)"
// @Param end_date query string false "End date (YYYY-MM-DD)"
// @Param limit query int false "Limit" default(20)
// @Param offset query int false "Offset" default(0)
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/admin/users/{user_id}/sessions [get]
// @Security BearerAuth
func (h *SessionHandler) AdminListUserSessions(c *gin.Context)
```

### Routing Changes

#### File: `backend/cmd/api/main.go` (or routes file)

Add new admin route:
```go
// Admin routes
admin := api.Group("/admin")
admin.Use(middleware.RequireRole("admin"))
{
    // New route for admin viewing user sessions
    admin.GET("/users/:user_id/sessions", sessionHandler.AdminListUserSessions)
}
```

### Implementation Order (Feature 2)

#### Phase 1: Write Tests (All Should Fail) ❌

1. **Day 6 Morning**: Repository tests
   - Write `session_repository_test.go`:
     - `TestSessionRepository_ListByUserID` (7 test cases)
   - Run: `go test ./internal/repositories/...` → Should FAIL

2. **Day 6 Afternoon**: Service tests
   - Write `session_service_test.go`:
     - `TestSessionService_ListUserSessions` (5 test cases)
     - `TestSessionService_ListUserSessions_Authorization` (3 test cases)
   - Run: `go test ./internal/services/...` → Should FAIL

3. **Day 7 Morning**: Handler tests
   - Write `sessions_test.go`:
     - `TestSessionHandler_AdminListUserSessions` (8 test cases)
   - Run: `go test ./internal/handlers/...` → Should FAIL

#### Phase 2: Implement to Pass Tests ✅

4. **Day 7 Afternoon**: Repository implementation
   - Implement `ListByUserID()` method
   - Reuse existing SQL query logic from `List()`, adapt for admin use
   - Run repository tests → Should PASS ✅

5. **Day 8 Morning**: Service implementation
   - Implement `ListUserSessions()` method
   - Add admin role check
   - Call repository `ListByUserID()`
   - Run service tests → Should PASS ✅

6. **Day 8 Afternoon**: Handler implementation
   - Implement `AdminListUserSessions()` handler
   - Parse query parameters (reuse existing validators)
   - Add route to router
   - Run handler tests → Should PASS ✅

#### Phase 3: Refactor and Polish 🔧

7. **Day 9**: Refactoring
   - Extract common query parameter parsing
   - Consolidate error handling
   - Add comprehensive logging
   - Update API documentation
   - Run full test suite → All PASS ✅

---

## Feature 3: Update User Role

### User Story
> As an admin, I want to promote users to admin or demote them to student, with safeguards to prevent system lockout (cannot demote self, must keep at least one admin).

### API Specification

**Endpoint**: `PUT /api/v1/users/{id}` (enhance existing)

**Request Body** (add `role` field):
```json
{
  "full_name": "John Doe",       // existing, optional
  "email": "john@example.com",   // existing, optional
  "password": "newpassword",     // existing, optional
  "is_active": true,             // existing, optional
  "role": "admin"                // NEW, optional, values: "admin" or "student"
}
```

**Business Rules**:
1. Only admins can change roles
2. Admin cannot change their own role (prevent self-demotion)
3. System must have at least one admin at all times
4. Role must be either "admin" or "student"

**Response**:
```json
{
  "message": "User updated successfully"
}
```

### Repository Layer Tests

#### File: `backend/internal/repositories/user_repository_test.go`

**Test Structure**:
```go
func TestUserRepository_Update(t *testing.T) {
    // Tests updating user including role field
}

func TestUserRepository_CountAdmins(t *testing.T) {
    // Tests counting total admins in system
}
```

**Test Cases for Update (Role Specific)**:

| Test Name | Setup | Update | Expected Result |
|-----------|-------|--------|-----------------|
| `update_user_role_to_admin` | Student user | role=admin | Role changed to admin |
| `update_user_role_to_student` | Admin user (2+ admins exist) | role=student | Role changed to student |
| `update_user_role_invalid` | Any user | role="invalid" | Error: invalid role |
| `update_user_role_unchanged` | Admin user | role=admin | No error, no change |
| `update_multiple_fields_including_role` | Student | role=admin, full_name, email | All fields updated |

**Test Cases for CountAdmins**:

| Test Name | Setup | Expected Count |
|-----------|-------|----------------|
| `count_admins_multiple` | 3 admins, 5 students | 3 |
| `count_admins_single` | 1 admin, 10 students | 1 |
| `count_admins_none` | 0 admins (edge case) | 0 |
| `count_admins_inactive_excluded` | 2 active admins, 1 inactive admin | 2 |

**Implementation Example**:
```go
func TestUserRepository_CountAdmins(t *testing.T) {
    tests := []struct {
        name      string
        setup     func(t *testing.T, repo *UserRepository)
        wantCount int
    }{
        {
            name: "count_admins_multiple",
            setup: func(t *testing.T, repo *UserRepository) {
                testutil.CreateTestAdmin(t, repo) // Active
                testutil.CreateTestAdmin(t, repo) // Active
                testutil.CreateTestAdmin(t, repo) // Active
                testutil.CreateTestStudent(t, repo)
                testutil.CreateTestStudent(t, repo)
            },
            wantCount: 3,
        },
        {
            name: "count_admins_inactive_excluded",
            setup: func(t *testing.T, repo *UserRepository) {
                admin1 := testutil.CreateTestAdmin(t, repo)
                admin1.IsActive = false
                repo.Update(context.Background(), admin1) // Inactive

                testutil.CreateTestAdmin(t, repo) // Active
                testutil.CreateTestAdmin(t, repo) // Active
            },
            wantCount: 2,
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            db := testutil.SetupTestDB(t)
            defer testutil.TeardownTestDB(t, db)
            repo := repositories.NewUserRepository(db)

            tt.setup(t, repo)

            // Act
            count, err := repo.CountAdmins(context.Background())

            // Assert
            if err != nil {
                t.Fatalf("CountAdmins() error = %v", err)
            }
            if count != tt.wantCount {
                t.Errorf("got %d admins, want %d", count, tt.wantCount)
            }
        })
    }
}
```

**New Repository Method Required**:
```go
// CountAdmins returns the number of active admin users
func (r *UserRepository) CountAdmins(ctx context.Context) (int, error)
```

**Modified Method**:
```go
// Update - already exists, but ensure it updates role field
// Current implementation at line 123-136 already updates role
// Verify it's included in the UPDATE query
```

### Service Layer Tests

#### File: `backend/internal/services/user_service_test.go`

**Test Structure**:
```go
func TestUserService_Update_RoleChange(t *testing.T) {
    // Tests role change business logic
}

func TestUserService_Update_RoleChangeValidation(t *testing.T) {
    // Tests business rule enforcement
}
```

**Test Cases for Update (Role Change)**:

| Test Name | Requesting User | Target User | New Role | Current Admins | Expected Result |
|-----------|----------------|-------------|----------|----------------|-----------------|
| `admin_can_promote_student` | Admin | Student | admin | 2 | Success, user promoted |
| `admin_can_demote_another_admin` | Admin1 | Admin2 | student | 3 | Success, Admin2 demoted |
| `admin_cannot_demote_self` | Admin1 | Admin1 (self) | student | 1 | Error: cannot change own role |
| `cannot_demote_last_admin` | Admin1 | Admin2 | student | 2 (Admin2 is last active) | Error: must keep 1 admin |
| `student_cannot_change_roles` | Student | Anyone | admin | N/A | Error: not authorized (handled by handler middleware) |
| `invalid_role_rejected` | Admin | Student | "superuser" | 2 | Error: invalid role |
| `promote_to_admin_when_none_exist` | (System operation) | Student | admin | 0 | Success (emergency case) |

**Mock Setup Example**:
```go
func TestUserService_Update_RoleChangeValidation(t *testing.T) {
    tests := []struct {
        name              string
        requestingUserID  uuid.UUID
        targetUserID      uuid.UUID
        targetCurrentRole models.UserRole
        newRole           *models.UserRole
        adminCount        int
        wantErr           bool
        expectedErrMsg    string
    }{
        {
            name:              "admin_cannot_demote_self",
            requestingUserID:  uuid.New(),
            targetUserID:      uuid.New(), // Same as requesting
            targetCurrentRole: models.RoleAdmin,
            newRole:           &models.RoleStudent,
            adminCount:        2,
            wantErr:           true,
            expectedErrMsg:    "cannot change your own role",
        },
        {
            name:              "cannot_demote_last_admin",
            requestingUserID:  uuid.New(),
            targetUserID:      uuid.New(),
            targetCurrentRole: models.RoleAdmin,
            newRole:           &models.RoleStudent,
            adminCount:        1, // Only one admin
            wantErr:           true,
            expectedErrMsg:    "at least one admin",
        },
        {
            name:              "admin_can_promote_student",
            requestingUserID:  uuid.New(),
            targetUserID:      uuid.New(),
            targetCurrentRole: models.RoleStudent,
            newRole:           &models.RoleAdmin,
            adminCount:        2,
            wantErr:           false,
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup mocks
            mockUserRepo := &testutil.MockUserRepository{
                GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.User, error) {
                    return &models.User{
                        ID:   id,
                        Role: tt.targetCurrentRole,
                    }, nil
                },
                CountAdminsFunc: func(ctx context.Context) (int, error) {
                    return tt.adminCount, nil
                },
                UpdateFunc: func(ctx context.Context, user *models.User) error {
                    return nil
                },
            }

            service := services.NewUserService(mockUserRepo, nil)

            // Act
            err := service.Update(
                context.Background(),
                tt.targetUserID,
                nil, // full_name
                nil, // email
                nil, // password
                nil, // is_active
                tt.newRole, // role (NEW parameter)
                tt.requestingUserID, // (NEW parameter for self-check)
            )

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("Update() error = %v, wantErr %v", err, tt.wantErr)
            }
            if tt.wantErr && !strings.Contains(err.Error(), tt.expectedErrMsg) {
                t.Errorf("Expected error containing '%s', got '%s'", tt.expectedErrMsg, err.Error())
            }
        })
    }
}
```

**Modified Service Method Signature**:
```go
// Update updates a user's details (including role)
// Add two new parameters: role and requestingUserID
func (s *UserService) Update(
    ctx context.Context,
    id uuid.UUID,
    fullName, email *string,
    password *string,
    isActive *bool,
    role *models.UserRole,        // NEW: optional role change
    requestingUserID uuid.UUID,   // NEW: for self-check
) error
```

**Business Logic to Add**:
1. If `role` is not nil (role change requested):
   - Validate role is "admin" or "student"
   - Check if `requestingUserID == id` → Error: "Cannot change your own role"
   - If demoting from admin to student:
     - Count current admins: `repo.CountAdmins(ctx)`
     - If count <= 1 → Error: "Cannot demote last admin"
   - Update user role
2. Update other fields as before

### Handler Layer Tests

#### File: `backend/internal/handlers/users_test.go`

**Test Structure**:
```go
func TestUserHandler_UpdateUser_RoleChange(t *testing.T) {
    // Tests role change via HTTP endpoint
}
```

**Test Cases for PUT /users/{id} (Role Change)**:

| Test Name | Auth | Request Body | Target User | Expected Status | Response Contains |
|-----------|------|--------------|-------------|-----------------|-------------------|
| `update_user_promote_to_admin` | Admin | {"role": "admin"} | Student | 200 OK | Success message |
| `update_user_demote_to_student` | Admin | {"role": "student"} | Admin2 | 200 OK | Success message |
| `update_user_invalid_role` | Admin | {"role": "superadmin"} | Student | 400 Bad Request | Invalid role error |
| `update_user_change_own_role` | Admin1 | {"role": "student"} | Admin1 (self) | 403 Forbidden | Cannot change own role |
| `update_user_demote_last_admin` | Admin1 | {"role": "student"} | Admin2 (last) | 409 Conflict | Must keep one admin |
| `update_user_role_with_other_fields` | Admin | {"role": "admin", "full_name": "New Name"} | Student | 200 OK | Success |
| `student_cannot_update_roles` | Student | {"role": "admin"} | Anyone | 403 Forbidden | Insufficient permissions |

**Handler Test Example**:
```go
func TestUserHandler_UpdateUser_RoleChange(t *testing.T) {
    tests := []struct {
        name           string
        targetUserID   string
        requestBody    map[string]interface{}
        authUserID     string
        authRole       string
        mockSetup      func(*testutil.MockUserService)
        expectedStatus int
        expectedError  string
    }{
        {
            name:         "update_user_promote_to_admin",
            targetUserID: uuid.New().String(),
            requestBody:  map[string]interface{}{"role": "admin"},
            authUserID:   uuid.New().String(),
            authRole:     "admin",
            mockSetup: func(m *testutil.MockUserService) {
                m.UpdateFunc = func(ctx, id uuid.UUID, ...) error {
                    return nil
                }
            },
            expectedStatus: http.StatusOK,
        },
        {
            name:         "update_user_change_own_role",
            targetUserID: "same-as-auth-id",
            requestBody:  map[string]interface{}{"role": "student"},
            authUserID:   "same-as-auth-id",
            authRole:     "admin",
            mockSetup: func(m *testutil.MockUserService) {
                m.UpdateFunc = func(...) error {
                    return appErrors.NewAuthorizationError("Cannot change your own role")
                }
            },
            expectedStatus: http.StatusForbidden,
            expectedError:  "own role",
        },
        // ... more cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup mock
            mockService := &testutil.MockUserService{}
            tt.mockSetup(mockService)
            handler := handlers.NewUserHandler(mockService)

            // Create request
            body, _ := json.Marshal(tt.requestBody)
            req := httptest.NewRequest("PUT", "/api/v1/users/"+tt.targetUserID, bytes.NewReader(body))
            req.Header.Set("Content-Type", "application/json")
            w := httptest.NewRecorder()

            // Setup Gin context
            c, _ := gin.CreateTestContext(w)
            c.Request = req
            c.Set("user_id", tt.authUserID)
            c.Set("user_role", tt.authRole)
            c.Params = gin.Params{{Key: "id", Value: tt.targetUserID}}

            // Execute
            handler.UpdateUser(c)

            // Assert
            assert.Equal(t, tt.expectedStatus, w.Code)
            if tt.expectedError != "" {
                body := w.Body.String()
                assert.Contains(t, body, tt.expectedError)
            }
        })
    }
}
```

**Modified Handler Implementation**:
```go
// UpdateUser handler - enhance to support role change
func (h *UserHandler) UpdateUser(c *gin.Context) {
    // ... existing code ...

    // Parse request
    var req validators.UpdateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
        return
    }

    // Get requesting user ID from auth context
    requestingUserID, err := middleware.GetUserID(c)
    if err != nil {
        respondWithAppError(c, err)
        return
    }

    // Parse role if provided
    var role *models.UserRole
    if req.Role != nil {
        r := models.UserRole(*req.Role)
        role = &r
    }

    // Call service with new parameters
    if err := h.userService.Update(
        c.Request.Context(),
        id,
        req.FullName,
        req.Email,
        req.Password,
        req.IsActive,
        role,              // NEW
        requestingUserID,  // NEW
    ); err != nil {
        respondWithAppError(c, err)
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "message": "User updated successfully",
    })
}
```

### Validator Changes

#### File: `backend/internal/validators/requests.go`

Add `role` field to existing struct:
```go
type UpdateUserRequest struct {
    FullName  *string `json:"full_name,omitempty"`
    Email     *string `json:"email,omitempty" validate:"omitempty,email"`
    Password  *string `json:"password,omitempty" validate:"omitempty,min=8"`
    IsActive  *bool   `json:"is_active,omitempty"`
    Role      *string `json:"role,omitempty" validate:"omitempty,oneof=admin student"` // NEW
}
```

### Implementation Order (Feature 3)

#### Phase 1: Write Tests (All Should Fail) ❌

1. **Day 10 Morning**: Repository tests
   - Write `user_repository_test.go`:
     - `TestUserRepository_Update` (5 test cases for role)
     - `TestUserRepository_CountAdmins` (4 test cases)
   - Run: `go test ./internal/repositories/...` → Should FAIL (CountAdmins doesn't exist)

2. **Day 10 Afternoon**: Service tests
   - Write `user_service_test.go`:
     - `TestUserService_Update_RoleChange` (7 test cases)
     - `TestUserService_Update_RoleChangeValidation` (4 test cases)
   - Run: `go test ./internal/services/...` → Should FAIL

3. **Day 11 Morning**: Handler tests
   - Write `users_test.go`:
     - `TestUserHandler_UpdateUser_RoleChange` (7 test cases)
   - Run: `go test ./internal/handlers/...` → Should FAIL

#### Phase 2: Implement to Pass Tests ✅

4. **Day 11 Afternoon**: Repository implementation
   - Implement `CountAdmins()` method:
     ```sql
     SELECT COUNT(*) FROM users
     WHERE role = 'admin' AND is_active = true
     ```
   - Verify `Update()` includes role field (already exists)
   - Run repository tests → Should PASS ✅

5. **Day 12 Morning**: Service implementation
   - Update `Update()` method signature (add role and requestingUserID params)
   - Add business logic:
     - Self-check validation
     - Last admin protection
     - Role validation
   - Run service tests → Should PASS ✅

6. **Day 12 Afternoon**: Handler implementation
   - Update `UpdateUserRequest` validator (add role field)
   - Modify `UpdateUser()` handler to:
     - Extract requesting user ID from context
     - Parse role from request
     - Pass to service
   - Run handler tests → Should PASS ✅

#### Phase 3: Refactor and Polish 🔧

7. **Day 13**: Refactoring
   - Extract role validation to helper function
   - Improve error messages for clarity
   - Add detailed logging for security auditing
   - Update API documentation
   - Run full test suite → All PASS ✅

---

## Continuous Testing Strategy

### During Development

1. **Run tests after each code change**:
   ```bash
   # Run specific package tests
   go test ./internal/repositories/program_repository_test.go -v

   # Run all tests in package
   go test ./internal/repositories/... -v

   # Run with coverage
   go test ./internal/repositories/... -cover
   ```

2. **Use test watchers** (optional):
   ```bash
   # Install gotestsum
   go install gotest.tools/gotestsum@latest

   # Watch mode
   gotestsum --watch
   ```

3. **Pre-commit checks**:
   ```bash
   # Run all tests
   go test ./... -v

   # Check coverage
   go test ./... -coverprofile=coverage.out
   go tool cover -html=coverage.out
   ```

### Coverage Expectations

**Target Coverage by Layer**:
- Repository: **90%+** (critical data layer)
- Service: **85%+** (business logic)
- Handler: **80%+** (HTTP layer)
- Overall: **85%+**

**Critical Paths (must be 100% covered)**:
- Soft delete logic
- Authorization checks
- Business rule enforcement (last admin, self-demotion)
- Data integrity (sessions preserved after soft delete)

### Test Execution Time Budget

- **Unit tests** (mocked): < 2 seconds total
- **Integration tests** (with DB): < 10 seconds total
- **Full suite**: < 15 seconds

If tests exceed budget, optimize with:
- Parallel test execution: `go test -parallel 4`
- Test database connection pooling
- Fixture caching

---

## Testing Utilities Reference

### Database Utilities (`testutil/db.go`)

```go
// Usage example
func TestMyFeature(t *testing.T) {
    db := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, db)

    repo := repositories.NewProgramRepository(db)

    // Test code here
}
```

### Fixture Utilities (`testutil/fixtures.go`)

```go
// Usage example
func TestSoftDelete(t *testing.T) {
    db := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, db)

    userRepo := repositories.NewUserRepository(db)
    programRepo := repositories.NewProgramRepository(db)

    admin := testutil.CreateTestAdmin(t, userRepo)
    program := testutil.CreateTestProgram(t, programRepo, admin.ID)

    // Test soft delete
    err := programRepo.SoftDelete(context.Background(), program.ID)
    // assertions...
}
```

### Mock Utilities (`testutil/mocks.go`)

```go
// Usage example
func TestProgramService_Delete(t *testing.T) {
    mockRepo := &testutil.MockProgramRepository{
        GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
            return &models.Program{ID: id, OwnedBy: &ownerID}, nil
        },
        SoftDeleteFunc: func(ctx context.Context, id uuid.UUID) error {
            return nil
        },
    }

    service := services.NewProgramService(mockRepo, nil)

    err := service.Delete(ctx, programID, userID)
    // assertions...
}
```

---

## Test Writing Best Practices

### 1. Table-Driven Tests (Follow Existing Pattern)

```go
func TestFeature(t *testing.T) {
    tests := []struct {
        name    string
        input   InputType
        want    OutputType
        wantErr bool
    }{
        {name: "case_1", input: ..., want: ..., wantErr: false},
        {name: "case_2", input: ..., want: ..., wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange, Act, Assert
        })
    }
}
```

### 2. Clear Test Names

Use descriptive snake_case names:
- ✅ `admin_can_soft_delete_any_program`
- ✅ `student_cannot_delete_others_program`
- ❌ `TestDelete1`, `TestDelete2`

### 3. AAA Pattern (Arrange-Act-Assert)

```go
t.Run("test_name", func(t *testing.T) {
    // Arrange - setup test data
    db := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, db)
    repo := repositories.NewProgramRepository(db)
    program := testutil.CreateTestProgram(t, repo, ownerID)

    // Act - execute the code under test
    err := repo.SoftDelete(context.Background(), program.ID)

    // Assert - verify results
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }

    result, _ := repo.GetByIDIncludingDeleted(context.Background(), program.ID)
    if result.DeletedAt == nil {
        t.Error("expected deleted_at to be set")
    }
})
```

### 4. Test Isolation

- Each test should be independent
- Use `t.Cleanup()` for resource cleanup
- Truncate tables between tests or use unique test databases
- Don't rely on test execution order

### 5. Helpful Error Messages

```go
// Bad
if got != want {
    t.Error("failed")
}

// Good
if got != want {
    t.Errorf("GetByID() = %v, want %v", got, want)
}
```

### 6. Test Edge Cases

For every feature, test:
- Happy path (normal operation)
- Error cases (not found, invalid input)
- Edge cases (empty lists, nil values)
- Boundary conditions (last admin, zero sessions)
- Authorization failures (wrong role, not owner)

---

## Dependencies and Tools

### Required Go Packages

```bash
# Testing dependencies
go get github.com/stretchr/testify/assert
go get github.com/stretchr/testify/mock

# Test HTTP server
# (net/http/httptest is built-in)

# Database testing
# (use existing pgx connection pool)
```

### Development Tools

```bash
# Test runner with better output
go install gotest.tools/gotestsum@latest

# Coverage visualization
go test -coverprofile=coverage.out
go tool cover -html=coverage.out

# Test database (Docker)
docker run --name xuangong-test-db \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=xuangong_test \
  -p 5433:5432 \
  -d postgres:15-alpine
```

---

## Summary: Implementation Timeline

### Week 1: Feature 1 (Soft Delete)
- **Mon-Tue**: Test infrastructure + Repository tests
- **Wed**: Service tests
- **Thu**: Handler tests + Migration
- **Fri**: Implementation + Refactoring

### Week 2: Feature 2 (Admin View Sessions)
- **Mon**: Repository tests
- **Tue**: Service + Handler tests
- **Wed**: Implementation
- **Thu**: Integration + Refactoring
- **Fri**: Buffer/Documentation

### Week 3: Feature 3 (Role Management)
- **Mon**: Repository tests (CountAdmins)
- **Tue**: Service tests (business rules)
- **Wed**: Handler tests
- **Thu**: Implementation
- **Fri**: Full system testing + Documentation

### Week 4: Polish & Deployment
- **Mon-Tue**: Integration testing across all features
- **Wed**: Performance testing and optimization
- **Thu**: Documentation and code review
- **Fri**: Deployment preparation

---

## Success Criteria

### Definition of Done

For each feature to be considered complete:

1. ✅ All tests written and passing
2. ✅ Test coverage meets targets (85%+)
3. ✅ Code reviewed and approved
4. ✅ Database migrations tested (up and down)
5. ✅ API documentation updated
6. ✅ Integration tests passing
7. ✅ No breaking changes to existing functionality
8. ✅ Security audit passed (authorization checks)
9. ✅ Performance benchmarks met

### Test Suite Health

- All tests pass on CI/CD
- No flaky tests (non-deterministic failures)
- Test execution time < 15 seconds
- Zero test warnings or skipped tests
- Coverage reports generated automatically

---

## Appendix: Test File Templates

### Repository Test Template

```go
package repositories

import (
    "context"
    "testing"

    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/pkg/testutil"
)

func TestXxxRepository_MethodName(t *testing.T) {
    tests := []struct {
        name    string
        setup   func(t *testing.T, repo *XxxRepository)
        wantErr bool
    }{
        // Test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            db := testutil.SetupTestDB(t)
            defer testutil.TeardownTestDB(t, db)
            repo := NewXxxRepository(db)

            if tt.setup != nil {
                tt.setup(t, repo)
            }

            // Act
            result, err := repo.MethodName(context.Background(), ...)

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
            // More assertions...
        })
    }
}
```

### Service Test Template

```go
package services

import (
    "context"
    "testing"

    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/pkg/testutil"
)

func TestXxxService_MethodName(t *testing.T) {
    tests := []struct {
        name      string
        mockSetup func(*testutil.MockXxxRepository)
        wantErr   bool
    }{
        // Test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            mockRepo := &testutil.MockXxxRepository{}
            tt.mockSetup(mockRepo)

            service := NewXxxService(mockRepo)

            // Act
            result, err := service.MethodName(context.Background(), ...)

            // Assert
            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
            // More assertions...
        })
    }
}
```

### Handler Test Template

```go
package handlers

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/stretchr/testify/assert"
    "github.com/xuangong/backend/pkg/testutil"
)

func TestXxxHandler_MethodName(t *testing.T) {
    tests := []struct {
        name           string
        requestBody    interface{}
        authRole       string
        mockSetup      func(*testutil.MockXxxService)
        expectedStatus int
    }{
        // Test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            mockService := &testutil.MockXxxService{}
            tt.mockSetup(mockService)
            handler := NewXxxHandler(mockService)

            body, _ := json.Marshal(tt.requestBody)
            req := httptest.NewRequest("POST", "/api/v1/endpoint", bytes.NewReader(body))
            w := httptest.NewRecorder()

            c, _ := gin.CreateTestContext(w)
            c.Request = req
            c.Set("user_role", tt.authRole)

            // Act
            handler.MethodName(c)

            // Assert
            assert.Equal(t, tt.expectedStatus, w.Code)
        })
    }
}
```

---

## Notes and Considerations

### Database Testing Strategy

**Decision**: Use real PostgreSQL for repository tests instead of mocks

**Rationale**:
- Catches SQL syntax errors
- Verifies query correctness
- Tests actual database behavior (transactions, constraints)
- More confidence in integration

**Trade-off**: Slightly slower tests, but still fast enough (<10s total)

### Migration Testing

Test migrations separately to ensure:
1. Up migration applies cleanly
2. Down migration rolls back completely
3. Data integrity maintained during migration
4. Indexes created correctly

### Security Testing

For authorization-sensitive features:
- Test every permission boundary
- Verify JWT token validation
- Test role-based access control
- Ensure business rules can't be bypassed

### Error Handling Testing

Test error paths as thoroughly as happy paths:
- Database errors (connection lost, constraint violations)
- Invalid input (malformed UUIDs, missing required fields)
- Business rule violations (last admin, self-demotion)
- Not found scenarios

---

**End of TDD Implementation Plan**

This plan will be executed by the main agent after approval. All code implementation will follow strict TDD red-green-refactor cycles as outlined in each feature's implementation order section.