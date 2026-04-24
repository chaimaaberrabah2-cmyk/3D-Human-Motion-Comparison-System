import os
import json
import numpy as np

FIT3D_TO_MEDIAPIPE = {
    10: 0,   # Tête -> Nez
    11: 11,  # Épaule Gauche -> Épaule Gauche
    12: 13,  # Coude Gauche -> Coude Gauche
    13: 15,  # Poignet Gauche -> Poignet Gauche
    14: 12,  # Épaule Droite -> Épaule Droite
    15: 14,  # Coude Droit -> Coude Droit
    16: 16,  # Poignet Droit -> Poignet Droit
    1: 23,   # Hanche Gauche -> Hanche Gauche
    2: 25,   # Genou Gauche -> Genou Gauche
    3: 27,   # Cheville Gauche -> Cheville Gauche
    4: 24,   # Hanche Droite -> Hanche Droite
    5: 26,   # Genou Droit -> Genou Droit
    6: 28,   # Cheville Droite -> Cheville Droite
}

def load_gt_data(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
    joints = np.array(data['joints3d_25'])
    return joints

gt_3d = load_gt_data("s03/joints3d_25/deadlift.json")

# Charger les résultats de TA DERNIÈRE ANALYSE (depuis le frontend)
our_3d_predictions = np.load("backend/data/frames/a876149a-9221-42a3-ae64-3ff448ff1e66/keypoints_3d.npy")

num_frames = min(gt_3d.shape[0], our_3d_predictions.shape[0])

fit3d_indices = list(FIT3D_TO_MEDIAPIPE.keys())
mp_indices = list(FIT3D_TO_MEDIAPIPE.values())

erreurs_par_frame = []

for f_idx in range(num_frames):
    gt_points = gt_3d[f_idx, fit3d_indices, :]
    # [:, :3] car le tableau a 4 dimensions (X, Y, Z, Visibility)
    our_points = our_3d_predictions[f_idx, mp_indices, :3] 
    
    gt_center = np.mean(gt_points, axis=0)
    our_center = np.mean(our_points, axis=0)
    gt_centered = gt_points - gt_center
    our_centered = our_points - our_center
    
    scale_gt = np.sqrt(np.sum(gt_centered ** 2))
    scale_our = np.sqrt(np.sum(our_centered ** 2))
    
    if scale_gt < 1e-6 or scale_our < 1e-6:
        continue
        
    gt_scaled = gt_centered / scale_gt
    our_scaled = our_centered / scale_our
    
    H = our_scaled.T @ gt_scaled
    U, S, Vt = np.linalg.svd(H)
    R_optimal = Vt.T @ U.T
    
    if np.linalg.det(R_optimal) < 0:
        Vt[-1, :] *= -1
        R_optimal = Vt.T @ U.T
    
    our_aligned = (our_centered @ R_optimal) * (scale_gt / scale_our)
    
    erreur_frame = np.linalg.norm(gt_centered - our_aligned, axis=1)
    erreurs_par_frame.append(np.mean(erreur_frame))

pa_mpjpe_m = np.mean(erreurs_par_frame)
pa_mpjpe_mm = pa_mpjpe_m * 1000
mediane_mm = np.median(erreurs_par_frame) * 1000

print(f"\n================ RÉSULTAT DE TON APP FLUTTER ===============")
print(f"👉 PA-MPJPE MOYEN DU PIPELINE FINAL: {pa_mpjpe_mm:.2f} mm")
print(f"👉 PA-MPJPE MÉDIAN DU PIPELINE FINAL: {mediane_mm:.2f} mm")
print(f"============================================================")
