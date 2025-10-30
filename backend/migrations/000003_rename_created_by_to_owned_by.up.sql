-- Rename created_by to owned_by in programs table
ALTER TABLE programs RENAME COLUMN created_by TO owned_by;

-- Update the index name for consistency
ALTER INDEX idx_programs_created_by RENAME TO idx_programs_owned_by;
