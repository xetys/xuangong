-- Remove audio volume settings from users table

ALTER TABLE users
DROP COLUMN IF EXISTS countdown_volume,
DROP COLUMN IF EXISTS start_volume,
DROP COLUMN IF EXISTS halfway_volume,
DROP COLUMN IF EXISTS finish_volume;
