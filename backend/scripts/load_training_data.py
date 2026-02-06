"""Load training data from JSON files into PostgreSQL database."""

import sys
import os
import json
from pathlib import Path
from tqdm import tqdm

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.db_config import SessionLocal
from database.models import Subject, Exercise, ExerciseData, CameraView


def load_subjects(session):
    """Load subjects (s03-s11) into database."""
    print("\n📊 Loading subjects...")
    
    train_dir = Path("train")
    subject_codes = [d.name for d in train_dir.iterdir() if d.is_dir() and d.name.startswith('s')]
    
    subjects_added = 0
    for code in sorted(subject_codes):
        existing = session.query(Subject).filter_by(subject_code=code).first()
        if not existing:
            subject = Subject(subject_code=code)
            session.add(subject)
            subjects_added += 1
    
    session.commit()
    print(f"   ✅ Loaded {subjects_added} subjects (total: {len(subject_codes)})")
    return {s.subject_code: s.id for s in session.query(Subject).all()}


def load_exercises(session):
    """Load exercise types into database."""
    print("\n🏋️  Loading exercises...")
    
    # Get exercise names from first subject directory
    train_dir = Path("train/s03/smplx")
    exercise_files = list(train_dir.glob("*.json"))
    
    # Define categories (you can customize this)
    warmup_exercises = [f"warmup_{i}" for i in range(1, 20)]
    
    exercises_added = 0
    for ex_file in exercise_files:
        exercise_name = ex_file.stem
        
        # Determine category
        if exercise_name in warmup_exercises:
            category = "warmup"
        elif "pushup" in exercise_name or "curl" in exercise_name or "press" in exercise_name:
            category = "strength"
        elif "burpees" in exercise_name or "kick" in exercise_name:
            category = "cardio"
        else:
            category = "general"
        
        existing = session.query(Exercise).filter_by(exercise_name=exercise_name).first()
        if not existing:
            exercise = Exercise(
                exercise_name=exercise_name,
                category=category,
                description=f"{exercise_name.replace('_', ' ').title()} exercise"
            )
            session.add(exercise)
            exercises_added += 1
    
    session.commit()
    print(f"   ✅ Loaded {exercises_added} exercises (total: {len(exercise_files)})")
    return {e.exercise_name: e.id for e in session.query(Exercise).all()}


def load_exercise_data(session, subject_map, exercise_map):
    """Load SMPL-X parameters and joints3D for each subject/exercise combination."""
    print("\n💾 Loading exercise data (SMPL-X parameters, joints3D)...")
    
    train_dir = Path("train")
    total_loaded = 0
    
    # Iterate through subjects
    for subject_code in tqdm(sorted(subject_map.keys()), desc="Subjects"):
        subject_id = subject_map[subject_code]
        subject_dir = train_dir / subject_code
        
        smplx_dir = subject_dir / "smplx"
        joints_dir = subject_dir / "joints3d_25"
        rep_ann_file = subject_dir / "rep_ann.json"
        
        # Load repetition annotations
        rep_annotations = {}
        if rep_ann_file.exists():
            with open(rep_ann_file, 'r') as f:
                rep_annotations = json.load(f)
        
        # Iterate through exercises
        for exercise_name, exercise_id in exercise_map.items():
            smplx_file = smplx_dir / f"{exercise_name}.json"
            joints_file = joints_dir / f"{exercise_name}.json"
            
            if not smplx_file.exists() or not joints_file.exists():
                continue
            
            # Check if already exists
            existing = session.query(ExerciseData).filter_by(
                subject_id=subject_id,
                exercise_id=exercise_id
            ).first()
            
            if existing:
                continue
            
            # Load SMPL-X parameters
            with open(smplx_file, 'r') as f:
                smplx_params = json.load(f)
            
            # Load joints3D
            with open(joints_file, 'r') as f:
                joints3d = json.load(f)
            
            # Calculate metadata
            num_frames = len(smplx_params.get('transl', []))
            duration_seconds = num_frames / 30.0  # Assuming 30 FPS
            
            # Get repetition annotations for this exercise
            rep_ann = rep_annotations.get(exercise_name, [])
            
            # Create exercise data entry
            exercise_data = ExerciseData(
                subject_id=subject_id,
                exercise_id=exercise_id,
                smplx_params=smplx_params,
                joints3d=joints3d,
                rep_annotations=rep_ann,
                num_frames=num_frames,
                duration_seconds=duration_seconds
            )
            session.add(exercise_data)
            total_loaded += 1
    
    session.commit()
    print(f"   ✅ Loaded {total_loaded} exercise data entries")


def load_camera_views(session):
    """Load camera parameters and video paths."""
    print("\n📹 Loading camera views...")
    
    train_dir = Path("train")
    total_loaded = 0
    
    # Get all exercise data entries
    exercise_data_entries = session.query(ExerciseData).all()
    
    for entry in tqdm(exercise_data_entries, desc="Camera views"):
        subject = session.query(Subject).get(entry.subject_id)
        exercise = session.query(Exercise).get(entry.exercise_id)
        
        subject_dir = train_dir / subject.subject_code
        camera_dir = subject_dir / "camera_parameters"
        video_dir = subject_dir / "videos"
        
        # Get camera IDs from directory
        camera_ids = [d.name for d in camera_dir.iterdir() if d.is_dir()]
        
        for camera_id in camera_ids:
            # Check if already exists
            existing = session.query(CameraView).filter_by(
                exercise_data_id=entry.id,
                camera_id=camera_id
            ).first()
            
            if existing:
                continue
            
            camera_param_file = camera_dir / camera_id / f"{exercise.exercise_name}.json"
            video_file = video_dir / camera_id / f"{exercise.exercise_name}.mp4"
            
            if not camera_param_file.exists():
                continue
            
            # Load camera parameters
            with open(camera_param_file, 'r') as f:
                camera_params = json.load(f)
            
            # Create camera view entry
            camera_view = CameraView(
                exercise_data_id=entry.id,
                camera_id=camera_id,
                camera_params=camera_params,
                video_path=str(video_file) if video_file.exists() else None
            )
            session.add(camera_view)
            total_loaded += 1
    
    session.commit()
    print(f"   ✅ Loaded {total_loaded} camera views")


def main():
    """Main data loading function."""
    print("=" * 60)
    print("  3D Human Motion Comparison System - Data Loading")
    print("=" * 60)
    
    # Create database session
    session = SessionLocal()
    
    try:
        # Load subjects
        subject_map = load_subjects(session)
        
        # Load exercises
        exercise_map = load_exercises(session)
        
        # Load exercise data (SMPL-X + joints3D)
        load_exercise_data(session, subject_map, exercise_map)
        
        # Load camera views
        load_camera_views(session)
        
        print("\n" + "=" * 60)
        print("  ✅ Data loading complete!")
        print("=" * 60)
        
        # Print summary
        print(f"\nDatabase summary:")
        print(f"  - Subjects: {session.query(Subject).count()}")
        print(f"  - Exercises: {session.query(Exercise).count()}")
        print(f"  - Exercise data entries: {session.query(ExerciseData).count()}")
        print(f"  - Camera views: {session.query(CameraView).count()}")
        
    except Exception as e:
        print(f"\n❌ Error during data loading: {e}")
        session.rollback()
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
