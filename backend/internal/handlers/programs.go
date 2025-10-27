package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/middleware"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type ProgramHandler struct {
	programService *services.ProgramService
	validate       *validator.Validate
}

func NewProgramHandler(programService *services.ProgramService) *ProgramHandler {
	return &ProgramHandler{
		programService: programService,
		validate:       validator.New(),
	}
}

// ListPrograms godoc
// @Summary List programs
// @Tags programs
// @Produce json
// @Param is_template query boolean false "Filter by template status"
// @Param is_public query boolean false "Filter by public status"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs [get]
// @Security BearerAuth
func (h *ProgramHandler) ListPrograms(c *gin.Context) {
	var query validators.ListProgramsQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid query parameters"))
		return
	}

	// Set defaults
	if query.Limit == 0 {
		query.Limit = 20
	}

	programs, err := h.programService.List(
		c.Request.Context(),
		query.IsTemplate,
		query.IsPublic,
		query.Limit,
		query.Offset,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"programs": programs,
		"limit":    query.Limit,
		"offset":   query.Offset,
	})
}

// GetProgram godoc
// @Summary Get program by ID
// @Tags programs
// @Produce json
// @Param id path string true "Program ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id} [get]
// @Security BearerAuth
func (h *ProgramHandler) GetProgram(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	program, err := h.programService.GetByID(c.Request.Context(), id, true)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, program)
}

// CreateProgram godoc
// @Summary Create a new program
// @Tags programs
// @Accept json
// @Produce json
// @Param request body validators.CreateProgramRequest true "Program details"
// @Success 201 {object} map[string]interface{}
// @Router /api/v1/programs [post]
// @Security BearerAuth
func (h *ProgramHandler) CreateProgram(c *gin.Context) {
	var req validators.CreateProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	program := &models.Program{
		Name:        req.Name,
		Description: req.Description,
		IsTemplate:  req.IsTemplate,
		IsPublic:    req.IsPublic,
		Tags:        req.Tags,
		Metadata:    req.Metadata,
	}

	if err := h.programService.Create(c.Request.Context(), program, userID); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, program)
}

// UpdateProgram godoc
// @Summary Update a program
// @Tags programs
// @Accept json
// @Produce json
// @Param id path string true "Program ID"
// @Param request body validators.UpdateProgramRequest true "Updated program details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id} [put]
// @Security BearerAuth
func (h *ProgramHandler) UpdateProgram(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	var req validators.UpdateProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	// Build update model
	program := &models.Program{}
	if req.Name != nil {
		program.Name = *req.Name
	}
	if req.Description != nil {
		program.Description = *req.Description
	}
	if req.IsTemplate != nil {
		program.IsTemplate = *req.IsTemplate
	}
	if req.IsPublic != nil {
		program.IsPublic = *req.IsPublic
	}
	if req.Tags != nil {
		program.Tags = req.Tags
	}
	if req.Metadata != nil {
		program.Metadata = req.Metadata
	}

	if err := h.programService.Update(c.Request.Context(), id, program); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Program updated successfully",
	})
}

// DeleteProgram godoc
// @Summary Delete a program
// @Tags programs
// @Param id path string true "Program ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id} [delete]
// @Security BearerAuth
func (h *ProgramHandler) DeleteProgram(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	if err := h.programService.Delete(c.Request.Context(), id); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Program deleted successfully",
	})
}

// AssignProgram godoc
// @Summary Assign program to users
// @Tags programs
// @Accept json
// @Produce json
// @Param id path string true "Program ID"
// @Param request body validators.AssignProgramRequest true "Assignment details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id}/assign [post]
// @Security BearerAuth
func (h *ProgramHandler) AssignProgram(c *gin.Context) {
	programID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	var req validators.AssignProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	// Parse user IDs
	var userIDs []uuid.UUID
	for _, idStr := range req.UserIDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid user ID format"))
			return
		}
		userIDs = append(userIDs, id)
	}

	if err := h.programService.AssignToUsers(
		c.Request.Context(),
		programID,
		userID,
		userIDs,
	); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Program assigned successfully",
	})
}

// GetMyPrograms godoc
// @Summary Get user's assigned programs
// @Tags programs
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/my-programs [get]
// @Security BearerAuth
func (h *ProgramHandler) GetMyPrograms(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	programs, err := h.programService.GetUserPrograms(c.Request.Context(), userID)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"programs": programs,
	})
}
