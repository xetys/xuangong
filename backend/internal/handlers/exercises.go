package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type ExerciseHandler struct {
	exerciseService *services.ExerciseService
	validate        *validator.Validate
}

func NewExerciseHandler(exerciseService *services.ExerciseService) *ExerciseHandler {
	return &ExerciseHandler{
		exerciseService: exerciseService,
		validate:        validator.New(),
	}
}

// ListExercises godoc
// @Summary List exercises for a program
// @Tags exercises
// @Produce json
// @Param id path string true "Program ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id}/exercises [get]
// @Security BearerAuth
func (h *ExerciseHandler) ListExercises(c *gin.Context) {
	programID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	exercises, err := h.exerciseService.ListByProgram(c.Request.Context(), programID)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"exercises": exercises,
	})
}

// CreateExercise godoc
// @Summary Create a new exercise
// @Tags exercises
// @Accept json
// @Produce json
// @Param request body validators.CreateExerciseRequest true "Exercise details"
// @Success 201 {object} map[string]interface{}
// @Router /api/v1/exercises [post]
// @Security BearerAuth
func (h *ExerciseHandler) CreateExercise(c *gin.Context) {
	var req validators.CreateExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	// Debug logging
	log.Printf("CreateExercise request: %+v", req)
	log.Printf("OrderIndex value: %d", req.OrderIndex)

	if err := h.validate.Struct(req); err != nil {
		log.Printf("Validation error: %v", err)
		respondWithValidationError(c, err)
		return
	}

	programID, err := uuid.Parse(req.ProgramID)
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	exercise := &models.Exercise{
		ProgramID:           programID,
		Name:                req.Name,
		Description:         req.Description,
		OrderIndex:          req.OrderIndex,
		ExerciseType:        models.ExerciseType(req.ExerciseType),
		DurationSeconds:     req.DurationSeconds,
		Repetitions:         req.Repetitions,
		RestAfterSeconds:    req.RestAfterSeconds,
		HasSides:            req.HasSides,
		SideDurationSeconds: req.SideDurationSeconds,
		Metadata:            req.Metadata,
	}

	if err := h.exerciseService.Create(c.Request.Context(), exercise); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, exercise)
}

// UpdateExercise godoc
// @Summary Update an exercise
// @Tags exercises
// @Accept json
// @Produce json
// @Param id path string true "Exercise ID"
// @Param request body validators.UpdateExerciseRequest true "Updated exercise details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/exercises/{id} [put]
// @Security BearerAuth
func (h *ExerciseHandler) UpdateExercise(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid exercise ID"))
		return
	}

	var req validators.UpdateExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	// Build update model
	exercise := &models.Exercise{
		ID: id,
	}

	if req.Name != nil {
		exercise.Name = *req.Name
	}
	if req.Description != nil {
		exercise.Description = *req.Description
	}
	if req.OrderIndex != nil {
		exercise.OrderIndex = *req.OrderIndex
	}
	if req.ExerciseType != nil {
		exercise.ExerciseType = models.ExerciseType(*req.ExerciseType)
	}
	if req.DurationSeconds != nil {
		exercise.DurationSeconds = req.DurationSeconds
	}
	if req.Repetitions != nil {
		exercise.Repetitions = req.Repetitions
	}
	if req.RestAfterSeconds != nil {
		exercise.RestAfterSeconds = *req.RestAfterSeconds
	}
	if req.HasSides != nil {
		exercise.HasSides = *req.HasSides
	}
	if req.SideDurationSeconds != nil {
		exercise.SideDurationSeconds = req.SideDurationSeconds
	}
	if req.Metadata != nil {
		exercise.Metadata = req.Metadata
	}

	if err := h.exerciseService.Update(c.Request.Context(), id, exercise); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Exercise updated successfully",
	})
}

// DeleteExercise godoc
// @Summary Delete an exercise
// @Tags exercises
// @Param id path string true "Exercise ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/exercises/{id} [delete]
// @Security BearerAuth
func (h *ExerciseHandler) DeleteExercise(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid exercise ID"))
		return
	}

	if err := h.exerciseService.Delete(c.Request.Context(), id); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Exercise deleted successfully",
	})
}

// ReorderExercises godoc
// @Summary Reorder exercises in a program
// @Tags exercises
// @Accept json
// @Produce json
// @Param id path string true "Program ID"
// @Param request body validators.ReorderExercisesRequest true "New exercise order"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/programs/{id}/exercises/reorder [put]
// @Security BearerAuth
func (h *ExerciseHandler) ReorderExercises(c *gin.Context) {
	programID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	var req validators.ReorderExercisesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid request body"))
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	// Parse exercise IDs
	var exerciseIDs []uuid.UUID
	for _, idStr := range req.ExerciseIDs {
		id, err := uuid.Parse(idStr)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid exercise ID format"))
			return
		}
		exerciseIDs = append(exerciseIDs, id)
	}

	if err := h.exerciseService.ReorderExercises(c.Request.Context(), programID, exerciseIDs); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Exercises reordered successfully",
	})
}
