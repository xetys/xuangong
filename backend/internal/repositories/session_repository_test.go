package repositories

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/xuangong/backend/pkg/testutil"
)

var _ = time.Now // prevent unused import error

func TestSessionRepository_ListByUserID(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSessionRepository(pool)
	ctx := context.Background()

	// Setup test data
	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
	student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")

	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 2")

	// Create sessions for student1
	session1 := testutil.CreateTestSession(t, pool, student1.ID, program1.ID)
	session2 := testutil.CreateTestSession(t, pool, student1.ID, program2.ID)
	testutil.CreateTestCompletedSession(t, pool, student1.ID, program1.ID)

	// Create sessions for student2 (should not appear in student1 results)
	testutil.CreateTestSession(t, pool, student2.ID, program1.ID)

	tests := []struct {
		name          string
		userID        uuid.UUID
		programID     *uuid.UUID
		expectedCount int
		expectedIDs   []uuid.UUID
	}{
		{
			name:          "list_all_sessions_for_user",
			userID:        student1.ID,
			programID:     nil,
			expectedCount: 3,
		},
		{
			name:          "filter_by_program_id",
			userID:        student1.ID,
			programID:     &program1.ID,
			expectedCount: 2, // session1 and completed session
			expectedIDs:   []uuid.UUID{session1.ID},
		},
		{
			name:          "filter_by_different_program",
			userID:        student1.ID,
			programID:     &program2.ID,
			expectedCount: 1,
			expectedIDs:   []uuid.UUID{session2.ID},
		},
		{
			name:          "user_with_no_sessions",
			userID:        admin.ID,
			programID:     nil,
			expectedCount: 0,
		},
		{
			name:          "different_user_sessions_not_returned",
			userID:        student2.ID,
			programID:     nil,
			expectedCount: 1, // Only student2's sessions
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sessions, err := repo.ListByUserID(ctx, tt.userID, tt.programID, nil, nil, 100, 0)
			if err != nil {
				t.Fatalf("ListByUserID() error = %v", err)
			}

			if len(sessions) != tt.expectedCount {
				t.Errorf("Expected %d sessions, got %d", tt.expectedCount, len(sessions))
			}

			// Verify specific IDs if provided
			if tt.expectedIDs != nil {
				foundIDs := make(map[uuid.UUID]bool)
				for _, s := range sessions {
					foundIDs[s.ID] = true
				}
				for _, expectedID := range tt.expectedIDs {
					if !foundIDs[expectedID] {
						t.Errorf("Expected to find session ID %s", expectedID)
					}
				}
			}

			// Verify all returned sessions belong to the requested user
			for _, s := range sessions {
				if s.UserID != tt.userID {
					t.Errorf("Session %s belongs to user %s, expected %s", s.ID, s.UserID, tt.userID)
				}
			}
		})
	}
}

func TestSessionRepository_ListByUserID_DateFiltering(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSessionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

	// Create sessions at different times
	now := time.Now()
	yesterday := now.Add(-24 * time.Hour)
	twoDaysAgo := now.Add(-48 * time.Hour)

	// Session from 2 days ago
	testutil.CreateTestSession(t, pool, student.ID, program.ID)
	testutil.ExecuteSQL(t, pool,
		"UPDATE practice_sessions SET started_at = $1 WHERE user_id = $2 AND started_at = (SELECT MAX(started_at) FROM practice_sessions WHERE user_id = $2)",
		twoDaysAgo, student.ID)

	// Session from yesterday
	testutil.CreateTestSession(t, pool, student.ID, program.ID)
	testutil.ExecuteSQL(t, pool,
		"UPDATE practice_sessions SET started_at = $1 WHERE user_id = $2 AND started_at = (SELECT MAX(started_at) FROM practice_sessions WHERE user_id = $2)",
		yesterday, student.ID)

	// Session from today
	testutil.CreateTestSession(t, pool, student.ID, program.ID)

	tests := []struct {
		name          string
		startDate     *time.Time
		endDate       *time.Time
		expectedCount int
	}{
		{
			name:          "no_date_filter",
			startDate:     nil,
			endDate:       nil,
			expectedCount: 3,
		},
		{
			name:          "filter_from_yesterday",
			startDate:     &yesterday,
			endDate:       nil,
			expectedCount: 2, // Yesterday and today
		},
		{
			name:          "filter_until_yesterday",
			startDate:     nil,
			endDate:       &yesterday,
			expectedCount: 2, // Two days ago and yesterday
		},
		{
			name:          "filter_date_range",
			startDate:     &twoDaysAgo,
			endDate:       &yesterday,
			expectedCount: 2, // Two days ago and yesterday
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sessions, err := repo.ListByUserID(ctx, student.ID, nil, tt.startDate, tt.endDate, 100, 0)
			if err != nil {
				t.Fatalf("ListByUserID() error = %v", err)
			}

			if len(sessions) != tt.expectedCount {
				t.Errorf("Expected %d sessions, got %d", tt.expectedCount, len(sessions))
			}
		})
	}
}

func TestSessionRepository_ListByUserID_Pagination(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSessionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

	// Create 10 sessions
	for i := 0; i < 10; i++ {
		testutil.CreateTestSession(t, pool, student.ID, program.ID)
		time.Sleep(1 * time.Millisecond) // Ensure different timestamps
	}

	tests := []struct {
		name          string
		limit         int
		offset        int
		expectedCount int
	}{
		{
			name:          "first_page",
			limit:         5,
			offset:        0,
			expectedCount: 5,
		},
		{
			name:          "second_page",
			limit:         5,
			offset:        5,
			expectedCount: 5,
		},
		{
			name:          "third_page_partial",
			limit:         5,
			offset:        10,
			expectedCount: 0,
		},
		{
			name:          "get_all",
			limit:         100,
			offset:        0,
			expectedCount: 10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sessions, err := repo.ListByUserID(ctx, student.ID, nil, nil, nil, tt.limit, tt.offset)
			if err != nil {
				t.Fatalf("ListByUserID() error = %v", err)
			}

			if len(sessions) != tt.expectedCount {
				t.Errorf("Expected %d sessions, got %d", tt.expectedCount, len(sessions))
			}
		})
	}
}

func TestSessionRepository_ListByUserID_OrderedByDate(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSessionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

	// Create sessions
	for i := 0; i < 5; i++ {
		testutil.CreateTestSession(t, pool, student.ID, program.ID)
		time.Sleep(2 * time.Millisecond) // Ensure different timestamps
	}

	sessions, err := repo.ListByUserID(ctx, student.ID, nil, nil, nil, 100, 0)
	if err != nil {
		t.Fatalf("ListByUserID() error = %v", err)
	}

	// Verify sessions are ordered by started_at DESC (newest first)
	for i := 0; i < len(sessions)-1; i++ {
		if sessions[i].StartedAt.Before(sessions[i+1].StartedAt) {
			t.Error("Sessions are not ordered by started_at DESC")
		}
	}
}

func TestSessionRepository_ListByUserID_IncludesProgramName(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSessionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "My Test Program")

	testutil.CreateTestSession(t, pool, student.ID, program.ID)

	sessions, err := repo.ListByUserID(ctx, student.ID, nil, nil, nil, 100, 0)
	if err != nil {
		t.Fatalf("ListByUserID() error = %v", err)
	}

	if len(sessions) != 1 {
		t.Fatalf("Expected 1 session, got %d", len(sessions))
	}

	if sessions[0].ProgramName == nil {
		t.Error("Expected ProgramName to be populated")
	} else if *sessions[0].ProgramName != "My Test Program" {
		t.Errorf("Expected program name 'My Test Program', got '%s'", *sessions[0].ProgramName)
	}
}
