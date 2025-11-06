package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/xuangong/backend/internal/config"
	"github.com/xuangong/backend/internal/database"
	"github.com/xuangong/backend/internal/handlers"
	"github.com/xuangong/backend/internal/middleware"
	"github.com/xuangong/backend/internal/repositories"
	"github.com/xuangong/backend/internal/services"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize database connection
	pool, err := database.NewPool(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close(pool)

	// Run migrations
	if err := database.RunMigrations(cfg.Database.URL, "migrations"); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize repositories
	userRepo := repositories.NewUserRepository(pool)
	programRepo := repositories.NewProgramRepository(pool)
	exerciseRepo := repositories.NewExerciseRepository(pool)
	sessionRepo := repositories.NewSessionRepository(pool)
	submissionRepo := repositories.NewSubmissionRepository(pool)

	// Initialize services
	authService := services.NewAuthService(userRepo, cfg)
	programService := services.NewProgramService(programRepo, exerciseRepo)
	sessionService := services.NewSessionService(sessionRepo, programRepo)
	userService := services.NewUserService(userRepo, programRepo)
	submissionService := services.NewSubmissionService(submissionRepo, programRepo)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService)
	programHandler := handlers.NewProgramHandler(programService)
	sessionHandler := handlers.NewSessionHandler(sessionService)
	userHandler := handlers.NewUserHandler(userService)
	submissionHandler := handlers.NewSubmissionHandler(submissionService)

	// Setup router
	router := setupRouter(cfg, authService, authHandler, programHandler, sessionHandler, userHandler, submissionHandler)

	// Suppress unused variable warnings
	_ = exerciseRepo

	// Create server
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("Server starting on port %s (env: %s)", cfg.Server.Port, cfg.Server.Env)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Server shutting down...")

	// Graceful shutdown with 10 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}

func setupRouter(
	cfg *config.Config,
	authService *services.AuthService,
	authHandler *handlers.AuthHandler,
	programHandler *handlers.ProgramHandler,
	sessionHandler *handlers.SessionHandler,
	userHandler *handlers.UserHandler,
	submissionHandler *handlers.SubmissionHandler,
) *gin.Engine {
	// Set gin mode
	if cfg.Server.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	// Global middleware
	router.Use(gin.Recovery())
	router.Use(middleware.Logger())
	router.Use(middleware.CORS(&cfg.CORS))
	router.Use(middleware.RateLimit(&cfg.RateLimit))

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"version": cfg.Server.APIVersion,
		})
	})

	// API routes
	api := router.Group(fmt.Sprintf("/api/%s", cfg.Server.APIVersion))

	// Public routes (no auth required)
	auth := api.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.RefreshToken)
	}

	// Protected routes (require authentication)
	protected := api.Group("")
	protected.Use(middleware.Auth(authService))
	{
		// Auth
		protected.POST("/auth/logout", authHandler.Logout)
		protected.GET("/auth/me", authHandler.GetProfile)
		protected.PUT("/auth/me", authHandler.UpdateProfile)
		protected.PUT("/auth/change-password", authHandler.ChangePassword)

		// Programs
		programs := protected.Group("/programs")
		{
			programs.GET("", programHandler.ListPrograms)
			programs.GET("/:id", programHandler.GetProgram)
			programs.POST("", programHandler.CreateProgram)       // All users can create programs
			programs.PUT("/:id", programHandler.UpdateProgram)    // Authorization check in handler
			programs.DELETE("/:id", programHandler.DeleteProgram) // Authorization check needed

			// Admin only
			adminPrograms := programs.Group("")
			adminPrograms.Use(middleware.RequireRole("admin"))
			{
				adminPrograms.POST("/:id/assign", programHandler.AssignProgram)
			}
		}

		// My programs (student view)
		protected.GET("/my-programs", programHandler.GetMyPrograms)

		// Sessions
		sessions := protected.Group("/sessions")
		{
			sessions.GET("", sessionHandler.ListSessions)
			sessions.GET("/stats", sessionHandler.GetStats)
			sessions.GET("/:id", sessionHandler.GetSession)
			sessions.POST("/start", sessionHandler.StartSession)
			sessions.PUT("/:id/exercise/:exercise_id", sessionHandler.LogExercise)
			sessions.PUT("/:id/complete", sessionHandler.CompleteSession)
			sessions.DELETE("/:id", sessionHandler.DeleteSession)
		}

		// Users (admin only)
		users := protected.Group("/users")
		users.Use(middleware.RequireRole("admin"))
		{
			users.GET("", userHandler.ListUsers)
			users.GET("/:id", userHandler.GetUser)
			users.POST("", userHandler.CreateUser)
			users.PUT("/:id", userHandler.UpdateUser)
			users.DELETE("/:id", userHandler.DeleteUser)
			users.GET("/:id/programs", userHandler.GetUserPrograms)
		}

		// Submissions
		submissions := protected.Group("/submissions")
		{
			submissions.GET("", submissionHandler.ListSubmissions)             // List with filters
			submissions.GET("/unread-count", submissionHandler.GetUnreadCount) // Get unread counts
			submissions.GET("/:id", submissionHandler.GetSubmission)           // Get single submission
			submissions.GET("/:id/messages", submissionHandler.GetMessages)    // Get messages for submission
			submissions.POST("/:id/messages", submissionHandler.CreateMessage) // Add message to submission
			submissions.DELETE("/:id", submissionHandler.DeleteSubmission)     // Soft delete (admin only, checked in handler)
		}

		// Create submission for a program
		protected.POST("/programs/:id/submissions", submissionHandler.CreateSubmission)

		// Mark message as read
		protected.PUT("/messages/:id/read", submissionHandler.MarkMessageAsRead)
	}

	return router
}
