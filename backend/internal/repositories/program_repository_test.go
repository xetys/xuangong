package repositories

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/xuangong/backend/pkg/testutil"
)

func TestProgramRepository_SoftDelete(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	tests := []struct {
		name    string
		setup   func() uuid.UUID
		wantErr bool
	}{
		{
			name: "soft_delete_existing_program",
			setup: func() uuid.UUID {
				admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
				program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
				return program.ID
			},
			wantErr: false,
		},
		{
			name: "soft_delete_non_existent_program",
			setup: func() uuid.UUID {
				return uuid.New() // Non-existent ID
			},
			wantErr: true,
		},
		{
			name: "soft_delete_already_deleted_program",
			setup: func() uuid.UUID {
				admin := testutil.CreateTestAdmin(t, pool, "admin2@test.com")
				program := testutil.CreateTestProgram(t, pool, admin.ID, "Deleted Program")
				// Soft delete it first
				err := repo.SoftDelete(ctx, program.ID)
				if err != nil {
					t.Fatalf("Failed to soft delete program: %v", err)
				}
				return program.ID
			},
			wantErr: true, // Should fail when trying to delete already deleted program
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			programID := tt.setup()

			err := repo.SoftDelete(ctx, programID)

			if (err != nil) != tt.wantErr {
				t.Errorf("SoftDelete() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				// Verify the program is soft deleted
				program, err := repo.GetByIDIncludingDeleted(ctx, programID)
				if err != nil {
					t.Fatalf("Failed to get program including deleted: %v", err)
				}
				if program == nil {
					t.Fatal("Expected program to exist")
				}
				if program.DeletedAt == nil {
					t.Error("Expected DeletedAt to be set")
				}
			}
		})
	}
}

func TestProgramRepository_GetByID_ExcludesDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Active Program")

	// Soft delete the program
	err := repo.SoftDelete(ctx, program.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// GetByID should NOT return soft-deleted programs
	result, err := repo.GetByID(ctx, program.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if result != nil {
		t.Error("Expected GetByID to return nil for soft-deleted program")
	}
}

func TestProgramRepository_GetByIDIncludingDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	tests := []struct {
		name      string
		setup     func() uuid.UUID
		wantFound bool
	}{
		{
			name: "find_active_program",
			setup: func() uuid.UUID {
				admin := testutil.CreateTestAdmin(t, pool, "admin1@test.com")
				program := testutil.CreateTestProgram(t, pool, admin.ID, "Active")
				return program.ID
			},
			wantFound: true,
		},
		{
			name: "find_deleted_program",
			setup: func() uuid.UUID {
				admin := testutil.CreateTestAdmin(t, pool, "admin2@test.com")
				program := testutil.CreateTestProgram(t, pool, admin.ID, "Deleted")
				repo.SoftDelete(ctx, program.ID)
				return program.ID
			},
			wantFound: true, // Should find even if deleted
		},
		{
			name: "non_existent_program",
			setup: func() uuid.UUID {
				return uuid.New()
			},
			wantFound: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			programID := tt.setup()

			result, err := repo.GetByIDIncludingDeleted(ctx, programID)
			if err != nil {
				t.Fatalf("GetByIDIncludingDeleted() error = %v", err)
			}

			if tt.wantFound && result == nil {
				t.Error("Expected to find program but got nil")
			}
			if !tt.wantFound && result != nil {
				t.Error("Expected nil but found program")
			}
		})
	}
}

func TestProgramRepository_List_ExcludesDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")

	// Create 3 programs: 2 active, 1 deleted
	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Active 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Active 2")
	program3 := testutil.CreateTestProgram(t, pool, admin.ID, "Deleted")

	// Soft delete program3
	err := repo.SoftDelete(ctx, program3.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// List should only return active programs
	programs, err := repo.List(ctx, nil, nil, 10, 0)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}

	if len(programs) != 2 {
		t.Errorf("Expected 2 active programs, got %d", len(programs))
	}

	// Verify the deleted program is not in the list
	for _, p := range programs {
		if p.ID == program3.ID {
			t.Error("Deleted program should not appear in List()")
		}
	}

	// Verify active programs are in the list
	found1, found2 := false, false
	for _, p := range programs {
		if p.ID == program1.ID {
			found1 = true
		}
		if p.ID == program2.ID {
			found2 = true
		}
	}
	if !found1 || !found2 {
		t.Error("Expected both active programs in the list")
	}
}

func TestProgramRepository_GetByOwner_ExcludesDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")

	// Create 2 programs for this admin
	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Owner Program 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Owner Program 2")

	// Soft delete one
	err := repo.SoftDelete(ctx, program2.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// GetByOwner should only return active programs
	programs, err := repo.GetByOwner(ctx, admin.ID)
	if err != nil {
		t.Fatalf("GetByOwner() error = %v", err)
	}

	if len(programs) != 1 {
		t.Errorf("Expected 1 active program, got %d", len(programs))
	}

	if len(programs) > 0 && programs[0].ID != program1.ID {
		t.Error("Expected to get the active program")
	}
}

func TestProgramRepository_GetUserPrograms_ExcludesDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")

	// Create 2 programs and assign to student
	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Assigned 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Assigned 2")

	testutil.AssignProgramToUser(t, pool, student.ID, program1.ID, admin.ID)
	testutil.AssignProgramToUser(t, pool, student.ID, program2.ID, admin.ID)

	// Soft delete one program
	err := repo.SoftDelete(ctx, program2.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// GetUserPrograms should only return active programs
	programs, err := repo.GetUserPrograms(ctx, student.ID, true)
	if err != nil {
		t.Fatalf("GetUserPrograms() error = %v", err)
	}

	if len(programs) != 1 {
		t.Errorf("Expected 1 active program, got %d", len(programs))
	}

	if len(programs) > 0 && programs[0].ID != program1.ID {
		t.Error("Expected to get the active assigned program")
	}
}

func TestProgramRepository_Sessions_PreservedAfterSoftDelete(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Program with Sessions")

	// Create a session for this program
	session := testutil.CreateTestSession(t, pool, student.ID, program.ID)

	// Soft delete the program
	err := repo.SoftDelete(ctx, program.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// Verify session still exists in database
	testutil.AssertRowCount(t, pool, "sessions", 1)

	// Verify we can still get session data (sessions are preserved)
	row := testutil.QueryRow(t, pool, "SELECT id FROM sessions WHERE id = $1", session.ID)
	if row["id"] == nil {
		t.Error("Session should still exist after program soft delete")
	}
}

func TestProgramRepository_SoftDelete_Idempotent(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewProgramRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Idempotent Test")

	// First soft delete
	err := repo.SoftDelete(ctx, program.ID)
	if err != nil {
		t.Fatalf("First SoftDelete() error = %v", err)
	}

	// Get the deleted_at timestamp
	result1, _ := repo.GetByIDIncludingDeleted(ctx, program.ID)
	firstDeletedAt := result1.DeletedAt

	// Wait a tiny bit to ensure timestamps would be different
	time.Sleep(10 * time.Millisecond)

	// Second soft delete should fail or not update timestamp
	err = repo.SoftDelete(ctx, program.ID)
	if err == nil {
		t.Error("Expected error when soft deleting already deleted program")
	}

	// Verify timestamp didn't change
	result2, _ := repo.GetByIDIncludingDeleted(ctx, program.ID)
	if result2.DeletedAt == nil {
		t.Fatal("DeletedAt should not be nil")
	}
	if !result2.DeletedAt.Equal(*firstDeletedAt) {
		t.Error("DeletedAt timestamp should not change on second soft delete")
	}
}
