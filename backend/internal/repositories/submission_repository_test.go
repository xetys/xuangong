package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/xuangong/backend/internal/models"
	"github.com/xuangong/backend/pkg/testutil"
)

func TestSubmissionRepository_Create(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

	tests := []struct {
		name    string
		setup   func() (*models.Submission, error)
		wantErr bool
	}{
		{
			name: "create_valid_submission",
			setup: func() (*models.Submission, error) {
				return repo.Create(ctx, program.ID, student.ID, "My First Submission")
			},
			wantErr: false,
		},
		{
			name: "create_submission_with_invalid_program_id",
			setup: func() (*models.Submission, error) {
				return repo.Create(ctx, uuid.New(), student.ID, "Invalid Program")
			},
			wantErr: true,
		},
		{
			name: "create_submission_with_invalid_user_id",
			setup: func() (*models.Submission, error) {
				return repo.Create(ctx, program.ID, uuid.New(), "Invalid User")
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			submission, err := tt.setup()

			if (err != nil) != tt.wantErr {
				t.Errorf("Create() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if submission.ID == uuid.Nil {
					t.Error("Expected submission ID to be set")
				}
				if submission.CreatedAt.IsZero() {
					t.Error("Expected CreatedAt to be set")
				}
				if submission.UpdatedAt.IsZero() {
					t.Error("Expected UpdatedAt to be set")
				}
			}
		})
	}
}

func TestSubmissionRepository_GetByID(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
	student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student1.ID, "Test Submission")

	tests := []struct {
		name    string
		userID  uuid.UUID
		isAdmin bool
		wantErr bool
	}{
		{
			name:    "student_owner_can_get_their_submission",
			userID:  student1.ID,
			isAdmin: false,
			wantErr: false,
		},
		{
			name:    "admin_can_get_any_submission",
			userID:  admin.ID,
			isAdmin: true,
			wantErr: false,
		},
		{
			name:    "other_student_cannot_get_submission",
			userID:  student2.ID,
			isAdmin: false,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := repo.GetByID(ctx, submission.ID, tt.userID, tt.isAdmin)

			if (err != nil) != tt.wantErr {
				t.Errorf("GetByID() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if result == nil {
					t.Fatal("Expected submission to be returned")
				}
				if result.ID != submission.ID {
					t.Errorf("Expected submission ID %v, got %v", submission.ID, result.ID)
				}
			}
		})
	}
}

func TestSubmissionRepository_GetByID_ExcludesDeleted(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student.ID, "Deleted Submission")

	// Soft delete the submission
	err := repo.SoftDelete(ctx, submission.ID)
	if err != nil {
		t.Fatalf("Failed to soft delete: %v", err)
	}

	// Try to get it
	result, err := repo.GetByID(ctx, submission.ID, student.ID, false)
	if err == nil {
		t.Error("Expected error when getting deleted submission")
	}
	if result != nil {
		t.Error("Expected nil result for deleted submission")
	}
}

func TestSubmissionRepository_List(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
	student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 2")

	// Create submissions
	sub1 := testutil.CreateTestSubmission(t, pool, program1.ID, student1.ID, "Student1 Program1")
	sub2 := testutil.CreateTestSubmission(t, pool, program1.ID, student2.ID, "Student2 Program1")
	sub3 := testutil.CreateTestSubmission(t, pool, program2.ID, student1.ID, "Student1 Program2")

	tests := []struct {
		name         string
		programID    *uuid.UUID
		userID       uuid.UUID
		isAdmin      bool
		expectedIDs  []uuid.UUID
		minExpected  int
	}{
		{
			name:        "student_sees_only_their_submissions",
			programID:   nil,
			userID:      student1.ID,
			isAdmin:     false,
			expectedIDs: []uuid.UUID{sub1.ID, sub3.ID},
		},
		{
			name:        "admin_sees_all_submissions",
			programID:   nil,
			userID:      admin.ID,
			isAdmin:     true,
			minExpected: 3, // At least the 3 we created
		},
		{
			name:        "filter_by_program",
			programID:   &program1.ID,
			userID:      admin.ID,
			isAdmin:     true,
			expectedIDs: []uuid.UUID{sub1.ID, sub2.ID},
		},
		{
			name:        "student_filter_by_program",
			programID:   &program1.ID,
			userID:      student1.ID,
			isAdmin:     false,
			expectedIDs: []uuid.UUID{sub1.ID},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			results, err := repo.List(ctx, tt.programID, tt.userID, tt.isAdmin, 50, 0)
			if err != nil {
				t.Fatalf("List() error = %v", err)
			}

			if tt.minExpected > 0 {
				if len(results) < tt.minExpected {
					t.Errorf("Expected at least %d submissions, got %d", tt.minExpected, len(results))
				}
			}

			if len(tt.expectedIDs) > 0 {
				if len(results) != len(tt.expectedIDs) {
					t.Errorf("Expected %d submissions, got %d", len(tt.expectedIDs), len(results))
				}

				foundIDs := make(map[uuid.UUID]bool)
				for _, sub := range results {
					foundIDs[sub.ID] = true
				}

				for _, expectedID := range tt.expectedIDs {
					if !foundIDs[expectedID] {
						t.Errorf("Expected to find submission %v in results", expectedID)
					}
				}
			}
		})
	}
}

func TestSubmissionRepository_CreateMessage(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student.ID, "Test Submission")

	youtubeURL := "https://youtube.com/watch?v=test123"

	tests := []struct {
		name    string
		setup   func() (*models.SubmissionMessage, error)
		wantErr bool
	}{
		{
			name: "create_text_message",
			setup: func() (*models.SubmissionMessage, error) {
				return repo.CreateMessage(ctx, submission.ID, student.ID, "Hello instructor!", nil)
			},
			wantErr: false,
		},
		{
			name: "create_message_with_youtube_url",
			setup: func() (*models.SubmissionMessage, error) {
				return repo.CreateMessage(ctx, submission.ID, admin.ID, "Check this video", &youtubeURL)
			},
			wantErr: false,
		},
		{
			name: "create_message_with_invalid_submission",
			setup: func() (*models.SubmissionMessage, error) {
				return repo.CreateMessage(ctx, uuid.New(), student.ID, "Invalid", nil)
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			message, err := tt.setup()

			if (err != nil) != tt.wantErr {
				t.Errorf("CreateMessage() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if message.ID == uuid.Nil {
					t.Error("Expected message ID to be set")
				}
				if message.CreatedAt.IsZero() {
					t.Error("Expected CreatedAt to be set")
				}
			}
		})
	}
}

func TestSubmissionRepository_GetMessages(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
	student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student1.ID, "Test Submission")

	// Create messages
	msg1 := testutil.CreateTestMessage(t, pool, submission.ID, student1.ID, "First message", nil)
	msg2 := testutil.CreateTestMessage(t, pool, submission.ID, admin.ID, "Admin reply", nil)
	_msg3 := testutil.CreateTestMessage(t, pool, submission.ID, student1.ID, "Thanks!", nil)
	_ = _msg3 // Used for test setup

	// Mark msg2 as read by student1
	testutil.MarkMessageAsRead(t, pool, student1.ID, msg2.ID)

	tests := []struct {
		name            string
		userID          uuid.UUID
		isAdmin         bool
		wantErr         bool
		expectedCount   int
		checkReadStatus bool
	}{
		{
			name:            "student_owner_gets_messages",
			userID:          student1.ID,
			isAdmin:         false,
			wantErr:         false,
			expectedCount:   3,
			checkReadStatus: true,
		},
		{
			name:          "admin_gets_messages",
			userID:        admin.ID,
			isAdmin:       true,
			wantErr:       false,
			expectedCount: 3,
		},
		{
			name:    "other_student_cannot_get_messages",
			userID:  student2.ID,
			isAdmin: false,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			messages, err := repo.GetMessages(ctx, submission.ID, tt.userID, tt.isAdmin)

			if (err != nil) != tt.wantErr {
				t.Errorf("GetMessages() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if len(messages) != tt.expectedCount {
					t.Errorf("Expected %d messages, got %d", tt.expectedCount, len(messages))
				}

				if tt.checkReadStatus {
					// Find msg2 in results and check it's marked as read
					for _, msg := range messages {
						if msg.ID == msg2.ID {
							if !msg.IsRead {
								t.Error("Expected msg2 to be marked as read for student1")
							}
						}
						if msg.ID == msg1.ID || msg.ID == _msg3.ID {
							if msg.IsRead {
								t.Error("Expected own messages to NOT be marked as read")
							}
						}
					}
				}
			}
		})
	}
}

func TestSubmissionRepository_MarkMessageAsRead(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student.ID, "Test Submission")
	message := testutil.CreateTestMessage(t, pool, submission.ID, admin.ID, "Instructor message", nil)

	tests := []struct {
		name    string
		userID  uuid.UUID
		msgID   uuid.UUID
		wantErr bool
	}{
		{
			name:    "mark_message_as_read",
			userID:  student.ID,
			msgID:   message.ID,
			wantErr: false,
		},
		{
			name:    "mark_same_message_twice_is_idempotent",
			userID:  student.ID,
			msgID:   message.ID,
			wantErr: false,
		},
		{
			name:    "mark_invalid_message",
			userID:  student.ID,
			msgID:   uuid.New(),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := repo.MarkMessageAsRead(ctx, tt.userID, tt.msgID)

			if (err != nil) != tt.wantErr {
				t.Errorf("MarkMessageAsRead() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSubmissionRepository_GetUnreadCount(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 1")
	program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 2")

	// Create submissions
	sub1 := testutil.CreateTestSubmission(t, pool, program1.ID, student.ID, "Sub 1")
	sub2 := testutil.CreateTestSubmission(t, pool, program2.ID, student.ID, "Sub 2")

	// Create messages from admin (unread for student)
	msg1 := testutil.CreateTestMessage(t, pool, sub1.ID, admin.ID, "Message 1", nil)
	_ = testutil.CreateTestMessage(t, pool, sub1.ID, admin.ID, "Message 2", nil) // msg2 - unread
	_ = testutil.CreateTestMessage(t, pool, sub2.ID, admin.ID, "Message 3", nil) // msg3 - unread

	// Mark msg1 as read by student
	testutil.MarkMessageAsRead(t, pool, student.ID, msg1.ID)

	tests := []struct {
		name                 string
		userID               uuid.UUID
		programID            *uuid.UUID
		expectedTotal        int
		expectedByProgram    map[uuid.UUID]int
		expectedBySubmission map[uuid.UUID]int
	}{
		{
			name:          "student_unread_count_all",
			userID:        student.ID,
			programID:     nil,
			expectedTotal: 2, // msg2 and msg3
			expectedByProgram: map[uuid.UUID]int{
				program1.ID: 1, // msg2
				program2.ID: 1, // msg3
			},
			expectedBySubmission: map[uuid.UUID]int{
				sub1.ID: 1, // msg2
				sub2.ID: 1, // msg3
			},
		},
		{
			name:          "student_unread_count_program1",
			userID:        student.ID,
			programID:     &program1.ID,
			expectedTotal: 1, // msg2
			expectedBySubmission: map[uuid.UUID]int{
				sub1.ID: 1,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			counts, err := repo.GetUnreadCount(ctx, tt.userID, tt.programID)
			if err != nil {
				t.Fatalf("GetUnreadCount() error = %v", err)
			}

			if counts.Total != tt.expectedTotal {
				t.Errorf("Expected total %d, got %d", tt.expectedTotal, counts.Total)
			}

			if tt.expectedByProgram != nil {
				for progID, expectedCount := range tt.expectedByProgram {
					if counts.ByProgram[progID.String()] != expectedCount {
						t.Errorf("Program %v: expected count %d, got %d", progID, expectedCount, counts.ByProgram[progID.String()])
					}
				}
			}

			if tt.expectedBySubmission != nil {
				for subID, expectedCount := range tt.expectedBySubmission {
					if counts.BySubmission[subID.String()] != expectedCount {
						t.Errorf("Submission %v: expected count %d, got %d", subID, expectedCount, counts.BySubmission[subID.String()])
					}
				}
			}
		})
	}
}

func TestSubmissionRepository_SoftDelete(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

	tests := []struct {
		name    string
		setup   func() uuid.UUID
		wantErr bool
	}{
		{
			name: "soft_delete_existing_submission",
			setup: func() uuid.UUID {
				sub := testutil.CreateTestSubmission(t, pool, program.ID, student.ID, "To Delete")
				return sub.ID
			},
			wantErr: false,
		},
		{
			name: "soft_delete_non_existent_submission",
			setup: func() uuid.UUID {
				return uuid.New()
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			submissionID := tt.setup()

			err := repo.SoftDelete(ctx, submissionID)

			if (err != nil) != tt.wantErr {
				t.Errorf("SoftDelete() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				// Verify submission cannot be retrieved
				result, err := repo.GetByID(ctx, submissionID, student.ID, false)
				if err == nil || result != nil {
					t.Error("Expected submission to be excluded after soft delete")
				}
			}
		})
	}
}

func TestSubmissionRepository_List_EnrichedMetadata(t *testing.T) {
	pool := testutil.SetupTestDB(t)
	defer testutil.TeardownTestDB(t, pool)

	repo := NewSubmissionRepository(pool)
	ctx := context.Background()

	admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
	student := testutil.CreateTestStudent(t, pool, "student@test.com")
	program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")
	submission := testutil.CreateTestSubmission(t, pool, program.ID, student.ID, "Test Submission")

	// Add messages
	testutil.CreateTestMessage(t, pool, submission.ID, student.ID, "Student message", nil)
	testutil.CreateTestMessage(t, pool, submission.ID, admin.ID, "Admin reply", nil)

	// List should return enriched data
	results, err := repo.List(ctx, nil, admin.ID, true, 50, 0)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}

	found := false
	for _, item := range results {
		if item.ID == submission.ID {
			found = true

			// Check metadata is populated
			if item.ProgramName == "" {
				t.Error("Expected program name to be populated")
			}
			if item.StudentName == "" {
				t.Error("Expected student name to be populated")
			}
			if item.MessageCount != 2 {
				t.Errorf("Expected message count 2, got %d", item.MessageCount)
			}
			if item.LastMessageAt.IsZero() {
				t.Error("Expected last message timestamp to be set")
			}

			break
		}
	}

	if !found {
		t.Error("Expected to find submission in enriched list")
	}
}
