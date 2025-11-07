package models

import (
	"time"

	"github.com/google/uuid"
)

// Submission represents a conversation thread for student-instructor feedback
type Submission struct {
	ID        uuid.UUID  `json:"id" db:"id"`
	ProgramID uuid.UUID  `json:"program_id" db:"program_id"`
	UserID    uuid.UUID  `json:"user_id" db:"user_id"` // Student who created it
	Title     string     `json:"title" db:"title"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}

// SubmissionMessage represents an individual message in a submission conversation
type SubmissionMessage struct {
	ID           uuid.UUID `json:"id" db:"id"`
	SubmissionID uuid.UUID `json:"submission_id" db:"submission_id"`
	UserID       uuid.UUID `json:"user_id" db:"user_id"` // Author (student or instructor)
	Content      string    `json:"content" db:"content"`
	YouTubeURL   *string   `json:"youtube_url,omitempty" db:"youtube_url"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// MessageReadStatus tracks which users have read which messages
type MessageReadStatus struct {
	UserID    uuid.UUID `json:"user_id" db:"user_id"`
	MessageID uuid.UUID `json:"message_id" db:"message_id"`
	ReadAt    time.Time `json:"read_at" db:"read_at"`
}

// SubmissionWithMessages includes submission and all its messages
type SubmissionWithMessages struct {
	Submission Submission          `json:"submission"`
	Messages   []SubmissionMessage `json:"messages"`
}

// SubmissionListItem is used for list views with metadata
type SubmissionListItem struct {
	Submission
	ProgramName     string    `json:"program_name" db:"program_name"`
	StudentName     string    `json:"student_name" db:"student_name"`
	StudentEmail    string    `json:"student_email" db:"student_email"`
	MessageCount    int       `json:"message_count" db:"message_count"`
	UnreadCount     int       `json:"unread_count" db:"unread_count"`
	LastMessageAt   time.Time `json:"last_message_at" db:"last_message_at"`
	LastMessageText string    `json:"last_message_text" db:"last_message_text"`
	LastMessageFrom string    `json:"last_message_from" db:"last_message_from"`
}

// MessageWithAuthor includes message with author details
type MessageWithAuthor struct {
	SubmissionMessage
	AuthorName  string   `json:"author_name" db:"author_name"`
	AuthorEmail string   `json:"author_email" db:"author_email"`
	AuthorRole  UserRole `json:"author_role" db:"author_role"`
	IsRead      bool     `json:"is_read" db:"is_read"` // For current user
}

// UnreadCounts holds unread message counts at various levels
type UnreadCounts struct {
	Total        int            `json:"total"`
	ByProgram    map[string]int `json:"by_program"`
	BySubmission map[string]int `json:"by_submission"`
}
