"""
run_last_session.py
-------------------
Lance le pipeline SMPL-X sur la dernière session disponible.

Usage :
    python run_last_session.py
    python run_last_session.py --iter 80
    python run_last_session.py --gender male
    python run_last_session.py --device mps
    python run_last_session.py --session <session_id>
"""

import os
import sys
import argparse
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.pipeline.step4_smplx_fitting_service import SmplxService


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


def print_info(session_dir: str):
    npy = os.path.join(session_dir, "keypoints_3d.npy")
    if not os.path.exists(npy):
        return
    data = np.load(npy)
    print(f"  keypoints_3d  shape = {data.shape}")
    vis_ok = (data[:, :, 3] > 0.3).mean() * 100
    print(f"  Visibility > 0.3    = {vis_ok:.1f}%")
    pelvis = (data[:, 23, :3] + data[:, 24, :3]) / 2
    neck   = (data[:, 11, :3] + data[:, 12, :3]) / 2
    torso  = float(np.linalg.norm(neck - pelvis, axis=1).mean())
    tag    = "~OK metres" if 0.1 < torso < 2.0 else "⚠ check scale"
    print(f"  Torso length (avg)  = {torso:.4f} ({tag})")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", type=str, default=None)
    parser.add_argument("--gender",  type=str, default="neutral",
                        choices=["neutral", "male", "female"])
    parser.add_argument("--iter",    type=int, default=80,
                        help="Adam iterations per frame (default=80)")
    parser.add_argument("--device",  type=str, default="auto",
                        choices=["auto", "cpu", "cuda", "mps"])
    args = parser.parse_args()

    backend_dir = os.path.dirname(os.path.abspath(__file__))
    frames_dir  = os.path.join(backend_dir, "data", "frames")

    if args.session:
        session_dir = args.session if os.path.isabs(args.session) \
            else os.path.join(frames_dir, args.session)
    else:
        session_dir = find_latest_session(frames_dir)

    if not session_dir or not os.path.isdir(session_dir):
        print(f"[ERREUR] Session introuvable : {session_dir}")
        sys.exit(1)

    kp3d = os.path.join(session_dir, "keypoints_3d.npy")
    if not os.path.exists(kp3d):
        print(f"[ERREUR] keypoints_3d.npy absent dans {session_dir}")
        print("         Phase 3 (triangulation) doit être terminée d'abord.")
        sys.exit(1)

    print("=" * 60)
    print("  SMPL-X Fitting — run_last_session.py")
    print("=" * 60)
    print(f"  Session   : {os.path.basename(session_dir)}")
    print(f"  Genre     : {args.gender}")
    print(f"  Itér/frame: {args.iter}")
    print(f"  Appareil  : {args.device}")
    print("  Frames    : ALL (max_export_frames=9999)")
    print("-" * 60)
    print_info(session_dir)
    print("=" * 60)

    result_path = SmplxService.fit_and_save(
        session_output_root=session_dir,
        gender=args.gender,
        n_iter=args.iter,
        device_str=args.device,
        max_export_frames=9999,   # toutes les frames
    )

    print()
    print("=" * 60)
    if result_path:
        print("[SUCCESS] Pipeline terminé.")
        print(f"  smplx_result.npz   → {result_path}")
        json_p = result_path.replace("smplx_result.npz", "smplx_threejs.json")
        if os.path.exists(json_p):
            mb = os.path.getsize(json_p) / (1024 * 1024)
            print(f"  smplx_threejs.json → {json_p} ({mb:.1f} MB)")
    else:
        print("[ECHEC] Pipeline retourne None. Voir logs DEBUG ci-dessus.")
    print("=" * 60)


if __name__ == "__main__":
    main()
