package middleware

import (
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/xuangong/backend/internal/config"
	appErrors "github.com/xuangong/backend/pkg/errors"
)

type visitor struct {
	requests  int
	lastReset time.Time
	mu        sync.Mutex
}

type rateLimiter struct {
	visitors map[string]*visitor
	mu       sync.RWMutex
	limit    int
	duration time.Duration
}

func newRateLimiter(limit int, duration time.Duration) *rateLimiter {
	rl := &rateLimiter{
		visitors: make(map[string]*visitor),
		limit:    limit,
		duration: duration,
	}

	// Cleanup old visitors every minute
	go rl.cleanup()

	return rl
}

func (rl *rateLimiter) getVisitor(ip string) *visitor {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	if !exists {
		v = &visitor{
			requests:  0,
			lastReset: time.Now(),
		}
		rl.visitors[ip] = v
	}

	return v
}

func (rl *rateLimiter) allow(ip string) bool {
	v := rl.getVisitor(ip)

	v.mu.Lock()
	defer v.mu.Unlock()

	// Reset counter if duration has passed
	if time.Since(v.lastReset) > rl.duration {
		v.requests = 0
		v.lastReset = time.Now()
	}

	if v.requests >= rl.limit {
		return false
	}

	v.requests++
	return true
}

func (rl *rateLimiter) cleanup() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		rl.mu.Lock()
		for ip, v := range rl.visitors {
			v.mu.Lock()
			if time.Since(v.lastReset) > rl.duration*2 {
				delete(rl.visitors, ip)
			}
			v.mu.Unlock()
		}
		rl.mu.Unlock()
	}
}

// RateLimit middleware limits requests per IP
func RateLimit(cfg *config.RateLimitConfig) gin.HandlerFunc {
	limiter := newRateLimiter(cfg.Requests, cfg.GetDuration())

	return func(c *gin.Context) {
		ip := c.ClientIP()

		if !limiter.allow(ip) {
			err := appErrors.NewRateLimitError()
			c.JSON(err.HTTPStatus, gin.H{
				"error": gin.H{
					"code":    err.Code,
					"message": err.Message,
				},
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
