package repositories

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

type ExerciseRepository struct {
	db *pgxpool.Pool
}

func NewExerciseRepository(db *pgxpool.Pool) *ExerciseRepository {
	return &ExerciseRepository{db: db}
}

func (r *ExerciseRepository) Create(ctx context.Context, exercise *models.Exercise) error {
	query := `
		INSERT INTO exercises (
			program_id, name, description, order_index, exercise_type,
			duration_seconds, repetitions, rest_after_seconds,
			has_sides, side_duration_seconds, metadata
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, created_at
	`
	return r.db.QueryRow(ctx, query,
		exercise.ProgramID,
		exercise.Name,
		exercise.Description,
		exercise.OrderIndex,
		exercise.ExerciseType,
		exercise.DurationSeconds,
		exercise.Repetitions,
		exercise.RestAfterSeconds,
		exercise.HasSides,
		exercise.SideDurationSeconds,
		exercise.Metadata,
	).Scan(&exercise.ID, &exercise.CreatedAt)
}

func (r *ExerciseRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Exercise, error) {
	var exercise models.Exercise
	query := `
		SELECT id, program_id, name, description, order_index, exercise_type,
		       duration_seconds, repetitions, rest_after_seconds,
		       has_sides, side_duration_seconds, metadata, created_at
		FROM exercises
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&exercise.ID,
		&exercise.ProgramID,
		&exercise.Name,
		&exercise.Description,
		&exercise.OrderIndex,
		&exercise.ExerciseType,
		&exercise.DurationSeconds,
		&exercise.Repetitions,
		&exercise.RestAfterSeconds,
		&exercise.HasSides,
		&exercise.SideDurationSeconds,
		&exercise.Metadata,
		&exercise.CreatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &exercise, nil
}

func (r *ExerciseRepository) ListByProgramID(ctx context.Context, programID uuid.UUID) ([]models.Exercise, error) {
	query := `
		SELECT id, program_id, name, description, order_index, exercise_type,
		       duration_seconds, repetitions, rest_after_seconds,
		       has_sides, side_duration_seconds, metadata, created_at
		FROM exercises
		WHERE program_id = $1
		ORDER BY order_index ASC
	`
	rows, err := r.db.Query(ctx, query, programID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	exercises := make([]models.Exercise, 0)
	for rows.Next() {
		var exercise models.Exercise
		err := rows.Scan(
			&exercise.ID,
			&exercise.ProgramID,
			&exercise.Name,
			&exercise.Description,
			&exercise.OrderIndex,
			&exercise.ExerciseType,
			&exercise.DurationSeconds,
			&exercise.Repetitions,
			&exercise.RestAfterSeconds,
			&exercise.HasSides,
			&exercise.SideDurationSeconds,
			&exercise.Metadata,
			&exercise.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		exercises = append(exercises, exercise)
	}

	return exercises, rows.Err()
}

func (r *ExerciseRepository) Update(ctx context.Context, exercise *models.Exercise) error {
	query := `
		UPDATE exercises
		SET name = $1, description = $2, order_index = $3, exercise_type = $4,
		    duration_seconds = $5, repetitions = $6, rest_after_seconds = $7,
		    has_sides = $8, side_duration_seconds = $9, metadata = $10
		WHERE id = $11
	`
	_, err := r.db.Exec(ctx, query,
		exercise.Name,
		exercise.Description,
		exercise.OrderIndex,
		exercise.ExerciseType,
		exercise.DurationSeconds,
		exercise.Repetitions,
		exercise.RestAfterSeconds,
		exercise.HasSides,
		exercise.SideDurationSeconds,
		exercise.Metadata,
		exercise.ID,
	)
	return err
}

func (r *ExerciseRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM exercises WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id)
	return err
}

func (r *ExerciseRepository) Reorder(ctx context.Context, programID uuid.UUID, exerciseIDs []uuid.UUID) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	query := `UPDATE exercises SET order_index = $1 WHERE id = $2 AND program_id = $3`
	for i, id := range exerciseIDs {
		_, err := tx.Exec(ctx, query, i, id, programID)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}
