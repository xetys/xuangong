-- Rollback: Rename owned_by back to created_by
ALTER TABLE programs RENAME COLUMN owned_by TO created_by;

-- Rollback: Restore the index name
ALTER INDEX idx_programs_owned_by RENAME TO idx_programs_created_by;
