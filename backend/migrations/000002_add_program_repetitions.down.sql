-- Remove repetition tracking fields from programs table
ALTER TABLE programs
    DROP COLUMN IF EXISTS repetitions_planned,
    DROP COLUMN IF EXISTS repetitions_completed;
