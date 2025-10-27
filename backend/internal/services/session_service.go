package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type SessionService struct {
	sessionRepo *repositories.SessionRepository
}

func NewSessionService(sessionRepo *repositories.SessionRepository) *SessionService {
	return &SessionService{
		sessionRepo: sessionRepo,
	}
}

func (s *SessionService) StartSession(ctx context.Context, userID, programID uuid.UUID, deviceInfo map[string]interface{}) (*models.PracticeSession, error) {
	session := &models.PracticeSession{
		UserID:     userID,
		ProgramID:  programID,
		DeviceInfo: deviceInfo,
	}

	if err := s.sessionRepo.Create(ctx, session); err != nil {
		return nil, appErrors.NewInternalError("Failed to start session").WithError(err)
	}

	return session, nil
}

func (s *SessionService) GetSession(ctx context.Context, sessionID, userID uuid.UUID) (*models.SessionWithLogs, error) {
	session, err := s.sessionRepo.GetByID(ctx, sessionID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch session").WithError(err)
	}
	if session == nil {
		return nil, appErrors.NewNotFoundError("Session")
	}

	// Verify user owns this session
	if session.UserID != userID {
		return nil, appErrors.NewAuthorizationError("You don't have access to this session")
	}

	// Get exercise logs
	logs, err := s.sessionRepo.GetExerciseLogs(ctx, sessionID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch exercise logs").WithError(err)
	}

	return &models.SessionWithLogs{
		Session:      *session,
		ExerciseLogs: logs,
	}, nil
}

func (s *SessionService) ListSessions(ctx context.Context, userID uuid.UUID, programID *uuid.UUID, startDate, endDate *time.Time, limit, offset int) ([]models.PracticeSession, error) {
	sessions, err := s.sessionRepo.List(ctx, userID, programID, startDate, endDate, limit, offset)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list sessions").WithError(err)
	}
	return sessions, nil
}

func (s *SessionService) LogExercise(ctx context.Context, sessionID, userID, exerciseID uuid.UUID, log *models.ExerciseLog) error {
	// Verify session exists and belongs to user
	session, err := s.sessionRepo.GetByID(ctx, sessionID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch session").WithError(err)
	}
	if session == nil {
		return appErrors.NewNotFoundError("Session")
	}
	if session.UserID != userID {
		return appErrors.NewAuthorizationError("You don't have access to this session")
	}

	// Set session and exercise IDs
	log.SessionID = sessionID
	log.ExerciseID = &exerciseID

	// Set timestamps if not provided
	now := time.Now()
	if log.StartedAt == nil {
		log.StartedAt = &now
	}
	if log.CompletedAt == nil && !log.Skipped {
		log.CompletedAt = &now
	}

	if err := s.sessionRepo.CreateExerciseLog(ctx, log); err != nil {
		return appErrors.NewInternalError("Failed to log exercise").WithError(err)
	}

	return nil
}

func (s *SessionService) CompleteSession(ctx context.Context, sessionID, userID uuid.UUID, totalDuration int, completionRate float64, notes string) error {
	// Verify session exists and belongs to user
	session, err := s.sessionRepo.GetByID(ctx, sessionID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch session").WithError(err)
	}
	if session == nil {
		return appErrors.NewNotFoundError("Session")
	}
	if session.UserID != userID {
		return appErrors.NewAuthorizationError("You don't have access to this session")
	}

	if session.CompletedAt != nil {
		return appErrors.NewBadRequestError("Session already completed")
	}

	if err := s.sessionRepo.Complete(ctx, sessionID, totalDuration, completionRate, notes); err != nil {
		return appErrors.NewInternalError("Failed to complete session").WithError(err)
	}

	return nil
}

func (s *SessionService) GetStats(ctx context.Context, userID uuid.UUID) (*models.SessionStats, error) {
	stats, err := s.sessionRepo.GetStats(ctx, userID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch session stats").WithError(err)
	}
	return stats, nil
}
