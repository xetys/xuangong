package models

import (
	"time"

	"github.com/google/uuid"
)

type Program struct {
	ID          uuid.UUID              `json:"id" db:"id"`
	Name        string                 `json:"name" db:"name"`
	Description string                 `json:"description" db:"description"`
	CreatedBy   *uuid.UUID             `json:"created_by" db:"created_by"`
	IsTemplate  bool                   `json:"is_template" db:"is_template"`
	IsPublic    bool                   `json:"is_public" db:"is_public"`
	Tags        []string               `json:"tags" db:"tags"`
	Metadata    map[string]interface{} `json:"metadata" db:"metadata"`
	CreatedAt   time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at" db:"updated_at"`
}

type ProgramWithExercises struct {
	Program   Program    `json:"program"`
	Exercises []Exercise `json:"exercises"`
}

type UserProgram struct {
	ID             uuid.UUID              `json:"id" db:"id"`
	UserID         uuid.UUID              `json:"user_id" db:"user_id"`
	ProgramID      uuid.UUID              `json:"program_id" db:"program_id"`
	AssignedBy     *uuid.UUID             `json:"assigned_by" db:"assigned_by"`
	AssignedAt     time.Time              `json:"assigned_at" db:"assigned_at"`
	IsActive       bool                   `json:"is_active" db:"is_active"`
	CustomSettings map[string]interface{} `json:"custom_settings" db:"custom_settings"`
}
