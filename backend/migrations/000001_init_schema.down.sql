-- Drop triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_programs_updated_at ON programs;

-- Drop function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop tables in reverse order (respecting foreign keys)
DROP TABLE IF EXISTS feedback;
DROP TABLE IF EXISTS video_submissions;
DROP TABLE IF EXISTS exercise_logs;
DROP TABLE IF EXISTS practice_sessions;
DROP TABLE IF EXISTS user_programs;
DROP TABLE IF EXISTS exercises;
DROP TABLE IF EXISTS programs;
DROP TABLE IF EXISTS users;

-- Drop extension
DROP EXTENSION IF EXISTS "pgcrypto";
