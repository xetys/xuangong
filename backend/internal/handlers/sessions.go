package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/middleware"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type SessionHandler struct {
	sessionService *services.SessionService
	validate       *validator.Validate
}

func NewSessionHandler(sessionService *services.SessionService) *SessionHandler {
	return &SessionHandler{
		sessionService: sessionService,
		validate:       validator.New(),
	}
}

// ListSessions godoc
// @Summary List user's practice sessions
// @Tags sessions
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions [get]
// @Security BearerAuth
func (h *SessionHandler) ListSessions(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	var query validators.ListSessionsQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid query parameters"))
		return
	}

	// Set defaults
	if query.Limit == 0 {
		query.Limit = 20
	}

	// Parse optional filters
	var programID *uuid.UUID
	if query.ProgramID != nil {
		id, err := uuid.Parse(*query.ProgramID)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
			return
		}
		programID = &id
	}

	var startDate, endDate *time.Time
	if query.StartDate != nil {
		t, err := time.Parse("2006-01-02", *query.StartDate)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid start date format"))
			return
		}
		startDate = &t
	}
	if query.EndDate != nil {
		t, err := time.Parse("2006-01-02", *query.EndDate)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid end date format"))
			return
		}
		endDate = &t
	}

	sessions, err := h.sessionService.ListSessions(
		c.Request.Context(),
		userID,
		programID,
		startDate,
		endDate,
		query.Limit,
		query.Offset,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"sessions": sessions,
		"limit":    query.Limit,
		"offset":   query.Offset,
	})
}

// GetSession godoc
// @Summary Get session details
// @Tags sessions
// @Produce json
// @Param id path string true "Session ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions/{id} [get]
// @Security BearerAuth
func (h *SessionHandler) GetSession(c *gin.Context) {
	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid session ID"))
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	session, err := h.sessionService.GetSession(c.Request.Context(), sessionID, userID)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, session)
}

// StartSession godoc
// @Summary Start a new practice session
// @Tags sessions
// @Accept json
// @Produce json
// @Param request body validators.StartSessionRequest true "Session details"
// @Success 201 {object} map[string]interface{}
// @Router /api/v1/sessions/start [post]
// @Security BearerAuth
func (h *SessionHandler) StartSession(c *gin.Context) {
	var req validators.StartSessionRequest
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

	programID, err := uuid.Parse(req.ProgramID)
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	session, err := h.sessionService.StartSession(
		c.Request.Context(),
		userID,
		programID,
		req.DeviceInfo,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, session)
}

// LogExercise godoc
// @Summary Log exercise completion
// @Tags sessions
// @Accept json
// @Produce json
// @Param id path string true "Session ID"
// @Param exercise_id path string true "Exercise ID"
// @Param request body validators.LogExerciseRequest true "Exercise log details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions/{id}/exercise/{exercise_id} [put]
// @Security BearerAuth
func (h *SessionHandler) LogExercise(c *gin.Context) {
	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid session ID"))
		return
	}

	exerciseID, err := uuid.Parse(c.Param("exercise_id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid exercise ID"))
		return
	}

	var req validators.LogExerciseRequest
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

	log := &models.ExerciseLog{
		PlannedDurationSeconds: req.PlannedDurationSeconds,
		ActualDurationSeconds:  req.ActualDurationSeconds,
		RepetitionsPlanned:     req.RepetitionsPlanned,
		RepetitionsCompleted:   req.RepetitionsCompleted,
		Skipped:                req.Skipped,
		Notes:                  req.Notes,
	}

	if err := h.sessionService.LogExercise(c.Request.Context(), sessionID, userID, exerciseID, log); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Exercise logged successfully",
	})
}

// CompleteSession godoc
// @Summary Complete a practice session
// @Tags sessions
// @Accept json
// @Produce json
// @Param id path string true "Session ID"
// @Param request body validators.CompleteSessionRequest true "Completion details"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions/{id}/complete [put]
// @Security BearerAuth
func (h *SessionHandler) CompleteSession(c *gin.Context) {
	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid session ID"))
		return
	}

	var req validators.CompleteSessionRequest
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

	if err := h.sessionService.CompleteSession(
		c.Request.Context(),
		sessionID,
		userID,
		req.TotalDurationSeconds,
		req.CompletionRate,
		req.Notes,
	); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Session completed successfully",
	})
}

// GetStats godoc
// @Summary Get practice statistics
// @Tags sessions
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions/stats [get]
// @Security BearerAuth
func (h *SessionHandler) GetStats(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	stats, err := h.sessionService.GetStats(c.Request.Context(), userID)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, stats)
}
