package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

// Sentinel errors for better error handling
var (
	ErrAccessDenied       = errors.New("access denied")
	ErrSubmissionNotFound = errors.New("submission not found")
	ErrMessageNotFound    = errors.New("message not found")
	ErrAlreadyDeleted     = errors.New("submission not found or already deleted")
)

type SubmissionRepository struct {
	db *pgxpool.Pool
}

func NewSubmissionRepository(db *pgxpool.Pool) *SubmissionRepository {
	return &SubmissionRepository{db: db}
}

// Create creates a new submission
func (r *SubmissionRepository) Create(ctx context.Context, programID, userID uuid.UUID, title string) (*models.Submission, error) {
	query := `
		INSERT INTO submissions (id, program_id, user_id, title, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, program_id, user_id, title, created_at, updated_at, deleted_at
	`

	submission := &models.Submission{
		ID:        uuid.New(),
		ProgramID: programID,
		UserID:    userID,
		Title:     title,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	err := r.db.QueryRow(ctx, query,
		submission.ID,
		submission.ProgramID,
		submission.UserID,
		submission.Title,
		submission.CreatedAt,
		submission.UpdatedAt,
	).Scan(
		&submission.ID,
		&submission.ProgramID,
		&submission.UserID,
		&submission.Title,
		&submission.CreatedAt,
		&submission.UpdatedAt,
		&submission.DeletedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create submission: %w", err)
	}

	return submission, nil
}

// GetByID retrieves a submission by ID with access control
func (r *SubmissionRepository) GetByID(ctx context.Context, id, userID uuid.UUID, isAdmin bool) (*models.Submission, error) {
	query := `
		SELECT id, program_id, user_id, title, created_at, updated_at, deleted_at
		FROM submissions
		WHERE id = $1 AND deleted_at IS NULL
	`

	var submission models.Submission
	err := r.db.QueryRow(ctx, query, id).Scan(
		&submission.ID,
		&submission.ProgramID,
		&submission.UserID,
		&submission.Title,
		&submission.CreatedAt,
		&submission.UpdatedAt,
		&submission.DeletedAt,
	)

	if err == pgx.ErrNoRows {
		return nil, ErrSubmissionNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get submission: %w", err)
	}

	// Access control: students can only see their own submissions
	if !isAdmin && submission.UserID != userID {
		return nil, ErrAccessDenied
	}

	return &submission, nil
}

// List retrieves submissions with filters and access control
func (r *SubmissionRepository) List(ctx context.Context, programID *uuid.UUID, userID uuid.UUID, isAdmin bool, limit, offset int) ([]models.SubmissionListItem, error) {
	// Optimized query using LATERAL join instead of subqueries for better performance
	query := `
		SELECT
			s.id, s.program_id, s.user_id, s.title, s.created_at, s.updated_at, s.deleted_at,
			p.name as program_name,
			u.full_name as student_name,
			u.email as student_email,
			COUNT(DISTINCT sm.id) as message_count,
			COUNT(DISTINCT CASE WHEN mrs.user_id IS NULL AND sm.user_id != $1 THEN sm.id END) as unread_count,
			COALESCE(MAX(sm.created_at), s.created_at) as last_message_at,
			COALESCE(lm.content, '') as last_message_text,
			COALESCE(lm.author_name, u.full_name) as last_message_from
		FROM submissions s
		JOIN programs p ON s.program_id = p.id
		JOIN users u ON s.user_id = u.id
		LEFT JOIN submission_messages sm ON s.id = sm.submission_id
		LEFT JOIN message_read_status mrs ON sm.id = mrs.message_id AND mrs.user_id = $1
		LEFT JOIN LATERAL (
			SELECT sm2.content, u2.full_name as author_name
			FROM submission_messages sm2
			JOIN users u2 ON sm2.user_id = u2.id
			WHERE sm2.submission_id = s.id
			ORDER BY sm2.created_at DESC
			LIMIT 1
		) lm ON true
		WHERE s.deleted_at IS NULL
			AND ($2::uuid IS NULL OR s.program_id = $2)
			AND ($3 = true OR s.user_id = $1)
		GROUP BY s.id, p.name, u.full_name, u.email, lm.content, lm.author_name
		ORDER BY last_message_at DESC
		LIMIT $4 OFFSET $5
	`

	rows, err := r.db.Query(ctx, query, userID, programID, isAdmin, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list submissions: %w", err)
	}
	defer rows.Close()

	var submissions []models.SubmissionListItem
	for rows.Next() {
		var item models.SubmissionListItem
		err := rows.Scan(
			&item.ID,
			&item.ProgramID,
			&item.UserID,
			&item.Title,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.DeletedAt,
			&item.ProgramName,
			&item.StudentName,
			&item.StudentEmail,
			&item.MessageCount,
			&item.UnreadCount,
			&item.LastMessageAt,
			&item.LastMessageText,
			&item.LastMessageFrom,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan submission: %w", err)
		}
		submissions = append(submissions, item)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating submissions: %w", err)
	}

	return submissions, nil
}

// CreateMessage adds a message to a submission
func (r *SubmissionRepository) CreateMessage(ctx context.Context, submissionID, userID uuid.UUID, content string, youtubeURL *string) (*models.SubmissionMessage, error) {
	query := `
		INSERT INTO submission_messages (id, submission_id, user_id, content, youtube_url, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, submission_id, user_id, content, youtube_url, created_at
	`

	message := &models.SubmissionMessage{
		ID:           uuid.New(),
		SubmissionID: submissionID,
		UserID:       userID,
		Content:      content,
		YouTubeURL:   youtubeURL,
		CreatedAt:    time.Now(),
	}

	err := r.db.QueryRow(ctx, query,
		message.ID,
		message.SubmissionID,
		message.UserID,
		message.Content,
		message.YouTubeURL,
		message.CreatedAt,
	).Scan(
		&message.ID,
		&message.SubmissionID,
		&message.UserID,
		&message.Content,
		&message.YouTubeURL,
		&message.CreatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create message: %w", err)
	}

	// Update submission's updated_at timestamp
	_, _ = r.db.Exec(ctx, `UPDATE submissions SET updated_at = $1 WHERE id = $2`, time.Now(), submissionID)

	return message, nil
}

// GetMessages retrieves all messages for a submission with access control and read status
func (r *SubmissionRepository) GetMessages(ctx context.Context, submissionID, userID uuid.UUID, isAdmin bool) ([]models.MessageWithAuthor, error) {
	// First check access
	submission, err := r.GetByID(ctx, submissionID, userID, isAdmin)
	if err != nil {
		return nil, err
	}
	if submission == nil {
		return nil, ErrSubmissionNotFound
	}

	query := `
		SELECT
			sm.id, sm.submission_id, sm.user_id, sm.content, sm.youtube_url, sm.created_at,
			u.full_name as author_name,
			u.email as author_email,
			u.role as author_role,
			CASE WHEN mrs.user_id IS NOT NULL THEN true ELSE false END as is_read
		FROM submission_messages sm
		JOIN users u ON sm.user_id = u.id
		LEFT JOIN message_read_status mrs ON sm.id = mrs.message_id AND mrs.user_id = $2
		WHERE sm.submission_id = $1
		ORDER BY sm.created_at ASC
	`

	rows, err := r.db.Query(ctx, query, submissionID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}
	defer rows.Close()

	var messages []models.MessageWithAuthor
	for rows.Next() {
		var msg models.MessageWithAuthor
		err := rows.Scan(
			&msg.ID,
			&msg.SubmissionID,
			&msg.UserID,
			&msg.Content,
			&msg.YouTubeURL,
			&msg.CreatedAt,
			&msg.AuthorName,
			&msg.AuthorEmail,
			&msg.AuthorRole,
			&msg.IsRead,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}
		messages = append(messages, msg)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating messages: %w", err)
	}

	return messages, nil
}

// MarkMessageAsRead marks a message as read by a user
func (r *SubmissionRepository) MarkMessageAsRead(ctx context.Context, userID, messageID uuid.UUID) error {
	// First check if message exists
	var exists bool
	err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM submission_messages WHERE id = $1)`, messageID).Scan(&exists)
	if err != nil {
		return fmt.Errorf("failed to check message existence: %w", err)
	}
	if !exists {
		return ErrMessageNotFound
	}

	query := `
		INSERT INTO message_read_status (user_id, message_id, read_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, message_id) DO NOTHING
	`

	_, err = r.db.Exec(ctx, query, userID, messageID, time.Now())
	if err != nil {
		return fmt.Errorf("failed to mark message as read: %w", err)
	}

	return nil
}

// GetUnreadCount returns unread message counts at various levels
func (r *SubmissionRepository) GetUnreadCount(ctx context.Context, userID uuid.UUID, programID *uuid.UUID) (*models.UnreadCounts, error) {
	query := `
		SELECT
			s.program_id,
			s.id as submission_id,
			COUNT(sm.id) as unread_count
		FROM submissions s
		JOIN submission_messages sm ON s.id = sm.submission_id
		LEFT JOIN message_read_status mrs ON sm.id = mrs.message_id AND mrs.user_id = $1
		WHERE s.deleted_at IS NULL
			AND sm.user_id != $1
			AND mrs.user_id IS NULL
			AND ($2::uuid IS NULL OR s.program_id = $2)
			AND (s.user_id = $1 OR EXISTS(SELECT 1 FROM users WHERE id = $1 AND role = 'admin'))
		GROUP BY s.program_id, s.id
	`

	rows, err := r.db.Query(ctx, query, userID, programID)
	if err != nil {
		return nil, fmt.Errorf("failed to get unread counts: %w", err)
	}
	defer rows.Close()

	counts := &models.UnreadCounts{
		Total:        0,
		ByProgram:    make(map[string]int),
		BySubmission: make(map[string]int),
	}

	for rows.Next() {
		var progID, subID uuid.UUID
		var unreadCount int
		err := rows.Scan(&progID, &subID, &unreadCount)
		if err != nil {
			return nil, fmt.Errorf("failed to scan unread count: %w", err)
		}

		counts.Total += unreadCount
		counts.ByProgram[progID.String()] += unreadCount
		counts.BySubmission[subID.String()] = unreadCount
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating unread counts: %w", err)
	}

	return counts, nil
}

// SoftDelete soft deletes a submission
func (r *SubmissionRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	query := `
		UPDATE submissions
		SET deleted_at = $1
		WHERE id = $2 AND deleted_at IS NULL
	`

	result, err := r.db.Exec(ctx, query, time.Now(), id)
	if err != nil {
		return fmt.Errorf("failed to soft delete submission: %w", err)
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return ErrAlreadyDeleted
	}

	return nil
}
