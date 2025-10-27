package errors

import (
	"fmt"
	"net/http"
)

// ErrorCode represents a specific error type
type ErrorCode string

const (
	ErrCodeValidation     ErrorCode = "VALIDATION_ERROR"
	ErrCodeAuthentication ErrorCode = "AUTHENTICATION_ERROR"
	ErrCodeAuthorization  ErrorCode = "AUTHORIZATION_ERROR"
	ErrCodeNotFound       ErrorCode = "NOT_FOUND"
	ErrCodeConflict       ErrorCode = "CONFLICT"
	ErrCodeInternal       ErrorCode = "INTERNAL_ERROR"
	ErrCodeBadRequest     ErrorCode = "BAD_REQUEST"
	ErrCodeRateLimit      ErrorCode = "RATE_LIMIT_EXCEEDED"
)

// AppError represents an application-level error with context
type AppError struct {
	Code       ErrorCode              `json:"code"`
	Message    string                 `json:"message"`
	Details    map[string]interface{} `json:"details,omitempty"`
	HTTPStatus int                    `json:"-"`
	Err        error                  `json:"-"`
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %s (%v)", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
	return e.Err
}

// NewAppError creates a new application error
func NewAppError(code ErrorCode, message string, httpStatus int) *AppError {
	return &AppError{
		Code:       code,
		Message:    message,
		HTTPStatus: httpStatus,
		Details:    make(map[string]interface{}),
	}
}

// WithError adds the underlying error
func (e *AppError) WithError(err error) *AppError {
	e.Err = err
	return e
}

// WithDetails adds additional context
func (e *AppError) WithDetails(key string, value interface{}) *AppError {
	if e.Details == nil {
		e.Details = make(map[string]interface{})
	}
	e.Details[key] = value
	return e
}

// Common errors
func NewValidationError(message string) *AppError {
	return NewAppError(ErrCodeValidation, message, http.StatusBadRequest)
}

func NewAuthenticationError(message string) *AppError {
	return NewAppError(ErrCodeAuthentication, message, http.StatusUnauthorized)
}

func NewAuthorizationError(message string) *AppError {
	return NewAppError(ErrCodeAuthorization, message, http.StatusForbidden)
}

func NewNotFoundError(resource string) *AppError {
	return NewAppError(
		ErrCodeNotFound,
		fmt.Sprintf("%s not found", resource),
		http.StatusNotFound,
	)
}

func NewConflictError(message string) *AppError {
	return NewAppError(ErrCodeConflict, message, http.StatusConflict)
}

func NewInternalError(message string) *AppError {
	return NewAppError(ErrCodeInternal, message, http.StatusInternalServerError)
}

func NewBadRequestError(message string) *AppError {
	return NewAppError(ErrCodeBadRequest, message, http.StatusBadRequest)
}

func NewRateLimitError() *AppError {
	return NewAppError(
		ErrCodeRateLimit,
		"Rate limit exceeded. Please try again later.",
		http.StatusTooManyRequests,
	)
}
