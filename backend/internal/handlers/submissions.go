package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/middleware"
	"github.com/xuangong/backend/internal/services"
	"github.com/xuangong/backend/internal/validators"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type SubmissionHandler struct {
	submissionService *services.SubmissionService
	validate          *validator.Validate
}

func NewSubmissionHandler(submissionService *services.SubmissionService) *SubmissionHandler {
	return &SubmissionHandler{
		submissionService: submissionService,
		validate:          validator.New(),
	}
}

// CreateSubmission creates a new submission for a program
// POST /api/v1/programs/:id/submissions
func (h *SubmissionHandler) CreateSubmission(c *gin.Context) {
	programID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
		return
	}

	var req validators.CreateSubmissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}

	submission, err := h.submissionService.CreateSubmission(
		c.Request.Context(),
		programID,
		userID,
		req.Title,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"submission": submission,
	})
}

// ListSubmissions lists submissions with filters
// GET /api/v1/submissions
func (h *SubmissionHandler) ListSubmissions(c *gin.Context) {
	var query validators.ListSubmissionsQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid query parameters"))
		return
	}

	// Set defaults
	if query.Limit == 0 {
		query.Limit = 50
	}

	// Parse optional program ID
	var programID *uuid.UUID
	if query.ProgramID != nil {
		id, err := uuid.Parse(*query.ProgramID)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
			return
		}
		programID = &id
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}
	isAdmin := middleware.IsAdmin(c)

	submissions, err := h.submissionService.ListSubmissions(
		c.Request.Context(),
		programID,
		userID,
		isAdmin,
		query.Limit,
		query.Offset,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"submissions": submissions,
		"limit":       query.Limit,
		"offset":      query.Offset,
		"count":       len(submissions),
	})
}

// GetSubmission retrieves a submission by ID
// GET /api/v1/submissions/:id
func (h *SubmissionHandler) GetSubmission(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid submission ID"))
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}
	isAdmin := middleware.IsAdmin(c)

	submission, err := h.submissionService.GetSubmission(
		c.Request.Context(),
		id,
		userID,
		isAdmin,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"submission": submission,
	})
}

// GetMessages retrieves all messages for a submission
// GET /api/v1/submissions/:id/messages
func (h *SubmissionHandler) GetMessages(c *gin.Context) {
	submissionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid submission ID"))
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}
	isAdmin := middleware.IsAdmin(c)

	messages, err := h.submissionService.GetMessages(
		c.Request.Context(),
		submissionID,
		userID,
		isAdmin,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
		"count":    len(messages),
	})
}

// CreateMessage adds a message to a submission
// POST /api/v1/submissions/:id/messages
func (h *SubmissionHandler) CreateMessage(c *gin.Context) {
	submissionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid submission ID"))
		return
	}

	var req validators.CreateMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	if err := h.validate.Struct(req); err != nil {
		respondWithValidationError(c, err)
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}
	isAdmin := middleware.IsAdmin(c)

	message, err := h.submissionService.CreateMessage(
		c.Request.Context(),
		submissionID,
		userID,
		isAdmin,
		req.Content,
		req.YouTubeURL,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": message,
	})
}

// MarkMessageAsRead marks a message as read by the current user
// PUT /api/v1/messages/:id/read
func (h *SubmissionHandler) MarkMessageAsRead(c *gin.Context) {
	messageID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid message ID"))
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}

	err = h.submissionService.MarkMessageAsRead(
		c.Request.Context(),
		userID,
		messageID,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Message marked as read",
	})
}

// GetUnreadCount returns unread message counts
// GET /api/v1/submissions/unread-count
func (h *SubmissionHandler) GetUnreadCount(c *gin.Context) {
	// Optional program ID filter
	var programID *uuid.UUID
	if programIDStr := c.Query("program_id"); programIDStr != "" {
		id, err := uuid.Parse(programIDStr)
		if err != nil {
			respondWithError(c, appErrors.NewBadRequestError("Invalid program ID"))
			return
		}
		programID = &id
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}

	counts, err := h.submissionService.GetUnreadCount(
		c.Request.Context(),
		userID,
		programID,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, counts)
}

// DeleteSubmission soft deletes a submission (admin only)
// DELETE /api/v1/submissions/:id
func (h *SubmissionHandler) DeleteSubmission(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		respondWithError(c, appErrors.NewBadRequestError("Invalid submission ID"))
		return
	}

	userID, err := middleware.GetUserID(c)
	if err != nil {
		respondWithError(c, appErrors.NewAuthenticationError("Invalid user"))
		return
	}
	isAdmin := middleware.IsAdmin(c)

	err = h.submissionService.SoftDeleteSubmission(
		c.Request.Context(),
		id,
		userID,
		isAdmin,
	)
	if err != nil {
		respondWithAppError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Submission deleted successfully",
	})
}
