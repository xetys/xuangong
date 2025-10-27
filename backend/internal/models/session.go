package models

import (
	"time"

	"github.com/google/uuid"
)

type PracticeSession struct {
	ID                   uuid.UUID              `json:"id" db:"id"`
	UserID               uuid.UUID              `json:"user_id" db:"user_id"`
	ProgramID            uuid.UUID              `json:"program_id" db:"program_id"`
	StartedAt            time.Time              `json:"started_at" db:"started_at"`
	CompletedAt          *time.Time             `json:"completed_at" db:"completed_at"`
	TotalDurationSeconds *int                   `json:"total_duration_seconds" db:"total_duration_seconds"`
	CompletionRate       *float64               `json:"completion_rate" db:"completion_rate"`
	Notes                string                 `json:"notes" db:"notes"`
	DeviceInfo           map[string]interface{} `json:"device_info" db:"device_info"`
}

type ExerciseLog struct {
	ID                     uuid.UUID  `json:"id" db:"id"`
	SessionID              uuid.UUID  `json:"session_id" db:"session_id"`
	ExerciseID             *uuid.UUID `json:"exercise_id" db:"exercise_id"`
	StartedAt              *time.Time `json:"started_at" db:"started_at"`
	CompletedAt            *time.Time `json:"completed_at" db:"completed_at"`
	PlannedDurationSeconds *int       `json:"planned_duration_seconds" db:"planned_duration_seconds"`
	ActualDurationSeconds  *int       `json:"actual_duration_seconds" db:"actual_duration_seconds"`
	RepetitionsPlanned     *int       `json:"repetitions_planned" db:"repetitions_planned"`
	RepetitionsCompleted   *int       `json:"repetitions_completed" db:"repetitions_completed"`
	Skipped                bool       `json:"skipped" db:"skipped"`
	Notes                  string     `json:"notes" db:"notes"`
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
