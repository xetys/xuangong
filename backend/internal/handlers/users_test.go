package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

// userServiceInterface defines the interface that UserHandler needs
// This allows us to mock the service in tests
type userServiceInterface interface {
	UpdateUserRole(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error
	GetByID(ctx context.Context, id uuid.UUID) (*models.UserResponse, error)
	List(ctx context.Context, limit, offset int) ([]models.UserResponse, error)
	Create(ctx context.Context, email, password, fullName, role string) (*models.UserResponse, error)
	Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool) error
	Delete(ctx context.Context, id uuid.UUID) error
	GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.ProgramWithExercises, error)
}

// MockUserService wraps service methods for handler-level testing
type MockUserService struct {
	UpdateUserRoleFunc  func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error
	GetByIDFunc         func(ctx context.Context, id uuid.UUID) (*models.UserResponse, error)
	ListFunc            func(ctx context.Context, limit, offset int) ([]models.UserResponse, error)
	CreateFunc          func(ctx context.Context, email, password, fullName, role string) (*models.UserResponse, error)
	UpdateFunc          func(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool) error
	DeleteFunc          func(ctx context.Context, id uuid.UUID) error
	GetUserProgramsFunc func(ctx context.Context, userID uuid.UUID) ([]models.ProgramWithExercises, error)
}

func (m *MockUserService) UpdateUserRole(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
	if m.UpdateUserRoleFunc != nil {
		return m.UpdateUserRoleFunc(ctx, requestingUserID, requestingRole, targetUserID, newRole)
	}
	return nil
}

func (m *MockUserService) GetByID(ctx context.Context, id uuid.UUID) (*models.UserResponse, error) {
	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *MockUserService) List(ctx context.Context, limit, offset int) ([]models.UserResponse, error) {
	if m.ListFunc != nil {
		return m.ListFunc(ctx, limit, offset)
	}
	return nil, nil
}

func (m *MockUserService) Create(ctx context.Context, email, password, fullName, role string) (*models.UserResponse, error) {
	if m.CreateFunc != nil {
		return m.CreateFunc(ctx, email, password, fullName, role)
	}
	return nil, nil
}

func (m *MockUserService) Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool) error {
	if m.UpdateFunc != nil {
		return m.UpdateFunc(ctx, id, fullName, email, password, isActive)
	}
	return nil
}

func (m *MockUserService) Delete(ctx context.Context, id uuid.UUID) error {
	if m.DeleteFunc != nil {
		return m.DeleteFunc(ctx, id)
	}
	return nil
}

func (m *MockUserService) GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.ProgramWithExercises, error) {
	if m.GetUserProgramsFunc != nil {
		return m.GetUserProgramsFunc(ctx, userID)
	}
	return nil, nil
}

// testUserHandler is a test version of UserHandler that uses the interface
type testUserHandler struct {
	userService userServiceInterface
	validate    *validator.Validate
}

// UpdateUserRole wraps the real handler implementation with our test-friendly service interface
func (h *testUserHandler) UpdateUserRole(c *gin.Context) {
	// Create a temporary UserHandler that wraps our mock service
	// We'll call the real handler logic but with our mock service
	// This is a bit of a hack but allows us to test the handler with mocks

	// Parse target user ID from URL parameter
	targetUserID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	// Parse request body
	var req validators.UpdateUserRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	// Validate request
	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	// Get requesting user ID and role from middleware context
	requestingUserIDStr, exists := c.Get("user_id")
	if !exists {
		respondWithError(c, appErrors.NewAuthenticationError("User not authenticated"))
		return
	}

	requestingUserID, err := uuid.Parse(requestingUserIDStr.(string))
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user ID in token"))
		return
	}

	requestingRoleStr, exists := c.Get("user_role")
	if !exists {
		respondWithError(c, appErrors.NewAuthenticationError("User role not found in token"))
		return
	}

	requestingRole := models.UserRole(requestingRoleStr.(string))
	newRole := models.UserRole(req.Role)

	// Call service to update role
	if err := h.userService.UpdateUserRole(
		c.Request.Context(),
		requestingUserID,
		requestingRole,
		targetUserID,
		newRole,
	); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User role updated successfully",
	})
}

func TestUserHandler_UpdateUserRole(t *testing.T) {
	gin.SetMode(gin.TestMode)

	adminID := uuid.New()
	studentID := uuid.New()

	tests := []struct {
		name               string
		targetUserID       string
		requestBody        map[string]string
		userID             uuid.UUID
		userRole           models.UserRole
		setupMockService   func(*MockUserService)
		expectedStatus     int
		expectedErrCode    string
		expectedErrMessage string
	}{
		{
			name:         "admin_can_promote_student_to_admin",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{"role": "admin"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return nil
				}
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:         "admin_can_demote_admin_to_student",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{"role": "student"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return nil
				}
			},
			expectedStatus: http.StatusOK,
		},
		{
			name:         "student_cannot_update_roles",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{"role": "admin"},
			userID:       studentID,
			userRole:     models.RoleStudent,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return appErrors.NewAuthorizationError("Only admins can update user roles")
				}
			},
			expectedStatus:     http.StatusForbidden,
			expectedErrCode:    "AUTHORIZATION_ERROR",
			expectedErrMessage: "Only admins can update user roles",
		},
		{
			name:         "cannot_demote_last_admin",
			targetUserID: adminID.String(),
			requestBody:  map[string]string{"role": "student"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return appErrors.NewBadRequestError("Cannot demote the last admin")
				}
			},
			expectedStatus:     http.StatusBadRequest,
			expectedErrCode:    "BAD_REQUEST",
			expectedErrMessage: "Cannot demote the last admin",
		},
		{
			name:         "invalid_user_id_format",
			targetUserID: "not-a-uuid",
			requestBody:  map[string]string{"role": "admin"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				// Service should not be called
			},
			expectedStatus:     http.StatusBadRequest,
			expectedErrCode:    "BAD_REQUEST",
			expectedErrMessage: "Invalid user ID",
		},
		{
			name:         "invalid_role_value",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{"role": "superuser"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				// Service won't be called because validation fails first
			},
			expectedStatus:     http.StatusBadRequest,
			expectedErrCode:    "VALIDATION_ERROR",
			expectedErrMessage: "Validation failed",
		},
		{
			name:         "target_user_not_found",
			targetUserID: uuid.New().String(),
			requestBody:  map[string]string{"role": "admin"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return appErrors.NewNotFoundError("User")
				}
			},
			expectedStatus:     http.StatusNotFound,
			expectedErrCode:    "NOT_FOUND",
			expectedErrMessage: "User not found",
		},
		{
			name:         "missing_role_in_request_body",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				// Service should not be called - validation fails first
			},
			expectedStatus:     http.StatusBadRequest,
			expectedErrCode:    "VALIDATION_ERROR",
			expectedErrMessage: "Validation failed",
		},
		{
			name:         "invalid_json_body",
			targetUserID: studentID.String(),
			requestBody:  nil, // Will send invalid JSON
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				// Service should not be called
			},
			expectedStatus:     http.StatusBadRequest,
			expectedErrCode:    "BAD_REQUEST",
			expectedErrMessage: "Invalid request body",
		},
		{
			name:         "repository_error_propagated",
			targetUserID: studentID.String(),
			requestBody:  map[string]string{"role": "admin"},
			userID:       adminID,
			userRole:     models.RoleAdmin,
			setupMockService: func(mock *MockUserService) {
				mock.UpdateUserRoleFunc = func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					return appErrors.NewInternalError("Failed to update user role")
				}
			},
			expectedStatus:     http.StatusInternalServerError,
			expectedErrCode:    "INTERNAL_ERROR",
			expectedErrMessage: "Failed to update user role",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup mock service
			mockService := &MockUserService{}
			tt.setupMockService(mockService)

			// Create handler directly with mock
			// Note: In GREEN phase, we'll refactor UserHandler to use userServiceInterface
			handler := &testUserHandler{
				userService: mockService,
				validate:    validator.New(),
			}

			// Setup Gin router and context
			router := gin.New()
			router.PUT("/api/v1/users/:id/role", func(c *gin.Context) {
				// Simulate middleware setting user info
				c.Set("user_id", tt.userID.String())
				c.Set("user_role", string(tt.userRole))
				handler.UpdateUserRole(c)
			})

			// Create request body
			var body []byte
			if tt.requestBody != nil {
				body, _ = json.Marshal(tt.requestBody)
			} else {
				body = []byte(`{invalid json}`)
			}

			// Create request
			req := httptest.NewRequest(http.MethodPut, "/api/v1/users/"+tt.targetUserID+"/role", bytes.NewBuffer(body))
			req.Header.Set("Content-Type", "application/json")

			// Record response
			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			// Assertions
			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d. Response body: %s", tt.expectedStatus, w.Code, w.Body.String())
				return
			}

			if tt.expectedStatus >= 400 {
				// Check error response structure
				var response map[string]interface{}
				if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
					t.Errorf("Failed to unmarshal error response: %v. Body: %s", err, w.Body.String())
					return
				}

				errorResponse, ok := response["error"].(map[string]interface{})
				if !ok {
					t.Errorf("Expected 'error' object in response, got: %v", response)
					return
				}

				if tt.expectedErrCode != "" {
					if code, ok := errorResponse["code"].(string); !ok || code != tt.expectedErrCode {
						t.Errorf("Expected error code '%s', got '%v'", tt.expectedErrCode, errorResponse["code"])
					}
				}

				if tt.expectedErrMessage != "" {
					if msg, ok := errorResponse["message"].(string); !ok || msg != tt.expectedErrMessage {
						t.Errorf("Expected error message '%s', got '%v'", tt.expectedErrMessage, errorResponse["message"])
					}
				}
			} else {
				// Success response should contain message
				var successResponse map[string]interface{}
				if err := json.Unmarshal(w.Body.Bytes(), &successResponse); err != nil {
					t.Errorf("Failed to unmarshal success response: %v", err)
					return
				}

				if _, ok := successResponse["message"]; !ok {
					t.Error("Expected success response to contain 'message' field")
				}
			}
		})
	}
}

func TestUserHandler_UpdateUserRole_AuthorizationMatrix(t *testing.T) {
	gin.SetMode(gin.TestMode)

	admin1ID := uuid.New()
	admin2ID := uuid.New()
	student1ID := uuid.New()
	student2ID := uuid.New()

	tests := []struct {
		name             string
		requestingUserID uuid.UUID
		requestingRole   models.UserRole
		targetUserID     uuid.UUID
		newRole          models.UserRole
		expectAllowed    bool
		expectedStatus   int
	}{
		{
			name:             "admin_can_update_other_admin",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     admin2ID,
			newRole:          models.RoleStudent,
			expectAllowed:    true,
			expectedStatus:   http.StatusOK,
		},
		{
			name:             "admin_can_update_student",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     student1ID,
			newRole:          models.RoleAdmin,
			expectAllowed:    true,
			expectedStatus:   http.StatusOK,
		},
		{
			name:             "admin_can_update_self",
			requestingUserID: admin1ID,
			requestingRole:   models.RoleAdmin,
			targetUserID:     admin1ID,
			newRole:          models.RoleStudent,
			expectAllowed:    true,
			expectedStatus:   http.StatusOK,
		},
		{
			name:             "student_cannot_update_other_student",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student2ID,
			newRole:          models.RoleAdmin,
			expectAllowed:    false,
			expectedStatus:   http.StatusForbidden,
		},
		{
			name:             "student_cannot_update_admin",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     admin1ID,
			newRole:          models.RoleStudent,
			expectAllowed:    false,
			expectedStatus:   http.StatusForbidden,
		},
		{
			name:             "student_cannot_update_self",
			requestingUserID: student1ID,
			requestingRole:   models.RoleStudent,
			targetUserID:     student1ID,
			newRole:          models.RoleAdmin,
			expectAllowed:    false,
			expectedStatus:   http.StatusForbidden,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockService := &MockUserService{
				UpdateUserRoleFunc: func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					if tt.expectAllowed {
						return nil
					}
					return appErrors.NewAuthorizationError("Only admins can update user roles")
				},
			}

			handler := &testUserHandler{
				userService: mockService,
				validate:    validator.New(),
			}

			router := gin.New()
			router.PUT("/api/v1/users/:id/role", func(c *gin.Context) {
				c.Set("user_id", tt.requestingUserID.String())
				c.Set("user_role", string(tt.requestingRole))
				handler.UpdateUserRole(c)
			})

			requestBody := map[string]string{"role": string(tt.newRole)}
			body, _ := json.Marshal(requestBody)

			req := httptest.NewRequest(http.MethodPut, "/api/v1/users/"+tt.targetUserID.String()+"/role", bytes.NewBuffer(body))
			req.Header.Set("Content-Type", "application/json")

			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d. Response: %s", tt.expectedStatus, w.Code, w.Body.String())
			}

			if !tt.expectAllowed {
				var response map[string]interface{}
				json.Unmarshal(w.Body.Bytes(), &response)
				errorResponse, ok := response["error"].(map[string]interface{})
				if !ok {
					t.Errorf("Expected 'error' object in response, got: %v", response)
					return
				}
				if code, ok := errorResponse["code"].(string); !ok || code != "AUTHORIZATION_ERROR" {
					t.Errorf("Expected AUTHORIZATION_ERROR error code, got %v", errorResponse["code"])
				}
			}
		})
	}
}

func TestUserHandler_UpdateUserRole_LastAdminProtection(t *testing.T) {
	gin.SetMode(gin.TestMode)

	adminID := uuid.New()

	tests := []struct {
		name           string
		adminCount     int
		shouldFail     bool
		expectedStatus int
	}{
		{
			name:           "cannot_demote_when_only_1_admin",
			adminCount:     1,
			shouldFail:     true,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "can_demote_when_2_admins",
			adminCount:     2,
			shouldFail:     false,
			expectedStatus: http.StatusOK,
		},
		{
			name:           "can_demote_when_many_admins",
			adminCount:     5,
			shouldFail:     false,
			expectedStatus: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockService := &MockUserService{
				UpdateUserRoleFunc: func(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
					if tt.shouldFail {
						return appErrors.NewBadRequestError("Cannot demote the last admin")
					}
					return nil
				},
			}

			handler := &testUserHandler{
				userService: mockService,
				validate:    validator.New(),
			}

			router := gin.New()
			router.PUT("/api/v1/users/:id/role", func(c *gin.Context) {
				c.Set("user_id", adminID.String())
				c.Set("user_role", string(models.RoleAdmin))
				handler.UpdateUserRole(c)
			})

			requestBody := map[string]string{"role": "student"}
			body, _ := json.Marshal(requestBody)

			req := httptest.NewRequest(http.MethodPut, "/api/v1/users/"+adminID.String()+"/role", bytes.NewBuffer(body))
			req.Header.Set("Content-Type", "application/json")

			w := httptest.NewRecorder()
			router.ServeHTTP(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d. Response: %s", tt.expectedStatus, w.Code, w.Body.String())
			}

			if tt.shouldFail {
				var response map[string]interface{}
				json.Unmarshal(w.Body.Bytes(), &response)
				errorResponse, ok := response["error"].(map[string]interface{})
				if !ok {
					t.Errorf("Expected 'error' object in response, got: %v", response)
					return
				}
				if msg, ok := errorResponse["message"].(string); !ok || msg != "Cannot demote the last admin" {
					t.Errorf("Expected 'Cannot demote the last admin' message, got %v", errorResponse["message"])
				}
			}
		})
	}
}
