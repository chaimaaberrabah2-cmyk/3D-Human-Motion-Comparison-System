#!/usr/bin/env python3
"""
run_gt_smplx.py — Pass GT 3D keypoints through SMPL-X fitting.

Converts FIT3D GT joints (17-joint format stored as 25-element array)
→ OP25 (OpenPose-25) and runs the same SMPL-X fitting as the pipeline.

Usage:
    python run_gt_smplx.py dumbbell_biceps_curls
    python run_gt_smplx.py deadlift
"""

import os, sys, json, argparse
import numpy as np

_PYENV_PY = "/Users/HP/.pyenv/versions/3.11.7/bin/python3"
if os.path.exists(_PYENV_PY) and sys.executable != _PYENV_PY:
    os.execv(_PYENV_PY, [_PYENV_PY] + sys.argv)

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "backend"))

# ─────────────────────────────────────────────────────────────────────────────
# FIT3D joint layout (25-element array, only 17 meaningful)
#   0:Pelvis  1:L_Hip  2:L_Knee  3:L_Ankle
#   4:R_Hip   5:R_Knee 6:R_Ankle
#   7:Spine1  8:Spine2 9:Chest   10:Head
#   11:L_Shoulder 12:L_Elbow 13:L_Wrist
#   14:R_Shoulder 15:R_Elbow 16:R_Wrist
#   17-24: additional foot / toe landmarks
#
# OP25 (OpenPose-25) layout expected by SMPL-X fitter:
#   0:Nose   1:Neck   2:RShoulder 3:RElbow 4:RWrist
#   5:LShoulder 6:LElbow 7:LWrist
#   8:MidHip 9:RHip  10:RKnee 11:RAnkle
#   12:LHip  13:LKnee 14:LAnkle
#   15:REye  16:LEye  17:REar  18:LEar
#   19:LBigToe 20:LSmallToe 21:LHeel
#   22:RBigToe 23:RSmallToe 24:RHeel
# ─────────────────────────────────────────────────────────────────────────────

# GT index → OP25 index
GT_TO_OP25 = {
    0:  8,   # Pelvis     → MidHip
    1:  12,  # L_Hip      → LHip
    2:  13,  # L_Knee     → LKnee
    3:  14,  # L_Ankle    → LAnkle
    4:  9,   # R_Hip      → RHip
    5:  10,  # R_Knee     → RKnee
    6:  11,  # R_Ankle    → RAnkle
    9:  1,   # Chest      → Neck
    10: 0,   # Head       → Nose
    11: 5,   # L_Shoulder → LShoulder
    12: 6,   # L_Elbow    → LElbow
    13: 7,   # L_Wrist    → LWrist
    14: 2,   # R_Shoulder → RShoulder
    15: 3,   # R_Elbow    → RElbow
    16: 4,   # R_Wrist    → RWrist
}

# FIT3D joints 17-24 → OP25 feet (best-effort)
GT_FEET_TO_OP25 = {
    17: 21,  # LHeel
    18: 24,  # RHeel
    19: 19,  # LBigToe
    20: 22,  # RBigToe
}


def gt_to_op25(gt: np.ndarray) -> np.ndarray:
    """
    Convert GT (T, 25, 3) FIT3D format → OP25 (T, 25, 4) with visibility column.
    Unmapped joints are NaN with visibility=0.
    """
    T = len(gt)
    op25 = np.full((T, 25, 4), np.nan, dtype=np.float32)
    op25[:, :, 3] = 0.0  # visibility = 0 by default

    for gt_idx, op_idx in GT_TO_OP25.items():
        pts = gt[:, gt_idx, :3]
        valid = ~np.any(np.isnan(pts), axis=1)
        op25[:, op_idx, :3] = pts
        op25[valid, op_idx, 3] = 1.0

    for gt_idx, op_idx in GT_FEET_TO_OP25.items():
        if gt_idx < gt.shape[1]:
            pts = gt[:, gt_idx, :3]
            valid = ~np.any(np.isnan(pts), axis=1)
            op25[:, op_idx, :3] = pts
            op25[valid, op_idx, 3] = 0.8

    return op25


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", help="exercise name, e.g. dumbbell_biceps_curls")
    parser.add_argument("--gender", default="neutral")
    parser.add_argument("--n_iter", type=int, default=20)
    args = parser.parse_args()

    exercise = args.exercise
    session_name = f"gt_{exercise}"

    # ── Load GT ───────────────────────────────────────────────────────────────
    gt_path = os.path.join(ROOT, "s03", "joints3d_25", f"{exercise}.json")
    if not os.path.exists(gt_path):
        print(f"GT not found: {gt_path}")
        sys.exit(1)

    with open(gt_path) as f:
        gt = np.array(json.load(f)["joints3d_25"], dtype=np.float32)  # (T, 25, 3)
    print(f"GT shape: {gt.shape}")

    # ── Convert to OP25 ───────────────────────────────────────────────────────
    op25 = gt_to_op25(gt)
    print(f"OP25 shape: {op25.shape}")
    mapped = sum(1 for i in range(25) if not np.all(np.isnan(op25[0, i, :3])))
    print(f"Mapped joints: {mapped}/25")

    # ── Save to session dir ───────────────────────────────────────────────────
    session_dir = os.path.join(ROOT, "backend", "data", "frames", session_name)
    os.makedirs(session_dir, exist_ok=True)

    kp_path = os.path.join(session_dir, "keypoints_3d.npy")
    np.save(kp_path, op25)
    print(f"Saved keypoints → {kp_path}")

    # ── Run SMPL-X fitting ────────────────────────────────────────────────────
    from app.pipeline.step4_smplx_fitting_service import SmplxService

    print(f"\nRunning SMPL-X fitting on GT keypoints ({len(op25)} frames)…")
    result = SmplxService.fit_and_save(
        session_output_root=session_dir,
        gender=args.gender,
        n_iter=args.n_iter,
    )

    if result:
        print(f"\nDone! SMPL-X result: {result}")
        print(f"\nView in comparator:")
        print(f"  python compare_viewer.py {exercise} --test {session_name}")
    else:
        print("\nSMPL-X fitting failed — check logs above.")


if __name__ == "__main__":
    main()
