package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type ProgramService struct {
	programRepo  *repositories.ProgramRepository
	exerciseRepo *repositories.ExerciseRepository
}

func NewProgramService(programRepo *repositories.ProgramRepository, exerciseRepo *repositories.ExerciseRepository) *ProgramService {
	return &ProgramService{
		programRepo:  programRepo,
		exerciseRepo: exerciseRepo,
	}
}

func (s *ProgramService) Create(ctx context.Context, program *models.Program, createdBy uuid.UUID) error {
	program.CreatedBy = &createdBy
	if err := s.programRepo.Create(ctx, program); err != nil {
		return appErrors.NewInternalError("Failed to create program").WithError(err)
	}
	return nil
}

func (s *ProgramService) GetByID(ctx context.Context, id uuid.UUID, includeExercises bool) (*models.ProgramWithExercises, error) {
	program, err := s.programRepo.GetByID(ctx, id)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch program").WithError(err)
	}
	if program == nil {
		return nil, appErrors.NewNotFoundError("Program")
	}

	result := &models.ProgramWithExercises{
		Program: *program,
	}

	if includeExercises {
		exercises, err := s.exerciseRepo.ListByProgramID(ctx, id)
		if err != nil {
			return nil, appErrors.NewInternalError("Failed to fetch exercises").WithError(err)
		}
		result.Exercises = exercises
	}

	return result, nil
}

func (s *ProgramService) List(ctx context.Context, isTemplate, isPublic *bool, limit, offset int) ([]models.Program, error) {
	programs, err := s.programRepo.List(ctx, isTemplate, isPublic, limit, offset)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list programs").WithError(err)
	}
	return programs, nil
}

func (s *ProgramService) Update(ctx context.Context, id uuid.UUID, updates *models.Program) error {
	existing, err := s.programRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch program").WithError(err)
	}
	if existing == nil {
		return appErrors.NewNotFoundError("Program")
	}

	updates.ID = id
	if err := s.programRepo.Update(ctx, updates); err != nil {
		return appErrors.NewInternalError("Failed to update program").WithError(err)
	}
	return nil
}

func (s *ProgramService) Delete(ctx context.Context, id uuid.UUID) error {
	existing, err := s.programRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch program").WithError(err)
	}
	if existing == nil {
		return appErrors.NewNotFoundError("Program")
	}

	if err := s.programRepo.Delete(ctx, id); err != nil {
		return appErrors.NewInternalError("Failed to delete program").WithError(err)
	}
	return nil
}

func (s *ProgramService) AssignToUsers(ctx context.Context, programID, assignedBy uuid.UUID, userIDs []uuid.UUID) error {
	// Verify program exists
	program, err := s.programRepo.GetByID(ctx, programID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch program").WithError(err)
	}
	if program == nil {
		return appErrors.NewNotFoundError("Program")
	}

	// Assign to each user
	for _, userID := range userIDs {
		userProgram := &models.UserProgram{
			UserID:         userID,
			ProgramID:      programID,
			AssignedBy:     &assignedBy,
			IsActive:       true,
			CustomSettings: make(map[string]interface{}),
		}
		if err := s.programRepo.AssignToUser(ctx, userProgram); err != nil {
			return appErrors.NewInternalError("Failed to assign program to user").WithError(err)
		}
	}

	return nil
}

func (s *ProgramService) GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.UserProgram, error) {
	userPrograms, err := s.programRepo.GetUserPrograms(ctx, userID, true)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user programs").WithError(err)
	}
	return userPrograms, nil
}

func (s *ProgramService) UpdateUserProgramSettings(ctx context.Context, userID, programID uuid.UUID, customSettings map[string]interface{}) error {
	if err := s.programRepo.UpdateUserProgramSettings(ctx, userID, programID, customSettings); err != nil {
		return appErrors.NewInternalError("Failed to update program settings").WithError(err)
	}
	return nil
}
