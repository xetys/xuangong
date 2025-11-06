# Admin API Requirements Analysis

**Date**: 2025-11-06
**Status**: Research Complete - Ready for Implementation
**Author**: go-backend-architect agent

## Executive Summary

This document provides a comprehensive analysis of the backend API changes needed to support admin features in the Xuan Gong application. Three main requirements have been analyzed: viewing student sessions, updating user roles, and ensuring program deletion exists.

## Current State Assessment

### Authentication & Authorization
**Status**: ✅ Solid foundation

- JWT-based authentication with role-based access control
- User roles: `admin` and `student` (defined in `models.UserRole`)
- Middleware: `RequireRole(role)` for route protection
- Helper: `IsAdmin(c)` checks if current user is admin
- Context helpers: `GetUserID(c)` and `GetUserRole(c)`

### Existing API Endpoints

#### Sessions (User-scoped)
- `GET /api/v1/sessions` - List current user's sessions
- `GET /api/v1/sessions/:id` - Get session details (ownership verified)
- Authorization: User can only see their own sessions

#### Users (Admin-only)
- `GET /api/v1/users` - List all users
- `GET /api/v1/users/:id` - Get user by ID
- `POST /api/v1/users` - Create user
- `PUT /api/v1/users/:id` - Update user
- `DELETE /api/v1/users/:id` - Delete user
- `GET /api/v1/users/:id/programs` - Get user's programs

#### Programs
- `DELETE /api/v1/programs/:id` - Delete program (exists, authorization check in handler)

## Task 1: Admin Endpoint to View Student Sessions

### Current Situation
**Status**: ❌ Missing

The existing `SessionHandler.ListSessions()` only returns sessions for the authenticated user:
```go
userID, err := middleware.GetUserID(c)  // Gets CURRENT user
sessions, err := h.sessionService.ListSessions(ctx, userID, ...)
```

### Required Changes

#### 1. New Handler Method
**File**: `backend/internal/handlers/sessions.go`

```go
// ListUserSessions godoc
// @Summary List sessions for a specific user (admin only)
// @Tags admin, sessions
// @Produce json
// @Param user_id path string true "User ID"
// @Param program_id query string false "Filter by program ID"
// @Param start_date query string false "Filter by start date (YYYY-MM-DD)"
// @Param end_date query string false "Filter by end date (YYYY-MM-DD)"
// @Param limit query int false "Limit" default(20)
// @Param offset query int false "Offset" default(0)
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/admin/users/{user_id}/sessions [get]
// @Security BearerAuth
func (h *SessionHandler) ListUserSessions(c *gin.Context) {
    // Parse user_id from path parameter
    userID, err := uuid.Parse(c.Param("user_id"))
    if err != nil {
        respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
        return
    }

    // Parse query parameters (same as ListSessions)
    var query validators.ListSessionsQuery
    if err := c.ShouldBindQuery(&query); err != nil {
        respondWithError(c, appErrors.NewBadRequestError("Invalid query parameters"))
        return
    }

    // Set defaults
    if query.Limit == 0 {
        query.Limit = 20
    }

    // Parse optional filters (same logic as ListSessions)
    var programID *uuid.UUID
    if query.ProgramID != nil {
        id, err := uuid.Parse(*query.ProgramID)
        if err != nil {
            respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
            return
        }
        programID = &id
    }

    var startDate, endDate *time.Time
    // ... (same date parsing logic as ListSessions)

    // Call service with specified userID instead of current user
    sessions, err := h.sessionService.ListSessions(
        c.Request.Context(),
        userID,  // <-- Key difference: use path parameter, not current user
        programID,
        startDate,
        endDate,
        query.Limit,
        query.Offset,
    )
    if err != nil {
        respondWithAppError(c, err)
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "sessions": sessions,
        "user_id":  userID,
        "limit":    query.Limit,
        "offset":   query.Offset,
    })
}
```

#### 2. New Route
**File**: `backend/cmd/api/main.go`

Add to the `setupRouter` function, within the `protected` group:

```go
// Admin-only routes
admin := protected.Group("/admin")
admin.Use(middleware.RequireRole("admin"))
{
    // User sessions (admin can view any user's sessions)
    admin.GET("/users/:user_id/sessions", sessionHandler.ListUserSessions)
}
```

#### 3. Service Layer
**Status**: ✅ No changes needed

The existing `SessionService.ListSessions()` already accepts `userID` as a parameter and doesn't enforce ownership checks. It can be reused as-is.

#### 4. Repository Layer
**Status**: ✅ No changes needed

The existing `SessionRepository.List()` already accepts `userID` as a parameter. No changes required.

### Testing Considerations

1. **Authorization**: Verify only admins can access this endpoint
2. **User validation**: Test with invalid user IDs (non-existent, malformed UUID)
3. **Filtering**: Ensure all query parameters work correctly
4. **Empty results**: User with no sessions should return empty array
5. **Pagination**: Verify limit/offset work correctly
6. **Performance**: Consider index on `user_id` column in `practice_sessions` table

### Alternative Approach

**Option**: Add optional `user_id` query parameter to existing endpoint

Instead of a new endpoint, modify existing `ListSessions` to accept optional `user_id` query param:
- If provided and user is admin: return that user's sessions
- If provided and user is not admin: return 403 error
- If not provided: return current user's sessions

**Recommendation**: Use the dedicated admin endpoint (original approach) for:
- **Security**: Clear separation between user and admin actions
- **Clarity**: Explicit intent in URL structure
- **Auditability**: Easier to track admin access to student data
- **RESTful**: Follows resource hierarchy pattern

---

## Task 2: Update User Role Endpoint

### Current Situation
**Status**: ⚠️ Partially exists, role update missing

The `UserHandler.UpdateUser()` endpoint exists at `PUT /api/v1/users/:id`, but it does NOT update the role field:

**File**: `backend/internal/handlers/users.go`
```go
func (h *UserHandler) UpdateUser(c *gin.Context) {
    // ...
    if err := h.userService.Update(
        c.Request.Context(),
        id,
        req.FullName,
        req.Email,
        req.Password,
        req.IsActive,  // ⚠️ No role parameter
    ); err != nil {
        respondWithAppError(c, err)
        return
    }
}
```

**File**: `backend/internal/services/user_service.go`
```go
func (s *UserService) Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool) error {
    // ...
    // ⚠️ Does not update role
}
```

**File**: `backend/internal/repositories/user_repository.go`
```go
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
    query := `
        UPDATE users
        SET email = $1, full_name = $2, role = $3, is_active = $4  // ✅ Role IS in query
        WHERE id = $5
        RETURNING updated_at
    `
    // ⚠️ But service doesn't set it
}
```

### Required Changes

#### 1. Update Request Validator
**File**: `backend/internal/validators/requests.go`

```go
type UpdateUserRequest struct {
    Email    *string `json:"email" validate:"omitempty,email"`
    Password *string `json:"password" validate:"omitempty,min=8"`
    FullName *string `json:"full_name" validate:"omitempty,min=2"`
    IsActive *bool   `json:"is_active"`
    Role     *string `json:"role" validate:"omitempty,oneof=admin student"`  // ✅ ADD THIS
}
```

#### 2. Update Handler
**File**: `backend/internal/handlers/users.go`

```go
func (h *UserHandler) UpdateUser(c *gin.Context) {
    // ... (existing validation)

    if err := h.userService.Update(
        c.Request.Context(),
        id,
        req.FullName,
        req.Email,
        req.Password,
        req.IsActive,
        req.Role,  // ✅ ADD THIS
    ); err != nil {
        respondWithAppError(c, err)
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "message": "User updated successfully",
    })
}
```

#### 3. Update Service
**File**: `backend/internal/services/user_service.go`

```go
// Update updates a user's details
func (s *UserService) Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool, role *string) error {
    user, err := s.userRepo.GetByID(ctx, id)
    if err != nil {
        return appErrors.NewInternalError("Failed to fetch user").WithError(err)
    }
    if user == nil {
        return appErrors.NewNotFoundError("User")
    }

    // Update fields if provided
    if fullName != nil {
        user.FullName = *fullName
    }
    if email != nil {
        // ... (existing email validation)
        user.Email = *email
    }
    if password != nil {
        // ... (existing password hashing)
        user.PasswordHash = passwordHash
    }
    if isActive != nil {
        user.IsActive = *isActive
    }

    // ✅ ADD THIS
    if role != nil {
        userRole := models.UserRole(*role)
        if userRole != models.RoleAdmin && userRole != models.RoleStudent {
            return appErrors.NewBadRequestError("Invalid role. Must be 'admin' or 'student'")
        }
        user.Role = userRole
    }

    if err := s.userRepo.Update(ctx, user); err != nil {
        return appErrors.NewInternalError("Failed to update user").WithError(err)
    }

    return nil
}
```

#### 4. Repository Layer
**Status**: ✅ Already supports role updates

The `UserRepository.Update()` already includes `role` in the UPDATE query. No changes needed.

### Business Rules & Validation

#### Critical Security Constraints

1. **Self-demotion protection**: Admin should not be able to demote themselves
   ```go
   // In service layer
   currentUserID, _ := middleware.GetUserID(c)
   if role != nil && id == currentUserID && *role == "student" {
       return appErrors.NewBadRequestError("You cannot demote yourself from admin")
   }
   ```

2. **Last admin protection**: System must have at least one admin
   ```go
   // Check if this is the last admin
   if role != nil && *role == "student" && user.Role == models.RoleAdmin {
       adminCount, err := s.userRepo.CountAdmins(ctx)
       if err != nil {
           return appErrors.NewInternalError("Failed to verify admin count").WithError(err)
       }
       if adminCount <= 1 {
           return appErrors.NewBadRequestError("Cannot demote the last admin user")
       }
   }
   ```

3. **Role escalation protection**: Already handled by `RequireRole("admin")` middleware

#### Recommended Implementation

Add business rule checks in the service layer:

```go
func (s *UserService) Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool, role *string, currentUserID uuid.UUID) error {
    user, err := s.userRepo.GetByID(ctx, id)
    if err != nil {
        return appErrors.NewInternalError("Failed to fetch user").WithError(err)
    }
    if user == nil {
        return appErrors.NewNotFoundError("User")
    }

    // Role change validation
    if role != nil {
        userRole := models.UserRole(*role)

        // Validate role value
        if userRole != models.RoleAdmin && userRole != models.RoleStudent {
            return appErrors.NewBadRequestError("Invalid role. Must be 'admin' or 'student'")
        }

        // Prevent self-demotion
        if id == currentUserID && userRole == models.RoleStudent && user.Role == models.RoleAdmin {
            return appErrors.NewBadRequestError("You cannot demote yourself from admin")
        }

        // Prevent last admin demotion
        if userRole == models.RoleStudent && user.Role == models.RoleAdmin {
            adminCount, err := s.userRepo.CountAdmins(ctx)
            if err != nil {
                return appErrors.NewInternalError("Failed to verify admin count").WithError(err)
            }
            if adminCount <= 1 {
                return appErrors.NewBadRequestError("Cannot demote the last admin user. System must have at least one admin.")
            }
        }

        user.Role = userRole
    }

    // ... rest of update logic

    if err := s.userRepo.Update(ctx, user); err != nil {
        return appErrors.NewInternalError("Failed to update user").WithError(err)
    }

    return nil
}
```

#### Additional Repository Method Needed

**File**: `backend/internal/repositories/user_repository.go`

```go
// CountAdmins returns the number of admin users
func (r *UserRepository) CountAdmins(ctx context.Context) (int, error) {
    var count int
    query := `SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = true`
    err := r.db.QueryRow(ctx, query).Scan(&count)
    return count, err
}
```

### Testing Considerations

1. **Happy path**: Admin updates student role to admin
2. **Self-demotion**: Admin tries to demote themselves (should fail)
3. **Last admin**: Try to demote the only admin (should fail)
4. **Multiple admins**: Demote one admin when multiple exist (should succeed)
5. **Invalid roles**: Test with invalid role values
6. **Inactive users**: Verify inactive admins don't count toward "last admin"
7. **Concurrent updates**: Two admins trying to demote simultaneously (race condition)

### Alternative Approaches

#### Option A: Dedicated Role Update Endpoint
```
PATCH /api/v1/admin/users/:id/role
Body: { "role": "admin" }
```

**Pros**:
- Explicit action, easier to audit
- Separate authorization logic possible
- Clear intent in API design

**Cons**:
- More endpoints to maintain
- Slightly more complex frontend integration

#### Option B: Use existing endpoint with role field
**Recommendation**: ✅ **Use this approach**

**Pros**:
- Follows RESTful pattern (PUT updates resource)
- Fewer endpoints to maintain
- Consistent with other field updates
- Already admin-protected

**Cons**:
- Must ensure proper validation in service layer

---

## Task 3: Program Delete Endpoint

### Current Situation
**Status**: ✅ Already exists

**Endpoint**: `DELETE /api/v1/programs/:id`
**Handler**: `ProgramHandler.DeleteProgram()` in `backend/internal/handlers/programs.go`

```go
func (h *ProgramHandler) DeleteProgram(c *gin.Context) {
    id, err := uuid.Parse(c.Param("id"))
    if err != nil {
        respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
        return
    }

    // Get user ID for authorization check
    userID, err := middleware.GetUserID(c)
    if err != nil {
        respondWithAppError(c, err)
        return
    }

    if err := h.programService.Delete(c.Request.Context(), id, userID); err != nil {
        respondWithAppError(c, err)
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "message": "Program deleted successfully",
    })
}
```

### Authorization Model

**Current implementation**: Program can be deleted by:
1. Program owner (creator)
2. Admin users

**File**: `backend/internal/services/program_service.go` (inferred from pattern)

The service layer likely checks:
- Is user the program owner?
- OR is user an admin?

### Recommendations

#### 1. Verify Authorization Logic

Ensure `ProgramService.Delete()` implements proper authorization:

```go
func (s *ProgramService) Delete(ctx context.Context, programID, userID uuid.UUID) error {
    program, err := s.programRepo.GetByID(ctx, programID)
    if err != nil {
        return appErrors.NewInternalError("Failed to fetch program").WithError(err)
    }
    if program == nil {
        return appErrors.NewNotFoundError("Program")
    }

    // Authorization check: owner or admin
    user, err := s.userRepo.GetByID(ctx, userID)
    if err != nil {
        return appErrors.NewInternalError("Failed to fetch user").WithError(err)
    }

    if program.OwnedBy != userID && user.Role != models.RoleAdmin {
        return appErrors.NewAuthorizationError("You don't have permission to delete this program")
    }

    // Check if program has active sessions (optional business rule)
    sessionCount, err := s.sessionRepo.CountByProgramID(ctx, programID)
    if err != nil {
        return appErrors.NewInternalError("Failed to check program usage").WithError(err)
    }
    if sessionCount > 0 {
        // Option A: Prevent deletion
        return appErrors.NewBadRequestError("Cannot delete program with existing practice sessions")

        // Option B: Cascade delete (ensure DB foreign keys handle this)
        // Option C: Soft delete (mark as inactive)
    }

    if err := s.programRepo.Delete(ctx, programID); err != nil {
        return appErrors.NewInternalError("Failed to delete program").WithError(err)
    }

    return nil
}
```

#### 2. Cascade Deletion Strategy

**Current database schema consideration**:

Check foreign key constraints in `practice_sessions` table:
```sql
-- If constraint exists:
FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE
-- Then sessions are automatically deleted

-- If no cascade:
FOREIGN KEY (program_id) REFERENCES programs(id)
-- Then need to handle manually
```

**Recommendation**: Review migration files in `backend/migrations/` to verify cascade behavior.

#### 3. Testing Considerations

1. **Owner deletion**: Program owner can delete their program
2. **Admin deletion**: Admin can delete any program
3. **Non-owner deletion**: Student cannot delete another user's program
4. **With sessions**: Behavior when program has active sessions
5. **With assignments**: Verify user_programs table is cleaned up
6. **Non-existent program**: 404 error handling

---

## Database Schema Verification

### Required Table Checks

1. **practice_sessions.user_id index**: Verify index exists for performance
   ```sql
   CREATE INDEX IF NOT EXISTS idx_practice_sessions_user_id ON practice_sessions(user_id);
   ```

2. **users.role index**: Optional, for admin count queries
   ```sql
   CREATE INDEX IF NOT EXISTS idx_users_role ON users(role) WHERE is_active = true;
   ```

3. **Foreign key constraints**: Verify cascade delete behavior
   ```sql
   -- Check in migrations/
   -- practice_sessions.program_id should have cascade delete
   -- OR handle orphaned sessions in service layer
   ```

---

## Implementation Summary

### Task 1: Admin View Student Sessions
**Complexity**: Low
**Estimated effort**: 1-2 hours

**Files to modify**:
1. `backend/internal/handlers/sessions.go` - Add `ListUserSessions()` method
2. `backend/cmd/api/main.go` - Add admin route

**Files to review**: None (reuses existing service/repository)

### Task 2: Update User Role
**Complexity**: Medium
**Estimated effort**: 3-4 hours (including business rule implementation)

**Files to modify**:
1. `backend/internal/validators/requests.go` - Add role field
2. `backend/internal/handlers/users.go` - Pass role to service
3. `backend/internal/services/user_service.go` - Add role update logic + validation
4. `backend/internal/repositories/user_repository.go` - Add `CountAdmins()` method

**Files to review**: None

### Task 3: Program Delete
**Complexity**: Low (verification only)
**Estimated effort**: 1 hour

**Files to review**:
1. `backend/internal/services/program_service.go` - Verify authorization logic
2. `backend/migrations/` - Verify foreign key cascade behavior

**Files to potentially modify**: Service layer if authorization is incomplete

---

## API Documentation Updates

### New Endpoint

```
GET /api/v1/admin/users/{user_id}/sessions
Authorization: Bearer {admin_token}

Query Parameters:
- program_id (optional): UUID - Filter by program
- start_date (optional): string - YYYY-MM-DD format
- end_date (optional): string - YYYY-MM-DD format
- limit (optional): integer - Default 20, max 100
- offset (optional): integer - Default 0

Response 200:
{
  "sessions": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "program_id": "uuid",
      "program_name": "string",
      "started_at": "timestamp",
      "completed_at": "timestamp",
      "total_duration_seconds": 1800,
      "completion_rate": 95.5,
      "notes": "string",
      "device_info": {},
      "exercise_logs": [...]
    }
  ],
  "user_id": "uuid",
  "limit": 20,
  "offset": 0
}

Errors:
- 400: Invalid user_id or query parameters
- 401: Not authenticated
- 403: Not an admin
- 404: User not found (optional check)
```

### Updated Endpoint

```
PUT /api/v1/users/{id}
Authorization: Bearer {admin_token}

Body:
{
  "email": "string (optional)",
  "password": "string (optional, min 8 chars)",
  "full_name": "string (optional, min 2 chars)",
  "is_active": boolean (optional),
  "role": "admin|student (optional)"  // ✅ NEW FIELD
}

Response 200:
{
  "message": "User updated successfully"
}

Errors:
- 400: Invalid request body, cannot demote last admin, cannot demote self
- 401: Not authenticated
- 403: Not an admin
- 404: User not found
- 409: Email already exists
```

---

## Testing Checklist

### Unit Tests

**SessionHandler.ListUserSessions()**
- ✅ Valid user ID with sessions
- ✅ Valid user ID with no sessions
- ✅ Invalid user ID format
- ✅ Non-existent user ID
- ✅ Filter by program_id
- ✅ Filter by date range
- ✅ Pagination (limit/offset)

**UserService.Update() - Role changes**
- ✅ Admin promotes student to admin
- ✅ Admin demotes admin to student (multiple admins exist)
- ✅ Admin tries to demote self (should fail)
- ✅ Last admin demotion (should fail)
- ✅ Invalid role value (should fail)
- ✅ Student tries to change role (caught by middleware)

**ProgramService.Delete()**
- ✅ Owner deletes own program
- ✅ Admin deletes any program
- ✅ Student tries to delete other's program (should fail)
- ✅ Delete non-existent program (should fail)
- ✅ Delete program with sessions (depends on business rule)

### Integration Tests

- ✅ End-to-end admin session viewing flow
- ✅ End-to-end role update flow
- ✅ End-to-end program deletion flow
- ✅ Authorization middleware enforcement
- ✅ Database constraint behavior

### Manual Testing

- ✅ Test in development environment
- ✅ Test with real data scenarios
- ✅ Test concurrent admin operations
- ✅ Verify audit logs (if implemented)

---

## Security Considerations

1. **Authorization**: All admin endpoints protected by `RequireRole("admin")` middleware
2. **Input validation**: All user input validated by request validators
3. **SQL injection**: Using parameterized queries (pgx library)
4. **IDOR (Insecure Direct Object Reference)**: Authorization checks in service layer
5. **Rate limiting**: Existing rate limit middleware applies to all endpoints
6. **Audit logging**: Consider adding audit logs for admin actions (future enhancement)

---

## Performance Considerations

1. **Database indexes**:
   - Verify `practice_sessions(user_id)` index exists
   - Consider composite index on `practice_sessions(user_id, program_id, started_at)`

2. **N+1 queries**:
   - `ListUserSessions` fetches exercise logs in loop - acceptable for MVP
   - Future optimization: Single query with JOIN

3. **Admin count query**:
   - Cached result possible if admins rarely change
   - Current approach (query per role update) acceptable for low frequency

---

## Deployment Considerations

1. **Database migrations**: None required (all columns exist)
2. **Backward compatibility**: All changes are additive (new endpoints, optional fields)
3. **API versioning**: No breaking changes to existing endpoints
4. **Environment variables**: No new config needed
5. **Rollback strategy**: Safe to rollback, no schema changes

---

## Open Questions & Recommendations

### Questions for Clarification

1. **Program deletion with sessions**: What should happen?
   - Option A: Prevent deletion (recommended for data integrity)
   - Option B: Cascade delete (lose practice history)
   - Option C: Soft delete (mark inactive)

2. **Admin audit logging**: Should we track admin actions?
   - Recommended: Yes, for compliance and debugging
   - Implementation: Add audit_log table or use structured logging

3. **User deletion with programs**: Current behavior?
   - Need to verify database constraints
   - Recommendation: Cascade delete or prevent deletion

### Recommendations

1. **Immediate implementation**: Tasks 1 and 2 (Task 3 is verification only)
2. **Business rules**: Implement all suggested validation (self-demotion, last admin)
3. **Testing**: Write comprehensive tests before deploying to production
4. **Documentation**: Update API docs and frontend integration guide
5. **Monitoring**: Add metrics for admin actions (count, success/failure rates)

---

## Implementation Order

1. **Phase 1**: Admin view student sessions (Task 1)
   - Lowest complexity, no business rule concerns
   - Can be deployed independently

2. **Phase 2**: Update user role (Task 2)
   - Implement all validation rules
   - Add repository method for admin count
   - Comprehensive testing required

3. **Phase 3**: Verify program deletion (Task 3)
   - Review existing implementation
   - Add missing checks if needed
   - Document cascade behavior

---

## References

### Key Files

**Handlers**: `backend/internal/handlers/`
- `sessions.go` - Session endpoints
- `users.go` - User management
- `programs.go` - Program management

**Services**: `backend/internal/services/`
- `session_service.go` - Business logic for sessions
- `user_service.go` - Business logic for users
- `program_service.go` - Business logic for programs

**Repositories**: `backend/internal/repositories/`
- `session_repository.go` - Database access for sessions
- `user_repository.go` - Database access for users
- `program_repository.go` - Database access for programs

**Models**: `backend/internal/models/`
- `user.go` - User model, roles
- `session.go` - Session models

**Middleware**: `backend/internal/middleware/`
- `auth.go` - JWT validation, role checking

**Validators**: `backend/internal/validators/`
- `requests.go` - Request validation structs

**Main**: `backend/cmd/api/`
- `main.go` - Routing configuration

---

## Conclusion

All three tasks are well-defined and implementable:

- **Task 1**: New admin endpoint needed, reuses existing service/repository
- **Task 2**: Extend existing endpoint with role field, add business rule validation
- **Task 3**: Already exists, requires verification only

**Estimated total effort**: 5-7 hours for implementation + testing

**Risk level**: Low - All changes are additive, no breaking changes

**Ready for implementation**: Yes, pending clarification on program deletion behavior