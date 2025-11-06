-- Remove index
DROP INDEX IF EXISTS idx_programs_deleted_at;

-- Remove deleted_at column from programs table
ALTER TABLE programs DROP COLUMN IF EXISTS deleted_at;
