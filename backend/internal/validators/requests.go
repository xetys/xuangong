package validators

import (
	"github.com/xuangong/backend/internal/models"
)

// Auth requests
type RegisterRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
	FullName string `json:"full_name" validate:"required,min=2"`
}

// User management requests (admin only)
type CreateUserRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
	FullName string `json:"full_name" validate:"required,min=2"`
	Role     string `json:"role" validate:"omitempty,oneof=admin student"`
}

type UpdateUserRequest struct {
	Email    *string `json:"email" validate:"omitempty,email"`
	Password *string `json:"password" validate:"omitempty,min=8"`
	FullName *string `json:"full_name" validate:"omitempty,min=2"`
	IsActive *bool   `json:"is_active"`
}

type LoginRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

// Profile management requests (user self-service)
type UpdateProfileRequest struct {
	Email    *string `json:"email" validate:"omitempty,email"`
	FullName *string `json:"full_name" validate:"omitempty,min=2"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
}

// Program requests
type CreateProgramRequest struct {
	Name               string                 `json:"name" validate:"required,min=3,max=255"`
	Description        string                 `json:"description"`
	IsTemplate         bool                   `json:"is_template"`
	IsPublic           bool                   `json:"is_public"`
	Tags               []string               `json:"tags"`
	Metadata           map[string]interface{} `json:"metadata"`
	RepetitionsPlanned *int                   `json:"repetitions_planned" validate:"omitempty,gte=1"`
	OwnedByUserID      *string                `json:"owned_by_user_id" validate:"omitempty,uuid"` // Admin can specify owner
	Exercises          []ExerciseRequest      `json:"exercises" validate:"dive"`
}

type UpdateProgramRequest struct {
	Name               *string                `json:"name" validate:"omitempty,min=3,max=255"`
	Description        *string                `json:"description"`
	IsTemplate         *bool                  `json:"is_template"`
	IsPublic           *bool                  `json:"is_public"`
	Tags               []string               `json:"tags"`
	Metadata           map[string]interface{} `json:"metadata"`
	RepetitionsPlanned *int                   `json:"repetitions_planned" validate:"omitempty,gte=1"`
	Exercises          []ExerciseRequest      `json:"exercises" validate:"dive"`
}

// ExerciseRequest is used for exercises within program requests
type ExerciseRequest struct {
	ID                  string                 `json:"id" validate:"omitempty,uuid"`
	Name                string                 `json:"name" validate:"required,min=3,max=255"`
	Description         string                 `json:"description"`
	OrderIndex          int                    `json:"order_index" validate:"gte=0"`
	ExerciseType        string                 `json:"exercise_type" validate:"required,oneof=timed repetition combined"`
	DurationSeconds     *int                   `json:"duration_seconds" validate:"omitempty,min=1"`
	Repetitions         *int                   `json:"repetitions" validate:"omitempty,min=1"`
	RestAfterSeconds    int                    `json:"rest_after_seconds" validate:"gte=0"`
	HasSides            bool                   `json:"has_sides"`
	SideDurationSeconds *int                   `json:"side_duration_seconds" validate:"omitempty,min=1"`
	Metadata            map[string]interface{} `json:"metadata"`
}

type AssignProgramRequest struct {
	UserIDs []string `json:"user_ids" validate:"required,min=1"`
}

// Exercise requests
type CreateExerciseRequest struct {
	ProgramID           string                 `json:"program_id" validate:"required,uuid"`
	Name                string                 `json:"name" validate:"required,min=3,max=255"`
	Description         string                 `json:"description"`
	OrderIndex          int                    `json:"order_index" validate:"gte=0"`
	ExerciseType        string                 `json:"exercise_type" validate:"required,oneof=timed repetition combined"`
	DurationSeconds     *int                   `json:"duration_seconds" validate:"omitempty,min=1"`
	Repetitions         *int                   `json:"repetitions" validate:"omitempty,min=1"`
	RestAfterSeconds    int                    `json:"rest_after_seconds" validate:"gte=0"`
	HasSides            bool                   `json:"has_sides"`
	SideDurationSeconds *int                   `json:"side_duration_seconds" validate:"omitempty,min=1"`
	Metadata            map[string]interface{} `json:"metadata"`
}

type UpdateExerciseRequest struct {
	Name                *string                `json:"name" validate:"omitempty,min=3,max=255"`
	Description         *string                `json:"description"`
	OrderIndex          *int                   `json:"order_index" validate:"omitempty,min=0"`
	ExerciseType        *string                `json:"exercise_type" validate:"omitempty,oneof=timed repetition combined"`
	DurationSeconds     *int                   `json:"duration_seconds" validate:"omitempty,min=1"`
	Repetitions         *int                   `json:"repetitions" validate:"omitempty,min=1"`
	RestAfterSeconds    *int                   `json:"rest_after_seconds" validate:"omitempty,min=0"`
	HasSides            *bool                  `json:"has_sides"`
	SideDurationSeconds *int                   `json:"side_duration_seconds" validate:"omitempty,min=1"`
	Metadata            map[string]interface{} `json:"metadata"`
}

type ReorderExercisesRequest struct {
	ExerciseIDs []string `json:"exercise_ids" validate:"required,min=1"`
}

// Session requests
type StartSessionRequest struct {
	ProgramID  string                 `json:"program_id" validate:"required,uuid"`
	DeviceInfo map[string]interface{} `json:"device_info"`
}

type LogExerciseRequest struct {
	PlannedDurationSeconds *int   `json:"planned_duration_seconds" validate:"omitempty,min=0"`
	ActualDurationSeconds  *int   `json:"actual_duration_seconds" validate:"omitempty,min=0"`
	RepetitionsPlanned     *int   `json:"repetitions_planned" validate:"omitempty,min=1"`
	RepetitionsCompleted   *int   `json:"repetitions_completed" validate:"omitempty,min=0"`
	Skipped                bool   `json:"skipped"`
	Notes                  string `json:"notes"`
}

type CompleteSessionRequest struct {
	TotalDurationSeconds *int     `json:"total_duration_seconds" validate:"omitempty,min=0"`
	CompletionRate       *float64 `json:"completion_rate" validate:"omitempty,min=0,max=100"`
	Notes                string   `json:"notes"`
	CompletedAt          *string  `json:"completed_at"`
}

// Submission requests
type CreateSubmissionRequest struct {
	SessionID       string   `json:"session_id" validate:"required,uuid"`
	ExerciseID      *string  `json:"exercise_id" validate:"omitempty,uuid"`
	VideoURL        string   `json:"video_url" validate:"required,url"`
	ThumbnailURL    string   `json:"thumbnail_url" validate:"omitempty,url"`
	DurationSeconds *int     `json:"duration_seconds" validate:"omitempty,min=0"`
	FileSizeMB      *float64 `json:"file_size_mb" validate:"omitempty,min=0"`
}

type CreateFeedbackRequest struct {
	FeedbackText string `json:"feedback_text" validate:"required,min=10"`
	FeedbackType string `json:"feedback_type" validate:"required,oneof=text audio"`
}

// Update settings request
type UpdateProgramSettingsRequest struct {
	CustomSettings map[string]interface{} `json:"custom_settings"`
}

// Query parameters
type ListProgramsQuery struct {
	IsTemplate *bool    `form:"is_template"`
	IsPublic   *bool    `form:"is_public"`
	Tags       []string `form:"tags"`
	Limit      int      `form:"limit" validate:"min=1,max=100"`
	Offset     int      `form:"offset" validate:"min=0"`
}

type ListSessionsQuery struct {
	ProgramID *string `form:"program_id" validate:"omitempty,uuid"`
	StartDate *string `form:"start_date" validate:"omitempty,datetime=2006-01-02"`
	EndDate   *string `form:"end_date" validate:"omitempty,datetime=2006-01-02"`
	Limit     int     `form:"limit" validate:"min=1,max=100"`
	Offset    int     `form:"offset" validate:"min=0"`
}

type ListSubmissionsQuery struct {
	Status *models.SubmissionStatus `form:"status" validate:"omitempty,oneof=pending reviewed archived"`
	UserID *string                  `form:"user_id" validate:"omitempty,uuid"`
	Limit  int                      `form:"limit" validate:"min=1,max=100"`
	Offset int                      `form:"offset" validate:"min=0"`
}
