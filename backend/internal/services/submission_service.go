package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	appErrors "github.com/xuangong/backend/pkg/errors"
	"github.com/xuangong/backend/pkg/youtube"
)

type SubmissionService struct {
	submissionRepo *repositories.SubmissionRepository
	programRepo    *repositories.ProgramRepository
}

func NewSubmissionService(submissionRepo *repositories.SubmissionRepository, programRepo *repositories.ProgramRepository) *SubmissionService {
	return &SubmissionService{
		submissionRepo: submissionRepo,
		programRepo:    programRepo,
	}
}

// CreateSubmission creates a new submission for a program
func (s *SubmissionService) CreateSubmission(ctx context.Context, programID, userID uuid.UUID, title string) (*models.Submission, error) {
	// Validate title
	if title == "" {
		return nil, appErrors.NewBadRequestError("Title cannot be empty")
	}

	// Verify program exists
	program, err := s.programRepo.GetByID(ctx, programID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to verify program").WithError(err)
	}
	if program == nil {
		return nil, appErrors.NewNotFoundError("Program")
	}

	// Create submission
	submission, err := s.submissionRepo.Create(ctx, programID, userID, title)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to create submission").WithError(err)
	}

	return submission, nil
}

// GetSubmission retrieves a submission by ID with access control
func (s *SubmissionService) GetSubmission(ctx context.Context, id, userID uuid.UUID, isAdmin bool) (*models.Submission, error) {
	submission, err := s.submissionRepo.GetByID(ctx, id, userID, isAdmin)
	if err != nil {
		if errors.Is(err, repositories.ErrAccessDenied) {
			return nil, appErrors.NewAuthorizationError("You don't have access to this submission")
		}
		if errors.Is(err, repositories.ErrSubmissionNotFound) {
			return nil, appErrors.NewNotFoundError("Submission")
		}
		return nil, appErrors.NewInternalError("Failed to fetch submission").WithError(err)
	}

	return submission, nil
}

// ListSubmissions retrieves submissions with filters and access control
func (s *SubmissionService) ListSubmissions(ctx context.Context, programID *uuid.UUID, userID uuid.UUID, isAdmin bool, limit, offset int) ([]models.SubmissionListItem, error) {
	// Validate pagination
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	submissions, err := s.submissionRepo.List(ctx, programID, userID, isAdmin, limit, offset)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list submissions").WithError(err)
	}

	return submissions, nil
}

// CreateMessage adds a message to a submission
func (s *SubmissionService) CreateMessage(ctx context.Context, submissionID, userID uuid.UUID, isAdmin bool, content string, youtubeURL *string) (*models.SubmissionMessage, error) {
	// Validate content
	if content == "" {
		return nil, appErrors.NewBadRequestError("Message content cannot be empty")
	}

	// Validate YouTube URL if provided
	if youtubeURL != nil && *youtubeURL != "" {
		if _, err := youtube.ValidateURL(*youtubeURL); err != nil {
			return nil, appErrors.NewBadRequestError(fmt.Sprintf("Invalid YouTube URL: %v", err))
		}
	}

	// Verify access to submission
	submission, err := s.submissionRepo.GetByID(ctx, submissionID, userID, isAdmin)
	if err != nil {
		if errors.Is(err, repositories.ErrAccessDenied) {
			return nil, appErrors.NewAuthorizationError("You don't have access to this submission")
		}
		if errors.Is(err, repositories.ErrSubmissionNotFound) {
			return nil, appErrors.NewNotFoundError("Submission")
		}
		return nil, appErrors.NewInternalError("Failed to verify submission access").WithError(err)
	}
	if submission == nil {
		return nil, appErrors.NewNotFoundError("Submission")
	}

	// Create message
	message, err := s.submissionRepo.CreateMessage(ctx, submissionID, userID, content, youtubeURL)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to create message").WithError(err)
	}

	return message, nil
}

// GetMessages retrieves all messages for a submission with access control
func (s *SubmissionService) GetMessages(ctx context.Context, submissionID, userID uuid.UUID, isAdmin bool) ([]models.MessageWithAuthor, error) {
	messages, err := s.submissionRepo.GetMessages(ctx, submissionID, userID, isAdmin)
	if err != nil {
		if errors.Is(err, repositories.ErrAccessDenied) {
			return nil, appErrors.NewAuthorizationError("You don't have access to this submission")
		}
		if errors.Is(err, repositories.ErrSubmissionNotFound) {
			return nil, appErrors.NewNotFoundError("Submission")
		}
		return nil, appErrors.NewInternalError("Failed to fetch messages").WithError(err)
	}

	return messages, nil
}

// MarkMessageAsRead marks a message as read by a user
func (s *SubmissionService) MarkMessageAsRead(ctx context.Context, userID, messageID uuid.UUID) error {
	err := s.submissionRepo.MarkMessageAsRead(ctx, userID, messageID)
	if err != nil {
		if errors.Is(err, repositories.ErrMessageNotFound) {
			return appErrors.NewNotFoundError("Message")
		}
		return appErrors.NewInternalError("Failed to mark message as read").WithError(err)
	}

	return nil
}

// GetUnreadCount returns unread message counts at various levels
func (s *SubmissionService) GetUnreadCount(ctx context.Context, userID uuid.UUID, programID *uuid.UUID) (*models.UnreadCounts, error) {
	counts, err := s.submissionRepo.GetUnreadCount(ctx, userID, programID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to get unread counts").WithError(err)
	}

	return counts, nil
}

// SoftDeleteSubmission soft deletes a submission (admin only)
func (s *SubmissionService) SoftDeleteSubmission(ctx context.Context, id, userID uuid.UUID, isAdmin bool) error {
	// Only admins can delete
	if !isAdmin {
		return appErrors.NewAuthorizationError("Only admins can delete submissions")
	}

	err := s.submissionRepo.SoftDelete(ctx, id)
	if err != nil {
		if errors.Is(err, repositories.ErrAlreadyDeleted) {
			return appErrors.NewNotFoundError("Submission")
		}
		return appErrors.NewInternalError("Failed to delete submission").WithError(err)
	}

	return nil
}
