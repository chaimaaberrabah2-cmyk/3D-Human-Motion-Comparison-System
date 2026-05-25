"""
DTW – Dynamic Time Warping
===========================
Aligne temporellement deux séquences de mouvement (keypoints 3D) de longueurs
différentes. Utilise fastdtw pour optimiser les performances.

Entrées attendues :
    - keypoints_3d.npy  →  shape (T, 33, 4)  [X, Y, Z, visibility]
    - On ne compare que les coordonnées XYZ (colonnes 0-2).
"""

import numpy as np
from fastdtw import fastdtw
from scipy.spatial.distance import euclidean
from typing import Optional, Tuple

# Sous-ensemble des joints les plus pertinents pour l'analyse du mouvement
BODY_JOINTS = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]

def _load_keypoints(path: str) -> np.ndarray:
    """Charge un fichier .npy de keypoints 3D et retourne uniquement XYZ."""
    data = np.load(path)  # (T, 33, 4)
    return data[:, :, :3].astype(np.float64)  # (T, 33, 3)

def compute_dtw(
    ref_path: str,
    pred_path: str,
    joint_subset: Optional[list] = None,
) -> dict:
    """
    Calcule l'alignement DTW entre deux séquences de keypoints 3D.
    Les séquences peuvent avoir des longueurs différentes.
    """
    ref = _load_keypoints(ref_path)
    pred = _load_keypoints(pred_path)

    if joint_subset is not None:
        ref = ref[:, joint_subset, :]
        pred = pred[:, joint_subset, :]

    # Aplatir les features par frame pour le calcul de distance
    # On passe de (T, J, 3) à (T, J*3)
    ref_flat = ref.reshape(ref.shape[0], -1)
    pred_flat = pred.reshape(pred.shape[0], -1)

    # Calcul DTW avec distance euclidienne
    # radius gère la taille de la fenêtre de recherche (plus petit = plus rapide)
    distance, path = fastdtw(ref_flat, pred_flat, dist=euclidean)

    # path est une liste de tuples (i, j) qui mappe la frame i de ref à la frame j de pred
    
    # On peut aussi calculer l'erreur moyenne normalisée par la longueur du chemin
    normalized_distance = distance / len(path)

    return {
        "dtw_distance": float(distance),
        "normalized_distance": float(normalized_distance),
        "path": path, # Utile pour aligner visuellement les séquences plus tard
        "ref_frames": ref.shape[0],
        "pred_frames": pred.shape[0],
        "path_length": len(path)
    }

def align_sequences_with_path(
    ref: np.ndarray, 
    pred: np.ndarray, 
    path: list
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Réaligne les séquences en utilisant le chemin DTW.
    Génère deux nouvelles séquences de même longueur (len(path)).
    """
    aligned_ref = []
    aligned_pred = []
    
    for i, j in path:
        aligned_ref.append(ref[i])
        aligned_pred.append(pred[j])
        
    return np.array(aligned_ref), np.array(aligned_pred)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="DTW – Alignement temporel de mouvements 3D")
    parser.add_argument("ref", help="Chemin vers keypoints_3d.npy de référence")
    parser.add_argument("pred", help="Chemin vers keypoints_3d.npy à évaluer")
    parser.add_argument("--body-only", action="store_true",
                        help="Ne comparer que les 12 joints du corps (sans visage)")
    args = parser.parse_args()

    subset = BODY_JOINTS if args.body_only else None

    result = compute_dtw(args.ref, args.pred, joint_subset=subset)

    print(f"\n{'='*60}")
    print(f"  DTW Alignment Results")
    print(f"{'='*60}")
    print(f"  Reference frames : {result['ref_frames']}")
    print(f"  Predicted frames : {result['pred_frames']}")
    print(f"  Path length      : {result['path_length']}")
    print(f"  Total Distance   : {result['dtw_distance']:.2f}")
    print(f"  Norm. Distance   : {result['normalized_distance']:.4f}")
    print(f"{'='*60}\n")
