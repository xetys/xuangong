package repositories

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

type SessionRepository struct {
	db *pgxpool.Pool
}

func NewSessionRepository(db *pgxpool.Pool) *SessionRepository {
	return &SessionRepository{db: db}
}

func (r *SessionRepository) Create(ctx context.Context, session *models.PracticeSession) error {
	query := `
		INSERT INTO practice_sessions (user_id, program_id, device_info)
		VALUES ($1, $2, $3)
		RETURNING id, started_at
	`
	return r.db.QueryRow(ctx, query,
		session.UserID,
		session.ProgramID,
		session.DeviceInfo,
	).Scan(&session.ID, &session.StartedAt)
}

func (r *SessionRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.PracticeSession, error) {
	var session models.PracticeSession
	query := `
		SELECT id, user_id, program_id, started_at, completed_at,
		       total_duration_seconds, completion_rate, notes, device_info
		FROM practice_sessions
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&session.ID,
		&session.UserID,
		&session.ProgramID,
		&session.StartedAt,
		&session.CompletedAt,
		&session.TotalDurationSeconds,
		&session.CompletionRate,
		&session.Notes,
		&session.DeviceInfo,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &session, nil
}

func (r *SessionRepository) List(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
	query := `
		SELECT ps.id, ps.user_id, ps.program_id, p.name as program_name, ps.started_at, ps.completed_at,
		       ps.total_duration_seconds, ps.completion_rate, ps.notes, ps.device_info
		FROM practice_sessions ps
		LEFT JOIN programs p ON ps.program_id = p.id
		WHERE ps.user_id = $1
		AND ($2::uuid IS NULL OR ps.program_id = $2)
		AND ($3::timestamp IS NULL OR ps.started_at >= $3)
		AND ($4::timestamp IS NULL OR ps.started_at <= $4)
		ORDER BY ps.started_at DESC
		LIMIT $5 OFFSET $6
	`
	rows, err := r.db.Query(ctx, query, userID, programID, startDate, endDate, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	sessions := make([]models.PracticeSession, 0)
	for rows.Next() {
		var session models.PracticeSession
		var programName sql.NullString
		err := rows.Scan(
			&session.ID,
			&session.UserID,
			&session.ProgramID,
			&programName,
			&session.StartedAt,
			&session.CompletedAt,
			&session.TotalDurationSeconds,
			&session.CompletionRate,
			&session.Notes,
			&session.DeviceInfo,
		)
		if err != nil {
			return nil, err
		}
		if programName.Valid {
			session.ProgramName = &programName.String
		}
		sessions = append(sessions, session)
	}

	return sessions, rows.Err()
}

func (r *SessionRepository) Complete(ctx context.Context, sessionID uuid.UUID, totalDuration int, completionRate float64, notes string, completedAt *time.Time) error {
	var query string
	var err error

	if completedAt != nil {
		// Use the provided completion time
		query = `
			UPDATE practice_sessions
			SET completed_at = $1, total_duration_seconds = $2, completion_rate = $3, notes = $4
			WHERE id = $5
		`
		_, err = r.db.Exec(ctx, query, completedAt, totalDuration, completionRate, notes, sessionID)
	} else {
		// Use current timestamp
		query = `
			UPDATE practice_sessions
			SET completed_at = CURRENT_TIMESTAMP, total_duration_seconds = $1, completion_rate = $2, notes = $3
			WHERE id = $4
		`
		_, err = r.db.Exec(ctx, query, totalDuration, completionRate, notes, sessionID)
	}

	return err
}

func (r *SessionRepository) CreateExerciseLog(ctx context.Context, log *models.ExerciseLog) error {
	query := `
		INSERT INTO exercise_logs (
			session_id, exercise_id, started_at, completed_at,
			planned_duration_seconds, actual_duration_seconds,
			repetitions_planned, repetitions_completed, skipped, notes
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id
	`
	return r.db.QueryRow(ctx, query,
		log.SessionID,
		log.ExerciseID,
		log.StartedAt,
		log.CompletedAt,
		log.PlannedDurationSeconds,
		log.ActualDurationSeconds,
		log.RepetitionsPlanned,
		log.RepetitionsCompleted,
		log.Skipped,
		log.Notes,
	).Scan(&log.ID)
}

func (r *SessionRepository) GetExerciseLogs(ctx context.Context, sessionID uuid.UUID) ([]models.ExerciseLog, error) {
	query := `
		SELECT id, session_id, exercise_id, started_at, completed_at,
		       planned_duration_seconds, actual_duration_seconds,
		       repetitions_planned, repetitions_completed, skipped, notes
		FROM exercise_logs
		WHERE session_id = $1
		ORDER BY started_at ASC
	`
	rows, err := r.db.Query(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logs := make([]models.ExerciseLog, 0)
	for rows.Next() {
		var log models.ExerciseLog
		err := rows.Scan(
			&log.ID,
			&log.SessionID,
			&log.ExerciseID,
			&log.StartedAt,
			&log.CompletedAt,
			&log.PlannedDurationSeconds,
			&log.ActualDurationSeconds,
			&log.RepetitionsPlanned,
			&log.RepetitionsCompleted,
			&log.Skipped,
			&log.Notes,
		)
		if err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}

	return logs, rows.Err()
}

func (r *SessionRepository) GetStats(ctx context.Context, userID uuid.UUID) (*models.SessionStats, error) {
	var stats models.SessionStats

	// Get basic stats
	query := `
		SELECT
			COUNT(*) as total_sessions,
			COUNT(completed_at) as completed_sessions,
			COALESCE(SUM(total_duration_seconds), 0) / 60 as total_duration_minutes,
			COALESCE(AVG(completion_rate), 0) as avg_completion_rate
		FROM practice_sessions
		WHERE user_id = $1
	`
	err := r.db.QueryRow(ctx, query, userID).Scan(
		&stats.TotalSessions,
		&stats.CompletedSessions,
		&stats.TotalDurationMinutes,
		&stats.AverageCompletionRate,
	)
	if err != nil {
		return nil, err
	}

	// Calculate current and longest streak
	streakQuery := `
		WITH daily_sessions AS (
			SELECT DISTINCT DATE(started_at) as session_date
			FROM practice_sessions
			WHERE user_id = $1 AND completed_at IS NOT NULL
			ORDER BY session_date DESC
		),
		streak_groups AS (
			SELECT
				session_date,
				session_date - (ROW_NUMBER() OVER (ORDER BY session_date))::int AS streak_group
			FROM daily_sessions
		),
		streaks AS (
			SELECT COUNT(*) as streak_length
			FROM streak_groups
			GROUP BY streak_group
			ORDER BY MIN(session_date) DESC
		)
		SELECT
			COALESCE((SELECT streak_length FROM streaks LIMIT 1), 0) as current_streak,
			COALESCE(MAX(streak_length), 0) as longest_streak
		FROM streaks
	`
	err = r.db.QueryRow(ctx, streakQuery, userID).Scan(
		&stats.CurrentStreak,
		&stats.LongestStreak,
	)
	if err != nil {
		return nil, err
	}

	return &stats, nil
}

func (r *SessionRepository) Delete(ctx context.Context, sessionID uuid.UUID) error {
	// Delete exercise logs first (foreign key constraint)
	_, err := r.db.Exec(ctx, `DELETE FROM exercise_logs WHERE session_id = $1`, sessionID)
	if err != nil {
		return err
	}

	// Delete session
	_, err = r.db.Exec(ctx, `DELETE FROM practice_sessions WHERE id = $1`, sessionID)
	return err
}
