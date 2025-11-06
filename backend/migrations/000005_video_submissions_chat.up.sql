-- Drop old submission tables (no data to preserve)
DROP TABLE IF EXISTS feedback CASCADE;
DROP TABLE IF EXISTS video_submissions CASCADE;

-- Submissions: Conversation threads for student-instructor feedback
CREATE TABLE submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

-- Submission messages: Individual messages in the conversation
CREATE TABLE submission_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    youtube_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Message read status: Track which messages each user has read
CREATE TABLE message_read_status (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES submission_messages(id) ON DELETE CASCADE,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, message_id)
);

-- Indexes for performance
CREATE INDEX idx_submissions_program_id ON submissions(program_id);
CREATE INDEX idx_submissions_user_id ON submissions(user_id);
CREATE INDEX idx_submissions_deleted_at ON submissions(deleted_at);
CREATE INDEX idx_submissions_created_at ON submissions(created_at DESC);

CREATE INDEX idx_submission_messages_submission_id ON submission_messages(submission_id);
CREATE INDEX idx_submission_messages_user_id ON submission_messages(user_id);
CREATE INDEX idx_submission_messages_created_at ON submission_messages(created_at);

CREATE INDEX idx_message_read_status_user_id ON message_read_status(user_id);
CREATE INDEX idx_message_read_status_message_id ON message_read_status(message_id);

-- Trigger for updated_at on submissions
CREATE TRIGGER update_submissions_updated_at BEFORE UPDATE ON submissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
