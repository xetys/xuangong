package services

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	appErrors "github.com/xuangong/backend/pkg/errors"
	"github.com/xuangong/backend/pkg/testutil"
)

func TestProgramService_SoftDelete(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name           string
		programID      uuid.UUID
		userID         uuid.UUID
		userRole       models.UserRole
		setupMocks     func(*testutil.MockProgramRepository)
		expectError    bool
		expectedErrMsg string
	}{
		{
			name:      "admin_can_soft_delete_any_program",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleAdmin,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				programID := uuid.New()
				ownerID := uuid.New()
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return testutil.NewMockProgram(programID, "Test Program", &ownerID), nil
				}
				mockRepo.SoftDeleteFunc = func(ctx context.Context, id uuid.UUID) error {
					return nil
				}
			},
			expectError: false,
		},
		{
			name:      "owner_can_soft_delete_their_own_program",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleStudent,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				userID := uuid.New()
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return testutil.NewMockProgram(id, "Test Program", &userID), nil
				}
				mockRepo.SoftDeleteFunc = func(ctx context.Context, id uuid.UUID) error {
					return nil
				}
			},
			expectError: false,
		},
		{
			name:      "student_cannot_soft_delete_others_program",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleStudent,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				ownerID := uuid.New() // Different from userID
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return testutil.NewMockProgram(id, "Test Program", &ownerID), nil
				}
			},
			expectError:    true,
			expectedErrMsg: "You don't have permission to delete this program",
		},
		{
			name:      "cannot_delete_non_existent_program",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleAdmin,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return nil, nil // Program not found
				}
			},
			expectError:    true,
			expectedErrMsg: "Program not found",
		},
		{
			name:      "cannot_delete_already_deleted_program",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleAdmin,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				programID := uuid.New()
				ownerID := uuid.New()
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return testutil.NewMockProgram(programID, "Test Program", &ownerID), nil
				}
				mockRepo.SoftDeleteFunc = func(ctx context.Context, id uuid.UUID) error {
					return errors.New("program already deleted")
				}
			},
			expectError:    true,
			expectedErrMsg: "Failed to delete program",
		},
		{
			name:      "soft_deleted_program_not_returned_in_service_queries",
			programID: uuid.New(),
			userID:    uuid.New(),
			userRole:  models.RoleAdmin,
			setupMocks: func(mockRepo *testutil.MockProgramRepository) {
				programID := uuid.New()
				ownerID := uuid.New()

				// First call returns the program (for soft delete)
				callCount := 0
				mockRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					callCount++
					if callCount == 1 {
						return testutil.NewMockProgram(programID, "Test Program", &ownerID), nil
					}
					// Second call returns nil (program is soft deleted)
					return nil, nil
				}
				mockRepo.SoftDeleteFunc = func(ctx context.Context, id uuid.UUID) error {
					return nil
				}
			},
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mocks
			mockProgramRepo := &testutil.MockProgramRepository{}
			mockExerciseRepo := &testutil.MockExerciseRepository{}
			tt.setupMocks(mockProgramRepo)

			service := NewProgramService(mockProgramRepo, mockExerciseRepo)

			// Call SoftDelete (this method doesn't exist yet - RED phase)
			err := service.SoftDelete(ctx, tt.programID, tt.userID, tt.userRole)

			// Assertions
			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error but got none")
					return
				}
				if tt.expectedErrMsg != "" {
					appErr, ok := err.(*appErrors.AppError)
					if !ok {
						t.Errorf("Expected AppError but got: %T", err)
						return
					}
					if appErr.Message != tt.expectedErrMsg {
						t.Errorf("Expected error message '%s' but got '%s'", tt.expectedErrMsg, appErr.Message)
					}
				}
			} else {
				if err != nil {
					t.Errorf("Expected no error but got: %v", err)
				}
			}

			// For the last test case, verify GetByID returns nil after soft delete
			if tt.name == "soft_deleted_program_not_returned_in_service_queries" && !tt.expectError {
				// Call GetByID again to verify program is not returned
				result, err := service.GetByID(ctx, tt.programID, false)
				if err == nil {
					t.Error("Expected error when getting soft-deleted program")
				}
				if result != nil {
					t.Error("Expected nil result when getting soft-deleted program")
				}
			}
		})
	}
}

func TestProgramService_SoftDelete_AuthorizationLogic(t *testing.T) {
	ctx := context.Background()

	ownerID := uuid.New()
	otherUserID := uuid.New()
	adminID := uuid.New()
	programID := uuid.New()

	tests := []struct {
		name         string
		userID       uuid.UUID
		userRole     models.UserRole
		programOwner uuid.UUID
		expectError  bool
		errorMsg     string
	}{
		{
			name:         "admin_can_delete_any_program",
			userID:       adminID,
			userRole:     models.RoleAdmin,
			programOwner: ownerID, // Different from adminID
			expectError:  false,
		},
		{
			name:         "owner_can_delete_own_program",
			userID:       ownerID,
			userRole:     models.RoleStudent,
			programOwner: ownerID, // Same as userID
			expectError:  false,
		},
		{
			name:         "student_cannot_delete_others_program",
			userID:       otherUserID,
			userRole:     models.RoleStudent,
			programOwner: ownerID, // Different from otherUserID
			expectError:  true,
			errorMsg:     "You don't have permission to delete this program",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockProgramRepo := &testutil.MockProgramRepository{
				GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.Program, error) {
					return testutil.NewMockProgram(programID, "Test Program", &tt.programOwner), nil
				},
				SoftDeleteFunc: func(ctx context.Context, id uuid.UUID) error {
					return nil
				},
			}
			mockExerciseRepo := &testutil.MockExerciseRepository{}

			service := NewProgramService(mockProgramRepo, mockExerciseRepo)

			err := service.SoftDelete(ctx, programID, tt.userID, tt.userRole)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error but got none")
					return
				}
				appErr, ok := err.(*appErrors.AppError)
				if !ok {
					t.Errorf("Expected AppError but got: %T", err)
					return
				}
				if appErr.Message != tt.errorMsg {
					t.Errorf("Expected error '%s' but got '%s'", tt.errorMsg, appErr.Message)
				}
			} else {
				if err != nil {
					t.Errorf("Expected no error but got: %v", err)
				}
			}
		})
	}
}
