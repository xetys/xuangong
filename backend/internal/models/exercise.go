package models

import (
	"time"

	"github.com/google/uuid"
)

type ExerciseType string

const (
	ExerciseTypeTimed      ExerciseType = "timed"
	ExerciseTypeRepetition ExerciseType = "repetition"
	ExerciseTypeCombined   ExerciseType = "combined"
)

type Exercise struct {
	ID                  uuid.UUID              `json:"id" db:"id"`
	ProgramID           uuid.UUID              `json:"program_id" db:"program_id"`
	Name                string                 `json:"name" db:"name"`
	Description         string                 `json:"description" db:"description"`
	OrderIndex          int                    `json:"order_index" db:"order_index"`
	ExerciseType        ExerciseType           `json:"exercise_type" db:"exercise_type"`
	DurationSeconds     *int                   `json:"duration_seconds" db:"duration_seconds"`
	Repetitions         *int                   `json:"repetitions" db:"repetitions"`
	RestAfterSeconds    int                    `json:"rest_after_seconds" db:"rest_after_seconds"`
	HasSides            bool                   `json:"has_sides" db:"has_sides"`
	SideDurationSeconds *int                   `json:"side_duration_seconds" db:"side_duration_seconds"`
	Metadata            map[string]interface{} `json:"metadata" db:"metadata"`
	CreatedAt           time.Time              `json:"created_at" db:"created_at"`
}
