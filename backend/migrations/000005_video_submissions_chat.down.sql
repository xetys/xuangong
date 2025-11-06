-- Drop new tables
DROP TRIGGER IF EXISTS update_submissions_updated_at ON submissions;
DROP TABLE IF EXISTS message_read_status CASCADE;
DROP TABLE IF EXISTS submission_messages CASCADE;
DROP TABLE IF EXISTS submissions CASCADE;

-- Restore old tables
CREATE TABLE video_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES practice_sessions(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES exercises(id) ON DELETE SET NULL,
    video_url TEXT,
    thumbnail_url TEXT,
    duration_seconds INTEGER,
    file_size_mb DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID REFERENCES video_submissions(id) ON DELETE CASCADE,
    instructor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    feedback_text TEXT NOT NULL,
    feedback_type VARCHAR(20) DEFAULT 'text',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_submissions_user_id ON video_submissions(user_id);
CREATE INDEX idx_submissions_status ON video_submissions(status);
CREATE INDEX idx_feedback_submission_id ON feedback(submission_id);
CREATE INDEX idx_feedback_instructor_id ON feedback(instructor_id);
