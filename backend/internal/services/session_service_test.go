package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	appErrors "github.com/xuangong/backend/pkg/errors"
	"github.com/xuangong/backend/pkg/testutil"
)

func TestSessionService_GetUserSessions(t *testing.T) {
	ctx := context.Background()

	adminID := uuid.New()
	student1ID := uuid.New()
	student2ID := uuid.New()
	programID := uuid.New()

	tests := []struct {
		name             string
		requestingUserID uuid.UUID
		requestingRole   models.UserRole
		targetUserID     uuid.UUID
		programID        *uuid.UUID
		setupMocks       func(*testutil.MockSessionRepository, *testutil.MockProgramRepository)
		expectError      bool
		expectedErrMsg   string
		expectedCount    int
	}{
		{
			name:             "admin_can_view_any_user_sessions",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			programID:        nil,
			setupMocks: func(sessionRepo *testutil.MockSessionRepository, programRepo *testutil.MockProgramRepository) {
				sessionRepo.ListByUserIDFunc = func(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
					// Return mock sessions for student1
					return []models.PracticeSession{
						{ID: uuid.New(), UserID: student1ID, ProgramID: programID},
						{ID: uuid.New(), UserID: student1ID, ProgramID: programID},
					}, nil
				}
			},
			expectError:   false,
			expectedCount: 2,
		},
		{
			name:             "admin_can_filter_by_program",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			programID:        &programID,
			setupMocks: func(sessionRepo *testutil.MockSessionRepository, programRepo *testutil.MockProgramRepository) {
				sessionRepo.ListByUserIDFunc = func(ctx context.Context, userID uuid.UUID, pid *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
					// Should be called with programID filter
					if pid == nil || *pid != programID {
						return nil, errors.New("expected programID filter")
					}
					return []models.PracticeSession{
						{ID: uuid.New(), UserID: student1ID, ProgramID: programID},
					}, nil
				}
			},
			expectError:   false,
			expectedCount: 1,
		},
		{
			name:             "student_can_view_own_sessions",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student1ID, // Same as requesting user
			programID:        nil,
			setupMocks: func(sessionRepo *testutil.MockSessionRepository, programRepo *testutil.MockProgramRepository) {
				sessionRepo.ListByUserIDFunc = func(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
					return []models.PracticeSession{
						{ID: uuid.New(), UserID: student1ID, ProgramID: uuid.New()},
					}, nil
				}
			},
			expectError:   false,
			expectedCount: 1,
		},
		{
			name:             "student_cannot_view_other_user_sessions",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student2ID, // Different from requesting user
			programID:        nil,
			setupMocks: func(sessionRepo *testutil.MockSessionRepository, programRepo *testutil.MockProgramRepository) {
				// Repository should not be called
			},
			expectError:    true,
			expectedErrMsg: "You don't have permission to view these sessions",
		},
		{
			name:             "repository_error_propagated",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			programID:        nil,
			setupMocks: func(sessionRepo *testutil.MockSessionRepository, programRepo *testutil.MockProgramRepository) {
				sessionRepo.ListByUserIDFunc = func(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
					return nil, errors.New("database error")
				}
			},
			expectError:    true,
			expectedErrMsg: "Failed to fetch user sessions",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSessionRepo := &testutil.MockSessionRepository{}
			mockProgramRepo := &testutil.MockProgramRepository{}
			tt.setupMocks(mockSessionRepo, mockProgramRepo)

			service := NewSessionService(mockSessionRepo, mockProgramRepo)

			// Call GetUserSessions (method doesn't exist yet - RED phase)
			sessions, err := service.GetUserSessions(ctx, tt.requestingUserID, tt.requestingRole, tt.targetUserID, tt.programID, nil, nil, 100, 0)

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
					return
				}
				if len(sessions) != tt.expectedCount {
					t.Errorf("Expected %d sessions but got %d", tt.expectedCount, len(sessions))
				}
			}
		})
	}
}

func TestSessionService_GetUserSessions_AuthorizationLogic(t *testing.T) {
	ctx := context.Background()

	adminID := uuid.New()
	studentID := uuid.New()
	otherStudentID := uuid.New()

	tests := []struct {
		name             string
		requestingUserID uuid.UUID
		requestingRole   models.UserRole
		targetUserID     uuid.UUID
		expectAllowed    bool
	}{
		{
			name:             "admin_views_own_sessions",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     adminID,
			expectAllowed:    true,
		},
		{
			name:             "admin_views_student_sessions",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     studentID,
			expectAllowed:    true,
		},
		{
			name:             "admin_views_different_student_sessions",
			requestingUserID: adminID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     otherStudentID,
			expectAllowed:    true,
		},
		{
			name:             "student_views_own_sessions",
			requestingUserID: studentID,
			requestingRole:   models.RoleStudent,
			targetUserID:     studentID,
			expectAllowed:    true,
		},
		{
			name:             "student_cannot_view_other_sessions",
			requestingUserID: studentID,
			requestingRole:   models.RoleStudent,
			targetUserID:     otherStudentID,
			expectAllowed:    false,
		},
		{
			name:             "student_cannot_view_admin_sessions",
			requestingUserID: studentID,
			requestingRole:   models.RoleStudent,
			targetUserID:     adminID,
			expectAllowed:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockSessionRepo := &testutil.MockSessionRepository{
				ListByUserIDFunc: func(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
					return []models.PracticeSession{}, nil
				},
			}
			mockProgramRepo := &testutil.MockProgramRepository{}

			service := NewSessionService(mockSessionRepo, mockProgramRepo)

			_, err := service.GetUserSessions(ctx, tt.requestingUserID, tt.requestingRole, tt.targetUserID, nil, nil, nil, 100, 0)

			if tt.expectAllowed {
				if err != nil {
					t.Errorf("Expected no error but got: %v", err)
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

func TestSessionService_GetUserSessions_PassesThroughFilters(t *testing.T) {
	ctx := context.Background()

	adminID := uuid.New()
	studentID := uuid.New()
	programID := uuid.New()
	startDate := time.Now().Add(-7 * 24 * time.Hour)
	endDate := time.Now()

	mockSessionRepo := &testutil.MockSessionRepository{
		ListByUserIDFunc: func(ctx context.Context, userID uuid.UUID, pid *uuid.UUID, start, end *time.Time, limit, offset int) ([]models.PracticeSession, error) {
			// Verify all parameters are passed through correctly
			if userID != studentID {
				t.Errorf("Expected userID %s but got %s", studentID, userID)
			}
			if pid == nil || *pid != programID {
				t.Error("Expected programID filter to be passed through")
			}
			if start == nil || !start.Equal(startDate) {
				t.Error("Expected startDate filter to be passed through")
			}
			if end == nil || !end.Equal(endDate) {
				t.Error("Expected endDate filter to be passed through")
			}
			if limit != 50 {
				t.Errorf("Expected limit 50 but got %d", limit)
			}
			if offset != 10 {
				t.Errorf("Expected offset 10 but got %d", offset)
			}
			return []models.PracticeSession{}, nil
		},
	}
	mockProgramRepo := &testutil.MockProgramRepository{}

	service := NewSessionService(mockSessionRepo, mockProgramRepo)

	_, err := service.GetUserSessions(ctx, adminID, models.RoleAdmin, studentID, &programID, &startDate, &endDate, 50, 10)

	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
}
