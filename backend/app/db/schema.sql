-- 3D Human Motion Comparison System Database Schema
-- PostgreSQL 17.5

-- Drop existing tables if they exist
DROP TABLE IF EXISTS comparisons CASCADE;
DROP TABLE IF EXISTS camera_views CASCADE;
DROP TABLE IF EXISTS exercise_data CASCADE;
DROP TABLE IF EXISTS exercises CASCADE;
DROP TABLE IF EXISTS subjects CASCADE;

-- Subjects table (s03-s11)
CREATE TABLE subjects (
    id SERIAL PRIMARY KEY,
    subject_code VARCHAR(10) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercises table (47 exercise types)
CREATE TABLE exercises (
    id SERIAL PRIMARY KEY,
    exercise_name VARCHAR(100) UNIQUE NOT NULL,
    category VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercise data table (SMPL-X parameters per subject/exercise)
CREATE TABLE exercise_data (
    id SERIAL PRIMARY KEY,
    subject_id INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
    
    -- SMPL-X parameters (stored as JSONB for flexibility)
    smplx_params JSONB NOT NULL,
    
    -- 3D joints (25 joints)
    joints3d JSONB NOT NULL,
    
    -- Repetition annotations
    rep_annotations JSONB,
    
    -- Metadata
    num_frames INTEGER,
    duration_seconds FLOAT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(subject_id, exercise_id)
);

-- Camera views table (4 camera angles per exercise)
CREATE TABLE camera_views (
    id SERIAL PRIMARY KEY,
    exercise_data_id INTEGER REFERENCES exercise_data(id) ON DELETE CASCADE,
    
    -- Camera identifier (e.g., "50591643Lb", "58860488RB", etc.)
    camera_id VARCHAR(20) NOT NULL,
    
    -- Camera parameters (intrinsics, extrinsics)
    camera_params JSONB NOT NULL,
    
    -- Video file path
    video_path VARCHAR(500),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(exercise_data_id, camera_id)
);

-- Comparisons table (user comparison history)
CREATE TABLE comparisons (
    id SERIAL PRIMARY KEY,
    
    -- Reference exercise
    reference_exercise_data_id INTEGER REFERENCES exercise_data(id),
    
    -- User uploaded data
    user_smplx_params JSONB,
    user_joints3d JSONB,
    
    -- Comparison results
    similarity_score FLOAT,
    errors_detected JSONB,
    feedback TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_exercise_data_subject ON exercise_data(subject_id);
CREATE INDEX idx_exercise_data_exercise ON exercise_data(exercise_id);
CREATE INDEX idx_camera_views_exercise_data ON camera_views(exercise_data_id);
CREATE INDEX idx_comparisons_reference ON comparisons(reference_exercise_data_id);
CREATE INDEX idx_exercises_name ON exercises(exercise_name);
CREATE INDEX idx_subjects_code ON subjects(subject_code);

-- Create GIN indexes for JSONB columns (for faster queries)
CREATE INDEX idx_exercise_data_smplx_params ON exercise_data USING GIN (smplx_params);
CREATE INDEX idx_exercise_data_joints3d ON exercise_data USING GIN (joints3d);
