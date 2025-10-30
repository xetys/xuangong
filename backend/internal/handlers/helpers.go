package handlers

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

// respondWithError sends an error response
func respondWithError(c *gin.Context, err *appErrors.AppError) {
	// Log the full error including underlying error
	if err.Err != nil {
		log.Printf("[ERROR] %s: %s (underlying error: %v)", err.Code, err.Message, err.Err)
	} else {
		log.Printf("[ERROR] %s: %s", err.Code, err.Message)
	}

	c.JSON(err.HTTPStatus, gin.H{
		"error": gin.H{
			"code":    err.Code,
			"message": err.Message,
			"details": err.Details,
		},
	})
}

// respondWithAppError handles application errors
func respondWithAppError(c *gin.Context, err error) {
	if appErr, ok := err.(*appErrors.AppError); ok {
		respondWithError(c, appErr)
		return
	}

	// Unknown error, treat as internal server error
	internalErr := appErrors.NewInternalError("An unexpected error occurred").WithError(err)
	respondWithError(c, internalErr)
}

// respondWithValidationError handles validation errors from go-playground/validator
func respondWithValidationError(c *gin.Context, err error) {
	validationErrs, ok := err.(validator.ValidationErrors)
	if !ok {
		respondWithError(c, appErrors.NewBadRequestError("Validation failed"))
		return
	}

	details := make(map[string]interface{})
	for _, fieldErr := range validationErrs {
		details[fieldErr.Field()] = getValidationErrorMessage(fieldErr)
	}

	appErr := appErrors.NewValidationError("Validation failed")
	appErr.Details = details
	respondWithError(c, appErr)
}

func getValidationErrorMessage(fe validator.FieldError) string {
	switch fe.Tag() {
	case "required":
		return "This field is required"
	case "email":
		return "Invalid email format"
	case "min":
		return "Value is too short or small"
	case "max":
		return "Value is too long or large"
	case "uuid":
		return "Invalid UUID format"
	case "oneof":
		return "Invalid value, must be one of the allowed values"
	case "url":
		return "Invalid URL format"
	case "datetime":
		return "Invalid date/time format"
	default:
		return "Validation failed"
	}
}
