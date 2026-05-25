"""
MPJPE – Mean Per-Joint Position Error
======================================
Calcule l'erreur moyenne (en mètres) entre deux séquences de keypoints 3D,
frame par frame et joint par joint.

Entrées attendues :
    - keypoints_3d.npy  →  shape (T, 33, 4)  [X, Y, Z, visibility]
    - On ne compare que les coordonnées XYZ (colonnes 0-2).

Variantes fournies :
    1. MPJPE classique  (erreur absolue par joint)
    2. PA-MPJPE         (après alignement Procrustes, supprime la différence
                         de taille / orientation globale)
    3. Per-joint MPJPE  (erreur moyenne ventilée par articulation)
"""

import numpy as np
from typing import Optional

# ─────────────────────────────────────────────────────────────────────────────
# Noms des 33 landmarks BlazePose / MediaPipe pour les rapports lisibles
# ─────────────────────────────────────────────────────────────────────────────
BLAZEPOSE_JOINTS = [
    "nose", "left_eye_inner", "left_eye", "left_eye_outer",
    "right_eye_inner", "right_eye", "right_eye_outer",
    "left_ear", "right_ear",
    "mouth_left", "mouth_right",
    "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow",
    "left_wrist", "right_wrist",
    "left_pinky", "right_pinky",
    "left_index", "right_index",
    "left_thumb", "right_thumb",
    "left_hip", "right_hip",
    "left_knee", "right_knee",
    "left_ankle", "right_ankle",
    "left_heel", "right_heel",
    "left_foot_index", "right_foot_index",
]

# Sous-ensemble des joints les plus pertinents pour l'analyse du mouvement
# (exclut les landmarks du visage qui sont bruités en multi-vue)
BODY_JOINTS = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]
BODY_JOINT_NAMES = [BLAZEPOSE_JOINTS[i] for i in BODY_JOINTS]


# ─────────────────────────────────────────────────────────────────────────────
# Utilitaires
# ─────────────────────────────────────────────────────────────────────────────

def _load_keypoints(path: str) -> np.ndarray:
    """Charge un fichier .npy de keypoints 3D et retourne uniquement XYZ."""
    data = np.load(path)  # (T, 33, 4)
    return data[:, :, :3].astype(np.float64)  # (T, 33, 3)


def _align_lengths(ref: np.ndarray, pred: np.ndarray):
    """Tronque les deux séquences à la longueur minimale commune."""
    T = min(ref.shape[0], pred.shape[0])
    return ref[:T], pred[:T]


def _procrustes_align(X: np.ndarray, Y: np.ndarray) -> np.ndarray:
    """
    Aligne Y sur X par transformation de Procrustes (rotation + translation + scale).
    X, Y : (J, 3)
    Retourne Y_aligned : (J, 3)
    """
    mu_x = X.mean(axis=0)
    mu_y = Y.mean(axis=0)
    X0 = X - mu_x
    Y0 = Y - mu_y

    ss_x = np.sum(X0 ** 2)
    ss_y = np.sum(Y0 ** 2)

    # Frobenius norm
    norm_x = np.sqrt(ss_x)
    norm_y = np.sqrt(ss_y)

    X0 /= (norm_x + 1e-8)
    Y0 /= (norm_y + 1e-8)

    # Rotation optimale via SVD
    A = X0.T @ Y0
    U, S, Vt = np.linalg.svd(A)
    # Corriger la réflexion
    d = np.sign(np.linalg.det(U @ Vt))
    D = np.diag([1, 1, d])
    R = U @ D @ Vt

    trace_S = np.sum(S * np.diag(D)[:len(S)])
    scale = trace_S * norm_x / (norm_y + 1e-8)

    Y_aligned = scale * (Y - mu_y) @ R.T + mu_x
    return Y_aligned


# ─────────────────────────────────────────────────────────────────────────────
# Métriques principales
# ─────────────────────────────────────────────────────────────────────────────

def compute_mpjpe(
    ref_path: str,
    pred_path: str,
    joint_subset: Optional[list] = None,
) -> dict:
    """
    Calcule le MPJPE classique entre deux séquences de keypoints 3D.

    Args:
        ref_path:     Chemin vers le fichier .npy de référence (expert / ground truth).
        pred_path:    Chemin vers le fichier .npy du sujet à évaluer.
        joint_subset: Liste d'indices de joints à considérer (par défaut : tous les 33).

    Returns:
        dict avec :
            - mpjpe_mean:       Erreur moyenne globale (m)
            - mpjpe_per_frame:  Erreur moyenne par frame (array)
            - mpjpe_per_joint:  Erreur moyenne par joint (array)
            - joint_names:      Noms des joints correspondants
            - num_frames:       Nombre de frames comparées
    """
    ref = _load_keypoints(ref_path)
    pred = _load_keypoints(pred_path)
    ref, pred = _align_lengths(ref, pred)

    if joint_subset is not None:
        ref = ref[:, joint_subset, :]
        pred = pred[:, joint_subset, :]
        names = [BLAZEPOSE_JOINTS[i] for i in joint_subset]
    else:
        names = BLAZEPOSE_JOINTS.copy()

    # Erreur euclidienne par joint par frame : (T, J)
    errors = np.linalg.norm(ref - pred, axis=2)

    return {
        "mpjpe_mean": float(np.mean(errors)),
        "mpjpe_per_frame": errors.mean(axis=1).tolist(),
        "mpjpe_per_joint": errors.mean(axis=0).tolist(),
        "joint_names": names,
        "num_frames": int(ref.shape[0]),
    }


def compute_pa_mpjpe(
    ref_path: str,
    pred_path: str,
    joint_subset: Optional[list] = None,
) -> dict:
    """
    Calcule le PA-MPJPE (Procrustes-Aligned MPJPE).
    Élimine les différences de position globale, rotation et échelle.
    Idéal pour comparer la *forme* du mouvement indépendamment du placement spatial.
    """
    ref = _load_keypoints(ref_path)
    pred = _load_keypoints(pred_path)
    ref, pred = _align_lengths(ref, pred)

    if joint_subset is not None:
        ref = ref[:, joint_subset, :]
        pred = pred[:, joint_subset, :]
        names = [BLAZEPOSE_JOINTS[i] for i in joint_subset]
    else:
        names = BLAZEPOSE_JOINTS.copy()

    T = ref.shape[0]
    errors = np.zeros((T, ref.shape[1]))

    for t in range(T):
        pred_aligned = _procrustes_align(ref[t], pred[t])
        errors[t] = np.linalg.norm(ref[t] - pred_aligned, axis=1)

    return {
        "pa_mpjpe_mean": float(np.mean(errors)),
        "pa_mpjpe_per_frame": errors.mean(axis=1).tolist(),
        "pa_mpjpe_per_joint": errors.mean(axis=0).tolist(),
        "joint_names": names,
        "num_frames": T,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Point d'entrée CLI
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse, json

    parser = argparse.ArgumentParser(description="MPJPE – Comparaison de mouvements 3D")
    parser.add_argument("ref", help="Chemin vers keypoints_3d.npy de référence")
    parser.add_argument("pred", help="Chemin vers keypoints_3d.npy à évaluer")
    parser.add_argument("--body-only", action="store_true",
                        help="Ne comparer que les 12 joints du corps (sans visage)")
    parser.add_argument("--procrustes", action="store_true",
                        help="Utiliser PA-MPJPE (alignement Procrustes)")
    args = parser.parse_args()

    subset = BODY_JOINTS if args.body_only else None

    if args.procrustes:
        result = compute_pa_mpjpe(args.ref, args.pred, joint_subset=subset)
        key = "pa_mpjpe_mean"
    else:
        result = compute_mpjpe(args.ref, args.pred, joint_subset=subset)
        key = "mpjpe_mean"

    print(f"\n{'='*60}")
    print(f"  {'PA-MPJPE' if args.procrustes else 'MPJPE'} Results")
    print(f"{'='*60}")
    print(f"  Frames comparées : {result['num_frames']}")
    print(f"  Erreur moyenne   : {result[key]*100:.2f} cm  ({result[key]*1000:.1f} mm)")
    print(f"\n  Erreur par joint :")

    per_joint_key = "pa_mpjpe_per_joint" if args.procrustes else "mpjpe_per_joint"
    for name, err in zip(result["joint_names"], result[per_joint_key]):
        bar = "█" * int(err * 500)
        print(f"    {name:25s} {err*100:6.2f} cm  {bar}")
    print()
