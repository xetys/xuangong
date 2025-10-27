package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger middleware logs HTTP requests
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Calculate latency
		latency := time.Since(start)

		// Get response status
		status := c.Writer.Status()

		// Get client IP
		clientIP := c.ClientIP()

		// Get request method
		method := c.Request.Method

		// Build log message
		logMsg := map[string]interface{}{
			"status":     status,
			"latency_ms": latency.Milliseconds(),
			"client_ip":  clientIP,
			"method":     method,
			"path":       path,
		}

		if query != "" {
			logMsg["query"] = query
		}

		// Log errors if any
		if len(c.Errors) > 0 {
			logMsg["errors"] = c.Errors.String()
		}

		// Simple structured logging
		if status >= 500 {
			log.Printf("[ERROR] %v", logMsg)
		} else if status >= 400 {
			log.Printf("[WARN] %v", logMsg)
		} else {
			log.Printf("[INFO] %v", logMsg)
		}
	}
}
