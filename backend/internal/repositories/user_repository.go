package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (email, password_hash, full_name, role, is_active)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.Role,
		user.IsActive,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		WHERE id = $1
	`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FullName,
		&user.Role,
		&user.IsActive,
		&user.CountdownVolume,
		&user.StartVolume,
		&user.HalfwayVolume,
		&user.FinishVolume,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		WHERE email = $1
	`
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.FullName,
		&user.Role,
		&user.IsActive,
		&user.CountdownVolume,
		&user.StartVolume,
		&user.HalfwayVolume,
		&user.FinishVolume,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
	query := `
		SELECT id, email, password_hash, full_name, role, is_active,
		       countdown_volume, start_volume, halfway_volume, finish_volume,
		       created_at, updated_at
		FROM users
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]models.User, 0)
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID,
			&user.Email,
			&user.PasswordHash,
			&user.FullName,
			&user.Role,
			&user.IsActive,
			&user.CountdownVolume,
			&user.StartVolume,
			&user.HalfwayVolume,
			&user.FinishVolume,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}

	return users, rows.Err()
}

func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET email = $1, full_name = $2, role = $3, is_active = $4,
		    countdown_volume = $5, start_volume = $6, halfway_volume = $7, finish_volume = $8
		WHERE id = $9
		RETURNING updated_at
	`
	return r.db.QueryRow(ctx, query,
		user.Email,
		user.FullName,
		user.Role,
		user.IsActive,
		user.CountdownVolume,
		user.StartVolume,
		user.HalfwayVolume,
		user.FinishVolume,
		user.ID,
	).Scan(&user.UpdatedAt)
}

func (r *UserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM users WHERE id = $1`
	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}
	return nil
}

func (r *UserRepository) EmailExists(ctx context.Context, email string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`
	err := r.db.QueryRow(ctx, query, email).Scan(&exists)
	return exists, err
}

func (r *UserRepository) CountAdmins(ctx context.Context) (int, error) {
	var count int
	query := `SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = true`
	err := r.db.QueryRow(ctx, query).Scan(&count)
	return count, err
}
