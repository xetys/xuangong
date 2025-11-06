package testutil

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

// Default test password (hashed)
const DefaultTestPassword = "Test123!@#"

var defaultPasswordHash string

func init() {
	// Pre-compute password hash to speed up tests
	hash, _ := bcrypt.GenerateFromPassword([]byte(DefaultTestPassword), bcrypt.MinCost)
	defaultPasswordHash = string(hash)
}

// CreateTestUser creates a student user in the database and returns it.
func CreateTestUser(t *testing.T, pool *pgxpool.Pool, email string) *models.User {
	t.Helper()
	return createUser(t, pool, email, models.RoleStudent)
}

// CreateTestAdmin creates an admin user in the database and returns it.
func CreateTestAdmin(t *testing.T, pool *pgxpool.Pool, email string) *models.User {
	t.Helper()
	return createUser(t, pool, email, models.RoleAdmin)
}

// CreateTestStudent is an alias for CreateTestUser for clarity.
func CreateTestStudent(t *testing.T, pool *pgxpool.Pool, email string) *models.User {
	t.Helper()
	return CreateTestUser(t, pool, email)
}

// createUser is the internal helper to create users with specified roles.
func createUser(t *testing.T, pool *pgxpool.Pool, email string, role models.UserRole) *models.User {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	user := &models.User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: defaultPasswordHash,
		FullName:     "Test User",
		Role:         role,
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	query := `
		INSERT INTO users (id, email, password_hash, full_name, role, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := pool.Exec(ctx, query,
		user.ID,
		user.Email,
		user.PasswordHash,
		user.FullName,
		user.Role,
		user.IsActive,
		user.CreatedAt,
		user.UpdatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test user: %v", err)
	}

	return user
}

// CreateTestProgram creates a program in the database and returns it.
func CreateTestProgram(t *testing.T, pool *pgxpool.Pool, ownerID uuid.UUID, name string) *models.Program {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	program := &models.Program{
		ID:                   uuid.New(),
		Name:                 name,
		Description:          "Test program description",
		OwnedBy:              &ownerID,
		IsTemplate:           false,
		IsPublic:             false,
		RepetitionsPlanned:   intPtr(10),
		RepetitionsCompleted: intPtr(0),
		Tags:                 []string{"test"},
		Metadata:             make(map[string]interface{}),
		CreatedAt:            time.Now(),
		UpdatedAt:            time.Now(),
	}

	query := `
		INSERT INTO programs (
			id, name, description, owned_by, is_template, is_public,
			repetitions_planned, repetitions_completed, tags, metadata,
			created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	_, err := pool.Exec(ctx, query,
		program.ID,
		program.Name,
		program.Description,
		program.OwnedBy,
		program.IsTemplate,
		program.IsPublic,
		program.RepetitionsPlanned,
		program.RepetitionsCompleted,
		program.Tags,
		program.Metadata,
		program.CreatedAt,
		program.UpdatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test program: %v", err)
	}

	return program
}

// CreateTestTemplate creates a template program (is_template=true).
func CreateTestTemplate(t *testing.T, pool *pgxpool.Pool, ownerID uuid.UUID, name string) *models.Program {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	program := &models.Program{
		ID:          uuid.New(),
		Name:        name,
		Description: "Test template description",
		OwnedBy:     &ownerID,
		IsTemplate:  true,
		IsPublic:    true,
		Tags:        []string{"template", "test"},
		Metadata:    make(map[string]interface{}),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	query := `
		INSERT INTO programs (
			id, name, description, owned_by, is_template, is_public,
			tags, metadata, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err := pool.Exec(ctx, query,
		program.ID,
		program.Name,
		program.Description,
		program.OwnedBy,
		program.IsTemplate,
		program.IsPublic,
		program.Tags,
		program.Metadata,
		program.CreatedAt,
		program.UpdatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test template: %v", err)
	}

	return program
}

// CreateTestSession creates a practice session in the database.
func CreateTestSession(t *testing.T, pool *pgxpool.Pool, userID, programID uuid.UUID) *models.PracticeSession {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	session := &models.PracticeSession{
		ID:        uuid.New(),
		UserID:    userID,
		ProgramID: programID,
		StartedAt: time.Now(),
	}

	query := `
		INSERT INTO sessions (id, user_id, program_id, started_at)
		VALUES ($1, $2, $3, $4)
	`

	_, err := pool.Exec(ctx, query,
		session.ID,
		session.UserID,
		session.ProgramID,
		session.StartedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test session: %v", err)
	}

	return session
}

// CreateTestCompletedSession creates a completed practice session.
func CreateTestCompletedSession(t *testing.T, pool *pgxpool.Pool, userID, programID uuid.UUID) *models.PracticeSession {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	now := time.Now()
	completedAt := now
	duration := int(30 * 60) // 30 minutes in seconds

	session := &models.PracticeSession{
		ID:                   uuid.New(),
		UserID:               userID,
		ProgramID:            programID,
		StartedAt:            now.Add(-30 * time.Minute),
		CompletedAt:          &completedAt,
		TotalDurationSeconds: &duration,
	}

	query := `
		INSERT INTO sessions (
			id, user_id, program_id, started_at, completed_at,
			total_duration_seconds
		)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := pool.Exec(ctx, query,
		session.ID,
		session.UserID,
		session.ProgramID,
		session.StartedAt,
		session.CompletedAt,
		session.TotalDurationSeconds,
	)

	if err != nil {
		t.Fatalf("Failed to create test completed session: %v", err)
	}

	return session
}

// CreateTestExercise creates an exercise linked to a program in the database.
func CreateTestExercise(t *testing.T, pool *pgxpool.Pool, programID uuid.UUID, name string) *models.Exercise {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	exercise := &models.Exercise{
		ID:               uuid.New(),
		ProgramID:        programID,
		Name:             name,
		Description:      "Test exercise description",
		OrderIndex:       1,
		ExerciseType:     models.ExerciseTypeCombined,
		DurationSeconds:  intPtr(60),
		Repetitions:      intPtr(10),
		RestAfterSeconds: 10,
		HasSides:         false,
		Metadata:         make(map[string]interface{}),
		CreatedAt:        time.Now(),
	}

	query := `
		INSERT INTO exercises (
			id, program_id, name, description, order_index, exercise_type,
			duration_seconds, repetitions, rest_after_seconds, has_sides,
			metadata, created_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`

	_, err := pool.Exec(ctx, query,
		exercise.ID,
		exercise.ProgramID,
		exercise.Name,
		exercise.Description,
		exercise.OrderIndex,
		exercise.ExerciseType,
		exercise.DurationSeconds,
		exercise.Repetitions,
		exercise.RestAfterSeconds,
		exercise.HasSides,
		exercise.Metadata,
		exercise.CreatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test exercise: %v", err)
	}

	return exercise
}

// AssignProgramToUser creates a user_program relationship.
func AssignProgramToUser(t *testing.T, pool *pgxpool.Pool, userID, programID, assignedByID uuid.UUID) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		INSERT INTO user_programs (id, user_id, program_id, assigned_by, assigned_at, is_active, custom_settings)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err := pool.Exec(ctx, query,
		uuid.New(),
		userID,
		programID,
		assignedByID,
		time.Now(),
		true,
		make(map[string]interface{}),
	)

	if err != nil {
		t.Fatalf("Failed to assign program to user: %v", err)
	}
}

// CreateTestSubmission creates a submission in the database and returns it.
func CreateTestSubmission(t *testing.T, pool *pgxpool.Pool, programID, userID uuid.UUID, title string) *models.Submission {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	submission := &models.Submission{
		ID:        uuid.New(),
		ProgramID: programID,
		UserID:    userID,
		Title:     title,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	query := `
		INSERT INTO submissions (id, program_id, user_id, title, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := pool.Exec(ctx, query,
		submission.ID,
		submission.ProgramID,
		submission.UserID,
		submission.Title,
		submission.CreatedAt,
		submission.UpdatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test submission: %v", err)
	}

	return submission
}

// CreateTestMessage creates a submission message in the database and returns it.
func CreateTestMessage(t *testing.T, pool *pgxpool.Pool, submissionID, userID uuid.UUID, content string, youtubeURL *string) *models.SubmissionMessage {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	message := &models.SubmissionMessage{
		ID:           uuid.New(),
		SubmissionID: submissionID,
		UserID:       userID,
		Content:      content,
		YouTubeURL:   youtubeURL,
		CreatedAt:    time.Now(),
	}

	query := `
		INSERT INTO submission_messages (id, submission_id, user_id, content, youtube_url, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := pool.Exec(ctx, query,
		message.ID,
		message.SubmissionID,
		message.UserID,
		message.Content,
		message.YouTubeURL,
		message.CreatedAt,
	)

	if err != nil {
		t.Fatalf("Failed to create test message: %v", err)
	}

	return message
}

// MarkMessageAsRead marks a message as read by a user.
func MarkMessageAsRead(t *testing.T, pool *pgxpool.Pool, userID, messageID uuid.UUID) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		INSERT INTO message_read_status (user_id, message_id, read_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, message_id) DO NOTHING
	`

	_, err := pool.Exec(ctx, query, userID, messageID, time.Now())

	if err != nil {
		t.Fatalf("Failed to mark message as read: %v", err)
	}
}

// Helper functions

func intPtr(i int) *int {
	return &i
}

func stringPtr(s string) *string {
	return &s
}
