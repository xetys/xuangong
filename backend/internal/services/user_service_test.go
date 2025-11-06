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

func TestUserService_UpdateUserRole(t *testing.T) {
	ctx := context.Background()

	adminID := uuid.New()
	student1ID := uuid.New()
	student2ID := uuid.New()

	tests := []struct {
		name             string
		requestingUserID uuid.UUID
		requestingRole   models.UserRole
		targetUserID     uuid.UUID
		newRole          models.UserRole
		setupMocks       func(*testutil.MockUserRepository)
		expectError      bool
		expectedErrMsg   string
	}{
		{
			name:             "admin_can_promote_student_to_admin",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.RoleAdmin,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(student1ID, "student1@test.com", models.RoleStudent), nil
				}
				userRepo.UpdateFunc = func(ctx context.Context, user *models.User) error {
					return nil
				}
			},
			expectError: false,
		},
		{
			name:             "admin_can_demote_admin_to_student_when_multiple_admins",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.RoleStudent,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(student1ID, "admin2@test.com", models.RoleAdmin), nil
				}
				userRepo.CountAdminsFunc = func(ctx context.Context) (int, error) {
					return 2, nil // Multiple admins exist
				}
				userRepo.UpdateFunc = func(ctx context.Context, user *models.User) error {
					return nil
				}
			},
			expectError: false,
		},
		{
			name:             "cannot_demote_last_admin",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     adminID,
			newRole:          models.RoleStudent,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(adminID, "admin@test.com", models.RoleAdmin), nil
				}
				userRepo.CountAdminsFunc = func(ctx context.Context) (int, error) {
					return 1, nil // Only one admin
				}
			},
			expectError:    true,
			expectedErrMsg: "Cannot demote the last admin",
		},
		{
			name:             "student_cannot_update_roles",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student2ID,
			newRole:          models.RoleAdmin,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				// Repository should not be called
			},
			expectError:    true,
			expectedErrMsg: "Only admins can update user roles",
		},
		{
			name:             "target_user_not_found",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     uuid.New(),
			newRole:          models.RoleAdmin,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return nil, nil // User not found
				}
			},
			expectError:    true,
			expectedErrMsg: "User not found",
		},
		{
			name:             "invalid_role_value",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.UserRole("invalid_role"),
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(student1ID, "student1@test.com", models.RoleStudent), nil
				}
			},
			expectError:    true,
			expectedErrMsg: "Invalid role. Must be 'admin' or 'student'",
		},
		{
			name:             "role_unchanged_is_valid",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.RoleStudent, // Same as current
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(student1ID, "student1@test.com", models.RoleStudent), nil
				}
				userRepo.UpdateFunc = func(ctx context.Context, user *models.User) error {
					return nil
				}
			},
			expectError: false,
		},
		{
			name:             "repository_error_propagated",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.RoleAdmin,
			setupMocks: func(userRepo *testutil.MockUserRepository) {
				userRepo.GetByIDFunc = func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return nil, errors.New("database connection failed")
				}
			},
			expectError:    true,
			expectedErrMsg: "Failed to fetch user",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockUserRepo := &testutil.MockUserRepository{}
			mockProgramRepo := &testutil.MockProgramRepository{}
			tt.setupMocks(mockUserRepo)

			service := NewUserService(mockUserRepo, mockProgramRepo)

			// Call UpdateUserRole (method doesn't exist yet - RED phase)
			err := service.UpdateUserRole(ctx, tt.requestingUserID, tt.requestingRole, tt.targetUserID, tt.newRole)

			// Assertions
			if tt.expectError {
				if err == nil {
					t.Error("Expected error but got none")
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
		})
	}
}

func TestUserService_UpdateUserRole_LastAdminProtection(t *testing.T) {
	ctx := context.Background()

	adminID := uuid.New()

	tests := []struct {
		name        string
		adminCount  int
		expectError bool
	}{
		{
			name:        "cannot_demote_when_1_admin",
			adminCount:  1,
			expectError: true,
		},
		{
			name:        "can_demote_when_2_admins",
			adminCount:  2,
			expectError: false,
		},
		{
			name:        "can_demote_when_many_admins",
			adminCount:  5,
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockUserRepo := &testutil.MockUserRepository{
				GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					return testutil.NewMockUser(adminID, "admin@test.com", models.RoleAdmin), nil
				},
				CountAdminsFunc: func(ctx context.Context) (int, error) {
					return tt.adminCount, nil
				},
				UpdateFunc: func(ctx context.Context, user *models.User) error {
					return nil
				},
			}
			mockProgramRepo := &testutil.MockProgramRepository{}

			service := NewUserService(mockUserRepo, mockProgramRepo)

			err := service.UpdateUserRole(ctx, adminID, models.RoleAdmin, adminID, models.RoleStudent)

			if tt.expectError && err == nil {
				t.Error("Expected error when demoting last admin but got none")
			}
			if !tt.expectError && err != nil {
				t.Errorf("Expected no error but got: %v", err)
			}
		})
	}
}

func TestUserService_UpdateUserRole_AuthorizationMatrix(t *testing.T) {
	ctx := context.Background()

	admin1ID := uuid.New()
	admin2ID := uuid.New()
	student1ID := uuid.New()
	student2ID := uuid.New()

	tests := []struct {
		name              string
		requestingUserID  uuid.UUID
		requestingRole    models.UserRole
		targetUserID      uuid.UUID
		expectAuthorized  bool
	}{
		{
			name:             "admin_can_update_other_admin",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     admin2ID,
			expectAuthorized: true,
		},
		{
			name:             "admin_can_update_student",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			expectAuthorized: true,
		},
		{
			name:             "admin_can_update_self",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     admin1ID,
			expectAuthorized: true,
		},
		{
			name:             "student_cannot_update_other_student",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student2ID,
			expectAuthorized: false,
		},
		{
			name:             "student_cannot_update_admin",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     admin1ID,
			expectAuthorized: false,
		},
		{
			name:             "student_cannot_update_self",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student1ID,
			expectAuthorized: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockUserRepo := &testutil.MockUserRepository{
				GetByIDFunc: func(ctx context.Context, id uuid.UUID) (*models.User, error) {
					// Return appropriate user based on ID
					role := models.RoleStudent
					if id == admin1ID || id == admin2ID {
						role = models.RoleAdmin
					}
					return testutil.NewMockUser(id, "test@test.com", role), nil
				},
				CountAdminsFunc: func(ctx context.Context) (int, error) {
					return 2, nil // Sufficient admins
				},
				UpdateFunc: func(ctx context.Context, user *models.User) error {
					return nil
				},
			}
			mockProgramRepo := &testutil.MockProgramRepository{}

			service := NewUserService(mockUserRepo, mockProgramRepo)

			err := service.UpdateUserRole(ctx, tt.requestingUserID, tt.requestingRole, tt.targetUserID, models.RoleAdmin)

			if tt.expectAuthorized {
				if err != nil {
					appErr, ok := err.(*appErrors.AppError)
					if ok && appErr.Code == "FORBIDDEN" {
						t.Error("Expected authorization to succeed but got FORBIDDEN")
					}
				}
			} else {
				if err == nil {
					t.Error("Expected authorization error but got none")
					return
				}
				appErr, ok := err.(*appErrors.AppError)
				if !ok || appErr.Code != "FORBIDDEN" {
					t.Errorf("Expected FORBIDDEN error but got: %v", err)
				}
			}
		})
	}
}
