package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/xuangong/backend/internal/config"
)

// CORS middleware handles Cross-Origin Resource Sharing
func CORS(cfg *config.CORSConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// Check if origin is allowed
		allowed := false
		for _, allowedOrigin := range cfg.AllowedOrigins {
			if allowedOrigin == "*" {
				allowed = true
				break
			}
			if allowedOrigin == origin {
				allowed = true
				break
			}
			// Allow any localhost origin in development (handles random Flutter ports)
			if strings.HasPrefix(allowedOrigin, "localhost:") &&
				(strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:")) {
				allowed = true
				break
			}
		}

		if allowed {
			// Always set the actual origin (not "*") when credentials are needed
			if origin != "" {
				c.Header("Access-Control-Allow-Origin", origin)
			} else if len(cfg.AllowedOrigins) > 0 && cfg.AllowedOrigins[0] != "*" {
				c.Header("Access-Control-Allow-Origin", cfg.AllowedOrigins[0])
			}

			c.Header("Access-Control-Allow-Methods", joinStrings(cfg.AllowedMethods))
			c.Header("Access-Control-Allow-Headers", joinStrings(cfg.AllowedHeaders))
			c.Header("Access-Control-Allow-Credentials", "true")
			c.Header("Access-Control-Max-Age", "86400")
		}

		// Handle preflight requests
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func joinStrings(slice []string) string {
	result := ""
	for i, s := range slice {
		if i > 0 {
			result += ", "
		}
		result += s
	}
	return result
}
