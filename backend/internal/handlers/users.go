package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type UserHandler struct {
	userService *services.UserService
	validate    *validator.Validate
}

func NewUserHandler(userService *services.UserService) *UserHandler {
	return &UserHandler{
		userService: userService,
		validate:    validator.New(),
	}
}

// ListUsers godoc
// @Summary List all users (admin only)
// @Tags users
// @Produce json
// @Param limit query int false "Limit" default(20)
// @Param offset query int false "Offset" default(0)
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/users [get]
// @Security BearerAuth
func (h *UserHandler) ListUsers(c *gin.Context) {
	var query struct {
		Limit  int `form:"limit" validate:"min=1,max=100"`
		Offset int `form:"offset" validate:"min=0"`
	}

	if err := c.ShouldBindQuery(&query); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid query parameters"))
		return
	}

	// Set defaults
	if query.Limit == 0 {
		query.Limit = 20
	}

	users, err := h.userService.List(c.Request.Context(), query.Limit, query.Offset)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"users":  users,
		"limit":  query.Limit,
		"offset": query.Offset,
	})
}

// GetUser godoc
// @Summary Get user by ID (admin only)
// @Tags users
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} models.UserResponse
// @Router /api/v1/users/{id} [get]
// @Security BearerAuth
func (h *UserHandler) GetUser(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	user, err := h.userService.GetByID(c.Request.Context(), id)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, user)
}

// CreateUser godoc
// @Summary Create a new user (admin only)
// @Tags users
// @Accept json
// @Produce json
// @Param request body validators.CreateUserRequest true "User details"
// @Success 201 {object} models.UserResponse
// @Router /api/v1/users [post]
// @Security BearerAuth
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req validators.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	user, err := h.userService.Create(
		c.Request.Context(),
		req.Email,
		req.Password,
		req.FullName,
		req.Role,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, user)
}

// UpdateUser godoc
// @Summary Update a user (admin only)
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Param request body validators.UpdateUserRequest true "Updated user details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/users/{id} [put]
// @Security BearerAuth
func (h *UserHandler) UpdateUser(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	var req validators.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.userService.Update(
		c.Request.Context(),
		id,
		req.FullName,
		req.Email,
		req.Password,
		req.IsActive,
	); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User updated successfully",
	})
}

// DeleteUser godoc
// @Summary Delete a user (admin only)
// @Tags users
// @Param id path string true "User ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/users/{id} [delete]
// @Security BearerAuth
func (h *UserHandler) DeleteUser(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	if err := h.userService.Delete(c.Request.Context(), id); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User deleted successfully",
	})
}

// GetUserPrograms godoc
// @Summary Get programs for a specific user (admin only)
// @Tags users
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/users/{id}/programs [get]
// @Security BearerAuth
func (h *UserHandler) GetUserPrograms(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	programs, err := h.userService.GetUserPrograms(c.Request.Context(), id)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"programs": programs,
	})
}
