-- Add repetition tracking fields to programs table
ALTER TABLE programs
    ADD COLUMN repetitions_planned INTEGER NULL,
    ADD COLUMN repetitions_completed INTEGER NULL DEFAULT 0;
