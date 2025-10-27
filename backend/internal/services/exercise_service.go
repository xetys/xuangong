package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type ExerciseService struct {
	exerciseRepo *repositories.ExerciseRepository
	programRepo  *repositories.ProgramRepository
}

func NewExerciseService(exerciseRepo *repositories.ExerciseRepository, programRepo *repositories.ProgramRepository) *ExerciseService {
	return &ExerciseService{
		exerciseRepo: exerciseRepo,
		programRepo:  programRepo,
	}
}

func (s *ExerciseService) Create(ctx context.Context, exercise *models.Exercise) error {
	// Verify program exists
	program, err := s.programRepo.GetByID(ctx, exercise.ProgramID)
	if err != nil {
		return appErrors.NewInternalError("Failed to verify program").WithError(err)
	}
	if program == nil {
		return appErrors.NewNotFoundError("Program")
	}

	// Validate exercise type and required fields
	switch exercise.ExerciseType {
	case models.ExerciseTypeTimed:
		if exercise.DurationSeconds == nil || *exercise.DurationSeconds <= 0 {
			return appErrors.NewBadRequestError("Duration is required for timed exercises")
		}
	case models.ExerciseTypeRepetition:
		if exercise.Repetitions == nil || *exercise.Repetitions <= 0 {
			return appErrors.NewBadRequestError("Repetitions are required for repetition exercises")
		}
	case models.ExerciseTypeCombined:
		if (exercise.DurationSeconds == nil || *exercise.DurationSeconds <= 0) &&
			(exercise.Repetitions == nil || *exercise.Repetitions <= 0) {
			return appErrors.NewBadRequestError("Duration or repetitions are required for combined exercises")
		}
	}

	// If has sides, validate side duration
	if exercise.HasSides && exercise.ExerciseType == models.ExerciseTypeTimed {
		if exercise.SideDurationSeconds == nil || *exercise.SideDurationSeconds <= 0 {
			return appErrors.NewBadRequestError("Side duration is required for exercises with sides")
		}
	}

	if err := s.exerciseRepo.Create(ctx, exercise); err != nil {
		return appErrors.NewInternalError("Failed to create exercise").WithError(err)
	}
	return nil
}

func (s *ExerciseService) GetByID(ctx context.Context, id uuid.UUID) (*models.Exercise, error) {
	exercise, err := s.exerciseRepo.GetByID(ctx, id)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to fetch exercise").WithError(err)
	}
	if exercise == nil {
		return nil, appErrors.NewNotFoundError("Exercise")
	}
	return exercise, nil
}

func (s *ExerciseService) ListByProgram(ctx context.Context, programID uuid.UUID) ([]models.Exercise, error) {
	// Verify program exists
	program, err := s.programRepo.GetByID(ctx, programID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to verify program").WithError(err)
	}
	if program == nil {
		return nil, appErrors.NewNotFoundError("Program")
	}

	exercises, err := s.exerciseRepo.ListByProgramID(ctx, programID)
	if err != nil {
		return nil, appErrors.NewInternalError("Failed to list exercises").WithError(err)
	}
	return exercises, nil
}

func (s *ExerciseService) Update(ctx context.Context, id uuid.UUID, updates *models.Exercise) error {
	// Verify exercise exists
	existing, err := s.exerciseRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch exercise").WithError(err)
	}
	if existing == nil {
		return appErrors.NewNotFoundError("Exercise")
	}

	// Preserve program ID and created at
	updates.ID = id
	updates.ProgramID = existing.ProgramID
	updates.CreatedAt = existing.CreatedAt

	// Validate updated fields
	if updates.ExerciseType != "" {
		switch updates.ExerciseType {
		case models.ExerciseTypeTimed:
			if updates.DurationSeconds == nil || *updates.DurationSeconds <= 0 {
				return appErrors.NewBadRequestError("Duration is required for timed exercises")
			}
		case models.ExerciseTypeRepetition:
			if updates.Repetitions == nil || *updates.Repetitions <= 0 {
				return appErrors.NewBadRequestError("Repetitions are required for repetition exercises")
			}
		case models.ExerciseTypeCombined:
			if (updates.DurationSeconds == nil || *updates.DurationSeconds <= 0) &&
				(updates.Repetitions == nil || *updates.Repetitions <= 0) {
				return appErrors.NewBadRequestError("Duration or repetitions are required for combined exercises")
			}
		}
	}

	if err := s.exerciseRepo.Update(ctx, updates); err != nil {
		return appErrors.NewInternalError("Failed to update exercise").WithError(err)
	}
	return nil
}

func (s *ExerciseService) Delete(ctx context.Context, id uuid.UUID) error {
	// Verify exercise exists
	existing, err := s.exerciseRepo.GetByID(ctx, id)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch exercise").WithError(err)
	}
	if existing == nil {
		return appErrors.NewNotFoundError("Exercise")
	}

	if err := s.exerciseRepo.Delete(ctx, id); err != nil {
		return appErrors.NewInternalError("Failed to delete exercise").WithError(err)
	}
	return nil
}

func (s *ExerciseService) ReorderExercises(ctx context.Context, programID uuid.UUID, exerciseIDs []uuid.UUID) error {
	// Verify program exists
	program, err := s.programRepo.GetByID(ctx, programID)
	if err != nil {
		return appErrors.NewInternalError("Failed to verify program").WithError(err)
	}
	if program == nil {
		return appErrors.NewNotFoundError("Program")
	}

	// Verify all exercises belong to the program
	existingExercises, err := s.exerciseRepo.ListByProgramID(ctx, programID)
	if err != nil {
		return appErrors.NewInternalError("Failed to fetch exercises").WithError(err)
	}

	existingMap := make(map[uuid.UUID]bool)
	for _, ex := range existingExercises {
		existingMap[ex.ID] = true
	}

	for _, id := range exerciseIDs {
		if !existingMap[id] {
			return appErrors.NewBadRequestError("Exercise does not belong to this program")
		}
	}

	if len(exerciseIDs) != len(existingExercises) {
		return appErrors.NewBadRequestError("Must provide all exercise IDs for reordering")
	}

	if err := s.exerciseRepo.Reorder(ctx, programID, exerciseIDs); err != nil {
		return appErrors.NewInternalError("Failed to reorder exercises").WithError(err)
	}
	return nil
}
