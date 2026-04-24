"""SQLAlchemy ORM models for the database."""

from sqlalchemy import Column, Integer, String, Float, Text, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database.setup import Base

class Establishment(Base):
    """Establishment model (Cliniques / Cabinets)."""
    __tablename__ = 'establishments'
    
    establishment_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    # The unique code that patients use to link their account to this clinic
    code = Column(String(50), unique=True, nullable=False)
    contact_email = Column(String(100))
    # Single calibration data for the whole establishment (4 cameras)
    calibration_data = Column(JSONB)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    users = relationship("User", back_populates="establishment")
    
    def __repr__(self):
        return f"<Establishment(name='{self.name}', code='{self.code}')>"


class User(Base):
    """User model (Utilisateurs)."""
    __tablename__ = 'users'
    
    user_id = Column(Integer, primary_key=True, autoincrement=True)
    pseudo = Column(String(50), nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    
    # Enum for roles (user, admin, super_admin)
    role = Column(String(50), default='user')
    
    # Link to an establishment (Null allowed if super_admin or newly created but not yet assigned)
    establishment_id = Column(Integer, ForeignKey('establishments.establishment_id', ondelete='SET NULL'), nullable=True)
    
    # Profile metadata (Poids, Taille, Objectifs)
    profile_json = Column(JSONB)
    
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    establishment = relationship("Establishment", back_populates="users")
    performances = relationship("Performance", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(pseudo='{self.pseudo}', email='{self.email}')>"


class Movement(Base):
    """Movement model (Référentiels Fit3D)."""
    __tablename__ = 'movements'
    
    movement_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), unique=True, nullable=False)
    category = Column(String(50))
    description = Column(Text)
    difficulty = Column(String(50))
    instructions = Column(JSONB)
    thumbnail_path = Column(String(500))
    reference_video_path = Column(String(500))
    
    # Camera parameters (intrinsics, extrinsics of the lab cameras)
    camera_calibration = Column(JSONB)
    
    # Reference SMPL-X parameters
    smpl_ref = Column(JSONB)
    
    # Reference 3D joints
    joints_3d = Column(JSONB)
    
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    performances = relationship("Performance", back_populates="movement", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Movement(name='{self.name}', category='{self.category}')>"


class Performance(Base):
    """Performance model (Exécutions Utilisateur)."""
    __tablename__ = 'performances'
    
    performance_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.user_id', ondelete='CASCADE'), nullable=False)
    movement_id = Column(Integer, ForeignKey('movements.movement_id', ondelete='CASCADE'), nullable=False)
    
    # Path to user uploaded video(s)
    video_paths = Column(JSONB)
    
    # Comparison score (DTW match %)
    score = Column(Float)
    
    # Extracted 3D points from user video
    results_3d = Column(JSONB)
    
    # Extracted SMPL parameters from user video
    results_smpl = Column(JSONB)
    
    # AI feedback and commentary
    feedback_txt = Column(Text)
    
    # Execution duration
    duration = Column(String(50))
    
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="performances")
    movement = relationship("Movement", back_populates="performances")
    
    def __repr__(self):
        return f"<Performance(id={self.performance_id}, score={self.score})>"
