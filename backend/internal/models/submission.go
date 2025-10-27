package models

import (
	"time"

	"github.com/google/uuid"
)

type SubmissionStatus string

const (
	StatusPending  SubmissionStatus = "pending"
	StatusReviewed SubmissionStatus = "reviewed"
	StatusArchived SubmissionStatus = "archived"
)

type FeedbackType string

const (
	FeedbackTypeText  FeedbackType = "text"
	FeedbackTypeAudio FeedbackType = "audio"
)

type VideoSubmission struct {
	ID              uuid.UUID        `json:"id" db:"id"`
	UserID          uuid.UUID        `json:"user_id" db:"user_id"`
	SessionID       uuid.UUID        `json:"session_id" db:"session_id"`
	ExerciseID      *uuid.UUID       `json:"exercise_id" db:"exercise_id"`
	VideoURL        string           `json:"video_url" db:"video_url"`
	ThumbnailURL    string           `json:"thumbnail_url" db:"thumbnail_url"`
	DurationSeconds *int             `json:"duration_seconds" db:"duration_seconds"`
	FileSizeMB      *float64         `json:"file_size_mb" db:"file_size_mb"`
	Status          SubmissionStatus `json:"status" db:"status"`
	SubmittedAt     time.Time        `json:"submitted_at" db:"submitted_at"`
}

type Feedback struct {
	ID           uuid.UUID    `json:"id" db:"id"`
	SubmissionID uuid.UUID    `json:"submission_id" db:"submission_id"`
	InstructorID *uuid.UUID   `json:"instructor_id" db:"instructor_id"`
	FeedbackText string       `json:"feedback_text" db:"feedback_text"`
	FeedbackType FeedbackType `json:"feedback_type" db:"feedback_type"`
	IsRead       bool         `json:"is_read" db:"is_read"`
	CreatedAt    time.Time    `json:"created_at" db:"created_at"`
}

type SubmissionWithFeedback struct {
	Submission VideoSubmission `json:"submission"`
	Feedback   []Feedback      `json:"feedback"`
}
