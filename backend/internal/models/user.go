package models

import (
	"time"

	"github.com/google/uuid"
)

type UserRole string

const (
	RoleAdmin   UserRole = "admin"
	RoleStudent UserRole = "student"
)

type User struct {
	ID              uuid.UUID `json:"id" db:"id"`
	Email           string    `json:"email" db:"email"`
	PasswordHash    string    `json:"-" db:"password_hash"`
	FullName        string    `json:"full_name" db:"full_name"`
	Role            UserRole  `json:"role" db:"role"`
	IsActive        bool      `json:"is_active" db:"is_active"`
	CountdownVolume int       `json:"countdown_volume" db:"countdown_volume"`
	StartVolume     int       `json:"start_volume" db:"start_volume"`
	HalfwayVolume   int       `json:"halfway_volume" db:"halfway_volume"`
	FinishVolume    int       `json:"finish_volume" db:"finish_volume"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

// UserResponse is the public representation of a user (without sensitive data)
type UserResponse struct {
	ID              uuid.UUID `json:"id"`
	Email           string    `json:"email"`
	FullName        string    `json:"full_name"`
	Role            UserRole  `json:"role"`
	IsActive        bool      `json:"is_active"`
	CountdownVolume int       `json:"countdown_volume"`
	StartVolume     int       `json:"start_volume"`
	HalfwayVolume   int       `json:"halfway_volume"`
	FinishVolume    int       `json:"finish_volume"`
	CreatedAt       time.Time `json:"created_at"`
}

func (u *User) ToResponse() *UserResponse {
	return &UserResponse{
		ID:              u.ID,
		Email:           u.Email,
		FullName:        u.FullName,
		Role:            u.Role,
		IsActive:        u.IsActive,
		CountdownVolume: u.CountdownVolume,
		StartVolume:     u.StartVolume,
		HalfwayVolume:   u.HalfwayVolume,
		FinishVolume:    u.FinishVolume,
		CreatedAt:       u.CreatedAt,
	}
}

func (u *User) IsAdmin() bool {
	return u.Role == RoleAdmin
}
