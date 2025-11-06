package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	"github.com/xuangong/backend/pkg/auth"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type UserService struct {
	userRepo     *repositories.UserRepository
	programRepo  *repositories.ProgramRepository
	exerciseRepo *repositories.ExerciseRepository
}

func NewUserService(userRepo *repositories.UserRepository, programRepo *repositories.ProgramRepository, exerciseRepo *repositories.ExerciseRepository) *UserService {
	return &UserService{
		userRepo:     userRepo,
		programRepo:  programRepo,
		exerciseRepo: exerciseRepo,
	}
}

// List returns all users (students only by default, admins can see all)
func (s *UserService) List(ctx context.Context, limit, offset int) ([]models.UserResponse, error) {
	users, err := s.userRepo.List(ctx, limit, offset)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list users").WithError(err)
	}

	// Convert to UserResponse to hide sensitive data
	responses := make([]models.UserResponse, len(users))
	for i, user := range users {
		responses[i] = models.UserResponse{
			ID:       user.ID,
			Email:    user.Email,
			FullName: user.FullName,
			Role:     user.Role,
			IsActive: user.IsActive,
		}
	}

	return responses, nil
}

// GetByID returns a user by ID
func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*models.UserResponse, error) {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return nil, appErrors.NewNotFoundError("User")
	}

	return &models.UserResponse{
		ID:       user.ID,
		Email:    user.Email,
		FullName: user.FullName,
		Role:     user.Role,
		IsActive: user.IsActive,
	}, nil
}

// Create creates a new user (admin only)
func (s *UserService) Create(ctx context.Context, email, password, fullName, role string) (*models.UserResponse, error) {
	// Check if email already exists
	exists, err := s.userRepo.EmailExists(ctx, email)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to check email").WithError(err)
	}
	if exists {
		return nil, appErrors.NewConflictError("User with this email already exists")
	}

	// Hash password
	passwordHash, err := auth.HashPassword(password)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to hash password").WithError(err)
	}

	// Default to student role if not specified
	userRole := models.UserRole(role)
	if role == "" {
		userRole = models.RoleStudent
	}

	// Validate role
	if userRole != models.RoleAdmin && userRole != models.RoleStudent {
		return nil, appErrors.NewBadRequestError("Invalid role. Must be 'admin' or 'student'")
	}

	user := &models.User{
		Email:        email,
		PasswordHash: passwordHash,
		FullName:     fullName,
		Role:         userRole,
		IsActive:     true,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, appErrors.NewInternalError("Failed to create user").WithError(err)
	}

	return &models.UserResponse{
		ID:       user.ID,
		Email:    user.Email,
		FullName: user.FullName,
		Role:     user.Role,
		IsActive: user.IsActive,
	}, nil
}

// Update updates a user's details
func (s *UserService) Update(ctx context.Context, id uuid.UUID, fullName, email *string, password *string, isActive *bool) error {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return appErrors.NewNotFoundError("User")
	}

	// Update fields if provided
	if fullName != nil {
		user.FullName = *fullName
	}
	if email != nil {
		// Check if new email already exists
		if *email != user.Email {
			exists, err := s.userRepo.EmailExists(ctx, *email)
			if err != nil {
				return appErrors.NewInternalError("Failed to check email").WithError(err)
			}
			if exists {
				return appErrors.NewConflictError("User with this email already exists")
			}
		}
		user.Email = *email
	}
	if password != nil {
		passwordHash, err := auth.HashPassword(*password)
		if err != nil {
			return appErrors.NewInternalError("Failed to hash password").WithError(err)
		}
		user.PasswordHash = passwordHash
	}
	if isActive != nil {
		user.IsActive = *isActive
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return appErrors.NewInternalError("Failed to update user").WithError(err)
	}

	return nil
}

// Delete deletes a user (with validation)
func (s *UserService) Delete(ctx context.Context, id uuid.UUID) error {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return appErrors.NewNotFoundError("User")
	}

	// Optional: Add validation to prevent deletion of users with active programs/sessions
	// For now, we'll allow deletion (database foreign keys will handle cleanup)

	if err := s.userRepo.Delete(ctx, id); err != nil {
		return appErrors.NewInternalError("Failed to delete user").WithError(err)
	}

	return nil
}

// GetUserPrograms returns programs owned by or assigned to a specific user
func (s *UserService) GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.ProgramWithExercises, error) {
	programs, err := s.programRepo.GetUserProgramsWithDetails(ctx, userID, false)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user programs").WithError(err)
	}

	// Fetch exercises for each program
	result := make([]models.ProgramWithExercises, len(programs))
	for i, program := range programs {
		exercises, err := s.exerciseRepo.ListByProgramID(ctx, program.ID)
		if err != nil {
			return nil, appErrors.NewInternalError("Failed to fetch exercises").WithError(err)
		}
		result[i] = models.ProgramWithExercises{
			Program:   program,
			Exercises: exercises,
		}
	}

	return result, nil
}

// UpdateUserRole updates a user's role (admin only)
func (s *UserService) UpdateUserRole(ctx context.Context, requestingUserID uuid.UUID, requestingRole models.UserRole, targetUserID uuid.UUID, newRole models.UserRole) error {
	// Authorization check: only admins can update user roles
	if requestingRole != models.RoleAdmin {
		return appErrors.NewAuthorizationError("Only admins can update user roles")
	}

	// Validate new role
	if newRole != models.RoleAdmin && newRole != models.RoleStudent {
		return appErrors.NewBadRequestError("Invalid role. Must be 'admin' or 'student'")
	}

	// Get target user
	targetUser, err := s.userRepo.GetByID(ctx, targetUserID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if targetUser == nil {
		return appErrors.NewNotFoundError("User")
	}

	// If demoting an admin to student, check if this is the last admin
	if targetUser.Role == models.RoleAdmin && newRole == models.RoleStudent {
		adminCount, err := s.userRepo.CountAdmins(ctx)
		if err != nil {
			return appErrors.NewInternalError("Failed to count admins").WithError(err)
		}
		if adminCount <= 1 {
			return appErrors.NewBadRequestError("Cannot demote the last admin")
		}
	}

	// Update role
	targetUser.Role = newRole
	if err := s.userRepo.Update(ctx, targetUser); err != nil {
		return appErrors.NewInternalError("Failed to update user role").WithError(err)
	}

	return nil
}
