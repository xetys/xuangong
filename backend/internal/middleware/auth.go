package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/pkg/auth"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

// Auth middleware validates JWT tokens
func Auth(authService *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			respondWithError(c, appErrors.NewAuthenticationError("Authorization header required"))
			return
		}

		token, err := auth.ExtractTokenFromHeader(authHeader)
		if err != nil {
			respondWithError(c, appErrors.NewAuthenticationError("Invalid authorization header format"))
			return
		}

		claims, err := authService.ValidateAccessToken(token)
		if err != nil {
			respondWithError(c, appErrors.NewAuthenticationError("Invalid or expired token"))
			return
		}

		// Set user information in context
		c.Set("user_id", claims.UserID)
		c.Set("user_email", claims.Email)
		c.Set("user_role", claims.Role)

		c.Next()
	}
}

// RequireRole middleware ensures the user has the required role
func RequireRole(role string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userRole, exists := c.Get("user_role")
		if !exists {
			respondWithError(c, appErrors.NewAuthenticationError("User not authenticated"))
			return
		}

		if userRole.(string) != role {
			respondWithError(c, appErrors.NewAuthorizationError("Insufficient permissions"))
			return
		}

		c.Next()
	}
}

// GetUserID extracts user ID from context
func GetUserID(c *gin.Context) (uuid.UUID, error) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, appErrors.NewAuthenticationError("User not authenticated")
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		return uuid.Nil, appErrors.NewInternalError("Invalid user ID format")
	}

	return userID, nil
}

// GetUserRole extracts user role from context
func GetUserRole(c *gin.Context) (string, error) {
	userRole, exists := c.Get("user_role")
	if !exists {
		return "", appErrors.NewAuthenticationError("User not authenticated")
	}
	return userRole.(string), nil
}

// IsAdmin checks if the current user is an admin
func IsAdmin(c *gin.Context) bool {
	role, err := GetUserRole(c)
	if err != nil {
		return false
	}
	return strings.EqualFold(role, "admin")
}

func respondWithError(c *gin.Context, err *appErrors.AppError) {
	c.JSON(err.HTTPStatus, gin.H{
		"error": gin.H{
			"code":    err.Code,
			"message": err.Message,
			"details": err.Details,
		},
	})
	c.Abort()
}
