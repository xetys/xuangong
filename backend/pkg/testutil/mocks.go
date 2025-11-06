package testutil

import (
	"context"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
)

// MockUserRepository is a mock implementation of UserRepository for testing.
// Use function fields to customize behavior per test case.
type MockUserRepository struct {
	CreateFunc      func(ctx context.Context, user *models.User) error
	GetByIDFunc     func(ctx context.Context, id uuid.UUID) (*models.User, error)
	GetByEmailFunc  func(ctx context.Context, email string) (*models.User, error)
	ListFunc        func(ctx context.Context, limit, offset int) ([]models.User, error)
	UpdateFunc      func(ctx context.Context, user *models.User) error
	DeleteFunc      func(ctx context.Context, id uuid.UUID) error
	EmailExistsFunc func(ctx context.Context, email string) (bool, error)
	CountAdminsFunc func(ctx context.Context) (int, error) // For role management tests
}

func (m *MockUserRepository) Create(ctx context.Context, user *models.User) error {
	if m.CreateFunc != nil {
		return m.CreateFunc(ctx, user)
	}
	return nil
}

func (m *MockUserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockUserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	if m.GetByEmailFunc != nil {
		return m.GetByEmailFunc(ctx, email)
	}
	return nil, nil
}

func (m *MockUserRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
	if m.ListFunc != nil {
		return m.ListFunc(ctx, limit, offset)
	}
	return []models.User{}, nil
}

func (m *MockUserRepository) Update(ctx context.Context, user *models.User) error {
	if m.UpdateFunc != nil {
		return m.UpdateFunc(ctx, user)
	}
	return nil
}

func (m *MockUserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	if m.DeleteFunc != nil {
		return m.DeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockUserRepository) EmailExists(ctx context.Context, email string) (bool, error) {
	if m.EmailExistsFunc != nil {
		return m.EmailExistsFunc(ctx, email)
	}
	return false, nil
}

func (m *MockUserRepository) CountAdmins(ctx context.Context) (int, error) {
	if m.CountAdminsFunc != nil {
		return m.CountAdminsFunc(ctx)
	}
	return 1, nil // Default: assume at least one admin exists
}

// MockProgramRepository is a mock implementation of ProgramRepository for testing.
type MockProgramRepository struct {
	CreateFunc                  func(ctx context.Context, program *models.Program) error
	GetByIDFunc                 func(ctx context.Context, id uuid.UUID) (*models.Program, error)
	GetByIDIncludingDeletedFunc func(ctx context.Context, id uuid.UUID) (*models.Program, error) // For soft delete tests
	ListFunc                    func(ctx context.Context, isTemplate, isPublic *bool, limit, offset int) ([]models.Program, error)
	GetByOwnerFunc              func(ctx context.Context, ownerID uuid.UUID) ([]models.Program, error)
	UpdateFunc                  func(ctx context.Context, program *models.Program) error
	DeleteFunc                  func(ctx context.Context, id uuid.UUID) error
	SoftDeleteFunc              func(ctx context.Context, id uuid.UUID) error // For soft delete tests
	AssignToUserFunc            func(ctx context.Context, userID, programID, assignedByID uuid.UUID) error
	GetUserProgramsFunc         func(ctx context.Context, userID uuid.UUID) ([]models.Program, error)
}

func (m *MockProgramRepository) Create(ctx context.Context, program *models.Program) error {
	if m.CreateFunc != nil {
		return m.CreateFunc(ctx, program)
	}
	return nil
}

func (m *MockProgramRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Program, error) {
	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockProgramRepository) GetByIDIncludingDeleted(ctx context.Context, id uuid.UUID) (*models.Program, error) {
	if m.GetByIDIncludingDeletedFunc != nil {
		return m.GetByIDIncludingDeletedFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockProgramRepository) List(ctx context.Context, isTemplate, isPublic *bool, limit, offset int) ([]models.Program, error) {
	if m.ListFunc != nil {
		return m.ListFunc(ctx, isTemplate, isPublic, limit, offset)
	}
	return []models.Program{}, nil
}

func (m *MockProgramRepository) GetByOwner(ctx context.Context, ownerID uuid.UUID) ([]models.Program, error) {
	if m.GetByOwnerFunc != nil {
		return m.GetByOwnerFunc(ctx, ownerID)
	}
	return []models.Program{}, nil
}

func (m *MockProgramRepository) Update(ctx context.Context, program *models.Program) error {
	if m.UpdateFunc != nil {
		return m.UpdateFunc(ctx, program)
	}
	return nil
}

func (m *MockProgramRepository) Delete(ctx context.Context, id uuid.UUID) error {
	if m.DeleteFunc != nil {
		return m.DeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockProgramRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	if m.SoftDeleteFunc != nil {
		return m.SoftDeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockProgramRepository) AssignToUser(ctx context.Context, userID, programID, assignedByID uuid.UUID) error {
	if m.AssignToUserFunc != nil {
		return m.AssignToUserFunc(ctx, userID, programID, assignedByID)
	}
	return nil
}

func (m *MockProgramRepository) GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.Program, error) {
	if m.GetUserProgramsFunc != nil {
		return m.GetUserProgramsFunc(ctx, userID)
	}
	return []models.Program{}, nil
}

// MockSessionRepository is a mock implementation of SessionRepository for testing.
type MockSessionRepository struct {
	CreateFunc       func(ctx context.Context, session *models.PracticeSession) error
	GetByIDFunc      func(ctx context.Context, id uuid.UUID) (*models.PracticeSession, error)
	ListFunc         func(ctx context.Context, userID uuid.UUID, filters map[string]interface{}) ([]models.PracticeSession, error)
	ListByUserIDFunc func(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, filters map[string]interface{}) ([]models.PracticeSession, error) // For admin sessions tests
	UpdateFunc       func(ctx context.Context, session *models.PracticeSession) error
	DeleteFunc       func(ctx context.Context, id uuid.UUID) error
	GetStatsFunc     func(ctx context.Context, userID uuid.UUID) (*models.SessionStats, error)
}

func (m *MockSessionRepository) Create(ctx context.Context, session *models.PracticeSession) error {
	if m.CreateFunc != nil {
		return m.CreateFunc(ctx, session)
	}
	return nil
}

func (m *MockSessionRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.PracticeSession, error) {
	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockSessionRepository) List(ctx context.Context, userID uuid.UUID, filters map[string]interface{}) ([]models.PracticeSession, error) {
	if m.ListFunc != nil {
		return m.ListFunc(ctx, userID, filters)
	}
	return []models.PracticeSession{}, nil
}

func (m *MockSessionRepository) ListByUserID(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, filters map[string]interface{}) ([]models.PracticeSession, error) {
	if m.ListByUserIDFunc != nil {
		return m.ListByUserIDFunc(ctx, userID, programID, filters)
	}
	return []models.PracticeSession{}, nil
}

func (m *MockSessionRepository) Update(ctx context.Context, session *models.PracticeSession) error {
	if m.UpdateFunc != nil {
		return m.UpdateFunc(ctx, session)
	}
	return nil
}

func (m *MockSessionRepository) Delete(ctx context.Context, id uuid.UUID) error {
	if m.DeleteFunc != nil {
		return m.DeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockSessionRepository) GetStats(ctx context.Context, userID uuid.UUID) (*models.SessionStats, error) {
	if m.GetStatsFunc != nil {
		return m.GetStatsFunc(ctx, userID)
	}
	return &models.SessionStats{}, nil
}

// MockExerciseRepository is a mock implementation of ExerciseRepository for testing.
type MockExerciseRepository struct {
	CreateFunc       func(ctx context.Context, exercise *models.Exercise) error
	GetByIDFunc      func(ctx context.Context, id uuid.UUID) (*models.Exercise, error)
	ListFunc         func(ctx context.Context, category *string, limit, offset int) ([]models.Exercise, error)
	UpdateFunc       func(ctx context.Context, exercise *models.Exercise) error
	DeleteFunc       func(ctx context.Context, id uuid.UUID) error
	GetByProgramFunc func(ctx context.Context, programID uuid.UUID) ([]models.Exercise, error)
}

func (m *MockExerciseRepository) Create(ctx context.Context, exercise *models.Exercise) error {
	if m.CreateFunc != nil {
		return m.CreateFunc(ctx, exercise)
	}
	return nil
}

func (m *MockExerciseRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Exercise, error) {
	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockExerciseRepository) List(ctx context.Context, category *string, limit, offset int) ([]models.Exercise, error) {
	if m.ListFunc != nil {
		return m.ListFunc(ctx, category, limit, offset)
	}
	return []models.Exercise{}, nil
}

func (m *MockExerciseRepository) Update(ctx context.Context, exercise *models.Exercise) error {
	if m.UpdateFunc != nil {
		return m.UpdateFunc(ctx, exercise)
	}
	return nil
}

func (m *MockExerciseRepository) Delete(ctx context.Context, id uuid.UUID) error {
	if m.DeleteFunc != nil {
		return m.DeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockExerciseRepository) GetByProgram(ctx context.Context, programID uuid.UUID) ([]models.Exercise, error) {
	if m.GetByProgramFunc != nil {
		return m.GetByProgramFunc(ctx, programID)
	}
	return []models.Exercise{}, nil
}

// Helper function to create a mock user for testing
func NewMockUser(id uuid.UUID, email string, role models.UserRole) *models.User {
	return &models.User{
		ID:       id,
		Email:    email,
		FullName: "Mock User",
		Role:     role,
		IsActive: true,
	}
}

// Helper function to create a mock program for testing
func NewMockProgram(id uuid.UUID, name string, ownerID *uuid.UUID) *models.Program {
	return &models.Program{
		ID:          id,
		Name:        name,
		Description: "Mock program",
		OwnedBy:     ownerID,
		IsTemplate:  false,
		IsPublic:    false,
	}
}

// Helper function to create a mock session for testing
func NewMockSession(id, userID, programID uuid.UUID) *models.PracticeSession {
	return &models.PracticeSession{
		ID:        id,
		UserID:    userID,
		ProgramID: programID,
	}
}
