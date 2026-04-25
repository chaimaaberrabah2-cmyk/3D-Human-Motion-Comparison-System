import os
import sys
import argparse
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.pipeline.step3_3d_keypoints_service import TriangulationService

def find_latest_session(frames_dir: str):
    if not os.path.isdir(frames_dir):
        return None
    sessions = [
        d for d in os.listdir(frames_dir)
        if os.path.isdir(os.path.join(frames_dir, d)) and not d.startswith(".")
    ]
    if not sessions:
        return None
    sessions.sort(
        key=lambda d: os.path.getmtime(os.path.join(frames_dir, d)),
        reverse=True,
    )
    return os.path.join(frames_dir, sessions[0])

def main():
    parser = argparse.ArgumentParser(description="Recalculate 3D keypoints for a session.")
    parser.add_argument("--session", type=str, default=None, help="Session ID or path")
    parser.add_argument("--exercise", type=str, default="deadlift", help="Exercise name for calibration")
    args = parser.parse_args()

    backend_dir = os.path.dirname(os.path.abspath(__file__))
    frames_dir  = os.path.join(backend_dir, "data", "frames")

    if args.session:
        if os.path.isabs(args.session):
            session_dir = args.session
        else:
            session_dir = os.path.join(frames_dir, args.session)
    else:
        session_dir = find_latest_session(frames_dir)

    if not session_dir or not os.path.exists(session_dir):
        print(f"[ERREUR] Session introuvable : {session_dir}")
        sys.exit(1)

    print("=" * 60)
    print(f"  Recalculate Triangulation (Step 3)")
    print("=" * 60)
    print(f"  Session  : {os.path.basename(session_dir)}")
    print(f"  Exercise : {args.exercise}")
    print("-" * 60)

    try:
        output_file = TriangulationService.triangulate(
            session_output_root=session_dir,
            exercise_name=args.exercise
        )
        print("=" * 60)
        print(f"[SUCCESS] Triangulation recalculée avec succès.")
        print(f"  Fichier : {output_file}")
        print("=" * 60)
    except Exception as e:
        print(f"[ERREUR] Échec de la triangulation : {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
