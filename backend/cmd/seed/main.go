package main

import (
	"context"
	"log"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/config"
	"github.com/xuangong/backend/internal/database"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/internal/repositories"
	"github.com/xuangong/backend/pkg/auth"
)

func main() {
	log.Println("Starting database seeding...")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Connect to database
	pool, err := database.NewPool(&cfg.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close(pool)

	ctx := context.Background()

	// Initialize repositories
	userRepo := repositories.NewUserRepository(pool)
	programRepo := repositories.NewProgramRepository(pool)
	exerciseRepo := repositories.NewExerciseRepository(pool)

	// Create admin user
	log.Println("Creating admin user...")
	adminPassword, _ := auth.HashPassword("admin123")
	admin := &models.User{
		Email:        "admin@xuangong.local",
		PasswordHash: adminPassword,
		FullName:     "Stefan Müller",
		Role:         models.RoleAdmin,
		IsActive:     true,
	}
	if err := userRepo.Create(ctx, admin); err != nil {
		log.Printf("Warning: Could not create admin user (may already exist): %v", err)
	} else {
		log.Printf("Admin user created: %s", admin.Email)
	}

	// Create test student
	log.Println("Creating test student...")
	studentPassword, _ := auth.HashPassword("student123")
	student := &models.User{
		Email:        "student@xuangong.local",
		PasswordHash: studentPassword,
		FullName:     "Li Wei",
		Role:         models.RoleStudent,
		IsActive:     true,
	}
	if err := userRepo.Create(ctx, student); err != nil {
		log.Printf("Warning: Could not create student user (may already exist): %v", err)
	} else {
		log.Printf("Student user created: %s", student.Email)
	}

	// Create sample programs with different intensities
	programs := []struct {
		name        string
		description string
		tags        []string
		exercises   []struct {
			name                string
			description         string
			exerciseType        models.ExerciseType
			durationSeconds     *int
			repetitions         *int
			restAfterSeconds    int
			hasSides            bool
			sideDurationSeconds *int
		}
	}{
		{
			name:        "Tai Chi Morning Practice - Light",
			description: "Gentle morning Tai Chi routine for beginners",
			tags:        []string{"tai-chi", "morning", "beginner", "light"},
			exercises: []struct {
				name                string
				description         string
				exerciseType        models.ExerciseType
				durationSeconds     *int
				repetitions         *int
				restAfterSeconds    int
				hasSides            bool
				sideDurationSeconds *int
			}{
				{
					name:             "Standing Meditation (Zhan Zhuang)",
					description:      "Stand in Wu Ji posture with arms at sides, feet shoulder-width apart",
					exerciseType:     models.ExerciseTypeTimed,
					durationSeconds:  intPtr(120), // 2 minutes
					restAfterSeconds: 30,
					hasSides:         false,
				},
				{
					name:             "Cloud Hands (Yun Shou)",
					description:      "Flowing side-to-side movement coordinating arms and waist",
					exerciseType:     models.ExerciseTypeRepetition,
					repetitions:      intPtr(5),
					restAfterSeconds: 30,
					hasSides:         true,
				},
				{
					name:                "Single Whip",
					description:         "Classic Tai Chi posture transitioning from center to side",
					exerciseType:        models.ExerciseTypeCombined,
					durationSeconds:     intPtr(60),
					repetitions:         intPtr(3),
					restAfterSeconds:    30,
					hasSides:            true,
					sideDurationSeconds: intPtr(30),
				},
			},
		},
		{
			name:        "Tai Chi Morning Practice - Medium",
			description: "Standard morning Tai Chi routine for regular practitioners",
			tags:        []string{"tai-chi", "morning", "intermediate", "medium"},
			exercises: []struct {
				name                string
				description         string
				exerciseType        models.ExerciseType
				durationSeconds     *int
				repetitions         *int
				restAfterSeconds    int
				hasSides            bool
				sideDurationSeconds *int
			}{
				{
					name:             "Standing Meditation (Zhan Zhuang)",
					description:      "Stand in Wu Ji posture with arms at sides, feet shoulder-width apart",
					exerciseType:     models.ExerciseTypeTimed,
					durationSeconds:  intPtr(300), // 5 minutes
					restAfterSeconds: 60,
					hasSides:         false,
				},
				{
					name:             "Cloud Hands (Yun Shou)",
					description:      "Flowing side-to-side movement coordinating arms and waist",
					exerciseType:     models.ExerciseTypeRepetition,
					repetitions:      intPtr(10),
					restAfterSeconds: 60,
					hasSides:         true,
				},
				{
					name:                "Single Whip",
					description:         "Classic Tai Chi posture transitioning from center to side",
					exerciseType:        models.ExerciseTypeCombined,
					durationSeconds:     intPtr(120),
					repetitions:         intPtr(8),
					restAfterSeconds:    60,
					hasSides:            true,
					sideDurationSeconds: intPtr(60),
				},
			},
		},
		{
			name:        "Tai Chi Morning Practice - Intensive",
			description: "Intensive morning Tai Chi routine for advanced practitioners",
			tags:        []string{"tai-chi", "morning", "advanced", "intensive"},
			exercises: []struct {
				name                string
				description         string
				exerciseType        models.ExerciseType
				durationSeconds     *int
				repetitions         *int
				restAfterSeconds    int
				hasSides            bool
				sideDurationSeconds *int
			}{
				{
					name:             "Standing Meditation (Zhan Zhuang)",
					description:      "Stand in Wu Ji posture with arms at sides, feet shoulder-width apart",
					exerciseType:     models.ExerciseTypeTimed,
					durationSeconds:  intPtr(600), // 10 minutes
					restAfterSeconds: 120,
					hasSides:         false,
				},
				{
					name:             "Cloud Hands (Yun Shou)",
					description:      "Flowing side-to-side movement coordinating arms and waist",
					exerciseType:     models.ExerciseTypeRepetition,
					repetitions:      intPtr(20),
					restAfterSeconds: 120,
					hasSides:         true,
				},
				{
					name:                "Single Whip",
					description:         "Classic Tai Chi posture transitioning from center to side",
					exerciseType:        models.ExerciseTypeCombined,
					durationSeconds:     intPtr(240),
					repetitions:         intPtr(15),
					restAfterSeconds:    120,
					hasSides:            true,
					sideDurationSeconds: intPtr(120),
				},
			},
		},
	}

	var mediumProgramID uuid.UUID

	for _, p := range programs {
		log.Printf("Creating program: %s", p.name)
		program := &models.Program{
			Name:        p.name,
			Description: p.description,
			CreatedBy:   &admin.ID,
			IsTemplate:  true,
			IsPublic:    true,
			Tags:        p.tags,
			Metadata:    map[string]interface{}{},
		}
		if err := programRepo.Create(ctx, program); err != nil {
			log.Printf("Warning: Could not create program %s: %v", p.name, err)
			continue
		}
		log.Printf("Program created: %s", program.Name)

		// Save the medium program ID for assignment
		if p.name == "Tai Chi Morning Practice - Medium" {
			mediumProgramID = program.ID
		}

		// Create exercises for this program
		for i, ex := range p.exercises {
			exercise := &models.Exercise{
				ProgramID:           program.ID,
				Name:                ex.name,
				Description:         ex.description,
				OrderIndex:          i,
				ExerciseType:        ex.exerciseType,
				DurationSeconds:     ex.durationSeconds,
				Repetitions:         ex.repetitions,
				RestAfterSeconds:    ex.restAfterSeconds,
				HasSides:            ex.hasSides,
				SideDurationSeconds: ex.sideDurationSeconds,
				Metadata:            map[string]interface{}{},
			}
			if err := exerciseRepo.Create(ctx, exercise); err != nil {
				log.Printf("Warning: Could not create exercise %s: %v", ex.name, err)
				continue
			}
			log.Printf("  Exercise created: %s", exercise.Name)
		}
	}

	// Assign medium program to student
	if mediumProgramID != uuid.Nil {
		log.Println("Assigning medium program to student...")
		userProgram := &models.UserProgram{
			UserID:         student.ID,
			ProgramID:      mediumProgramID,
			AssignedBy:     &admin.ID,
			IsActive:       true,
			CustomSettings: map[string]interface{}{},
		}
		if err := programRepo.AssignToUser(ctx, userProgram); err != nil {
			log.Printf("Warning: Could not assign program: %v", err)
		} else {
			log.Println("Program assigned to student successfully")
		}
	}

	log.Println("Database seeding completed!")
	log.Println("\nTest accounts:")
	log.Println("  Admin:   admin@xuangong.local / admin123")
	log.Println("  Student: student@xuangong.local / student123")
}

func intPtr(i int) *int {
	return &i
}
