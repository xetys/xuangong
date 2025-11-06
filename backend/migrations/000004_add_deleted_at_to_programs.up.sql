-- Add deleted_at column to programs table for soft delete functionality
ALTER TABLE programs ADD COLUMN deleted_at TIMESTAMP DEFAULT NULL;

-- Add index for faster queries filtering out deleted programs
CREATE INDEX idx_programs_deleted_at ON programs(deleted_at) WHERE deleted_at IS NULL;

-- Add comment explaining the soft delete column
COMMENT ON COLUMN programs.deleted_at IS 'Timestamp when program was soft deleted. NULL means active.';
