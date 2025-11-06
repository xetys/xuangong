package repositories

import (
	"context"
	"testing"

	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/pkg/testutil"
)

func TestUserRepository_CountAdmins(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewUserRepository(pool)
	ctx := context.Background()

	tests := []struct {
		name          string
		setup         func()
		expectedCount int
	}{
		{
			name: "no_admins",
			setup: func() {
				// Create only students
				testutil.CreateTestStudent(t, pool, "student1@test.com")
				testutil.CreateTestStudent(t, pool, "student2@test.com")
			},
			expectedCount: 0,
		},
		{
			name: "one_admin",
			setup: func() {
				testutil.CreateTestAdmin(t, pool, "admin1@test.com")
				testutil.CreateTestStudent(t, pool, "student1@test.com")
			},
			expectedCount: 1,
		},
		{
			name: "multiple_admins",
			setup: func() {
				testutil.CreateTestAdmin(t, pool, "admin1@test.com")
				testutil.CreateTestAdmin(t, pool, "admin2@test.com")
				testutil.CreateTestAdmin(t, pool, "admin3@test.com")
				testutil.CreateTestStudent(t, pool, "student1@test.com")
			},
			expectedCount: 3,
		},
		{
			name: "all_admins",
			setup: func() {
				testutil.CreateTestAdmin(t, pool, "admin1@test.com")
				testutil.CreateTestAdmin(t, pool, "admin2@test.com")
			},
			expectedCount: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear users table before each test
			testutil.TruncateTables(t, pool)

			tt.setup()

			count, err := repo.CountAdmins(ctx)
			if err != nil {
				t.Fatalf("CountAdmins() error = %v", err)
			}

			if count != tt.expectedCount {
				t.Errorf("Expected %d admins, got %d", tt.expectedCount, count)
			}
		})
	}
}

func TestUserRepository_CountAdmins_ActiveOnly(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewUserRepository(pool)
	ctx := context.Background()

	// Create active admin
	_ = testutil.CreateTestAdmin(t, pool, "active@test.com")

	// Create inactive admin
	inactiveAdmin := testutil.CreateTestAdmin(t, pool, "inactive@test.com")
	inactiveAdmin.IsActive = false
	if err := repo.Update(ctx, inactiveAdmin); err != nil {
		t.Fatalf("Failed to update admin: %v", err)
	}

	// Count should only include active admins
	count, err := repo.CountAdmins(ctx)
	if err != nil {
		t.Fatalf("CountAdmins() error = %v", err)
	}

	if count != 1 {
		t.Errorf("Expected 1 active admin, got %d", count)
	}
}

func TestUserRepository_UpdateRole(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewUserRepository(pool)
	ctx := context.Background()

	tests := []struct {
		name     string
		setup    func() *models.User
		newRole  models.UserRole
		wantErr  bool
	}{
		{
			name: "promote_student_to_admin",
			setup: func() *models.User {
				return testutil.CreateTestStudent(t, pool, "student@test.com")
			},
			newRole: models.RoleAdmin,
			wantErr: false,
		},
		{
			name: "demote_admin_to_student",
			setup: func() *models.User {
				return testutil.CreateTestAdmin(t, pool, "admin@test.com")
			},
			newRole: models.RoleStudent,
			wantErr: false,
		},
		{
			name: "role_remains_unchanged",
			setup: func() *models.User {
				return testutil.CreateTestAdmin(t, pool, "admin@test.com")
			},
			newRole: models.RoleAdmin,
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testutil.TruncateTables(t, pool)

			user := tt.setup()
			originalRole := user.Role

			// Update role
			user.Role = tt.newRole
			err := repo.Update(ctx, user)

			if (err != nil) != tt.wantErr {
				t.Errorf("Update() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				// Verify role was updated
				updated, err := repo.GetByID(ctx, user.ID)
				if err != nil {
					t.Fatalf("GetByID() error = %v", err)
				}
				if updated.Role != tt.newRole {
					t.Errorf("Expected role %s, got %s", tt.newRole, updated.Role)
				}

				// Log the change for test visibility
				t.Logf("Role changed: %s -> %s", originalRole, updated.Role)
			}
		})
	}
}
