"""SQLAlchemy ORM models for the database."""

from sqlalchemy import Column, Integer, String, Float, Text, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database.db_config import Base


class Subject(Base):
    """Subject model (s03-s11)."""
    __tablename__ = 'subjects'
    
    id = Column(Integer, primary_key=True)
    subject_code = Column(String(10), unique=True, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    exercise_data = relationship("ExerciseData", back_populates="subject", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Subject(code='{self.subject_code}')>"


class Exercise(Base):
    """Exercise model (47 exercise types)."""
    __tablename__ = 'exercises'
    
    id = Column(Integer, primary_key=True)
    exercise_name = Column(String(100), unique=True, nullable=False)
    category = Column(String(50))
    description = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    exercise_data = relationship("ExerciseData", back_populates="exercise", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Exercise(name='{self.exercise_name}', category='{self.category}')>"


class ExerciseData(Base):
    """Exercise data model with SMPL-X parameters."""
    __tablename__ = 'exercise_data'
    
    id = Column(Integer, primary_key=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False)
    exercise_id = Column(Integer, ForeignKey('exercises.id', ondelete='CASCADE'), nullable=False)
    
    # SMPL-X parameters (transl, global_orient, body_pose, etc.)
    smplx_params = Column(JSONB, nullable=False)
    
    # 3D joints (25 joints)
    joints3d = Column(JSONB, nullable=False)
    
    # Repetition annotations
    rep_annotations = Column(JSONB)
    
    # Metadata
    num_frames = Column(Integer)
    duration_seconds = Column(Float)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    subject = relationship("Subject", back_populates="exercise_data")
    exercise = relationship("Exercise", back_populates="exercise_data")
    camera_views = relationship("CameraView", back_populates="exercise_data", cascade="all, delete-orphan")
    comparisons = relationship("Comparison", back_populates="reference_exercise_data")
    
    # Unique constraint
    __table_args__ = (
        UniqueConstraint('subject_id', 'exercise_id', name='uq_subject_exercise'),
    )
    
    def __repr__(self):
        return f"<ExerciseData(subject_id={self.subject_id}, exercise_id={self.exercise_id}, frames={self.num_frames})>"


class CameraView(Base):
    """Camera view model (4 camera angles per exercise)."""
    __tablename__ = 'camera_views'
    
    id = Column(Integer, primary_key=True)
    exercise_data_id = Column(Integer, ForeignKey('exercise_data.id', ondelete='CASCADE'), nullable=False)
    
    # Camera identifier
    camera_id = Column(String(20), nullable=False)
    
    # Camera parameters (intrinsics, extrinsics)
    camera_params = Column(JSONB, nullable=False)
    
    # Video file path
    video_path = Column(String(500))
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    exercise_data = relationship("ExerciseData", back_populates="camera_views")
    
    # Unique constraint
    __table_args__ = (
        UniqueConstraint('exercise_data_id', 'camera_id', name='uq_exercise_camera'),
    )
    
    def __repr__(self):
        return f"<CameraView(camera_id='{self.camera_id}')>"


class Comparison(Base):
    """Comparison model (user comparison history)."""
    __tablename__ = 'comparisons'
    
    id = Column(Integer, primary_key=True)
    
    # Reference exercise
    reference_exercise_data_id = Column(Integer, ForeignKey('exercise_data.id'))
    
    # User uploaded data
    user_smplx_params = Column(JSONB)
    user_joints3d = Column(JSONB)
    
    # Comparison results
    similarity_score = Column(Float)
    errors_detected = Column(JSONB)
    feedback = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    reference_exercise_data = relationship("ExerciseData", back_populates="comparisons")
    
    def __repr__(self):
        return f"<Comparison(id={self.id}, score={self.similarity_score})>"
