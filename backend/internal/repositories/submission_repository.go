package repositories

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

type SubmissionRepository struct {
	db *pgxpool.Pool
}

func NewSubmissionRepository(db *pgxpool.Pool) *SubmissionRepository {
	return &SubmissionRepository{db: db}
}

func (r *SubmissionRepository) Create(ctx context.Context, submission *models.VideoSubmission) error {
	query := `
		INSERT INTO video_submissions (
			user_id, session_id, exercise_id, video_url, thumbnail_url,
			duration_seconds, file_size_mb, status
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, submitted_at
	`
	return r.db.QueryRow(ctx, query,
		submission.UserID,
		submission.SessionID,
		submission.ExerciseID,
		submission.VideoURL,
		submission.ThumbnailURL,
		submission.DurationSeconds,
		submission.FileSizeMB,
		submission.Status,
	).Scan(&submission.ID, &submission.SubmittedAt)
}

func (r *SubmissionRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.VideoSubmission, error) {
	var submission models.VideoSubmission
	query := `
		SELECT id, user_id, session_id, exercise_id, video_url, thumbnail_url,
		       duration_seconds, file_size_mb, status, submitted_at
		FROM video_submissions
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&submission.ID,
		&submission.UserID,
		&submission.SessionID,
		&submission.ExerciseID,
		&submission.VideoURL,
		&submission.ThumbnailURL,
		&submission.DurationSeconds,
		&submission.FileSizeMB,
		&submission.Status,
		&submission.SubmittedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &submission, nil
}

func (r *SubmissionRepository) List(ctx context.Context, userID *uuid.UUID, status *models.SubmissionStatus, limit, offset int) ([]models.VideoSubmission, error) {
	query := `
		SELECT id, user_id, session_id, exercise_id, video_url, thumbnail_url,
		       duration_seconds, file_size_mb, status, submitted_at
		FROM video_submissions
		WHERE ($1::uuid IS NULL OR user_id = $1)
		AND ($2::varchar IS NULL OR status = $2)
		ORDER BY submitted_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.db.Query(ctx, query, userID, status, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var submissions []models.VideoSubmission
	for rows.Next() {
		var submission models.VideoSubmission
		err := rows.Scan(
			&submission.ID,
			&submission.UserID,
			&submission.SessionID,
			&submission.ExerciseID,
			&submission.VideoURL,
			&submission.ThumbnailURL,
			&submission.DurationSeconds,
			&submission.FileSizeMB,
			&submission.Status,
			&submission.SubmittedAt,
		)
		if err != nil {
			return nil, err
		}
		submissions = append(submissions, submission)
	}

	return submissions, rows.Err()
}

func (r *SubmissionRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status models.SubmissionStatus) error {
	query := `UPDATE video_submissions SET status = $1 WHERE id = $2`
	_, err := r.db.Exec(ctx, query, status, id)
	return err
}

func (r *SubmissionRepository) CreateFeedback(ctx context.Context, feedback *models.Feedback) error {
	query := `
		INSERT INTO feedback (submission_id, instructor_id, feedback_text, feedback_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`
	err := r.db.QueryRow(ctx, query,
		feedback.SubmissionID,
		feedback.InstructorID,
		feedback.FeedbackText,
		feedback.FeedbackType,
	).Scan(&feedback.ID, &feedback.CreatedAt)

	if err != nil {
		return err
	}

	// Update submission status to reviewed
	return r.UpdateStatus(ctx, feedback.SubmissionID, models.StatusReviewed)
}

func (r *SubmissionRepository) GetFeedback(ctx context.Context, submissionID uuid.UUID) ([]models.Feedback, error) {
	query := `
		SELECT id, submission_id, instructor_id, feedback_text, feedback_type, is_read, created_at
		FROM feedback
		WHERE submission_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.db.Query(ctx, query, submissionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var feedbacks []models.Feedback
	for rows.Next() {
		var feedback models.Feedback
		err := rows.Scan(
			&feedback.ID,
			&feedback.SubmissionID,
			&feedback.InstructorID,
			&feedback.FeedbackText,
			&feedback.FeedbackType,
			&feedback.IsRead,
			&feedback.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		feedbacks = append(feedbacks, feedback)
	}

	return feedbacks, rows.Err()
}

func (r *SubmissionRepository) MarkFeedbackAsRead(ctx context.Context, feedbackID uuid.UUID) error {
	query := `UPDATE feedback SET is_read = true WHERE id = $1`
	_, err := r.db.Exec(ctx, query, feedbackID)
	return err
}

func (r *SubmissionRepository) GetUnreadFeedbackCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	query := `
		SELECT COUNT(*)
		FROM feedback f
		JOIN video_submissions vs ON f.submission_id = vs.id
		WHERE vs.user_id = $1 AND f.is_read = false
	`
	err := r.db.QueryRow(ctx, query, userID).Scan(&count)
	return count, err
}
