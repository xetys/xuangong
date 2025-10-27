-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table with role-based access
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'student')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Programs (training routines)
CREATE TABLE programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    is_template BOOLEAN DEFAULT false,
    is_public BOOLEAN DEFAULT false,
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercises within programs (with timing directly included)
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    order_index INTEGER NOT NULL,
    exercise_type VARCHAR(20) CHECK (exercise_type IN ('timed', 'repetition', 'combined')),
    duration_seconds INTEGER,
    repetitions INTEGER,
    rest_after_seconds INTEGER DEFAULT 0,
    has_sides BOOLEAN DEFAULT false,
    side_duration_seconds INTEGER,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User's assigned programs
CREATE TABLE user_programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    custom_settings JSONB DEFAULT '{}',
    UNIQUE(user_id, program_id)
);

-- Practice sessions
CREATE TABLE practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    program_id UUID REFERENCES programs(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    total_duration_seconds INTEGER,
    completion_rate DECIMAL(5,2),
    notes TEXT,
    device_info JSONB
);

-- Individual exercise completion logs
CREATE TABLE exercise_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES practice_sessions(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES exercises(id) ON DELETE SET NULL,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    planned_duration_seconds INTEGER,
    actual_duration_seconds INTEGER,
    repetitions_planned INTEGER,
    repetitions_completed INTEGER,
    skipped BOOLEAN DEFAULT false,
    notes TEXT
);

-- Video submissions
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

-- Instructor feedback
CREATE TABLE feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID REFERENCES video_submissions(id) ON DELETE CASCADE,
    instructor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    feedback_text TEXT NOT NULL,
    feedback_type VARCHAR(20) DEFAULT 'text',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_programs_created_by ON programs(created_by);
CREATE INDEX idx_programs_is_template ON programs(is_template);
CREATE INDEX idx_programs_is_public ON programs(is_public);
CREATE INDEX idx_exercises_program_id ON exercises(program_id);
CREATE INDEX idx_exercises_order ON exercises(program_id, order_index);
CREATE INDEX idx_user_programs_user_id ON user_programs(user_id);
CREATE INDEX idx_user_programs_is_active ON user_programs(user_id, is_active);
CREATE INDEX idx_sessions_user_id ON practice_sessions(user_id);
CREATE INDEX idx_sessions_started_at ON practice_sessions(started_at);
CREATE INDEX idx_exercise_logs_session_id ON exercise_logs(session_id);
CREATE INDEX idx_submissions_user_id ON video_submissions(user_id);
CREATE INDEX idx_submissions_status ON video_submissions(status);
CREATE INDEX idx_feedback_submission_id ON feedback(submission_id);
CREATE INDEX idx_feedback_instructor_id ON feedback(instructor_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_programs_updated_at BEFORE UPDATE ON programs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
