"""
Score Generator
===============
Génère un score de comparaison global entre deux mouvements.
1. Aligne temporellement les deux séquences (DTW).
2. Calcule l'erreur spatiale (PA-MPJPE) sur les séquences alignées.
3. Convertit l'erreur en un score sur 100.
"""

import argparse
import numpy as np
from .dtw import compute_dtw, align_sequences_with_path
from .mpjpe import _procrustes_align, BLAZEPOSE_JOINTS, BODY_JOINTS

def generate_score(ref_path: str, pred_path: str, body_only: bool = True) -> dict:
    """
    Combine DTW et PA-MPJPE pour générer un score global de similarité.
    """
    subset = BODY_JOINTS if body_only else None
    
    # 1. Alignement temporel avec DTW
    dtw_result = compute_dtw(ref_path, pred_path, joint_subset=subset)
    path = dtw_result["path"]
    
    # Charger les données complètes pour appliquer l'alignement
    from .dtw import _load_keypoints
    ref_data = _load_keypoints(ref_path)
    pred_data = _load_keypoints(pred_path)
    
    if subset is not None:
        ref_data = ref_data[:, subset, :]
        pred_data = pred_data[:, subset, :]
        names = [BLAZEPOSE_JOINTS[i] for i in subset]
    else:
        names = BLAZEPOSE_JOINTS.copy()
        
    # Aligner les séquences selon le chemin DTW
    ref_aligned, pred_aligned = align_sequences_with_path(ref_data, pred_data, path)
    
    # 2. Calcul du PA-MPJPE sur les séquences synchronisées
    T = ref_aligned.shape[0]
    errors = np.zeros((T, ref_aligned.shape[1]))
    
    for t in range(T):
        pred_proc = _procrustes_align(ref_aligned[t], pred_aligned[t])
        errors[t] = np.linalg.norm(ref_aligned[t] - pred_proc, axis=1)
        
    mean_error = float(np.mean(errors)) # Erreur moyenne en mètres
    
    # 3. Conversion en score sur 100
    # L'erreur moyenne (PA-MPJPE) est généralement entre 0.05m (très bon) et 0.20m (mauvais)
    # On utilise une fonction de décroissance exponentielle pour le score
    # Score = 100 * exp(-k * error)
    # k=15 signifie qu'une erreur de 10cm donne ~22/100 (assez strict)
    # k=7 signifie qu'une erreur de 10cm donne ~50/100 (plus clément)
    k = 8.0 
    score = 100.0 * np.exp(-k * mean_error)
    score = max(0, min(100, score)) # Borner entre 0 et 100
    
    return {
        "score_out_of_100": score,
        "mean_error_meters": mean_error,
        "mean_error_cm": mean_error * 100,
        "dtw_normalized_distance": dtw_result["normalized_distance"],
        "aligned_frames_count": T
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Générateur de Score de Mouvement 3D")
    parser.add_argument("ref", help="Chemin vers keypoints_3d.npy de l'expert (référence)")
    parser.add_argument("pred", help="Chemin vers keypoints_3d.npy de l'utilisateur")
    parser.add_argument("--body-only", action="store_true", default=True,
                        help="Ne comparer que les 12 joints du corps")
    args = parser.parse_args()

    result = generate_score(args.ref, args.pred, body_only=args.body_only)

    print(f"\n{'='*50}")
    print(f"  RÉSULTAT DE LA COMPARAISON (EXPERT VS USER)")
    print(f"{'='*50}")
    print(f"  Score Global          : {result['score_out_of_100']:.1f} / 100")
    print(f"  Erreur Spatiale Moy.  : {result['mean_error_cm']:.1f} cm")
    print(f"  Désynchronisation DTW : {result['dtw_normalized_distance']:.4f}")
    print(f"  Frames Analysées      : {result['aligned_frames_count']} frames (après alignement)")
    print(f"{'='*50}\n")
