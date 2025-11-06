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
		// Start of day (00:00:00)
		startDate = &t
	}
	if query.EndDate != nil {
		t, err := time.Parse("2006-01-02", *query.EndDate)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid end date format"))
			return
		}
		// End of day (23:59:59.999999999)
		endOfDay := time.Date(t.Year(), t.Month(), t.Day(), 23, 59, 59, 999999999, t.Location())
		endDate = &endOfDay
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

	var notes *string
	if req.Notes != "" {
		notes = &req.Notes
	}

	log := &models.ExerciseLog{
		PlannedDurationSeconds: req.PlannedDurationSeconds,
		ActualDurationSeconds:  req.ActualDurationSeconds,
		RepetitionsPlanned:     req.RepetitionsPlanned,
		RepetitionsCompleted:   req.RepetitionsCompleted,
		Skipped:                req.Skipped,
		Notes:                  notes,
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

	// Parse the optional completed_at timestamp
	var completedAt *time.Time
	if req.CompletedAt != nil && *req.CompletedAt != "" {
		// Try multiple formats
		formats := []string{
			time.RFC3339,
			"2006-01-02T15:04:05.999999999",
			"2006-01-02T15:04:05",
			time.RFC3339Nano,
		}

		var parsedTime time.Time
		var parseErr error
		for _, format := range formats {
			parsedTime, parseErr = time.Parse(format, *req.CompletedAt)
			if parseErr == nil {
				break
			}
		}

		if parseErr != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid completed_at format. Expected ISO8601/RFC3339 format"))
			return
		}
		completedAt = &parsedTime
	}

	// Get values or use defaults
	totalDuration := 0
	if req.TotalDurationSeconds != nil {
		totalDuration = *req.TotalDurationSeconds
	}
	completionRate := 100.0
	if req.CompletionRate != nil {
		completionRate = *req.CompletionRate
	}

	if err := h.sessionService.CompleteSession(
		c.Request.Context(),
		sessionID,
		userID,
		totalDuration,
		completionRate,
		req.Notes,
		completedAt,
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

// DeleteSession godoc
// @Summary Delete a practice session
// @Tags sessions
// @Produce json
// @Param id path string true "Session ID"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/sessions/{id} [delete]
// @Security BearerAuth
func (h *SessionHandler) DeleteSession(c *gin.Context) {
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

	if err := h.sessionService.DeleteSession(c.Request.Context(), sessionID, userID); err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Session deleted successfully",
	})
}

// GetUserSessions godoc
// @Summary Get sessions for a specific user (admin only, or own sessions)
// @Tags sessions
// @Produce json
// @Param user_id path string true "User ID"
// @Param program_id query string false "Filter by program ID"
// @Param start_date query string false "Filter by start date (YYYY-MM-DD)"
// @Param end_date query string false "Filter by end date (YYYY-MM-DD)"
// @Param limit query int false "Limit (default 20)"
// @Param offset query int false "Offset (default 0)"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/users/{user_id}/sessions [get]
// @Security BearerAuth
func (h *SessionHandler) GetUserSessions(c *gin.Context) {
	// Parse target user ID from URL path
	targetUserID, err := uuid.Parse(c.Param("user_id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid user ID"))
		return
	}

	// Get requesting user info from context
	requestingUserID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	requestingRoleStr, err := middleware.GetUserRole(c)
	if err != nil {
		respondWithAppError(c, err)
		return
	}
	requestingRole := models.UserRole(requestingRoleStr)

	// Parse query parameters
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
		// End of day (23:59:59.999999999)
		endOfDay := time.Date(t.Year(), t.Month(), t.Day(), 23, 59, 59, 999999999, t.Location())
		endDate = &endOfDay
	}

	// Call service with authorization
	sessions, err := h.sessionService.GetUserSessions(
		c.Request.Context(),
		requestingUserID,
		requestingRole,
		targetUserID,
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
