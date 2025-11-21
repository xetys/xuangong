package services

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/config"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	"github.com/xuangong/backend/pkg/auth"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type AuthService struct {
	userRepo *repositories.UserRepository
	cfg      *config.Config
}

func NewAuthService(userRepo *repositories.UserRepository, cfg *config.Config) *AuthService {
	return &AuthService{
		userRepo: userRepo,
		cfg:      cfg,
	}
}

func (s *AuthService) Register(ctx context.Context, email, password, fullName string, role models.UserRole) (*models.User, *auth.TokenPair, error) {
	// Check if email already exists
	exists, err := s.userRepo.EmailExists(ctx, email)
	if err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to check email existence").WithError(err)
	}
	if exists {
		return nil, nil, appErrors.NewConflictError("Email already registered")
	}

	// Hash password
	passwordHash, err := auth.HashPassword(password)
	if err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to hash password").WithError(err)
	}

	// Create user
	user := &models.User{
		Email:        email,
		PasswordHash: passwordHash,
		FullName:     fullName,
		Role:         role,
		IsActive:     true,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to create user").WithError(err)
	}

	// Generate tokens
	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*models.User, *auth.TokenPair, error) {
	// Get user by email
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return nil, nil, appErrors.NewAuthenticationError("Invalid email or password")
	}

	// Check if user is active
	if !user.IsActive {
		return nil, nil, appErrors.NewAuthenticationError("Account is inactive")
	}

	// Verify password
	if !auth.CheckPassword(password, user.PasswordHash) {
		return nil, nil, appErrors.NewAuthenticationError("Invalid email or password")
	}

	// Generate tokens
	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*auth.TokenPair, error) {
	// Validate refresh token
	claims, err := auth.ValidateToken(refreshToken, s.cfg.JWT.Secret, auth.RefreshToken)
	if err != nil {
		return nil, appErrors.NewAuthenticationError("Invalid refresh token")
	}

	// Get user to ensure they still exist and are active
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, appErrors.NewAuthenticationError("Invalid user ID in token")
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil || !user.IsActive {
		return nil, appErrors.NewAuthenticationError("User not found or inactive")
	}

	// Generate new token pair
	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, err
	}

	return tokens, nil
}

func (s *AuthService) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, id)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return nil, appErrors.NewNotFoundError("User")
	}
	return user, nil
}

func (s *AuthService) generateTokens(user *models.User) (*auth.TokenPair, error) {
	tokens, err := auth.GenerateTokenPair(
		user.ID.String(),
		user.Email,
		string(user.Role),
		s.cfg.JWT.Secret,
		s.cfg.JWT.GetJWTExpiry(),
		s.cfg.JWT.GetRefreshExpiry(),
	)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to generate tokens").WithError(err)
	}
	return tokens, nil
}

func (s *AuthService) UpdateProfile(ctx context.Context, userID uuid.UUID, email, fullName *string, countdownVolume, startVolume, halfwayVolume, finishVolume *int) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return appErrors.NewNotFoundError("User")
	}

	// Check if email is being changed and if it already exists
	if email != nil && *email != user.Email {
		exists, err := s.userRepo.EmailExists(ctx, *email)
		if err != nil {
			return appErrors.NewInternalError("Failed to check email existence").WithError(err)
		}
		if exists {
			return appErrors.NewConflictError("Email already in use")
		}
	}

	// Update user fields
	if email != nil {
		user.Email = *email
	}
	if fullName != nil {
		user.FullName = *fullName
	}
	if countdownVolume != nil {
		user.CountdownVolume = *countdownVolume
	}
	if startVolume != nil {
		user.StartVolume = *startVolume
	}
	if halfwayVolume != nil {
		user.HalfwayVolume = *halfwayVolume
	}
	if finishVolume != nil {
		user.FinishVolume = *finishVolume
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return appErrors.NewInternalError("Failed to update profile").WithError(err)
	}

	return nil
}

func (s *AuthService) ChangePassword(ctx context.Context, userID uuid.UUID, currentPassword, newPassword string) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch user").WithError(err)
	}
	if user == nil {
		return appErrors.NewNotFoundError("User")
	}

	// Verify current password
	if !auth.CheckPassword(currentPassword, user.PasswordHash) {
		return appErrors.NewAuthenticationError("Current password is incorrect")
	}

	// Hash new password
	passwordHash, err := auth.HashPassword(newPassword)
	if err != nil {
		return appErrors.NewInternalError("Failed to hash password").WithError(err)
	}

	// Update password
	user.PasswordHash = passwordHash
	if err := s.userRepo.Update(ctx, user); err != nil {
		return appErrors.NewInternalError("Failed to update password").WithError(err)
	}

	return nil
}

func (s *AuthService) ValidateAccessToken(token string) (*auth.Claims, error) {
	claims, err := auth.ValidateToken(token, s.cfg.JWT.Secret, auth.AccessToken)
	if err != nil {
		return nil, fmt.Errorf("invalid access token: %w", err)
	}
	return claims, nil
}

// Impersonate allows an admin to impersonate another user
func (s *AuthService) Impersonate(ctx context.Context, adminID, targetUserID uuid.UUID) (*models.User, *auth.TokenPair, error) {
	// Verify the admin user
	admin, err := s.userRepo.GetByID(ctx, adminID)
	if err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to fetch admin user").WithError(err)
	}
	if admin == nil || !admin.IsAdmin() {
		return nil, nil, appErrors.NewAuthorizationError("Only admins can impersonate users")
	}

	// Get the target user
	targetUser, err := s.userRepo.GetByID(ctx, targetUserID)
	if err != nil {
		return nil, nil, appErrors.NewInternalError("Failed to fetch target user").WithError(err)
	}
	if targetUser == nil {
		return nil, nil, appErrors.NewNotFoundError("Target user")
	}

	// Generate tokens for the target user
	tokens, err := s.generateTokens(targetUser)
	if err != nil {
		return nil, nil, err
	}

	return targetUser, tokens, nil
}
