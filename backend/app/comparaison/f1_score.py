"""
F1 Score – Évaluation de détection d'articulations 3D
======================================================
Calcule Precision, Recall et F1 à partir du ground truth Fit3D (s03).

Une articulation est un TP si elle est valide dans le GT et la prédiction
et que l'erreur 3D (Procrustes par frame) est sous le seuil PCK (défaut 150 mm).

Usage CLI :
    python -m app.comparaison.f1_score <gt_json> <pred_npy> [--threshold-mm 150]
"""

from __future__ import annotations

import json
from typing import Dict, List, Tuple

import numpy as np

from .mpjpe import _procrustes_align

# Fit3D index → MediaPipe BlazePose index
FIT3D_TO_MEDIAPIPE: Dict[int, int] = {
    10: 0,
    11: 11, 12: 13, 13: 15,
    14: 12, 15: 14, 16: 16,
    1: 23, 2: 25, 3: 27,
    4: 24, 5: 26, 6: 28,
}

# SMPL-X index → Fit3D index
SMPLX_TO_FIT3D: Dict[int, int] = {
    16: 14, 17: 11, 18: 15, 19: 12, 20: 16, 21: 13,
    1: 1, 2: 4, 4: 2, 5: 5, 7: 3, 8: 6,
}


def load_fit3d_gt(json_path: str) -> np.ndarray:
    with open(json_path, "r") as f:
        data = json.load(f)
    if isinstance(data, dict) and "joints3d_25" in data:
        return np.array(data["joints3d_25"], dtype=np.float64)
    return np.array(data, dtype=np.float64)


def load_keypoints_3d(npy_path: str) -> np.ndarray:
    data = np.load(npy_path)
    return data[:, :, :3].astype(np.float64) if data.ndim == 3 else data.astype(np.float64)


def load_smplx_joints(npz_path: str) -> np.ndarray:
    return np.array(np.load(npz_path)["joints"], dtype=np.float64)


def _is_valid(xyz: np.ndarray) -> bool:
    if np.any(np.isnan(xyz[:3])):
        return False
    return float(np.linalg.norm(xyz[:3])) > 1e-6


def _joint_pairs_mediapipe() -> List[Tuple[int, int]]:
    """(fit3d_idx, mediapipe_idx)."""
    return list(FIT3D_TO_MEDIAPIPE.items())


def _joint_pairs_smplx() -> List[Tuple[int, int]]:
    """(fit3d_idx, smplx_idx)."""
    return [(fit3d, smplx) for smplx, fit3d in SMPLX_TO_FIT3D.items()]


def _count_frame(
    gt: np.ndarray,
    pred: np.ndarray,
    pairs: List[Tuple[int, int]],
    threshold_m: float,
) -> Tuple[int, int, int, List[float]]:
    """Retourne (tp, fp, fn, errors_tp) pour une frame."""
    gt_pts, pred_pts, pair_meta = [], [], []

    n_gt = gt.shape[0]
    n_pred = pred.shape[0]
    for fit3d_idx, pred_idx in pairs:
        if fit3d_idx >= n_gt or pred_idx >= n_pred:
            continue
        g = gt[fit3d_idx, :3]
        p = pred[pred_idx, :3]
        gt_ok = _is_valid(g)
        pred_ok = _is_valid(p)
        pair_meta.append((gt_ok, pred_ok))

        if gt_ok and pred_ok:
            gt_pts.append(g)
            pred_pts.append(p)

    tp = fp = fn = 0
    errors_tp: List[float] = []

    if len(gt_pts) >= 2:
        gt_arr = np.stack(gt_pts)
        pred_arr = np.stack(pred_pts)
        pred_aligned = _procrustes_align(gt_arr, pred_arr)
        aligned_errors = np.linalg.norm(gt_arr - pred_aligned, axis=1)
        err_i = 0
        for gt_ok, pred_ok in pair_meta:
            if gt_ok and pred_ok:
                err = float(aligned_errors[err_i])
                err_i += 1
                if err < threshold_m:
                    tp += 1
                    errors_tp.append(err)
                else:
                    fn += 1
                    fp += 1
            elif gt_ok:
                fn += 1
            elif pred_ok:
                fp += 1
    else:
        for gt_ok, pred_ok in pair_meta:
            if gt_ok and pred_ok:
                fn += 1
            elif gt_ok:
                fn += 1
            elif pred_ok:
                fp += 1

    return tp, fp, fn, errors_tp


def compute_f1_from_arrays(
    gt: np.ndarray,
    pred: np.ndarray,
    pairs: List[Tuple[int, int]],
    threshold_m: float = 0.15,
) -> dict:
    num_frames = min(gt.shape[0], pred.shape[0])
    tp = fp = fn = 0
    all_errors_tp: List[float] = []

    for f_idx in range(num_frames):
        t, f, n, errs = _count_frame(gt[f_idx], pred[f_idx], pairs, threshold_m)
        tp += t
        fp += f
        fn += n
        all_errors_tp.extend(errs)

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0

    return {
        "threshold_mm": threshold_m * 1000,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "precision": precision,
        "recall": recall,
        "f1_score": f1,
        "pck_percent": 100.0 * tp / (tp + fn) if (tp + fn) > 0 else 0.0,
        "num_frames": num_frames,
        "num_joints_evaluated": len(pairs),
        "mean_error_correct_mm": float(np.mean(all_errors_tp) * 1000) if all_errors_tp else None,
    }


def compute_f1_keypoints(gt_json_path: str, pred_npy_path: str, threshold_m: float = 0.15) -> dict:
    gt = load_fit3d_gt(gt_json_path)
    pred = load_keypoints_3d(pred_npy_path)
    return compute_f1_from_arrays(gt, pred, _joint_pairs_mediapipe(), threshold_m)


def compute_f1_smplx(gt_json_path: str, smplx_npz_path: str, threshold_m: float = 0.15) -> dict:
    gt = load_fit3d_gt(gt_json_path)
    pred = load_smplx_joints(smplx_npz_path)
    return compute_f1_from_arrays(gt, pred, _joint_pairs_smplx(), threshold_m)


def evaluate_pipeline_session(
    session_dir: str,
    exercise_name: str,
    gt_root: str,
    threshold_mm: float = 150.0,
) -> dict:
    import os

    gt_path = os.path.join(gt_root, "joints3d_25", f"{exercise_name}.json")
    tri_path = os.path.join(session_dir, "keypoints_3d.npy")
    smpl_path = os.path.join(session_dir, "smplx_result.npz")
    threshold_m = threshold_mm / 1000.0

    results = {
        "exercise": exercise_name,
        "session_dir": session_dir,
        "gt_path": gt_path,
        "threshold_mm": threshold_mm,
    }

    if not os.path.exists(gt_path):
        results["error"] = f"Ground truth not found: {gt_path}"
        return results

    if os.path.exists(tri_path):
        results["step3_triangulation"] = compute_f1_keypoints(gt_path, tri_path, threshold_m)
    if os.path.exists(smpl_path):
        results["step4_smplx"] = compute_f1_smplx(gt_path, smpl_path, threshold_m)

    return results


def _print_result(label: str, result: dict) -> None:
    print(f"\n{'=' * 55}")
    print(f"  F1 SCORE — {label}")
    print(f"{'=' * 55}")
    print(f"  Seuil PCK       : {result['threshold_mm']:.0f} mm")
    print(f"  Frames          : {result['num_frames']}")
    print(f"  Articulations   : {result['num_joints_evaluated']}")
    print(f"  TP / FP / FN    : {result['tp']} / {result['fp']} / {result['fn']}")
    print(f"  Precision       : {result['precision']:.4f}")
    print(f"  Recall          : {result['recall']:.4f}")
    print(f"  F1 Score        : {result['f1_score']:.4f}")
    print(f"  PCK (%)         : {result['pck_percent']:.2f}%")
    if result["mean_error_correct_mm"] is not None:
        print(f"  Erreur moy. TP  : {result['mean_error_correct_mm']:.2f} mm")
    print(f"{'=' * 55}")


if __name__ == "__main__":
    import argparse
    import os

    parser = argparse.ArgumentParser(description="F1 score pipeline vs Fit3D GT")
    parser.add_argument("gt_json", nargs="?", help="s03/joints3d_25/<exercise>.json")
    parser.add_argument("pred", nargs="?", help="keypoints_3d.npy ou dossier session")
    parser.add_argument("--threshold-mm", type=float, default=150.0)
    parser.add_argument("--smplx", action="store_true")
    parser.add_argument("--session", help="Dossier session (évalue step 3 + 4)")
    parser.add_argument("--exercise", default="deadlift", help="Nom exercice Fit3D")
    parser.add_argument(
        "--gt-root",
        default=None,
        help="Racine dataset s03 (défaut: <projet>/s03)",
    )
    args = parser.parse_args()

    backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    project_root = os.path.dirname(backend_dir)
    gt_root = args.gt_root or os.path.join(project_root, "s03")

    if args.session:
        results = evaluate_pipeline_session(
            args.session, args.exercise, gt_root, args.threshold_mm
        )
        if "error" in results:
            print(f"ERREUR: {results['error']}")
        else:
            print(f"\nPipeline — {results['exercise']} @ {results['threshold_mm']:.0f} mm")
            if "step3_triangulation" in results:
                _print_result("Triangulation 3D (Step 3)", results["step3_triangulation"])
            if "step4_smplx" in results:
                _print_result("SMPL-X Fitting (Step 4)", results["step4_smplx"])
    elif args.gt_json and args.pred:
        threshold_m = args.threshold_mm / 1000.0
        if args.smplx:
            result = compute_f1_smplx(args.gt_json, args.pred, threshold_m)
            _print_result("SMPL-X (Step 4)", result)
        else:
            result = compute_f1_keypoints(args.gt_json, args.pred, threshold_m)
            _print_result("Triangulation 3D (Step 3)", result)
    else:
        parser.print_help()
