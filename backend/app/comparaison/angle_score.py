"""
Angle-based Comparison Score
=============================
Replaces PA-MPJPE with joint angle comparison + DTW alignment.

OP25 joint indices used:
  0=Nose  1=Neck  2=RShoulder  3=RElbow  4=RWrist
  5=LShoulder  6=LElbow  7=LWrist  8=MidHip
  9=RHip  10=RKnee  11=RAnkle  12=LHip  13=LKnee  14=LAnkle
"""

import numpy as np
from fastdtw import fastdtw
from scipy.spatial.distance import euclidean
import math

# ── Joint angle definitions (name, A, B_vertex, C) ────────────────────────────
# Angle at B between vectors B→A and B→C
ANGLE_DEFS = {
    "right_knee":    (9,  10, 11),   # RHip  → RKnee  → RAnkle
    "left_knee":     (12, 13, 14),   # LHip  → LKnee  → LAnkle
    "right_hip":     (2,  9,  10),   # RShoulder → RHip → RKnee
    "left_hip":      (5,  12, 13),   # LShoulder → LHip → LKnee
    "right_elbow":   (2,  3,  4),    # RShoulder → RElbow → RWrist
    "left_elbow":    (5,  6,  7),    # LShoulder → LElbow → LWrist
    "trunk_hip":     (1,  8,  9),    # Neck → MidHip → RHip (trunk lean)
}

# Human-readable feedback names
ANGLE_LABELS = {
    "right_knee":  "Right knee flexion",
    "left_knee":   "Left knee flexion",
    "right_hip":   "Right hip angle",
    "left_hip":    "Left hip angle",
    "right_elbow": "Right elbow",
    "left_elbow":  "Left elbow",
    "trunk_hip":   "Trunk lean",
}


def _angle_3pts(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """Angle at vertex B between BA and BC, in degrees."""
    ba = a - b
    bc = c - b
    n_ba = np.linalg.norm(ba)
    n_bc = np.linalg.norm(bc)
    if n_ba < 1e-6 or n_bc < 1e-6:
        return np.nan
    cos_a = np.dot(ba, bc) / (n_ba * n_bc)
    return math.degrees(math.acos(float(np.clip(cos_a, -1.0, 1.0))))


def compute_angle_sequence(keypoints: np.ndarray) -> np.ndarray:
    """
    Compute joint angles for every frame.

    Args:
        keypoints: (T, 25, 4) OP25 array [X, Y, Z, vis]

    Returns:
        angles: (T, n_angles) in degrees, NaN where joints are missing
    """
    T = keypoints.shape[0]
    angle_names = list(ANGLE_DEFS.keys())
    angles = np.full((T, len(angle_names)), np.nan, dtype=np.float64)

    for t in range(T):
        for k, name in enumerate(angle_names):
            ai, bi, ci = ANGLE_DEFS[name]
            a = keypoints[t, ai, :3]
            b = keypoints[t, bi, :3]
            c = keypoints[t, ci, :3]
            if np.any(np.isnan([a, b, c])):
                continue
            angles[t, k] = _angle_3pts(a, b, c)

    return angles


def _fill_nan(seq: np.ndarray) -> np.ndarray:
    """Linear interpolation to fill NaN values per column."""
    out = seq.copy()
    for col in range(out.shape[1]):
        s = out[:, col]
        nans = np.isnan(s)
        if nans.all():
            out[:, col] = 0.0
            continue
        x = np.arange(len(s))
        out[:, col] = np.interp(x, x[~nans], s[~nans])
    return out


def generate_angle_score(ref_path: str, pred_path: str) -> dict:
    """
    Compare two motion sequences using joint angle DTW.

    Returns:
        score_out_of_100, per_joint_errors_deg, feedback list
    """
    ref_kp  = np.load(ref_path)[:, :, :]    # (T_ref, 25, 4)
    pred_kp = np.load(pred_path)[:, :, :]   # (T_pred, 25, 4)

    # 1. Compute angle sequences
    ref_angles  = compute_angle_sequence(ref_kp)    # (T_ref,  n_angles)
    pred_angles = compute_angle_sequence(pred_kp)   # (T_pred, n_angles)

    # 2. Fill NaN via interpolation before DTW
    ref_filled  = _fill_nan(ref_angles)
    pred_filled = _fill_nan(pred_angles)

    # 3. DTW alignment on the full angle feature vector
    distance, path = fastdtw(ref_filled, pred_filled, dist=euclidean)
    normalized_distance = distance / max(len(path), 1)

    # 4. Build aligned sequences from DTW path
    ref_idx  = [p[0] for p in path]
    pred_idx = [p[1] for p in path]
    ref_al   = ref_angles[ref_idx]    # (T_aligned, n_angles)
    pred_al  = pred_angles[pred_idx]  # (T_aligned, n_angles)

    # 5. Per-joint mean absolute angle error (degrees)
    angle_names = list(ANGLE_DEFS.keys())
    per_joint_errors = {}
    valid_errors = []

    for k, name in enumerate(angle_names):
        r = ref_al[:, k]
        p = pred_al[:, k]
        valid = ~(np.isnan(r) | np.isnan(p))
        if valid.sum() < 5:
            per_joint_errors[name] = None
            continue
        err = float(np.mean(np.abs(r[valid] - p[valid])))
        per_joint_errors[name] = round(err, 1)
        valid_errors.append(err)

    mean_angle_error_deg = float(np.mean(valid_errors)) if valid_errors else 30.0

    # 6. Score: 10° error ≈ 80/100, 20° ≈ 63/100, 30° ≈ 50/100
    k_score = 1.3 / math.degrees(1)   # convert degree scale to radian scale factor
    score = 100.0 * math.exp(-k_score * mean_angle_error_deg)
    score = max(0.0, min(100.0, score))

    # 7. Generate per-joint feedback
    feedbacks = []
    for name, err in per_joint_errors.items():
        if err is None:
            continue
        label = ANGLE_LABELS.get(name, name)
        if err < 8:
            feedbacks.append({"joint": label, "error_deg": err,
                               "msg": f"Excellent — {err:.1f}° from reference", "status": "excellent"})
        elif err < 15:
            feedbacks.append({"joint": label, "error_deg": err,
                               "msg": f"Good — {err:.1f}° deviation", "status": "good"})
        elif err < 25:
            feedbacks.append({"joint": label, "error_deg": err,
                               "msg": f"Needs work — {err:.1f}° off reference", "status": "warning"})
        else:
            feedbacks.append({"joint": label, "error_deg": err,
                               "msg": f"Significant deviation — {err:.1f}° from reference", "status": "error"})

    feedbacks.sort(key=lambda x: x["error_deg"], reverse=True)

    return {
        "score_out_of_100":       round(score, 1),
        "mean_angle_error_deg":   round(mean_angle_error_deg, 1),
        "per_joint_errors_deg":   per_joint_errors,
        "dtw_normalized_distance": round(normalized_distance, 4),
        "aligned_frames_count":   len(path),
        "feedbacks":              feedbacks,
    }
