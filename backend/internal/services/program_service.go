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

func (s *ProgramService) Create(ctx context.Context, program *models.Program, exercises []models.Exercise, createdBy uuid.UUID) error {
	program.CreatedBy = &createdBy
	if err := s.programRepo.Create(ctx, program); err != nil {
		return appErrors.NewInternalError("Failed to create program").WithError(err)
	}

	// Create exercises
	for _, exercise := range exercises {
		exercise.ProgramID = program.ID
		if err := s.exerciseRepo.Create(ctx, &exercise); err != nil {
			return appErrors.NewInternalError("Failed to create exercise").WithError(err)
		}
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

func (s *ProgramService) List(ctx context.Context, isTemplate, isPublic *bool, limit, offset int) ([]models.ProgramWithExercises, error) {
	programs, err := s.programRepo.List(ctx, isTemplate, isPublic, limit, offset)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list programs").WithError(err)
	}

	// Fetch exercises for each program
	result := make([]models.ProgramWithExercises, len(programs))
	for i, program := range programs {
		exercises, err := s.exerciseRepo.ListByProgramID(ctx, program.ID)
		if err != nil {
			return nil, appErrors.NewInternalError("Failed to fetch exercises").WithError(err)
		}
		result[i] = models.ProgramWithExercises{
			Program:   program,
			Exercises: exercises,
		}
	}

	return result, nil
}

func (s *ProgramService) Update(ctx context.Context, id uuid.UUID, updates *models.Program, exercises []models.Exercise, userID uuid.UUID) error {
	existing, err := s.programRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch program").WithError(err)
	}
	if existing == nil {
		return appErrors.NewNotFoundError("Program")
	}

	// Authorization check: only the creator can update their program
	if existing.CreatedBy != nil && *existing.CreatedBy != userID {
		return appErrors.NewAuthorizationError("You don't have permission to edit this program")
	}

	updates.ID = id
	if err := s.programRepo.Update(ctx, updates); err != nil {
		return appErrors.NewInternalError("Failed to update program").WithError(err)
	}

	// Fetch existing exercises
	existingExercises, err := s.exerciseRepo.ListByProgramID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch existing exercises").WithError(err)
	}

	// Build map of existing exercise IDs
	existingIDs := make(map[uuid.UUID]bool)
	for _, ex := range existingExercises {
		existingIDs[ex.ID] = true
	}

	// Build map of new exercise IDs
	newIDs := make(map[uuid.UUID]bool)
	for _, ex := range exercises {
		if ex.ID != uuid.Nil {
			newIDs[ex.ID] = true
		}
	}

	// Delete exercises that are no longer in the list
	for _, ex := range existingExercises {
		if !newIDs[ex.ID] {
			if err := s.exerciseRepo.Delete(ctx, ex.ID); err != nil {
				return appErrors.NewInternalError("Failed to delete exercise").WithError(err)
			}
		}
	}

	// Create or update exercises
	for _, exercise := range exercises {
		exercise.ProgramID = id
		if exercise.ID == uuid.Nil {
			// New exercise - create it
			if err := s.exerciseRepo.Create(ctx, &exercise); err != nil {
				return appErrors.NewInternalError("Failed to create exercise").WithError(err)
			}
		} else if existingIDs[exercise.ID] {
			// Existing exercise - update it
			if err := s.exerciseRepo.Update(ctx, &exercise); err != nil {
				return appErrors.NewInternalError("Failed to update exercise").WithError(err)
			}
		}
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

func (s *ProgramService) GetUserPrograms(ctx context.Context, userID uuid.UUID) ([]models.ProgramWithExercises, error) {
	programs, err := s.programRepo.GetUserProgramsWithDetails(ctx, userID, true)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch user programs").WithError(err)
	}

	// Fetch exercises for each program
	result := make([]models.ProgramWithExercises, len(programs))
	for i, program := range programs {
		exercises, err := s.exerciseRepo.ListByProgramID(ctx, program.ID)
		if err != nil {
			return nil, appErrors.NewInternalError("Failed to fetch exercises").WithError(err)
		}
		result[i] = models.ProgramWithExercises{
			Program:   program,
			Exercises: exercises,
		}
	}

	return result, nil
}

func (s *ProgramService) UpdateUserProgramSettings(ctx context.Context, userID, programID uuid.UUID, customSettings map[string]interface{}) error {
	if err := s.programRepo.UpdateUserProgramSettings(ctx, userID, programID, customSettings); err != nil {
		return appErrors.NewInternalError("Failed to update program settings").WithError(err)
	}
	return nil
}
