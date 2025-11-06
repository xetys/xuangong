# Video Submission System - TDD Implementation Plan

**Author**: go-backend-architect agent
**Date**: 2025-11-06
**Status**: Planning Phase

---

## Executive Summary

This document provides a comprehensive TDD (Test-Driven Development) implementation plan for a chat-like video submission system where students and instructors can exchange messages (text + optional YouTube URLs) within submission conversations.

### Key Architectural Decisions

1. **DROP old tables** - Old `video_submissions` and `feedback` tables have NO DATA, so we'll create fresh schema
2. **Chat-like model** - Submissions are conversations with messages (like WhatsApp threads)
3. **YouTube URLs** - Leverage existing `youtube.ValidateURL()` package
4. **Read tracking** - Per-user, per-message read status using junction table
5. **Access control** - Students see only their submissions; admins see all

---

## Database Schema Design

### Migration: `000005_video_submission_chat_system.up.sql`

```sql
-- Drop old tables (confirmed NO DATA exists)
DROP TABLE IF EXISTS feedback;
DROP TABLE IF EXISTS video_submissions;

-- Submissions: Each is a conversation thread tied to a program
CREATE TABLE submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Student who created
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP -- Soft delete support
);

-- Messages: Each message in the conversation
CREATE TABLE submission_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Author (student or instructor)
    content TEXT NOT NULL CHECK (LENGTH(content) >= 1), -- Minimum 1 character
    youtube_url TEXT, -- Optional YouTube video/voice message URL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Read status tracking: Which messages each user has read
CREATE TABLE message_read_status (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES submission_messages(id) ON DELETE CASCADE,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, message_id)
);

-- Indexes for performance
CREATE INDEX idx_submissions_program_id ON submissions(program_id);
CREATE INDEX idx_submissions_user_id ON submissions(user_id);
CREATE INDEX idx_submissions_deleted_at ON submissions(deleted_at); -- For soft delete queries
CREATE INDEX idx_submission_messages_submission_id ON submission_messages(submission_id);
CREATE INDEX idx_submission_messages_created_at ON submission_messages(submission_id, created_at);
CREATE INDEX idx_message_read_status_user_id ON message_read_status(user_id);
CREATE INDEX idx_message_read_status_message_id ON message_read_status(message_id);

-- Trigger for updated_at on submissions
CREATE TRIGGER update_submissions_updated_at BEFORE UPDATE ON submissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Migration: `000005_video_submission_chat_system.down.sql`

```sql
DROP TRIGGER IF EXISTS update_submissions_updated_at ON submissions;
DROP TABLE IF EXISTS message_read_status;
DROP TABLE IF EXISTS submission_messages;
DROP TABLE IF EXISTS submissions;

-- Note: We don't recreate the old tables since they had no data
```

---

## Data Models

### File: `backend/internal/models/submission.go`

**REPLACE existing file completely:**

```go
package models

import (
    "time"
    "github.com/google/uuid"
)

// Submission represents a conversation thread between student and instructor
type Submission struct {
    ID         uuid.UUID  `json:"id" db:"id"`
    ProgramID  uuid.UUID  `json:"program_id" db:"program_id"`
    UserID     uuid.UUID  `json:"user_id" db:"user_id"` // Student who created
    Title      string     `json:"title" db:"title"`
    CreatedAt  time.Time  `json:"created_at" db:"created_at"`
    UpdatedAt  time.Time  `json:"updated_at" db:"updated_at"`
    DeletedAt  *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}

// SubmissionMessage represents a single message in a submission conversation
type SubmissionMessage struct {
    ID           uuid.UUID `json:"id" db:"id"`
    SubmissionID uuid.UUID `json:"submission_id" db:"submission_id"`
    UserID       uuid.UUID `json:"user_id" db:"user_id"` // Author (student or admin)
    Content      string    `json:"content" db:"content"`
    YoutubeURL   *string   `json:"youtube_url,omitempty" db:"youtube_url"`
    CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// MessageReadStatus tracks which messages a user has read
type MessageReadStatus struct {
    UserID    uuid.UUID `json:"user_id" db:"user_id"`
    MessageID uuid.UUID `json:"message_id" db:"message_id"`
    ReadAt    time.Time `json:"read_at" db:"read_at"`
}

// SubmissionWithDetails combines submission with metadata for list views
type SubmissionWithDetails struct {
    Submission
    ProgramName     string    `json:"program_name" db:"program_name"`
    StudentName     string    `json:"student_name" db:"student_name"`
    StudentEmail    string    `json:"student_email" db:"student_email"`
    MessageCount    int       `json:"message_count" db:"message_count"`
    UnreadCount     int       `json:"unread_count" db:"unread_count"` // For current user
    LastMessageAt   *time.Time `json:"last_message_at,omitempty" db:"last_message_at"`
}

// SubmissionWithMessages combines submission with all its messages
type SubmissionWithMessages struct {
    Submission
    ProgramName  string              `json:"program_name"`
    StudentName  string              `json:"student_name"`
    StudentEmail string              `json:"student_email"`
    Messages     []MessageWithAuthor `json:"messages"`
}

// MessageWithAuthor includes message author details
type MessageWithAuthor struct {
    SubmissionMessage
    AuthorName  string `json:"author_name" db:"author_name"`
    AuthorEmail string `json:"author_email" db:"author_email"`
    AuthorRole  string `json:"author_role" db:"author_role"`
    IsRead      bool   `json:"is_read" db:"is_read"` // For current user
}

// UnreadCount represents unread counts at different levels
type UnreadCount struct {
    TotalUnread   int                     `json:"total_unread"`
    ByProgram     map[string]int          `json:"by_program,omitempty"` // program_id -> count
    BySubmission  map[string]int          `json:"by_submission,omitempty"` // submission_id -> count
}
```

---

## TDD Implementation Plan

### Phase 1: Repository Layer (RED → GREEN → REFACTOR)

#### File: `backend/internal/repositories/submission_repository.go`

**REPLACE existing file completely. Implement these methods:**

```go
package repositories

import (
    "context"
    "time"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/xuangong/backend/internal/models"
)

type SubmissionRepository struct {
    db *pgxpool.Pool
}

func NewSubmissionRepository(db *pgxpool.Pool) *SubmissionRepository {
    return &SubmissionRepository{db: db}
}

// Submission CRUD
func (r *SubmissionRepository) Create(ctx context.Context, submission *models.Submission) error
func (r *SubmissionRepository) GetByID(ctx context.Context, submissionID uuid.UUID) (*models.Submission, error)
func (r *SubmissionRepository) List(ctx context.Context, filters SubmissionFilters) ([]models.SubmissionWithDetails, error)
func (r *SubmissionRepository) Delete(ctx context.Context, submissionID uuid.UUID) error // Soft delete

// Message operations
func (r *SubmissionRepository) CreateMessage(ctx context.Context, message *models.SubmissionMessage) error
func (r *SubmissionRepository) GetMessages(ctx context.Context, submissionID uuid.UUID, currentUserID uuid.UUID) ([]models.MessageWithAuthor, error)
func (r *SubmissionRepository) GetMessageByID(ctx context.Context, messageID uuid.UUID) (*models.SubmissionMessage, error)

// Read status operations
func (r *SubmissionRepository) MarkMessageAsRead(ctx context.Context, userID, messageID uuid.UUID) error
func (r *SubmissionRepository) MarkAllMessagesAsRead(ctx context.Context, userID, submissionID uuid.UUID) error
func (r *SubmissionRepository) GetUnreadCount(ctx context.Context, userID uuid.UUID, programID *uuid.UUID) (*models.UnreadCount, error)

// Access control helpers
func (r *SubmissionRepository) CanUserAccessSubmission(ctx context.Context, userID, submissionID uuid.UUID, isAdmin bool) (bool, error)
```

**SubmissionFilters struct:**

```go
type SubmissionFilters struct {
    UserID    *uuid.UUID // Filter by student (nil for admins to see all)
    ProgramID *uuid.UUID // Filter by program
    Limit     int
    Offset    int
}
```

#### File: `backend/internal/repositories/submission_repository_test.go`

**Create new file with comprehensive tests:**

##### RED Phase Tests (Write These First)

```go
package repositories

import (
    "context"
    "testing"
    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/pkg/testutil"
)

// Test naming convention: TestMethodName_Scenario_ExpectedBehavior

// --- SUBMISSION CRUD TESTS ---

func TestSubmissionRepository_Create_ValidSubmission_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{
        ProgramID: program.ID,
        UserID:    student.ID,
        Title:     "Help with form correction",
    }

    err := repo.Create(ctx, submission)

    // Assertions
    if err != nil {
        t.Fatalf("Create() error = %v", err)
    }
    if submission.ID == uuid.Nil {
        t.Error("Expected ID to be generated")
    }
    if submission.CreatedAt.IsZero() {
        t.Error("Expected CreatedAt to be set")
    }
    if submission.UpdatedAt.IsZero() {
        t.Error("Expected UpdatedAt to be set")
    }

    // Verify in database
    testutil.AssertRowCount(t, pool, "submissions", 1)
}

func TestSubmissionRepository_Create_EmptyTitle_Fails(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{
        ProgramID: program.ID,
        UserID:    student.ID,
        Title:     "", // Empty title
    }

    err := repo.Create(ctx, submission)

    if err == nil {
        t.Error("Expected error for empty title")
    }
}

func TestSubmissionRepository_GetByID_ExistingSubmission_ReturnsSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    created := &models.Submission{
        ProgramID: program.ID,
        UserID:    student.ID,
        Title:     "Test Submission",
    }
    repo.Create(ctx, created)

    retrieved, err := repo.GetByID(ctx, created.ID)

    if err != nil {
        t.Fatalf("GetByID() error = %v", err)
    }
    if retrieved == nil {
        t.Fatal("Expected submission to be found")
    }
    if retrieved.ID != created.ID {
        t.Errorf("Expected ID %s, got %s", created.ID, retrieved.ID)
    }
    if retrieved.Title != "Test Submission" {
        t.Errorf("Expected title 'Test Submission', got %s", retrieved.Title)
    }
}

func TestSubmissionRepository_GetByID_NonExistent_ReturnsNil(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    nonExistentID := uuid.New()
    retrieved, err := repo.GetByID(ctx, nonExistentID)

    if err != nil {
        t.Errorf("Expected no error, got %v", err)
    }
    if retrieved != nil {
        t.Error("Expected nil for non-existent submission")
    }
}

func TestSubmissionRepository_List_StudentFilter_OnlyReturnsTheirSubmissions(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
    student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    // Create submissions for both students
    sub1 := &models.Submission{ProgramID: program.ID, UserID: student1.ID, Title: "Student 1 Sub"}
    sub2 := &models.Submission{ProgramID: program.ID, UserID: student2.ID, Title: "Student 2 Sub"}
    repo.Create(ctx, sub1)
    repo.Create(ctx, sub2)

    // List for student1 only
    filters := SubmissionFilters{
        UserID: &student1.ID,
        Limit:  10,
        Offset: 0,
    }
    results, err := repo.List(ctx, filters)

    if err != nil {
        t.Fatalf("List() error = %v", err)
    }
    if len(results) != 1 {
        t.Errorf("Expected 1 submission, got %d", len(results))
    }
    if results[0].ID != sub1.ID {
        t.Error("Expected student1's submission")
    }
}

func TestSubmissionRepository_List_AdminNoFilter_ReturnsAllSubmissions(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
    student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    // Create submissions for both students
    sub1 := &models.Submission{ProgramID: program.ID, UserID: student1.ID, Title: "Sub 1"}
    sub2 := &models.Submission{ProgramID: program.ID, UserID: student2.ID, Title: "Sub 2"}
    repo.Create(ctx, sub1)
    repo.Create(ctx, sub2)

    // List with no user filter (admin view)
    filters := SubmissionFilters{
        UserID: nil,
        Limit:  10,
        Offset: 0,
    }
    results, err := repo.List(ctx, filters)

    if err != nil {
        t.Fatalf("List() error = %v", err)
    }
    if len(results) != 2 {
        t.Errorf("Expected 2 submissions, got %d", len(results))
    }
}

func TestSubmissionRepository_List_ProgramFilter_OnlyReturnsThatProgram(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 1")
    program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 2")

    sub1 := &models.Submission{ProgramID: program1.ID, UserID: student.ID, Title: "Sub for P1"}
    sub2 := &models.Submission{ProgramID: program2.ID, UserID: student.ID, Title: "Sub for P2"}
    repo.Create(ctx, sub1)
    repo.Create(ctx, sub2)

    filters := SubmissionFilters{
        ProgramID: &program1.ID,
        Limit:     10,
        Offset:    0,
    }
    results, err := repo.List(ctx, filters)

    if err != nil {
        t.Fatalf("List() error = %v", err)
    }
    if len(results) != 1 {
        t.Errorf("Expected 1 submission, got %d", len(results))
    }
    if results[0].ProgramID != program1.ID {
        t.Error("Expected program1's submission")
    }
}

func TestSubmissionRepository_List_IncludesMetadata_ProgramNameStudentNameMessageCount(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Tai Chi Basics")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    // Add messages
    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Message 1"}
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: admin.ID, Content: "Message 2"}
    repo.CreateMessage(ctx, msg1)
    repo.CreateMessage(ctx, msg2)

    filters := SubmissionFilters{Limit: 10, Offset: 0}
    results, err := repo.List(ctx, filters)

    if err != nil {
        t.Fatalf("List() error = %v", err)
    }
    if len(results) != 1 {
        t.Fatal("Expected 1 submission")
    }

    sub := results[0]
    if sub.ProgramName != "Tai Chi Basics" {
        t.Errorf("Expected program name 'Tai Chi Basics', got %s", sub.ProgramName)
    }
    if sub.StudentName != "Test User" {
        t.Errorf("Expected student name 'Test User', got %s", sub.StudentName)
    }
    if sub.MessageCount != 2 {
        t.Errorf("Expected 2 messages, got %d", sub.MessageCount)
    }
}

func TestSubmissionRepository_List_ExcludesSoftDeletedSubmissions(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    sub1 := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Active"}
    sub2 := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Deleted"}
    repo.Create(ctx, sub1)
    repo.Create(ctx, sub2)

    // Soft delete sub2
    repo.Delete(ctx, sub2.ID)

    filters := SubmissionFilters{Limit: 10, Offset: 0}
    results, err := repo.List(ctx, filters)

    if err != nil {
        t.Fatalf("List() error = %v", err)
    }
    if len(results) != 1 {
        t.Errorf("Expected 1 active submission, got %d", len(results))
    }
    if results[0].ID != sub1.ID {
        t.Error("Expected only active submission")
    }
}

func TestSubmissionRepository_List_Pagination_CorrectLimitOffset(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    // Create 10 submissions
    for i := 0; i < 10; i++ {
        sub := &models.Submission{
            ProgramID: program.ID,
            UserID:    student.ID,
            Title:     fmt.Sprintf("Submission %d", i),
        }
        repo.Create(ctx, sub)
        time.Sleep(1 * time.Millisecond) // Ensure different timestamps
    }

    // Test pagination
    tests := []struct {
        limit  int
        offset int
        expect int
    }{
        {limit: 5, offset: 0, expect: 5},
        {limit: 5, offset: 5, expect: 5},
        {limit: 5, offset: 10, expect: 0},
        {limit: 100, offset: 0, expect: 10},
    }

    for _, tt := range tests {
        filters := SubmissionFilters{Limit: tt.limit, Offset: tt.offset}
        results, err := repo.List(ctx, filters)
        if err != nil {
            t.Fatalf("List() error = %v", err)
        }
        if len(results) != tt.expect {
            t.Errorf("Limit=%d Offset=%d: expected %d results, got %d",
                tt.limit, tt.offset, tt.expect, len(results))
        }
    }
}

// --- MESSAGE CRUD TESTS ---

func TestSubmissionRepository_CreateMessage_ValidMessage_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    message := &models.SubmissionMessage{
        SubmissionID: submission.ID,
        UserID:       student.ID,
        Content:      "Please review my form",
        YoutubeURL:   stringPtr("https://youtube.com/watch?v=dQw4w9WgXcQ"),
    }

    err := repo.CreateMessage(ctx, message)

    if err != nil {
        t.Fatalf("CreateMessage() error = %v", err)
    }
    if message.ID == uuid.Nil {
        t.Error("Expected ID to be generated")
    }
    if message.CreatedAt.IsZero() {
        t.Error("Expected CreatedAt to be set")
    }
}

func TestSubmissionRepository_CreateMessage_EmptyContent_Fails(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    message := &models.SubmissionMessage{
        SubmissionID: submission.ID,
        UserID:       student.ID,
        Content:      "", // Empty content
    }

    err := repo.CreateMessage(ctx, message)

    if err == nil {
        t.Error("Expected error for empty content")
    }
}

func TestSubmissionRepository_CreateMessage_WithoutYoutubeURL_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    message := &models.SubmissionMessage{
        SubmissionID: submission.ID,
        UserID:       student.ID,
        Content:      "Text only message",
        YoutubeURL:   nil,
    }

    err := repo.CreateMessage(ctx, message)

    if err != nil {
        t.Fatalf("CreateMessage() error = %v", err)
    }
}

func TestSubmissionRepository_GetMessages_ReturnsMessagesInOrder_OldestFirst(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "First"}
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: admin.ID, Content: "Second"}
    msg3 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Third"}

    repo.CreateMessage(ctx, msg1)
    time.Sleep(1 * time.Millisecond)
    repo.CreateMessage(ctx, msg2)
    time.Sleep(1 * time.Millisecond)
    repo.CreateMessage(ctx, msg3)

    messages, err := repo.GetMessages(ctx, submission.ID, student.ID)

    if err != nil {
        t.Fatalf("GetMessages() error = %v", err)
    }
    if len(messages) != 3 {
        t.Fatalf("Expected 3 messages, got %d", len(messages))
    }

    // Verify order (oldest first)
    if messages[0].Content != "First" {
        t.Error("First message should be 'First'")
    }
    if messages[1].Content != "Second" {
        t.Error("Second message should be 'Second'")
    }
    if messages[2].Content != "Third" {
        t.Error("Third message should be 'Third'")
    }
}

func TestSubmissionRepository_GetMessages_IncludesAuthorDetails_NameEmailRole(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    msg := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Test"}
    repo.CreateMessage(ctx, msg)

    messages, err := repo.GetMessages(ctx, submission.ID, student.ID)

    if err != nil {
        t.Fatalf("GetMessages() error = %v", err)
    }
    if len(messages) != 1 {
        t.Fatal("Expected 1 message")
    }

    m := messages[0]
    if m.AuthorName != "Test User" {
        t.Errorf("Expected author name 'Test User', got %s", m.AuthorName)
    }
    if m.AuthorEmail != "student@test.com" {
        t.Errorf("Expected author email 'student@test.com', got %s", m.AuthorEmail)
    }
    if m.AuthorRole != "student" {
        t.Errorf("Expected author role 'student', got %s", m.AuthorRole)
    }
}

func TestSubmissionRepository_GetMessages_MarksReadStatus_ForCurrentUser(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 1"}
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: admin.ID, Content: "Msg 2"}
    repo.CreateMessage(ctx, msg1)
    repo.CreateMessage(ctx, msg2)

    // Admin marks msg1 as read
    repo.MarkMessageAsRead(ctx, admin.ID, msg1.ID)

    messages, err := repo.GetMessages(ctx, submission.ID, admin.ID)

    if err != nil {
        t.Fatalf("GetMessages() error = %v", err)
    }
    if len(messages) != 2 {
        t.Fatal("Expected 2 messages")
    }

    // msg1 should be marked as read for admin
    if !messages[0].IsRead {
        t.Error("Expected msg1 to be marked as read")
    }
    // msg2 should NOT be marked as read (admin wrote it)
    if messages[1].IsRead {
        t.Error("Expected msg2 to be unread")
    }
}

// --- READ STATUS TESTS ---

func TestSubmissionRepository_MarkMessageAsRead_CreatesReadStatus(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    message := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Test"}
    repo.CreateMessage(ctx, message)

    err := repo.MarkMessageAsRead(ctx, admin.ID, message.ID)

    if err != nil {
        t.Fatalf("MarkMessageAsRead() error = %v", err)
    }

    // Verify in database
    testutil.AssertRowCount(t, pool, "message_read_status", 1)
}

func TestSubmissionRepository_MarkMessageAsRead_Idempotent_SecondCallNoError(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    message := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Test"}
    repo.CreateMessage(ctx, message)

    // Mark as read twice
    err1 := repo.MarkMessageAsRead(ctx, admin.ID, message.ID)
    err2 := repo.MarkMessageAsRead(ctx, admin.ID, message.ID)

    if err1 != nil {
        t.Errorf("First call error = %v", err1)
    }
    if err2 != nil {
        t.Errorf("Second call error = %v (should be idempotent)", err2)
    }

    // Should still only have 1 row
    testutil.AssertRowCount(t, pool, "message_read_status", 1)
}

func TestSubmissionRepository_MarkAllMessagesAsRead_MarksAllInSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 1"}
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 2"}
    msg3 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 3"}
    repo.CreateMessage(ctx, msg1)
    repo.CreateMessage(ctx, msg2)
    repo.CreateMessage(ctx, msg3)

    err := repo.MarkAllMessagesAsRead(ctx, admin.ID, submission.ID)

    if err != nil {
        t.Fatalf("MarkAllMessagesAsRead() error = %v", err)
    }

    // All 3 messages should be marked as read
    testutil.AssertRowCount(t, pool, "message_read_status", 3)
}

func TestSubmissionRepository_GetUnreadCount_NoFilters_ReturnsTotalUnread(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    // Create 3 messages from student
    for i := 0; i < 3; i++ {
        msg := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: fmt.Sprintf("Msg %d", i)}
        repo.CreateMessage(ctx, msg)
    }

    // Admin hasn't read any
    unread, err := repo.GetUnreadCount(ctx, admin.ID, nil)

    if err != nil {
        t.Fatalf("GetUnreadCount() error = %v", err)
    }
    if unread.TotalUnread != 3 {
        t.Errorf("Expected 3 unread messages, got %d", unread.TotalUnread)
    }
}

func TestSubmissionRepository_GetUnreadCount_WithProgramFilter_OnlyCountsThatProgram(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program1 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 1")
    program2 := testutil.CreateTestProgram(t, pool, admin.ID, "Program 2")

    sub1 := &models.Submission{ProgramID: program1.ID, UserID: student.ID, Title: "Sub 1"}
    sub2 := &models.Submission{ProgramID: program2.ID, UserID: student.ID, Title: "Sub 2"}
    repo.Create(ctx, sub1)
    repo.Create(ctx, sub2)

    // 2 messages in program1
    msg1 := &models.SubmissionMessage{SubmissionID: sub1.ID, UserID: student.ID, Content: "P1 Msg 1"}
    msg2 := &models.SubmissionMessage{SubmissionID: sub1.ID, UserID: student.ID, Content: "P1 Msg 2"}
    repo.CreateMessage(ctx, msg1)
    repo.CreateMessage(ctx, msg2)

    // 1 message in program2
    msg3 := &models.SubmissionMessage{SubmissionID: sub2.ID, UserID: student.ID, Content: "P2 Msg 1"}
    repo.CreateMessage(ctx, msg3)

    unread, err := repo.GetUnreadCount(ctx, admin.ID, &program1.ID)

    if err != nil {
        t.Fatalf("GetUnreadCount() error = %v", err)
    }
    if unread.TotalUnread != 2 {
        t.Errorf("Expected 2 unread in program1, got %d", unread.TotalUnread)
    }
}

func TestSubmissionRepository_GetUnreadCount_ExcludesOwnMessages(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    // Student writes 2 messages
    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Student Msg"}
    repo.CreateMessage(ctx, msg1)

    // Admin writes 1 message
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: admin.ID, Content: "Admin Msg"}
    repo.CreateMessage(ctx, msg2)

    // Admin's unread count should be 1 (only student's message)
    unread, err := repo.GetUnreadCount(ctx, admin.ID, nil)

    if err != nil {
        t.Fatalf("GetUnreadCount() error = %v", err)
    }
    if unread.TotalUnread != 1 {
        t.Errorf("Expected 1 unread (excluding own message), got %d", unread.TotalUnread)
    }
}

func TestSubmissionRepository_GetUnreadCount_AfterMarkingAsRead_DecreasesCount(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    msg1 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 1"}
    msg2 := &models.SubmissionMessage{SubmissionID: submission.ID, UserID: student.ID, Content: "Msg 2"}
    repo.CreateMessage(ctx, msg1)
    repo.CreateMessage(ctx, msg2)

    // Initially 2 unread
    unread1, _ := repo.GetUnreadCount(ctx, admin.ID, nil)
    if unread1.TotalUnread != 2 {
        t.Errorf("Expected 2 unread initially, got %d", unread1.TotalUnread)
    }

    // Mark one as read
    repo.MarkMessageAsRead(ctx, admin.ID, msg1.ID)

    // Now 1 unread
    unread2, err := repo.GetUnreadCount(ctx, admin.ID, nil)
    if err != nil {
        t.Fatalf("GetUnreadCount() error = %v", err)
    }
    if unread2.TotalUnread != 1 {
        t.Errorf("Expected 1 unread after marking one read, got %d", unread2.TotalUnread)
    }
}

// --- ACCESS CONTROL TESTS ---

func TestSubmissionRepository_CanUserAccessSubmission_Student_OnlyOwnSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
    student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    sub1 := &models.Submission{ProgramID: program.ID, UserID: student1.ID, Title: "Student 1 Sub"}
    repo.Create(ctx, sub1)

    // Student1 can access their own submission
    canAccess1, err := repo.CanUserAccessSubmission(ctx, student1.ID, sub1.ID, false)
    if err != nil {
        t.Fatalf("CanUserAccessSubmission() error = %v", err)
    }
    if !canAccess1 {
        t.Error("Student should be able to access their own submission")
    }

    // Student2 cannot access student1's submission
    canAccess2, err := repo.CanUserAccessSubmission(ctx, student2.ID, sub1.ID, false)
    if err != nil {
        t.Fatalf("CanUserAccessSubmission() error = %v", err)
    }
    if canAccess2 {
        t.Error("Student should NOT be able to access other student's submission")
    }
}

func TestSubmissionRepository_CanUserAccessSubmission_Admin_CanAccessAll(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)
    repo := NewSubmissionRepository(pool)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission := &models.Submission{ProgramID: program.ID, UserID: student.ID, Title: "Test"}
    repo.Create(ctx, submission)

    canAccess, err := repo.CanUserAccessSubmission(ctx, admin.ID, submission.ID, true)
    if err != nil {
        t.Fatalf("CanUserAccessSubmission() error = %v", err)
    }
    if !canAccess {
        t.Error("Admin should be able to access any submission")
    }
}

// Helper function
func stringPtr(s string) *string {
    return &s
}
```

##### GREEN Phase: Implementation

After writing RED tests, implement the repository methods in `submission_repository.go` to make tests pass.

**Key implementation notes:**

1. **List() query** must JOIN with programs and users tables to get metadata
2. **GetMessages() query** must JOIN with users and LEFT JOIN with message_read_status
3. **GetUnreadCount()** must:
   - Exclude messages authored by the current user
   - Count only messages without a read_status entry for current user
   - Support optional program filter
4. **MarkMessageAsRead()** must use `INSERT ... ON CONFLICT DO NOTHING` for idempotency

##### REFACTOR Phase: Optimization

After tests pass, refactor for:
- Query efficiency (avoid N+1 queries)
- Connection pooling best practices
- Error message clarity
- Code duplication removal

---

### Phase 2: Service Layer (RED → GREEN → REFACTOR)

#### File: `backend/internal/services/submission_service.go`

**Create new file:**

```go
package services

import (
    "context"
    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/internal/repositories"
    "github.com/xuangong/backend/pkg/youtube"
    appErrors "github.com/xuangong/backend/pkg/errors"
)

type SubmissionService struct {
    submissionRepo *repositories.SubmissionRepository
    programRepo    *repositories.ProgramRepository
}

func NewSubmissionService(
    submissionRepo *repositories.SubmissionRepository,
    programRepo *repositories.ProgramRepository,
) *SubmissionService {
    return &SubmissionService{
        submissionRepo: submissionRepo,
        programRepo:    programRepo,
    }
}

// CreateSubmission creates a new submission conversation
func (s *SubmissionService) CreateSubmission(ctx context.Context, userID, programID uuid.UUID, title string) (*models.Submission, error)

// GetSubmission retrieves submission with messages (with access check)
func (s *SubmissionService) GetSubmission(ctx context.Context, submissionID, userID uuid.UUID, isAdmin bool) (*models.SubmissionWithMessages, error)

// ListSubmissions lists submissions (filtered by access control)
func (s *SubmissionService) ListSubmissions(ctx context.Context, userID uuid.UUID, isAdmin bool, programID *uuid.UUID, limit, offset int) ([]models.SubmissionWithDetails, error)

// AddMessage adds a message to a submission (with validation)
func (s *SubmissionService) AddMessage(ctx context.Context, submissionID, userID uuid.UUID, isAdmin bool, content string, youtubeURL *string) (*models.SubmissionMessage, error)

// MarkMessageAsRead marks a message as read
func (s *SubmissionService) MarkMessageAsRead(ctx context.Context, userID, messageID uuid.UUID, isAdmin bool) error

// GetUnreadCount gets unread message counts
func (s *SubmissionService) GetUnreadCount(ctx context.Context, userID uuid.UUID, programID *uuid.UUID) (*models.UnreadCount, error)
```

#### File: `backend/internal/services/submission_service_test.go`

**Create new file with service-level tests:**

##### RED Phase Tests

```go
package services

import (
    "context"
    "testing"
    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/internal/repositories"
    "github.com/xuangong/backend/pkg/testutil"
    appErrors "github.com/xuangong/backend/pkg/errors"
)

// --- BUSINESS LOGIC TESTS ---

func TestSubmissionService_CreateSubmission_ValidData_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, err := service.CreateSubmission(ctx, student.ID, program.ID, "Need help with form")

    if err != nil {
        t.Fatalf("CreateSubmission() error = %v", err)
    }
    if submission == nil {
        t.Fatal("Expected submission to be created")
    }
    if submission.Title != "Need help with form" {
        t.Errorf("Expected title 'Need help with form', got %s", submission.Title)
    }
}

func TestSubmissionService_CreateSubmission_EmptyTitle_ReturnsError(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    _, err := service.CreateSubmission(ctx, student.ID, program.ID, "")

    if err == nil {
        t.Error("Expected error for empty title")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "BAD_REQUEST" {
        t.Error("Expected BAD_REQUEST error")
    }
}

func TestSubmissionService_CreateSubmission_NonExistentProgram_ReturnsNotFoundError(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    nonExistentProgram := uuid.New()

    _, err := service.CreateSubmission(ctx, student.ID, nonExistentProgram, "Test")

    if err == nil {
        t.Error("Expected error for non-existent program")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "NOT_FOUND" {
        t.Error("Expected NOT_FOUND error")
    }
}

func TestSubmissionService_GetSubmission_Student_CanAccessOwnSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    created, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    retrieved, err := service.GetSubmission(ctx, created.ID, student.ID, false)

    if err != nil {
        t.Fatalf("GetSubmission() error = %v", err)
    }
    if retrieved == nil {
        t.Fatal("Expected submission to be retrieved")
    }
    if retrieved.ID != created.ID {
        t.Error("Expected same submission ID")
    }
}

func TestSubmissionService_GetSubmission_Student_CannotAccessOthersSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
    student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student1.ID, program.ID, "Test")

    _, err := service.GetSubmission(ctx, submission.ID, student2.ID, false)

    if err == nil {
        t.Error("Expected authorization error")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "FORBIDDEN" {
        t.Error("Expected FORBIDDEN error")
    }
}

func TestSubmissionService_GetSubmission_Admin_CanAccessAnySubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    retrieved, err := service.GetSubmission(ctx, submission.ID, admin.ID, true)

    if err != nil {
        t.Fatalf("GetSubmission() error = %v", err)
    }
    if retrieved == nil {
        t.Fatal("Expected admin to access submission")
    }
}

func TestSubmissionService_AddMessage_ValidContent_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    message, err := service.AddMessage(ctx, submission.ID, student.ID, false, "Please review my form", nil)

    if err != nil {
        t.Fatalf("AddMessage() error = %v", err)
    }
    if message == nil {
        t.Fatal("Expected message to be created")
    }
    if message.Content != "Please review my form" {
        t.Errorf("Expected content 'Please review my form', got %s", message.Content)
    }
}

func TestSubmissionService_AddMessage_EmptyContent_ReturnsError(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    _, err := service.AddMessage(ctx, submission.ID, student.ID, false, "", nil)

    if err == nil {
        t.Error("Expected error for empty content")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "BAD_REQUEST" {
        t.Error("Expected BAD_REQUEST error")
    }
}

func TestSubmissionService_AddMessage_ValidYoutubeURL_Success(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    youtubeURL := "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    message, err := service.AddMessage(ctx, submission.ID, student.ID, false, "Check my form", &youtubeURL)

    if err != nil {
        t.Fatalf("AddMessage() error = %v", err)
    }
    if message.YoutubeURL == nil {
        t.Fatal("Expected YouTube URL to be saved")
    }
    if *message.YoutubeURL != youtubeURL {
        t.Errorf("Expected YouTube URL %s, got %s", youtubeURL, *message.YoutubeURL)
    }
}

func TestSubmissionService_AddMessage_InvalidYoutubeURL_ReturnsError(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    invalidURL := "https://not-youtube.com/watch?v=123"
    _, err := service.AddMessage(ctx, submission.ID, student.ID, false, "Test", &invalidURL)

    if err == nil {
        t.Error("Expected error for invalid YouTube URL")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "BAD_REQUEST" {
        t.Error("Expected BAD_REQUEST error")
    }
}

func TestSubmissionService_AddMessage_Student_CannotAddToOthersSubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student1 := testutil.CreateTestStudent(t, pool, "student1@test.com")
    student2 := testutil.CreateTestStudent(t, pool, "student2@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student1.ID, program.ID, "Test")

    _, err := service.AddMessage(ctx, submission.ID, student2.ID, false, "I shouldn't be able to post this", nil)

    if err == nil {
        t.Error("Expected authorization error")
    }
    appErr, ok := err.(*appErrors.AppError)
    if !ok || appErr.Code != "FORBIDDEN" {
        t.Error("Expected FORBIDDEN error")
    }
}

func TestSubmissionService_AddMessage_Admin_CanAddToAnySubmission(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := NewSubmissionService(submissionRepo, programRepo)
    ctx := context.Background()

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(ctx, student.ID, program.ID, "Test")

    message, err := service.AddMessage(ctx, submission.ID, admin.ID, true, "Great work!", nil)

    if err != nil {
        t.Fatalf("AddMessage() error = %v", err)
    }
    if message == nil {
        t.Fatal("Expected admin to be able to add message")
    }
}

// Add more tests for ListSubmissions, MarkMessageAsRead, GetUnreadCount...
```

##### GREEN Phase: Implementation

Implement service methods with:
1. **Validation** - Title not empty, content not empty, YouTube URL format
2. **Authorization** - Check `CanUserAccessSubmission` before operations
3. **Business logic** - Verify program exists before creating submission
4. **Error wrapping** - Use `appErrors` for consistent error responses

##### REFACTOR Phase

- Extract validation functions
- Consolidate access checks
- Improve error messages

---

### Phase 3: Handler Layer (RED → GREEN → REFACTOR)

#### File: `backend/internal/handlers/submission_handler.go`

**Create new file:**

```go
package handlers

import (
    "net/http"
    "github.com/gin-gonic/gin"
    "github.com/go-playground/validator/v10"
    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/middleware"
    "github.com/xuangong/backend/internal/services"
    "github.com/xuangong/backend/internal/validators"
    appErrors "github.com/xuangong/backend/pkg/errors"
)

type SubmissionHandler struct {
    submissionService *services.SubmissionService
    validate          *validator.Validate
}

func NewSubmissionHandler(submissionService *services.SubmissionService) *SubmissionHandler {
    return &SubmissionHandler{
        submissionService: submissionService,
        validate:          validator.New(),
    }
}

// CreateSubmission creates a new submission conversation
// POST /api/v1/programs/:programId/submissions
func (h *SubmissionHandler) CreateSubmission(c *gin.Context)

// ListSubmissions lists submissions (filtered by access)
// GET /api/v1/submissions?program_id=xxx
func (h *SubmissionHandler) ListSubmissions(c *gin.Context)

// GetSubmission gets a submission with messages
// GET /api/v1/submissions/:id
func (h *SubmissionHandler) GetSubmission(c *gin.Context)

// AddMessage adds a message to submission
// POST /api/v1/submissions/:id/messages
func (h *SubmissionHandler) AddMessage(c *gin.Context)

// MarkMessageAsRead marks a message as read
// PUT /api/v1/messages/:id/read
func (h *SubmissionHandler) MarkMessageAsRead(c *gin.Context)

// GetUnreadCount gets unread message counts
// GET /api/v1/submissions/unread-count?program_id=xxx
func (h *SubmissionHandler) GetUnreadCount(c *gin.Context)
```

#### File: `backend/internal/validators/requests.go`

**Add these request/response structs:**

```go
// Submission requests
type CreateSubmissionRequest struct {
    Title string `json:"title" validate:"required,min=3,max=255"`
}

type AddMessageRequest struct {
    Content    string  `json:"content" validate:"required,min=1"`
    YoutubeURL *string `json:"youtube_url" validate:"omitempty,url"`
}

// Query parameters
type ListSubmissionsQuery struct {
    ProgramID *string `form:"program_id" validate:"omitempty,uuid"`
    Limit     int     `form:"limit" validate:"min=1,max=100"`
    Offset    int     `form:"offset" validate:"min=0"`
}
```

#### File: `backend/internal/handlers/submission_handler_test.go`

**Create new file with handler tests:**

##### RED Phase Tests

```go
package handlers

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/xuangong/backend/internal/models"
    "github.com/xuangong/backend/internal/repositories"
    "github.com/xuangong/backend/internal/services"
    "github.com/xuangong/backend/pkg/testutil"
)

func TestSubmissionHandler_CreateSubmission_ValidRequest_Returns201(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := services.NewSubmissionService(submissionRepo, programRepo)
    handler := NewSubmissionHandler(service)

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    // Setup request
    reqBody := map[string]interface{}{
        "title": "Help with form",
    }
    body, _ := json.Marshal(reqBody)

    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    c.Request, _ = http.NewRequest(http.MethodPost, "/api/v1/programs/"+program.ID.String()+"/submissions", bytes.NewBuffer(body))
    c.Request.Header.Set("Content-Type", "application/json")
    c.Params = gin.Params{gin.Param{Key: "programId", Value: program.ID.String()}}
    c.Set("user_id", student.ID.String())
    c.Set("user_role", "student")

    handler.CreateSubmission(c)

    // Assertions
    if w.Code != http.StatusCreated {
        t.Errorf("Expected status 201, got %d", w.Code)
    }

    var response map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &response)

    if response["submission"] == nil {
        t.Error("Expected submission in response")
    }
}

func TestSubmissionHandler_CreateSubmission_EmptyTitle_Returns400(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := services.NewSubmissionService(submissionRepo, programRepo)
    handler := NewSubmissionHandler(service)

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    reqBody := map[string]interface{}{
        "title": "",
    }
    body, _ := json.Marshal(reqBody)

    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    c.Request, _ = http.NewRequest(http.MethodPost, "/api/v1/programs/"+program.ID.String()+"/submissions", bytes.NewBuffer(body))
    c.Request.Header.Set("Content-Type", "application/json")
    c.Params = gin.Params{gin.Param{Key: "programId", Value: program.ID.String()}}
    c.Set("user_id", student.ID.String())
    c.Set("user_role", "student")

    handler.CreateSubmission(c)

    if w.Code != http.StatusBadRequest {
        t.Errorf("Expected status 400, got %d", w.Code)
    }
}

func TestSubmissionHandler_GetSubmission_ValidID_Returns200WithMessages(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := services.NewSubmissionService(submissionRepo, programRepo)
    handler := NewSubmissionHandler(service)

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(c.Request.Context(), student.ID, program.ID, "Test")
    service.AddMessage(c.Request.Context(), submission.ID, student.ID, false, "First message", nil)

    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    c.Request, _ = http.NewRequest(http.MethodGet, "/api/v1/submissions/"+submission.ID.String(), nil)
    c.Params = gin.Params{gin.Param{Key: "id", Value: submission.ID.String()}}
    c.Set("user_id", student.ID.String())
    c.Set("user_role", "student")

    handler.GetSubmission(c)

    if w.Code != http.StatusOK {
        t.Errorf("Expected status 200, got %d", w.Code)
    }

    var response map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &response)

    submission := response["submission"].(map[string]interface{})
    messages := submission["messages"].([]interface{})

    if len(messages) != 1 {
        t.Errorf("Expected 1 message, got %d", len(messages))
    }
}

func TestSubmissionHandler_AddMessage_ValidRequest_Returns201(t *testing.T) {
    pool := testutil.SetupTestDB(t)
    defer testutil.TeardownTestDB(t, pool)

    submissionRepo := repositories.NewSubmissionRepository(pool)
    programRepo := repositories.NewProgramRepository(pool)
    service := services.NewSubmissionService(submissionRepo, programRepo)
    handler := NewSubmissionHandler(service)

    admin := testutil.CreateTestAdmin(t, pool, "admin@test.com")
    student := testutil.CreateTestStudent(t, pool, "student@test.com")
    program := testutil.CreateTestProgram(t, pool, admin.ID, "Test Program")

    submission, _ := service.CreateSubmission(c.Request.Context(), student.ID, program.ID, "Test")

    reqBody := map[string]interface{}{
        "content":     "Please review my form",
        "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    }
    body, _ := json.Marshal(reqBody)

    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)
    c.Request, _ = http.NewRequest(http.MethodPost, "/api/v1/submissions/"+submission.ID.String()+"/messages", bytes.NewBuffer(body))
    c.Request.Header.Set("Content-Type", "application/json")
    c.Params = gin.Params{gin.Param{Key: "id", Value: submission.ID.String()}}
    c.Set("user_id", student.ID.String())
    c.Set("user_role", "student")

    handler.AddMessage(c)

    if w.Code != http.StatusCreated {
        t.Errorf("Expected status 201, got %d", w.Code)
    }
}

// Add more handler tests...
```

##### GREEN Phase: Implementation

Implement handlers with:
1. **Request validation** - Bind JSON/query params, validate with validator
2. **Extract user context** - Use `middleware.GetUserID()` and `middleware.GetUserRole()`
3. **Call service layer** - Pass context and parameters
4. **Response formatting** - Consistent JSON structure
5. **Error handling** - Use `respondWithAppError()` helper

##### REFACTOR Phase

- Extract common patterns (auth extraction, error responses)
- Consolidate response builders
- Add Swagger documentation comments

---

### Phase 4: Integration and Routing

#### File: `backend/cmd/api/main.go`

**Update to wire up submission system:**

```go
// In main():
submissionRepo := repositories.NewSubmissionRepository(pool)

// Update service initialization
submissionService := services.NewSubmissionService(submissionRepo, programRepo)

// Update handler initialization
submissionHandler := handlers.NewSubmissionHandler(submissionService)

// In setupRouter(), add routes:
protected := api.Group("")
protected.Use(middleware.Auth(authService))
{
    // ... existing routes ...

    // Submissions
    protected.POST("/programs/:programId/submissions", submissionHandler.CreateSubmission)
    protected.GET("/submissions", submissionHandler.ListSubmissions)
    protected.GET("/submissions/unread-count", submissionHandler.GetUnreadCount)
    protected.GET("/submissions/:id", submissionHandler.GetSubmission)
    protected.POST("/submissions/:id/messages", submissionHandler.AddMessage)
    protected.PUT("/messages/:id/read", submissionHandler.MarkMessageAsRead)
}
```

---

## Testing Strategy

### Unit Tests (Repository Layer)
- Test all CRUD operations
- Test access control logic
- Test query filters
- Test edge cases (empty results, NULL values)
- Test soft delete behavior
- Test unread counting logic

**Coverage Target**: >90%

### Integration Tests (Service Layer)
- Test business logic validation
- Test authorization enforcement
- Test cross-entity operations (program existence check)
- Test YouTube URL validation integration
- Test transaction rollback scenarios

**Coverage Target**: >85%

### Handler Tests
- Test request validation
- Test response formatting
- Test HTTP status codes
- Test error responses
- Test authentication/authorization flow

**Coverage Target**: >80%

### Manual Testing Checklist
1. Create submission as student
2. Add text message
3. Add message with YouTube URL
4. Admin views all submissions
5. Admin adds response
6. Student sees unread count
7. Student marks as read
8. Verify unread count decreases
9. Filter submissions by program
10. Test pagination

---

## API Endpoints Reference

### POST /api/v1/programs/:programId/submissions
Create new submission

**Request:**
```json
{
  "title": "Help with Ba Gua form"
}
```

**Response (201):**
```json
{
  "submission": {
    "id": "uuid",
    "program_id": "uuid",
    "user_id": "uuid",
    "title": "Help with Ba Gua form",
    "created_at": "2025-11-06T10:00:00Z",
    "updated_at": "2025-11-06T10:00:00Z"
  }
}
```

### GET /api/v1/submissions
List submissions (filtered by access)

**Query Params:**
- `program_id` (optional, UUID)
- `limit` (default: 20, max: 100)
- `offset` (default: 0)

**Response (200):**
```json
{
  "submissions": [
    {
      "id": "uuid",
      "program_id": "uuid",
      "user_id": "uuid",
      "title": "Help with Ba Gua form",
      "program_name": "Ba Gua Zhang Basics",
      "student_name": "Li Wei",
      "student_email": "liwei@example.com",
      "message_count": 5,
      "unread_count": 2,
      "last_message_at": "2025-11-06T12:30:00Z",
      "created_at": "2025-11-06T10:00:00Z",
      "updated_at": "2025-11-06T12:30:00Z"
    }
  ],
  "total": 10,
  "limit": 20,
  "offset": 0
}
```

### GET /api/v1/submissions/:id
Get submission with messages

**Response (200):**
```json
{
  "submission": {
    "id": "uuid",
    "program_id": "uuid",
    "user_id": "uuid",
    "title": "Help with Ba Gua form",
    "program_name": "Ba Gua Zhang Basics",
    "student_name": "Li Wei",
    "student_email": "liwei@example.com",
    "created_at": "2025-11-06T10:00:00Z",
    "updated_at": "2025-11-06T12:30:00Z",
    "messages": [
      {
        "id": "uuid",
        "submission_id": "uuid",
        "user_id": "uuid",
        "content": "I'm having trouble with the footwork",
        "youtube_url": "https://youtube.com/watch?v=abc123",
        "author_name": "Li Wei",
        "author_email": "liwei@example.com",
        "author_role": "student",
        "is_read": false,
        "created_at": "2025-11-06T10:05:00Z"
      },
      {
        "id": "uuid",
        "submission_id": "uuid",
        "user_id": "uuid",
        "content": "Focus on keeping your weight centered",
        "youtube_url": null,
        "author_name": "Stefan Müller",
        "author_email": "stefan@example.com",
        "author_role": "admin",
        "is_read": true,
        "created_at": "2025-11-06T12:30:00Z"
      }
    ]
  }
}
```

### POST /api/v1/submissions/:id/messages
Add message to submission

**Request:**
```json
{
  "content": "Thank you! That helps a lot",
  "youtube_url": "https://youtube.com/watch?v=xyz789"
}
```

**Response (201):**
```json
{
  "message": {
    "id": "uuid",
    "submission_id": "uuid",
    "user_id": "uuid",
    "content": "Thank you! That helps a lot",
    "youtube_url": "https://youtube.com/watch?v=xyz789",
    "created_at": "2025-11-06T13:00:00Z"
  }
}
```

### PUT /api/v1/messages/:id/read
Mark message as read

**Response (200):**
```json
{
  "success": true
}
```

### GET /api/v1/submissions/unread-count
Get unread message counts

**Query Params:**
- `program_id` (optional, UUID)

**Response (200):**
```json
{
  "total_unread": 5,
  "by_program": {
    "uuid-1": 2,
    "uuid-2": 3
  },
  "by_submission": {
    "uuid-a": 1,
    "uuid-b": 2,
    "uuid-c": 2
  }
}
```

---

## Error Handling

All errors follow the existing `appErrors` pattern:

```json
{
  "error": {
    "code": "BAD_REQUEST",
    "message": "Invalid YouTube URL",
    "details": "youtube.ValidateURL: invalid video ID format"
  }
}
```

**Error Codes:**
- `BAD_REQUEST` (400) - Invalid input, empty content, invalid YouTube URL
- `UNAUTHORIZED` (401) - Not authenticated
- `FORBIDDEN` (403) - Student accessing other's submission
- `NOT_FOUND` (404) - Submission or message not found
- `INTERNAL_ERROR` (500) - Database or unexpected errors

---

## Migration Execution

```bash
# Development
cd backend
migrate -path migrations -database "postgres://postgres:postgres@localhost:5432/xuangong_dev?sslmode=disable" up

# Test
migrate -path migrations -database "postgres://postgres:postgres@localhost:5432/xuangong_test?sslmode=disable" up

# Production (via CI/CD or manual)
migrate -path migrations -database "${DATABASE_URL}" up
```

---

## Files to Create/Modify

### New Files
1. `backend/migrations/000005_video_submission_chat_system.up.sql`
2. `backend/migrations/000005_video_submission_chat_system.down.sql`
3. `backend/internal/handlers/submission_handler.go`
4. `backend/internal/handlers/submission_handler_test.go`
5. `backend/internal/services/submission_service.go`
6. `backend/internal/services/submission_service_test.go`
7. `backend/internal/repositories/submission_repository_test.go`

### Files to Replace
1. `backend/internal/models/submission.go` - Complete replacement
2. `backend/internal/repositories/submission_repository.go` - Complete replacement

### Files to Update
1. `backend/internal/validators/requests.go` - Add submission request structs
2. `backend/cmd/api/main.go` - Wire up submission service and routes

---

## Implementation Order (TDD Strict)

### Day 1: Repository Layer
1. ✅ Write migration files
2. ✅ Run migration on test DB
3. ✅ Write ALL repository tests (RED phase)
4. ✅ Implement repository methods (GREEN phase)
5. ✅ Refactor and optimize queries (REFACTOR phase)
6. ✅ Verify 90%+ test coverage

### Day 2: Service Layer
1. ✅ Write ALL service tests (RED phase)
2. ✅ Implement service methods (GREEN phase)
3. ✅ Refactor validation and error handling (REFACTOR phase)
4. ✅ Verify 85%+ test coverage

### Day 3: Handler Layer
1. ✅ Add request/response validators
2. ✅ Write ALL handler tests (RED phase)
3. ✅ Implement handlers (GREEN phase)
4. ✅ Refactor response formatting (REFACTOR phase)
5. ✅ Verify 80%+ test coverage

### Day 4: Integration & Testing
1. ✅ Update main.go with routing
2. ✅ Run full test suite
3. ✅ Manual testing with curl/Postman
4. ✅ Update API documentation
5. ✅ Create session log

---

## Success Criteria

- [ ] All migrations run successfully
- [ ] All repository tests pass (>90% coverage)
- [ ] All service tests pass (>85% coverage)
- [ ] All handler tests pass (>80% coverage)
- [ ] Manual testing checklist complete
- [ ] No breaking changes to existing endpoints
- [ ] YouTube URL validation working
- [ ] Access control verified (students can't see others' submissions)
- [ ] Unread counts accurate
- [ ] Pagination working correctly

---

## Security Considerations

1. **Access Control**: Students can ONLY access their own submissions
2. **SQL Injection**: All queries use parameterized statements (pgx)
3. **Input Validation**: All user input validated at handler AND service layers
4. **YouTube URLs**: Validated using existing `youtube.ValidateURL()` package
5. **Soft Deletes**: Messages are NOT soft-deleted (only submissions)
6. **Rate Limiting**: Existing middleware applies to all endpoints

---

## Performance Considerations

1. **Indexes**: Created on all foreign keys and filter columns
2. **Pagination**: Required for list endpoints
3. **N+1 Queries**: Avoided by JOINing in single queries
4. **Connection Pooling**: Existing pgx pool configuration sufficient
5. **Unread Counts**: Calculated in single query with JOINs

---

## Future Enhancements (Not in MVP)

1. **Real-time updates**: WebSocket notifications for new messages
2. **File attachments**: Direct video upload (not just YouTube URLs)
3. **Rich text**: Markdown support for message content
4. **Message editing**: Edit/delete own messages
5. **Submission templates**: Pre-fill title based on program
6. **Bulk operations**: Mark all as read for a submission
7. **Search**: Full-text search across messages
8. **Analytics**: Instructor response time metrics

---

## Questions for Clarification

None at this time. Requirements are clear and comprehensive.

---

## References

- Existing patterns: `session_repository.go`, `session_service.go`, `sessions.go`
- Test utilities: `backend/pkg/testutil/`
- YouTube validation: `backend/pkg/youtube/validator.go`
- Error handling: `backend/pkg/errors/`
- Authentication: `backend/internal/middleware/auth.go`

---

**END OF IMPLEMENTATION PLAN**