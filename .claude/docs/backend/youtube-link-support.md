# Implementation Plan: YouTube Video Link Support for Exercises

**Date**: 2025-11-05
**Status**: Planning
**Complexity**: Low
**Estimated Effort**: 2-3 hours

## Overview

Add support for storing and validating YouTube video links in the exercise `metadata` JSONB field. This will allow instructors to attach reference videos to exercises, helping students understand proper form and technique.

## Context Analysis

### Current State
- **Database**: Exercise table has `metadata JSONB DEFAULT '{}'` field (line 43 in `000001_init_schema.up.sql`)
- **Model**: `models.Exercise` struct has `Metadata map[string]interface{}` field fully wired
- **API Layer**: All CRUD operations already handle metadata field correctly
- **Validation**: `ExerciseRequest` and `UpdateExerciseRequest` accept `Metadata map[string]interface{}`

### Key Observations
1. No database migration needed - JSONB field already exists
2. No model changes needed - metadata field fully functional
3. No repository changes needed - metadata properly persisted
4. Focus is purely on **validation** and **helper utilities**

## Requirements Breakdown

### Functional Requirements
1. Store YouTube URL in metadata as `{"youtube_url": "https://youtube.com/..."}`
2. YouTube URL is **optional** (can be null, empty string, or omitted)
3. Support multiple YouTube URL formats:
   - `https://www.youtube.com/watch?v=VIDEO_ID`
   - `https://youtube.com/watch?v=VIDEO_ID`
   - `https://youtu.be/VIDEO_ID`
   - `https://www.youtube.com/embed/VIDEO_ID`
   - `https://m.youtube.com/watch?v=VIDEO_ID` (mobile)
4. Extract and validate video ID (11 characters, alphanumeric + underscore + hyphen)
5. Return clear validation errors for malformed URLs

### Non-Functional Requirements
1. Validation must not break existing exercises without YouTube links
2. Validation should be reusable across create and update operations
3. Error messages must be specific and actionable
4. Performance: validation should be negligible overhead

## Implementation Plan

### Phase 1: Helper Functions Package

**File**: `/backend/pkg/youtube/validator.go` (NEW)

Create a dedicated package for YouTube URL validation with the following functions:

```go
package youtube

import (
    "fmt"
    "net/url"
    "regexp"
    "strings"
)

// ExtractVideoID extracts YouTube video ID from various URL formats
// Returns video ID and error if URL is invalid
func ExtractVideoID(youtubeURL string) (string, error) {
    // Implementation details below
}

// IsValidVideoID validates a YouTube video ID format
// Video IDs are 11 characters: alphanumeric, underscore, hyphen
func IsValidVideoID(videoID string) bool {
    // Implementation details below
}

// ValidateYouTubeURL validates and normalizes a YouTube URL
// Returns normalized URL or error
func ValidateYouTubeURL(youtubeURL string) (string, error) {
    // Implementation details below
}

// NormalizeURL converts any valid YouTube URL to standard watch format
// Returns: https://www.youtube.com/watch?v=VIDEO_ID
func NormalizeURL(youtubeURL string) (string, error) {
    // Implementation details below
}
```

**Implementation Details**:

1. **ExtractVideoID**:
   - Parse URL using `net/url.Parse()`
   - Handle each format:
     - `youtube.com/watch?v=VIDEO_ID` → query param `v`
     - `youtu.be/VIDEO_ID` → path segment
     - `youtube.com/embed/VIDEO_ID` → path segment after `/embed/`
     - `m.youtube.com/watch?v=VIDEO_ID` → query param `v`
   - Return extracted ID or descriptive error

2. **IsValidVideoID**:
   - Regex: `^[a-zA-Z0-9_-]{11}$`
   - Exactly 11 characters, no more, no less

3. **ValidateYouTubeURL**:
   - Trim whitespace
   - Return nil error if empty (optional field)
   - Check if URL or bare video ID
   - If bare ID, validate format
   - If URL, extract ID and validate
   - Return error with suggestions if invalid

4. **NormalizeURL**:
   - Extract video ID
   - Return standard format: `https://www.youtube.com/watch?v={id}`
   - Useful for consistent storage

**Error Handling Strategy**:
```go
// Specific error types for better user feedback
var (
    ErrInvalidURL      = errors.New("invalid YouTube URL format")
    ErrMissingVideoID  = errors.New("could not extract video ID from URL")
    ErrInvalidVideoID  = errors.New("invalid video ID format (must be 11 characters)")
)
```

**Test Cases** (`validator_test.go`):
```go
func TestExtractVideoID(t *testing.T) {
    tests := []struct {
        name        string
        url         string
        expectedID  string
        expectError bool
    }{
        {"standard watch", "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ", false},
        {"short form", "https://youtu.be/dQw4w9WgXcQ", "dQw4w9WgXcQ", false},
        {"embed", "https://www.youtube.com/embed/dQw4w9WgXcQ", "dQw4w9WgXcQ", false},
        {"mobile", "https://m.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ", false},
        {"with timestamp", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s", "dQw4w9WgXcQ", false},
        {"no protocol", "youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ", false},
        {"invalid domain", "https://notyoutube.com/watch?v=dQw4w9WgXcQ", "", true},
        {"missing video id", "https://www.youtube.com/watch", "", true},
        {"empty string", "", "", true},
        {"malformed url", "not a url at all", "", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}

func TestIsValidVideoID(t *testing.T) {
    tests := []struct {
        name     string
        videoID  string
        expected bool
    }{
        {"valid standard", "dQw4w9WgXcQ", true},
        {"valid with underscore", "dQw4w9_gXcQ", true},
        {"valid with hyphen", "dQw4w9-WgXcQ", true},
        {"too short", "dQw4w9WgXc", false},
        {"too long", "dQw4w9WgXcQQ", false},
        {"invalid chars", "dQw4w9@WgXcQ", false},
        {"empty", "", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

### Phase 2: Validation Layer Enhancement

**File**: `/backend/internal/validators/requests.go` (MODIFY)

Add a custom validation tag for YouTube URLs. Go validator allows custom tags:

```go
// At package level, register custom validator
func init() {
    // This would be called when creating the validator in handlers
    // Register custom validation function
}

// Custom validation function
func validateYouTubeURL(fl validator.FieldLevel) bool {
    youtubeURL := fl.Field().String()

    // Empty is valid (optional field)
    if youtubeURL == "" {
        return true
    }

    // Use our helper package
    _, err := youtube.ValidateYouTubeURL(youtubeURL)
    return err == nil
}
```

However, since metadata is `map[string]interface{}`, we need a different approach.

**Better Approach**: Add validation in service layer rather than using struct tags, since metadata is free-form JSONB.

### Phase 3: Service Layer Validation

**File**: `/backend/internal/services/exercise_service.go` (MODIFY)

Add metadata validation to `Create` and `Update` methods:

**Location**: After existing validation, before repository call

```go
// In Create method, after line 56 (side duration validation)
// In Update method, after line 124 (type validation)

// Add this helper method to ExerciseService:
func (s *ExerciseService) validateMetadata(metadata map[string]interface{}) error {
    if metadata == nil {
        return nil
    }

    // Check for youtube_url field
    if youtubeURLRaw, exists := metadata["youtube_url"]; exists {
        // Handle nil value (explicitly set to null)
        if youtubeURLRaw == nil {
            return nil
        }

        // Must be string
        youtubeURL, ok := youtubeURLRaw.(string)
        if !ok {
            return appErrors.NewBadRequestError("youtube_url must be a string")
        }

        // Empty string is valid
        if youtubeURL == "" {
            return nil
        }

        // Validate URL format
        if _, err := youtube.ValidateYouTubeURL(youtubeURL); err != nil {
            return appErrors.NewBadRequestError(
                fmt.Sprintf("invalid YouTube URL: %s", err.Error()),
            )
        }
    }

    // Future: Add validation for other metadata fields here

    return nil
}
```

**Integration Points**:

1. **In `Create` method** (line 58, before `s.exerciseRepo.Create`):
```go
// Validate metadata
if err := s.validateMetadata(exercise.Metadata); err != nil {
    return err
}

if err := s.exerciseRepo.Create(ctx, exercise); err != nil {
    return appErrors.NewInternalError("Failed to create exercise").WithError(err)
}
```

2. **In `Update` method** (line 126, before `s.exerciseRepo.Update`):
```go
// Validate metadata if provided
if updates.Metadata != nil {
    if err := s.validateMetadata(updates.Metadata); err != nil {
        return err
    }
}

if err := s.exerciseRepo.Update(ctx, updates); err != nil {
    return appErrors.NewInternalError("Failed to update exercise").WithError(err)
}
```

**Why Service Layer?**:
- Keeps business logic centralized
- Easy to test independently
- Doesn't require changes to validator struct tags
- Works naturally with JSONB free-form structure
- Can be reused across different handlers

### Phase 4: Optional Enhancement - Response Transformation

**File**: `/backend/internal/handlers/exercises.go` (OPTIONAL MODIFY)

If you want to provide normalized URLs in responses, add transformation:

```go
// Helper function in handler
func normalizeExerciseMetadata(exercise *models.Exercise) {
    if exercise.Metadata == nil {
        return
    }

    if youtubeURLRaw, exists := exercise.Metadata["youtube_url"]; exists {
        if youtubeURL, ok := youtubeURLRaw.(string); ok && youtubeURL != "" {
            if normalized, err := youtube.NormalizeURL(youtubeURL); err == nil {
                exercise.Metadata["youtube_url"] = normalized
            }
        }
    }
}

// Call before returning responses:
// - After Create (line 105)
// - In ListExercises for each exercise (line 43-51)
// - In GetByID responses (not shown but likely exists)
```

**Trade-offs**:
- **Pro**: Consistent URL format in responses
- **Pro**: Easier for frontend to handle
- **Con**: Modifies user input
- **Con**: Additional processing on every read

**Recommendation**: Skip this for MVP. Let frontend handle normalization if needed.

## File Change Summary

### New Files
1. `/backend/pkg/youtube/validator.go` - Core validation logic
2. `/backend/pkg/youtube/validator_test.go` - Comprehensive test suite

### Modified Files
1. `/backend/internal/services/exercise_service.go` - Add metadata validation
   - New method: `validateMetadata`
   - Modify: `Create` method (add validation call)
   - Modify: `Update` method (add validation call)

### No Changes Required
- Database migrations (metadata field exists)
- Models (metadata field exists)
- Repositories (metadata already persisted)
- Handlers (metadata already accepted in requests)
- Validators (struct-level validation not needed for JSONB)

## Testing Strategy

### Unit Tests

**Package**: `pkg/youtube/validator_test.go`
- Test all URL formats (see test cases in Phase 1)
- Test edge cases: empty, nil, malformed
- Test video ID extraction
- Test video ID validation
- Coverage target: 100%

**Package**: `internal/services/exercise_service_test.go`
- Test metadata validation with valid YouTube URLs
- Test metadata validation with invalid YouTube URLs
- Test metadata validation with empty/nil values
- Test metadata validation with non-string values
- Test that exercises without YouTube URLs still work
- Coverage target: 90%+

### Integration Tests

**Test Scenarios**:
1. Create exercise with valid YouTube URL
2. Create exercise with invalid YouTube URL (expect 400)
3. Create exercise without YouTube URL (expect success)
4. Update exercise to add YouTube URL
5. Update exercise to remove YouTube URL (set to empty)
6. Update exercise with invalid YouTube URL (expect 400)
7. Create/update with malformed metadata (non-string youtube_url)

**Test Data**:
```json
// Valid metadata
{"youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}
{"youtube_url": "https://youtu.be/dQw4w9WgXcQ"}
{"youtube_url": ""} // Empty is valid
{} // No youtube_url is valid

// Invalid metadata
{"youtube_url": "https://notyoutube.com/watch?v=123"}
{"youtube_url": "not a url"}
{"youtube_url": 12345} // Not a string
{"youtube_url": "https://youtube.com/watch"} // Missing video ID
```

### Manual Testing

Use curl or Postman to test endpoints:

```bash
# Create exercise with YouTube link
curl -X POST http://localhost:8080/api/v1/exercises \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "program_id": "uuid-here",
    "name": "Tai Chi Form",
    "description": "24 Yang Style",
    "order_index": 0,
    "exercise_type": "timed",
    "duration_seconds": 300,
    "rest_after_seconds": 60,
    "metadata": {
      "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    }
  }'

# Test with invalid URL (should return 400)
curl -X POST http://localhost:8080/api/v1/exercises \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "program_id": "uuid-here",
    "name": "Tai Chi Form",
    "metadata": {
      "youtube_url": "not a valid url"
    }
  }'
```

## Error Handling

### Error Scenarios

1. **Invalid URL format**:
   - Response: `400 Bad Request`
   - Body: `{"error": "invalid YouTube URL: invalid URL format"}`

2. **Missing video ID**:
   - Response: `400 Bad Request`
   - Body: `{"error": "invalid YouTube URL: could not extract video ID from URL"}`

3. **Wrong domain**:
   - Response: `400 Bad Request`
   - Body: `{"error": "invalid YouTube URL: URL must be from youtube.com or youtu.be"}`

4. **Non-string value**:
   - Response: `400 Bad Request`
   - Body: `{"error": "youtube_url must be a string"}`

### Error Response Format

Consistent with existing error handling in `pkg/errors/errors.go`:
```json
{
  "error": "Descriptive error message",
  "code": "VALIDATION_ERROR"
}
```

## Security Considerations

### Input Validation
- Whitelist only youtube.com and youtu.be domains
- Reject URLs with unusual protocols (only http/https)
- Limit URL length (reasonable max: 2048 characters)
- Sanitize for SQL injection (PostgreSQL JSONB handles this)

### Injection Attacks
- JSONB field prevents SQL injection
- URL validation prevents JavaScript injection
- No XSS risk (backend only stores, doesn't render)

### Rate Limiting
- Existing rate limiting in middleware applies
- No special considerations needed

## Performance Considerations

### Validation Performance
- URL parsing: O(1), very fast
- Regex matching: O(n) where n = video ID length (11 chars)
- Negligible overhead: < 1ms per request

### Database Performance
- JSONB indexing: No additional indexes needed for MVP
- Future optimization: Add GIN index on metadata field if querying by youtube_url becomes common
  ```sql
  CREATE INDEX idx_exercises_metadata ON exercises USING GIN (metadata);
  ```

### Caching
- Not needed for MVP (validation is fast)
- Consider caching parsed video IDs if validation becomes bottleneck (unlikely)

## Migration Strategy

### Rollout Plan
1. Deploy helper package (no user impact)
2. Deploy service layer validation
3. Monitor error logs for validation failures
4. Document in API docs

### Backward Compatibility
- Existing exercises without YouTube URLs: Unaffected
- Existing exercises with invalid URLs: Will fail on update (acceptable)
- Frontend changes: Not required (optional field)

### Rollback Plan
If validation causes issues:
1. Remove validation call from service layer
2. Deploy immediately
3. Investigate and fix
4. Redeploy with fix

No database changes means rollback is simple.

## Future Enhancements

### Phase 2 Features (Future)
1. **Video ID Extraction API**: Endpoint to validate URL before submission
2. **Thumbnail Fetching**: Auto-fetch YouTube thumbnail URL
3. **Metadata Validation Framework**: Extensible validation for other metadata fields
4. **YouTube API Integration**: Validate video exists and is accessible
5. **Embed URL Generation**: Auto-generate embed URL for frontend
6. **Playlist Support**: Support YouTube playlist URLs
7. **Multi-video Support**: Array of YouTube URLs per exercise

### Potential Metadata Extensions
```json
{
  "youtube_url": "https://youtube.com/watch?v=...",
  "youtube_thumbnail": "https://i.ytimg.com/vi/.../hqdefault.jpg",
  "video_start_time": 42,  // seconds
  "video_duration": 180,    // seconds
  "difficulty_level": "beginner",
  "equipment_needed": ["mat", "sword"],
  "reference_links": [
    "https://example.com/article1",
    "https://example.com/article2"
  ]
}
```

## API Documentation Updates

### Update OpenAPI/Swagger Docs

Add to exercise schema:
```yaml
Exercise:
  properties:
    # ... existing fields ...
    metadata:
      type: object
      properties:
        youtube_url:
          type: string
          format: uri
          example: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
          description: "Optional YouTube video URL demonstrating the exercise"
      additionalProperties: true
```

### Example Request/Response

**Create Exercise with YouTube Link**:
```json
POST /api/v1/exercises
{
  "program_id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "24 Yang Style Tai Chi Form",
  "description": "Complete form demonstration",
  "order_index": 0,
  "exercise_type": "timed",
  "duration_seconds": 600,
  "rest_after_seconds": 120,
  "has_sides": false,
  "metadata": {
    "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "instructor_notes": "Focus on breathing"
  }
}
```

**Response**:
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174001",
  "program_id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "24 Yang Style Tai Chi Form",
  "description": "Complete form demonstration",
  "order_index": 0,
  "exercise_type": "timed",
  "duration_seconds": 600,
  "repetitions": null,
  "rest_after_seconds": 120,
  "has_sides": false,
  "side_duration_seconds": null,
  "metadata": {
    "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "instructor_notes": "Focus on breathing"
  },
  "created_at": "2025-11-05T10:30:00Z"
}
```

## Implementation Checklist

### Phase 1: Helper Package
- [ ] Create `/backend/pkg/youtube/` directory
- [ ] Implement `validator.go` with all functions
- [ ] Write comprehensive unit tests
- [ ] Test with table-driven tests
- [ ] Verify 100% code coverage

### Phase 2: Service Layer Validation
- [ ] Add `validateMetadata` method to ExerciseService
- [ ] Integrate validation in `Create` method
- [ ] Integrate validation in `Update` method
- [ ] Write service-level unit tests
- [ ] Test with mock repository

### Phase 3: Integration Testing
- [ ] Write integration tests for all scenarios
- [ ] Test with real database
- [ ] Verify error messages are clear
- [ ] Test backward compatibility

### Phase 4: Documentation
- [ ] Update API documentation
- [ ] Add code comments
- [ ] Update CHANGELOG
- [ ] Create migration guide (if needed)

### Phase 5: Deployment
- [ ] Code review
- [ ] Run full test suite
- [ ] Deploy to staging
- [ ] Manual testing on staging
- [ ] Deploy to production
- [ ] Monitor error logs

## Time Estimates

- **Helper Package**: 1 hour (implementation + tests)
- **Service Validation**: 30 minutes (integration + tests)
- **Integration Tests**: 30 minutes
- **Documentation**: 30 minutes
- **Testing & Review**: 30 minutes

**Total**: 2.5-3 hours

## Dependencies

### Go Packages Required
- `net/url` (standard library)
- `regexp` (standard library)
- `strings` (standard library)
- `fmt` (standard library)
- `errors` (standard library)

No external dependencies needed.

## Risk Assessment

### Low Risk
- No database changes
- No breaking changes to API
- Optional field (doesn't affect existing functionality)
- Easy to rollback (remove validation call)

### Potential Issues
1. **False positives**: URL validation too strict
   - Mitigation: Comprehensive test suite
   - Mitigation: Clear error messages

2. **False negatives**: URL validation too lenient
   - Mitigation: Whitelist known YouTube domains
   - Mitigation: Strict video ID format check

3. **Frontend incompatibility**: Frontend sends unexpected formats
   - Mitigation: Thorough integration testing
   - Mitigation: Clear API documentation

## Success Criteria

1. Exercises can be created with valid YouTube URLs
2. Invalid YouTube URLs are rejected with clear errors
3. Existing exercises without YouTube URLs continue to work
4. All tests pass with >90% coverage
5. No performance degradation
6. Clear error messages for users
7. API documentation updated

## Conclusion

This implementation adds YouTube URL support to exercises with minimal risk and clear benefits:

- **Simple**: Leverages existing metadata field
- **Safe**: No database migrations required
- **Testable**: Clear separation of concerns
- **Extensible**: Easy to add more metadata validations
- **Maintainable**: Well-documented and tested

The phased approach allows for incremental development and testing, with easy rollback if issues arise.

---

**Next Steps**: Proceed with implementation starting with Phase 1 (Helper Package), then move through phases sequentially, ensuring each phase is tested before proceeding to the next.
