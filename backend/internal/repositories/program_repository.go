package repositories

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

type ProgramRepository struct {
	db *pgxpool.Pool
}

func NewProgramRepository(db *pgxpool.Pool) *ProgramRepository {
	return &ProgramRepository{db: db}
}

func (r *ProgramRepository) Create(ctx context.Context, program *models.Program) error {
	query := `
		INSERT INTO programs (name, description, created_by, is_template, is_public, tags, metadata)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		program.Name,
		program.Description,
		program.CreatedBy,
		program.IsTemplate,
		program.IsPublic,
		program.Tags,
		program.Metadata,
	).Scan(&program.ID, &program.CreatedAt, &program.UpdatedAt)
}

func (r *ProgramRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Program, error) {
	var program models.Program
	query := `
		SELECT id, name, description, created_by, is_template, is_public, tags, metadata, created_at, updated_at
		FROM programs
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&program.ID,
		&program.Name,
		&program.Description,
		&program.CreatedBy,
		&program.IsTemplate,
		&program.IsPublic,
		&program.Tags,
		&program.Metadata,
		&program.CreatedAt,
		&program.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &program, nil
}

func (r *ProgramRepository) List(ctx context.Context, isTemplate, isPublic *bool, limit, offset int) ([]models.Program, error) {
	query := `
		SELECT p.id, p.name, p.description, p.created_by, u.full_name as creator_name,
		       p.is_template, p.is_public, p.tags, p.metadata, p.created_at, p.updated_at
		FROM programs p
		LEFT JOIN users u ON p.created_by = u.id
		WHERE ($1::boolean IS NULL OR p.is_template = $1)
		AND ($2::boolean IS NULL OR p.is_public = $2)
		ORDER BY p.created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.db.Query(ctx, query, isTemplate, isPublic, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	programs := make([]models.Program, 0)
	for rows.Next() {
		var program models.Program
		err := rows.Scan(
			&program.ID,
			&program.Name,
			&program.Description,
			&program.CreatedBy,
			&program.CreatorName,
			&program.IsTemplate,
			&program.IsPublic,
			&program.Tags,
			&program.Metadata,
			&program.CreatedAt,
			&program.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		programs = append(programs, program)
	}

	return programs, rows.Err()
}

func (r *ProgramRepository) Update(ctx context.Context, program *models.Program) error {
	query := `
		UPDATE programs
		SET name = $1, description = $2, is_template = $3, is_public = $4, tags = $5, metadata = $6
		WHERE id = $7
		RETURNING updated_at
	`
	return r.db.QueryRow(ctx, query,
		program.Name,
		program.Description,
		program.IsTemplate,
		program.IsPublic,
		program.Tags,
		program.Metadata,
		program.ID,
	).Scan(&program.UpdatedAt)
}

func (r *ProgramRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM programs WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id)
	return err
}

func (r *ProgramRepository) AssignToUser(ctx context.Context, userProgram *models.UserProgram) error {
	query := `
		INSERT INTO user_programs (user_id, program_id, assigned_by, custom_settings)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (user_id, program_id) DO UPDATE
		SET is_active = true, assigned_by = $3, assigned_at = CURRENT_TIMESTAMP
		RETURNING id, assigned_at
	`
	return r.db.QueryRow(ctx, query,
		userProgram.UserID,
		userProgram.ProgramID,
		userProgram.AssignedBy,
		userProgram.CustomSettings,
	).Scan(&userProgram.ID, &userProgram.AssignedAt)
}

func (r *ProgramRepository) GetUserPrograms(ctx context.Context, userID uuid.UUID, activeOnly bool) ([]models.UserProgram, error) {
	query := `
		SELECT id, user_id, program_id, assigned_by, assigned_at, is_active, custom_settings
		FROM user_programs
		WHERE user_id = $1 AND ($2 = false OR is_active = true)
		ORDER BY assigned_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID, activeOnly)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	userPrograms := make([]models.UserProgram, 0)
	for rows.Next() {
		var up models.UserProgram
		err := rows.Scan(
			&up.ID,
			&up.UserID,
			&up.ProgramID,
			&up.AssignedBy,
			&up.AssignedAt,
			&up.IsActive,
			&up.CustomSettings,
		)
		if err != nil {
			return nil, err
		}
		userPrograms = append(userPrograms, up)
	}

	return userPrograms, rows.Err()
}

func (r *ProgramRepository) UpdateUserProgramSettings(ctx context.Context, userID, programID uuid.UUID, customSettings map[string]interface{}) error {
	query := `
		UPDATE user_programs
		SET custom_settings = $1
		WHERE user_id = $2 AND program_id = $3
	`
	_, err := r.db.Exec(ctx, query, customSettings, userID, programID)
	return err
}

func (r *ProgramRepository) GetUserProgramsWithDetails(ctx context.Context, userID uuid.UUID, activeOnly bool) ([]models.Program, error) {
	query := `
		SELECT DISTINCT p.id, p.name, p.description, p.created_by, u.full_name as creator_name,
		       p.is_template, p.is_public, p.tags, p.metadata, p.created_at, p.updated_at
		FROM programs p
		LEFT JOIN user_programs up ON p.id = up.program_id AND up.user_id = $1
		LEFT JOIN users u ON p.created_by = u.id
		WHERE ((up.user_id = $1 AND ($2 = false OR up.is_active = true))
		   OR (p.created_by = $1))
		   AND p.is_template = false
		ORDER BY p.created_at DESC
	`
	rows, err := r.db.Query(ctx, query, userID, activeOnly)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	programs := make([]models.Program, 0)
	for rows.Next() {
		var program models.Program
		err := rows.Scan(
			&program.ID,
			&program.Name,
			&program.Description,
			&program.CreatedBy,
			&program.CreatorName,
			&program.IsTemplate,
			&program.IsPublic,
			&program.Tags,
			&program.Metadata,
			&program.CreatedAt,
			&program.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		programs = append(programs, program)
	}

	return programs, rows.Err()
}
