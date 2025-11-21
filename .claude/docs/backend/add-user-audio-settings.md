# Backend Implementation Plan: User Audio Settings

**Date**: 2025-11-19
**Status**: ⏳ Ready for Implementation
**Author**: go-backend-architect (Claude Code AI)

---

## Overview

Add per-sound volume controls to user profiles, stored server-side for cross-device sync. Users can set volume levels for countdown beeps, exercise start sound, halfway bell, and finish gong.

---

## Requirements Summary

**Add 4 volume fields to users table**:
- `countdown_volume` - Countdown beeps before exercise (default: 75)
- `start_volume` - Exercise start sound (default: 75)
- `halfway_volume` - Halfway completion bell (default: 25)
- `finish_volume` - Session completion gong (default: 100)

**Constraints**:
- Values: 0, 25, 50, 75, or 100 (enforced via CHECK constraint)
- NOT NULL with sensible defaults
- Extend existing `GET/PUT /api/v1/auth/me` endpoints (no new routes)

---

## Database Migration

### Migration Number: `000006`

Next sequential number after `000005_video_submissions_chat.sql`.

### Migration: `000006_add_user_audio_settings.up.sql`

```sql
-- Add audio volume settings to users table
-- Values are restricted to 0, 25, 50, 75, 100 for UI simplicity

ALTER TABLE users
ADD COLUMN countdown_volume INTEGER NOT NULL DEFAULT 75
    CHECK (countdown_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN start_volume INTEGER NOT NULL DEFAULT 75
    CHECK (start_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN halfway_volume INTEGER NOT NULL DEFAULT 25
    CHECK (halfway_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN finish_volume INTEGER NOT NULL DEFAULT 100
    CHECK (finish_volume IN (0, 25, 50, 75, 100));

-- Add comment for documentation
COMMENT ON COLUMN users.countdown_volume IS 'Volume for countdown beeps (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.start_volume IS 'Volume for exercise start sound (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.halfway_volume IS 'Volume for halfway bell (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.finish_volume IS 'Volume for session completion gong (0, 25, 50, 75, 100)';
```

### Migration: `000006_add_user_audio_settings.down.sql`

```sql
-- Remove audio volume settings from users table

ALTER TABLE users
DROP COLUMN countdown_volume,
DROP COLUMN start_volume,
DROP COLUMN halfway_volume,
DROP COLUMN finish_volume;
```

**Migration Strategy**:
- Use `ALTER TABLE ADD COLUMN` with DEFAULT - efficient on large tables
- CHECK constraints prevent invalid values at database level
- Defaults chosen based on martial arts practice needs:
  - Countdown/start: 75% (clear but not jarring)
  - Halfway: 25% (subtle reminder)
  - Finish: 100% (important completion signal)

---

## Code Changes

### 1. Update User Model

**File**: `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/models/user.go`

**Changes**:

Add fields to `User` struct (after line 24, before `CreatedAt`):

```go
type User struct {
	ID              uuid.UUID `json:"id" db:"id"`
	Email           string    `json:"email" db:"email"`
	PasswordHash    string    `json:"-" db:"password_hash"`
	FullName        string    `json:"full_name" db:"full_name"`
	Role            UserRole  `json:"role" db:"role"`
	IsActive        bool      `json:"is_active" db:"is_active"`
	CountdownVolume int       `json:"countdown_volume" db:"countdown_volume"`
	StartVolume     int       `json:"start_volume" db:"start_volume"`
	HalfwayVolume   int       `json:"halfway_volume" db:"halfway_volume"`
	FinishVolume    int       `json:"finish_volume" db:"finish_volume"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}
```

Also update `UserResponse` struct (after line 33):

```go
type UserResponse struct {
	ID              uuid.UUID `json:"id"`
	Email           string    `json:"email"`
	FullName        string    `json:"full_name"`
	Role            UserRole  `json:"role"`
	IsActive        bool      `json:"is_active"`
	CountdownVolume int       `json:"countdown_volume"`
	StartVolume     int       `json:"start_volume"`
	HalfwayVolume   int       `json:"halfway_volume"`
	FinishVolume    int       `json:"finish_volume"`
	CreatedAt       time.Time `json:"created_at"`
}
```

Update `ToResponse()` method (line 37-46):

```go
func (u *User) ToResponse() *UserResponse {
	return &UserResponse{
		ID:              u.ID,
		Email:           u.Email,
		FullName:        u.FullName,
		Role:            u.Role,
		IsActive:        u.IsActive,
		CountdownVolume: u.CountdownVolume,
		StartVolume:     u.StartVolume,
		HalfwayVolume:   u.HalfwayVolume,
		FinishVolume:    u.FinishVolume,
		CreatedAt:       u.CreatedAt,
	}
}
```

**Rationale**:
- Fields included in JSON response (no `-` tag) for Flutter client
- Database tags match column names exactly
- UserResponse includes audio settings so they're returned in auth endpoints

---

### 2. Update Request Validator

**File**: `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/validators/requests.go`

**Changes**:

Update `UpdateProfileRequest` struct (line 39-42):

```go
type UpdateProfileRequest struct {
	Email           *string `json:"email" validate:"omitempty,email"`
	FullName        *string `json:"full_name" validate:"omitempty,min=2"`
	CountdownVolume *int    `json:"countdown_volume" validate:"omitempty,oneof=0 25 50 75 100"`
	StartVolume     *int    `json:"start_volume" validate:"omitempty,oneof=0 25 50 75 100"`
	HalfwayVolume   *int    `json:"halfway_volume" validate:"omitempty,oneof=0 25 50 75 100"`
	FinishVolume    *int    `json:"finish_volume" validate:"omitempty,oneof=0 25 50 75 100"`
}
```

**Validation Details**:
- `*int` (pointer) makes fields optional - clients can update just one volume
- `omitempty` allows NULL (client doesn't send field if not changing)
- `oneof=0 25 50 75 100` enforces exact values in Go validation layer
- Database CHECK constraint is second line of defense

**Validation Behavior**:
- Request with `{"countdown_volume": 50}` → Valid, updates only countdown
- Request with `{"countdown_volume": 30}` → 400 Bad Request (invalid value)
- Request with `{}` → Valid, no volume fields updated
- Request with `{"email": "new@example.com"}` → Valid, email updated, volumes unchanged

---

### 3. Update UserRepository

**File**: `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/repositories/user_repository.go`

**Changes**:

#### 3a. Update `Create` method (line 22-34)

Add volume fields to INSERT:

```go
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, password_hash, full_name, role, is_active,
		                   countdown_volume, start_volume, halfway_volume, finish_volume)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.Role,
		user.IsActive,
		user.CountdownVolume,
		user.StartVolume,
		user.HalfwayVolume,
		user.FinishVolume,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}
```

**Note**: If volume fields are not set in the User struct before Create(), they'll be 0 (Go default for int). The database DEFAULT will NOT apply because we're explicitly passing values.

**Solution**: Ensure User struct is initialized with defaults when creating users, OR modify to use COALESCE:

```go
// Option A: Let database handle defaults (recommended)
query := `
	INSERT INTO users (email, password_hash, full_name, role, is_active,
	                   countdown_volume, start_volume, halfway_volume, finish_volume)
	VALUES ($1, $2, $3, $4, $5,
	        COALESCE(NULLIF($6, 0), 75),
	        COALESCE(NULLIF($7, 0), 75),
	        COALESCE(NULLIF($8, 0), 25),
	        COALESCE(NULLIF($9, 0), 100))
	RETURNING id, created_at, updated_at
`
```

**Actually, better approach**: Don't include volume fields in Create() at all. Let database defaults apply. Only insert email, password_hash, full_name, role, is_active.

```go
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, password_hash, full_name, role, is_active)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, countdown_volume, start_volume, halfway_volume, finish_volume,
		          created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.Role,
		user.IsActive,
	).Scan(&user.ID, &user.CountdownVolume, &user.StartVolume,
	       &user.HalfwayVolume, &user.FinishVolume, &user.CreatedAt, &user.UpdatedAt)
}
```

**Rationale**: Database defaults are applied, and we read them back into the struct via RETURNING.

#### 3b. Update `GetByID` method (line 36-60)

Add volume fields to SELECT and Scan:

```go
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FullName,
		&user.Role,
		&user.IsActive,
		&user.CountdownVolume,
		&user.StartVolume,
		&user.HalfwayVolume,
		&user.FinishVolume,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}
```

#### 3c. Update `GetByEmail` method (line 62-86)

Same pattern as GetByID:

```go
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		WHERE email = $1
	`
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FullName,
		&user.Role,
		&user.IsActive,
		&user.CountdownVolume,
		&user.StartVolume,
		&user.HalfwayVolume,
		&user.FinishVolume,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}
```

#### 3d. Update `List` method (line 88-121)

Add to SELECT and Scan in loop:

```go
func (r *UserRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]models.User, 0)
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.FullName,
			&user.Role,
			&user.IsActive,
			&user.CountdownVolume,
			&user.StartVolume,
			&user.HalfwayVolume,
			&user.FinishVolume,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}
```

#### 3e. Update `Update` method (line 123-137)

**Important**: This is the critical method for profile updates.

```go
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET email = $1, full_name = $2, role = $3, is_active = $4,
		    countdown_volume = $5, start_volume = $6,
		    halfway_volume = $7, finish_volume = $8
		WHERE id = $9
		RETURNING updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.Email,
		user.FullName,
		user.Role,
		user.IsActive,
		user.CountdownVolume,
		user.StartVolume,
		user.HalfwayVolume,
		user.FinishVolume,
		user.ID,
	).Scan(&user.UpdatedAt)
}
```

**Note**: This always updates all fields. The AuthService layer is responsible for only updating fields that were provided in the request.

---

### 4. Update AuthService

**File**: `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/services/auth_service.go`

**Changes**:

Update `UpdateProfile` method signature and implementation (line 150-183):

```go
func (s *AuthService) UpdateProfile(ctx context.Context, userID uuid.UUID,
	email, fullName *string,
	countdownVolume, startVolume, halfwayVolume, finishVolume *int) error {

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return appErrors.NewNotFoundError("User")
	}

	// Check if email is being changed and if it already exists
	if email != nil && *email != user.Email {
		exists, err := s.userRepo.EmailExists(ctx, *email)
		if err != nil {
			return appErrors.NewInternalError("Failed to check email existence").WithError(err)
		}
		if exists {
			return appErrors.NewConflictError("Email already in use")
		}
	}

	// Update user fields (only if provided)
	if email != nil {
		user.Email = *email
	}
	if fullName != nil {
		user.FullName = *fullName
	}
	if countdownVolume != nil {
		user.CountdownVolume = *countdownVolume
	}
	if startVolume != nil {
		user.StartVolume = *startVolume
	}
	if halfwayVolume != nil {
		user.HalfwayVolume = *halfwayVolume
	}
	if finishVolume != nil {
		user.FinishVolume = *finishVolume
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return appErrors.NewInternalError("Failed to update profile").WithError(err)
	}

	return nil
}
```

**Logic**:
1. Fetch current user state
2. Apply only the fields that were provided (non-nil pointers)
3. Volume validation already happened in handler via validator
4. Repository Update() writes full user struct (including unchanged fields)

**No separate validation needed** because go-playground/validator handles it at handler layer.

---

### 5. Update AuthHandler

**File**: `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/handlers/auth.go`

**Changes**:

Update `GetProfile` method - **NO CHANGES NEEDED**. Line 154-168 already returns `user.ToResponse()` which will now include the audio settings automatically.

Update `UpdateProfile` method (line 179-205):

```go
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	var req validators.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.authService.UpdateProfile(c.Request.Context(), userID,
		req.Email, req.FullName,
		req.CountdownVolume, req.StartVolume, req.HalfwayVolume, req.FinishVolume); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
	})
}
```

**Changes**:
- Pass volume pointers to UpdateProfile (line 197)
- Validator already checked `oneof=0 25 50 75 100` constraint
- Database CHECK constraint is final safety net

---

## Testing Strategy

### 1. Migration Testing

```bash
# In backend directory
make migrate-up    # Should succeed without errors
make migrate-down  # Should cleanly remove columns
make migrate-up    # Should work again
```

**Verify**:
```sql
\d users;
-- Should show 4 new columns with CHECK constraints
-- Should show DEFAULT values

SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name LIKE '%_volume';
```

### 2. Repository Testing

**Test existing users get defaults** (manual test in psql):

```sql
-- Before migration
SELECT id, email, created_at FROM users LIMIT 1;

-- After migration
SELECT id, email, countdown_volume, start_volume, halfway_volume, finish_volume
FROM users LIMIT 1;
-- Should show: 75, 75, 25, 100
```

### 3. API Testing

#### Test 1: Get profile returns audio settings

```bash
curl -X GET http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected Response**:
```json
{
  "id": "...",
  "email": "user@example.com",
  "full_name": "Test User",
  "role": "student",
  "is_active": true,
  "countdown_volume": 75,
  "start_volume": 75,
  "halfway_volume": 25,
  "finish_volume": 100,
  "created_at": "2025-11-19T..."
}
```

#### Test 2: Update single volume

```bash
curl -X PUT http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"countdown_volume": 50}'
```

**Expected**: 200 OK, message: "Profile updated successfully"

**Verify**: GET /api/v1/auth/me should show countdown_volume: 50, others unchanged

#### Test 3: Update multiple volumes

```bash
curl -X PUT http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "countdown_volume": 100,
    "start_volume": 50,
    "halfway_volume": 0,
    "finish_volume": 75
  }'
```

**Expected**: 200 OK, all volumes updated

#### Test 4: Invalid volume value

```bash
curl -X PUT http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"countdown_volume": 30}'
```

**Expected**: 400 Bad Request
```json
{
  "error": "Validation failed",
  "details": "countdown_volume must be one of [0 25 50 75 100]"
}
```

#### Test 5: Update email and volume together

```bash
curl -X PUT http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newemail@example.com",
    "finish_volume": 50
  }'
```

**Expected**: 200 OK, both fields updated

#### Test 6: Boundary values

```bash
# Test 0 (silent)
curl -X PUT ... -d '{"countdown_volume": 0}'
# Expected: 200 OK

# Test 100 (max)
curl -X PUT ... -d '{"finish_volume": 100}'
# Expected: 200 OK

# Test invalid negative
curl -X PUT ... -d '{"countdown_volume": -25}'
# Expected: 400 Bad Request
```

### 4. Backward Compatibility Testing

**Test existing clients** (that don't send volume fields):

```bash
# Old client updating only email
curl -X PUT http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "updated@example.com"}'
```

**Expected**: 200 OK, volumes unchanged (because pointers are nil, service doesn't update them)

### 5. Database Constraint Testing

**Direct SQL injection attempt** (manual test in psql):

```sql
-- Should fail with CHECK constraint violation
UPDATE users SET countdown_volume = 42 WHERE id = 'some-uuid';
-- Expected: ERROR: new row violates check constraint
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All files updated (models, validators, repository, service, handler)
- [ ] Migration files created and tested locally
- [ ] API tested with curl/Postman
- [ ] Existing users verified to have defaults after migration
- [ ] Invalid values rejected by both validator and database
- [ ] Backward compatibility verified (old clients still work)

### Deployment Steps

1. **Run migration** (production database):
   ```bash
   make migrate-up
   ```
   - Adds 4 columns with defaults and CHECK constraints
   - Existing rows get default values (75, 75, 25, 100)
   - No downtime (adding columns is non-blocking in PostgreSQL)

2. **Deploy backend** (new Go binary):
   - Build new Docker image
   - Deploy via Helm (update image tag only)
   - Rolling restart (zero downtime)

3. **Verify in production**:
   ```bash
   # Check user profile includes volumes
   curl https://xuangong-prod.stytex.cloud/api/v1/auth/me -H "Authorization: Bearer TOKEN"
   ```

### Rollback Plan

If issues occur:

1. **Rollback code** (revert to previous Docker image tag)
2. **Rollback migration** (only if necessary):
   ```bash
   make migrate-down
   ```
   - Removes 4 columns
   - Data loss: user volume preferences will be lost
   - Old code will work again

**Recommendation**: Keep migration UP even if rolling back code. The extra columns don't hurt, and user preferences are preserved.

---

## Edge Cases & Considerations

### 1. Null Handling

**Question**: What if client sends `{"countdown_volume": null}`?

**Answer**:
- JSON null → Go pointer is nil
- Validator `omitempty` treats nil as "not provided"
- Service skips updating that field
- Database value unchanged

**Conclusion**: Null is same as not sending the field (safe behavior).

### 2. Zero Volume (Silent)

**Question**: Is 0 (silent) a valid use case?

**Answer**:
- Yes, some practitioners may want silent practice
- 0 is explicitly allowed in validation and CHECK constraint
- UI should clearly indicate "Off" or "Silent" for 0

### 3. Concurrent Updates

**Question**: What if user updates profile from two devices simultaneously?

**Answer**:
- Last write wins (standard REST behavior)
- No locks needed (volume preferences are non-critical)
- PostgreSQL UPDATE is atomic per row
- `updated_at` timestamp reflects last change

**Conclusion**: No special handling needed.

### 4. Migration on Large Tables

**Question**: Will migration lock the users table?

**Answer**:
- `ALTER TABLE ADD COLUMN ... DEFAULT ...` in PostgreSQL 11+ is non-blocking
- Default values are stored in table metadata, not written to existing rows immediately
- Reading existing rows returns default without table rewrite
- No locks held (safe for production)

**Conclusion**: Safe to run on production without downtime.

### 5. API Versioning

**Question**: Should this be a v2 API?

**Answer**:
- No, this is additive (not breaking)
- Old clients ignore new fields in GET response
- Old clients don't send new fields in PUT request
- New clients get new fields automatically
- Follows REST evolution best practices

**Conclusion**: Keep existing `/api/v1/auth/me` endpoints.

---

## Security Considerations

### 1. No Authorization Issues

- Users can only update their own profile (middleware.GetUserID ensures this)
- No privilege escalation possible (changing volumes doesn't affect role/permissions)
- Volumes are user-specific preferences (not sensitive data)

### 2. Input Validation

**Defense in Depth**:
1. **Go validator**: `oneof=0 25 50 75 100` in handler
2. **Database CHECK constraint**: Final enforcement
3. **Type safety**: Go int type prevents string injection

### 3. No SQL Injection Risk

- All values passed via parameterized queries (`$1, $2, ...`)
- pgx driver handles escaping
- Integer type prevents injection

---

## Performance Impact

### Database

- **Column Addition**: O(1) metadata operation (PostgreSQL 11+)
- **Index Impact**: None (no indexes needed on volume columns)
- **Storage**: +16 bytes per user row (4 × 4-byte integers)
- **Query Performance**: Negligible (SELECT already fetches full row)

### API

- **GET /api/v1/auth/me**: +32 bytes JSON per response (4 × 8 bytes for int + field names)
- **PUT /api/v1/auth/me**: Same UPDATE query cost (already updates full row)
- **Network**: Minimal increase (<1% for typical response size)

**Conclusion**: No measurable performance impact.

---

## Documentation Updates Needed

### 1. API Documentation

Update Swagger/OpenAPI annotations in `auth.go`:

```go
// UpdateProfile godoc
// @Summary Update current user profile
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.UpdateProfileRequest true "Profile update details (email, full_name, audio volumes)"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/me [put]
// @Security BearerAuth
```

### 2. Context Files

Update `/Users/dsteiman/Dev/stuff/xuangong/.claude/tasks/context/features.md`:

Add to "User Management" section:
```markdown
- **Audio Settings**: Per-sound volume controls (countdown, start, halfway, finish)
  - Values: 0 (off), 25%, 50%, 75%, 100%
  - Stored in user profile for cross-device sync
  - Defaults: countdown=75, start=75, halfway=25, finish=100
```

### 3. Session Log

Create session file: `/Users/dsteiman/Dev/stuff/xuangong/.claude/tasks/sessions/2025-11-19_user-audio-settings.md`

Document:
- Implementation approach
- Files modified
- Testing results
- Deployment outcome

---

## Files to Modify

Summary of all changes:

1. **New Files** (2):
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/migrations/000006_add_user_audio_settings.up.sql`
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/migrations/000006_add_user_audio_settings.down.sql`

2. **Modified Files** (5):
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/models/user.go`
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/validators/requests.go`
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/repositories/user_repository.go`
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/services/auth_service.go`
   - `/Users/dsteiman/Dev/stuff/xuangong/backend/internal/handlers/auth.go`

---

## Implementation Order

Follow this sequence to avoid compilation errors:

1. **Create migration files** (database changes independent)
2. **Update User model** (foundation for other changes)
3. **Update UpdateProfileRequest validator** (defines API contract)
4. **Update UserRepository** (all 5 methods: Create, GetByID, GetByEmail, List, Update)
5. **Update AuthService** (UpdateProfile method signature and logic)
6. **Update AuthHandler** (UpdateProfile method to pass new params)
7. **Run migration** (`make migrate-up`)
8. **Test locally** (curl commands from testing section)
9. **Verify compilation** (`go build ./cmd/api`)
10. **Deploy to production** (migration → code deployment)

---

## Questions Answered

### 1. Migration Number?
**Answer**: `000006` (next after `000005_video_submissions_chat.sql`)

### 2. Validation Error Format?
**Answer**:
- Invalid values (e.g., 30) → 400 Bad Request
- Error message from go-playground/validator: "countdown_volume must be one of [0 25 50 75 100]"
- Consistent with existing validation error format in codebase

### 3. Backward Compatibility?
**Answer**:
- ✅ Old clients work fine (don't send volume fields → pointers are nil → service doesn't update)
- ✅ New fields in GET response ignored by old clients
- ✅ No breaking changes

### 4. Testing Approach?
**Answer**:
- **Manual API testing** with curl (see Testing Strategy section)
- **No unit tests needed** (straightforward CRUD, low risk)
- **Integration testing** via migration + API calls
- **Rationale**: Volume settings are simple preferences, exhaustive unit tests would be overkill

**Optional**: If you want unit tests, add to:
- `user_repository_test.go` - Test Create/Update/Get with volume fields
- `auth_service_test.go` - Test UpdateProfile with volume combinations

But for this simple additive feature, manual API testing is sufficient.

---

## Risk Assessment

**Overall Risk**: 🟢 LOW

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Migration fails | Low | Medium | Test locally first, rollback plan ready |
| Invalid values stored | Very Low | Low | Dual validation (Go + DB CHECK) |
| Backward compatibility breaks | Very Low | High | Additive design, optional fields |
| Performance degradation | Very Low | Low | +16 bytes per user (negligible) |

### Business Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| User data loss | Very Low | Medium | Migration is additive (no data deleted) |
| Existing users affected | Very Low | Low | Defaults preserve current behavior |
| Cross-device sync fails | Low | Medium | Server-side storage (design intent) |

**Recommendation**: Proceed with implementation. Low risk, high value for users.

---

## Success Criteria

Implementation is successful when:

- ✅ Migration runs without errors
- ✅ Existing users have default volumes (75, 75, 25, 100)
- ✅ `GET /api/v1/auth/me` returns volume fields
- ✅ `PUT /api/v1/auth/me` accepts volume updates
- ✅ Invalid values (e.g., 30) rejected with 400
- ✅ Old clients (not sending volumes) still work
- ✅ Multiple devices sync volume preferences
- ✅ No compilation errors in Go codebase
- ✅ No performance degradation measured

---

## Next Steps (Post-Implementation)

After backend is deployed:

1. **Flutter Integration**:
   - Update User model in `app/lib/models/user.dart`
   - Add volume sliders to settings screen
   - Update audio player to use user preferences
   - Test cross-device sync

2. **UI/UX Design**:
   - Settings screen layout (4 volume sliders)
   - Labels: "Countdown Beeps", "Exercise Start", "Halfway Bell", "Completion Gong"
   - Value labels: "Off", "25%", "50%", "75%", "100%"
   - Preview button to test each sound at selected volume

3. **Documentation**:
   - User guide: How to adjust audio settings
   - Video tutorial: Customizing practice audio

---

## Conclusion

This implementation adds user-configurable audio volume settings to the Xuan Gong backend with minimal risk and high user value. The design:

- ✅ Leverages existing auth endpoints (no new routes)
- ✅ Maintains backward compatibility (additive design)
- ✅ Enforces data integrity (dual validation layers)
- ✅ Supports cross-device sync (server-side storage)
- ✅ Follows existing code patterns (consistent architecture)
- ✅ Requires no downtime (non-blocking migration)

**Recommended**: Proceed with implementation following the order specified above.

---

**Author**: go-backend-architect (Claude Code AI)
**Date**: 2025-11-19
**Implementation Plan Version**: 1.0