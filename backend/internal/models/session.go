package models

import (
	"time"

	"github.com/google/uuid"
)

type PracticeSession struct {
	ID                   uuid.UUID              `json:"id" db:"id"`
	UserID               uuid.UUID              `json:"user_id" db:"user_id"`
	ProgramID            uuid.UUID              `json:"program_id" db:"program_id"`
	ProgramName          *string                `json:"program_name,omitempty"`
	StartedAt            time.Time              `json:"started_at" db:"started_at"`
	CompletedAt          *time.Time             `json:"completed_at,omitempty" db:"completed_at"`
	TotalDurationSeconds *int                   `json:"total_duration_seconds,omitempty" db:"total_duration_seconds"`
	CompletionRate       *float64               `json:"completion_rate,omitempty" db:"completion_rate"`
	Notes                *string                `json:"notes,omitempty" db:"notes"`
	DeviceInfo           map[string]interface{} `json:"device_info,omitempty" db:"device_info"`
}

type ExerciseLog struct {
	ID                     uuid.UUID  `json:"id" db:"id"`
	SessionID              uuid.UUID  `json:"session_id" db:"session_id"`
	ExerciseID             *uuid.UUID `json:"exercise_id,omitempty" db:"exercise_id"`
	StartedAt              *time.Time `json:"started_at,omitempty" db:"started_at"`
	CompletedAt            *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	PlannedDurationSeconds *int       `json:"planned_duration_seconds,omitempty" db:"planned_duration_seconds"`
	ActualDurationSeconds  *int       `json:"actual_duration_seconds,omitempty" db:"actual_duration_seconds"`
	RepetitionsPlanned     *int       `json:"repetitions_planned,omitempty" db:"repetitions_planned"`
	RepetitionsCompleted   *int       `json:"repetitions_completed,omitempty" db:"repetitions_completed"`
	Skipped                bool       `json:"skipped" db:"skipped"`
	Notes                  *string    `json:"notes,omitempty" db:"notes"`
}

type SessionWithLogs struct {
	Session      PracticeSession `json:"session"`
	ExerciseLogs []ExerciseLog   `json:"exercise_logs"`
}

type SessionStats struct {
	TotalSessions         int     `json:"total_sessions"`
	CompletedSessions     int     `json:"completed_sessions"`
	TotalDurationMinutes  int     `json:"total_duration_minutes"`
	AverageCompletionRate float64 `json:"average_completion_rate"`
	CurrentStreak         int     `json:"current_streak"`
	LongestStreak         int     `json:"longest_streak"`
}
