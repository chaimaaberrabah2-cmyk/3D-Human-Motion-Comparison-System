"""
Automatic Exercise Detection
=============================
Compares a user's 3D motion against all reference exercises in the DB
using DTW on joint angles and picks the closest match.
"""

import os
import numpy as np
from fastdtw import fastdtw
from scipy.spatial.distance import euclidean
from .angle_score import compute_angle_sequence, _fill_nan

CONFIDENCE_THRESHOLD = 0.35  # if best normalized distance > this → "unclear"


def detect_exercise(pred_path: str, frame_dir: str) -> dict:
    """
    Compare pred motion against all reference exercises found in frame_dir.

    Returns:
        {
          "detected": "deadlift" | None,
          "confidence": 0.0-1.0,
          "scores": {"deadlift": 0.82, "squat": 0.45, ...},
          "unclear": bool
        }
    """
    pred_kp = np.load(pred_path)
    pred_angles = _fill_nan(compute_angle_sequence(pred_kp))

    results = {}

    # Scan all subfolders that have a keypoints_3d.npy and are not user sessions
    for entry in os.scandir(frame_dir):
        if not entry.is_dir():
            continue
        name = entry.name
        # Skip user session folders (UUIDs contain '-') and test_ folders
        if '-' in name or name.startswith('test_'):
            continue
        ref_path = os.path.join(entry.path, "keypoints_3d.npy")
        if not os.path.exists(ref_path):
            continue
        try:
            ref_kp = np.load(ref_path)
            ref_angles = _fill_nan(compute_angle_sequence(ref_kp))
            distance, path = fastdtw(ref_angles, pred_angles, dist=euclidean)
            norm_dist = distance / max(len(path), 1)
            results[name] = norm_dist
        except Exception as e:
            print(f"AUTO_DETECT: skipping {name}: {e}")

    if not results:
        return {"detected": None, "confidence": 0.0, "scores": {}, "unclear": True}

    best = min(results, key=results.get)
    best_dist = results[best]

    # Convert distance to confidence (lower distance = higher confidence)
    # Normalize: if dist=0 → conf=1.0, if dist=THRESHOLD → conf=0
    confidence = max(0.0, 1.0 - best_dist / CONFIDENCE_THRESHOLD)
    unclear = best_dist > CONFIDENCE_THRESHOLD

    # Build human-readable scores (inverted — higher = better)
    max_dist = max(results.values()) or 1.0
    scores = {k: round(1.0 - v / max_dist, 2) for k, v in results.items()}

    return {
        "detected":   best if not unclear else None,
        "confidence": round(confidence, 2),
        "scores":     scores,
        "unclear":    unclear,
    }
