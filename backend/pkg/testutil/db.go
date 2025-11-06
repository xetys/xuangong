package testutil

import (
	"context"
	"fmt"
	"log"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuangong/backend/internal/config"
	"github.com/xuangong/backend/internal/database"
)

const (
	// Default test database URL - override with TEST_DATABASE_URL env var
	defaultTestDBURL = "postgres://postgres:postgres@localhost:5432/xuangong_test?sslmode=disable"

	// Test database connection settings
	testMaxConns     = 5
	testIdleConns    = 2
	testLifetimeMins = 5
)

// SetupTestDB creates and configures a test database connection pool.
// It runs all migrations and returns a ready-to-use connection pool.
// Call TeardownTestDB to clean up after tests.
func SetupTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	// Get test database URL from environment or use default
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		dbURL = defaultTestDBURL
	}

	// Create database config
	dbConfig := &config.DatabaseConfig{
		URL:                dbURL,
		MaxConnections:     testMaxConns,
		MaxIdleConnections: testIdleConns,
		MaxLifetimeMinutes: testLifetimeMins,
	}

	// Create connection pool
	pool, err := database.NewPool(dbConfig)
	if err != nil {
		t.Fatalf("Failed to create test database pool: %v", err)
	}

	// Run migrations to ensure schema is up to date
	if err := database.RunMigrations(dbURL, "../../migrations"); err != nil {
		pool.Close()
		t.Fatalf("Failed to run migrations on test database: %v", err)
	}

	// Truncate all tables to start with clean state
	TruncateTables(t, pool)

	return pool
}

// TeardownTestDB closes the database connection pool and cleans up.
func TeardownTestDB(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()

	if pool != nil {
		// Truncate tables before closing to leave database clean
		TruncateTables(t, pool)
		pool.Close()
	}
}

// TruncateTables removes all data from test tables while preserving schema.
// This is faster than dropping/recreating tables between tests.
func TruncateTables(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// List of tables to truncate in dependency order (child tables first)
	tables := []string{
		"session_exercises",
		"sessions",
		"user_programs",
		"program_exercises",
		"programs",
		"exercises",
		"users",
	}

	for _, table := range tables {
		query := fmt.Sprintf("TRUNCATE TABLE %s RESTART IDENTITY CASCADE", table)
		if _, err := pool.Exec(ctx, query); err != nil {
			// Log error but don't fail - table might not exist yet
			log.Printf("Warning: Failed to truncate table %s: %v", table, err)
		}
	}
}

// ExecuteSQL is a helper function to execute arbitrary SQL during test setup.
// Useful for creating specific test scenarios.
func ExecuteSQL(t *testing.T, pool *pgxpool.Pool, query string, args ...interface{}) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if _, err := pool.Exec(ctx, query, args...); err != nil {
		t.Fatalf("Failed to execute SQL: %v\nQuery: %s", err, query)
	}
}

// QueryRow is a helper function to query a single row during tests.
func QueryRow(t *testing.T, pool *pgxpool.Pool, query string, args ...interface{}) map[string]interface{} {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	rows, err := pool.Query(ctx, query, args...)
	if err != nil {
		t.Fatalf("Failed to query: %v\nQuery: %s", err, query)
	}
	defer rows.Close()

	if !rows.Next() {
		t.Fatal("No rows returned")
	}

	values, err := rows.Values()
	if err != nil {
		t.Fatalf("Failed to get values: %v", err)
	}

	fields := rows.FieldDescriptions()
	result := make(map[string]interface{})
	for i, field := range fields {
		result[string(field.Name)] = values[i]
	}

	return result
}

// AssertRowCount checks that a table has the expected number of rows.
func AssertRowCount(t *testing.T, pool *pgxpool.Pool, table string, expected int) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var count int
	query := fmt.Sprintf("SELECT COUNT(*) FROM %s", table)
	err := pool.QueryRow(ctx, query).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to count rows in %s: %v", table, err)
	}

	if count != expected {
		t.Errorf("Expected %d rows in %s, got %d", expected, table, count)
	}
}
