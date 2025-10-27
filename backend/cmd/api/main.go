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
	sessionService := services.NewSessionService(sessionRepo)
	exerciseService := services.NewExerciseService(exerciseRepo, programRepo)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService)
	programHandler := handlers.NewProgramHandler(programService)
	sessionHandler := handlers.NewSessionHandler(sessionService)
	exerciseHandler := handlers.NewExerciseHandler(exerciseService)

	// Setup router
	router := setupRouter(cfg, authService, authHandler, programHandler, sessionHandler, exerciseHandler)

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

	// Suppress unused variable warnings for now
	_ = submissionRepo
}

func setupRouter(
	cfg *config.Config,
	authService *services.AuthService,
	authHandler *handlers.AuthHandler,
	programHandler *handlers.ProgramHandler,
	sessionHandler *handlers.SessionHandler,
	exerciseHandler *handlers.ExerciseHandler,
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

		// Programs
		programs := protected.Group("/programs")
		{
			programs.GET("", programHandler.ListPrograms)
			programs.GET("/:id", programHandler.GetProgram)

			// Admin only
			adminPrograms := programs.Group("")
			adminPrograms.Use(middleware.RequireRole("admin"))
			{
				adminPrograms.POST("", programHandler.CreateProgram)
				adminPrograms.PUT("/:id", programHandler.UpdateProgram)
				adminPrograms.DELETE("/:id", programHandler.DeleteProgram)
				adminPrograms.POST("/:id/assign", programHandler.AssignProgram)
			}
		}

		// My programs (student view)
		protected.GET("/my-programs", programHandler.GetMyPrograms)

		// Exercises
		exercises := protected.Group("/exercises")
		{
			// Admin only
			adminExercises := exercises.Group("")
			adminExercises.Use(middleware.RequireRole("admin"))
			{
				adminExercises.POST("", exerciseHandler.CreateExercise)
				adminExercises.PUT("/:id", exerciseHandler.UpdateExercise)
				adminExercises.DELETE("/:id", exerciseHandler.DeleteExercise)
			}
		}

		// Exercise operations on programs
		protected.GET("/programs/:id/exercises", exerciseHandler.ListExercises)
		adminProtected := protected.Group("")
		adminProtected.Use(middleware.RequireRole("admin"))
		{
			adminProtected.PUT("/programs/:id/exercises/reorder", exerciseHandler.ReorderExercises)
		}

		// Sessions
		sessions := protected.Group("/sessions")
		{
			sessions.GET("", sessionHandler.ListSessions)
			sessions.GET("/stats", sessionHandler.GetStats)
			sessions.GET("/:id", sessionHandler.GetSession)
			sessions.POST("/start", sessionHandler.StartSession)
			sessions.PUT("/:id/exercise/:exercise_id", sessionHandler.LogExercise)
			sessions.PUT("/:id/complete", sessionHandler.CompleteSession)
		}

		// TODO: Add submissions, feedback, exercises endpoints
	}

	return router
}
