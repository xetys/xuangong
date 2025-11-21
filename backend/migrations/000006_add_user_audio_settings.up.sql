-- Add audio volume settings to users table
-- Values: 0 (off), 25 (quiet), 50 (medium), 75 (loud), 100 (max)

ALTER TABLE users
ADD COLUMN countdown_volume INTEGER NOT NULL DEFAULT 75
    CHECK (countdown_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN start_volume INTEGER NOT NULL DEFAULT 75
    CHECK (start_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN halfway_volume INTEGER NOT NULL DEFAULT 25
    CHECK (halfway_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN finish_volume INTEGER NOT NULL DEFAULT 100
    CHECK (finish_volume IN (0, 25, 50, 75, 100));

-- Add comments explaining the purpose
COMMENT ON COLUMN users.countdown_volume IS 'Volume for countdown beeps before exercise starts (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.start_volume IS 'Volume for exercise start sound (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.halfway_volume IS 'Volume for halfway completion bell (0, 25, 50, 75, 100)';
COMMENT ON COLUMN users.finish_volume IS 'Volume for session completion gong (0, 25, 50, 75, 100)';
