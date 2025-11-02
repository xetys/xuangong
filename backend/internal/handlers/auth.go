package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/xuangong/backend/internal/middleware"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type AuthHandler struct {
	authService *services.AuthService
	validate    *validator.Validate
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		validate:    validator.New(),
	}
}

// Register godoc
// @Summary Register a new user
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.RegisterRequest true "Registration details"
// @Success 201 {object} map[string]interface{}
// @Router /api/v1/auth/register [post]
func (h *AuthHandler) Register(c *gin.Context) {
	var req validators.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	user, tokens, err := h.authService.Register(
		c.Request.Context(),
		req.Email,
		req.Password,
		req.FullName,
		models.RoleStudent, // Default role for registration
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"user":   user.ToResponse(),
		"tokens": tokens,
	})
}

// Login godoc
// @Summary Login user
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.LoginRequest true "Login credentials"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req validators.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	user, tokens, err := h.authService.Login(
		c.Request.Context(),
		req.Email,
		req.Password,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"user":   user.ToResponse(),
		"tokens": tokens,
	})
}

// RefreshToken godoc
// @Summary Refresh access token
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.RefreshTokenRequest true "Refresh token"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/refresh [post]
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req validators.RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	tokens, err := h.authService.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"tokens": tokens,
	})
}

// Logout godoc
// @Summary Logout user
// @Tags auth
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/logout [post]
// @Security BearerAuth
func (h *AuthHandler) Logout(c *gin.Context) {
	// In a stateless JWT setup, logout is typically handled client-side
	// by discarding the token. For now, just return success.
	// In production, you might want to implement token blacklisting.
	c.JSON(http.StatusOK, gin.H{
		"message": "Logged out successfully",
	})
}

// GetProfile godoc
// @Summary Get current user profile
// @Tags auth
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/me [get]
// @Security BearerAuth
func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	user, err := h.authService.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, user.ToResponse())
}

// UpdateProfile godoc
// @Summary Update current user profile
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.UpdateProfileRequest true "Profile update details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/me [put]
// @Security BearerAuth
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	var req validators.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.authService.UpdateProfile(c.Request.Context(), userID, req.Email, req.FullName); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
	})
}

// ChangePassword godoc
// @Summary Change user password
// @Tags auth
// @Accept json
// @Produce json
// @Param request body validators.ChangePasswordRequest true "Password change details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/auth/change-password [put]
// @Security BearerAuth
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	var req validators.ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.authService.ChangePassword(c.Request.Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Password changed successfully",
	})
}
