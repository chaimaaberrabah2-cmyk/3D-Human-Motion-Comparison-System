import os
import numpy as np
import json
import torch

def load_fit3d_gt(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
    return np.array(data['joints3d_25']) # (frames, 25, 3)

def load_my_triangulation(npy_path):
    data = np.load(npy_path)
    return data[:, :, :3] # (frames, 33, 3)

def load_my_smplx(npz_path):
    data = np.load(npz_path)
    return data['joints'] # (frames, 22, 3)

# Mapping pour comparer les 14 articulations principales (H36M style)
# Fit3D_Index : MediaPipe_Index
MP_TO_GT = {
    11: 14, 12: 11, # Shoulders
    13: 15, 14: 12, # Elbows
    15: 16, 16: 13, # Wrists
    23: 1,  24: 4,  # Hips
    25: 2,  26: 5,  # Knees
    27: 3,  28: 6   # Ankles
}

# SMPLX_Index : Fit3D_Index
SMPLX_TO_GT = {
    16: 14, 17: 11, # Shoulders
    18: 15, 19: 12, # Elbows
    20: 16, 21: 13, # Wrists
    1:  1,  2:  4,  # Hips
    4:  2,  5:  5,  # Knees
    7:  3,  8:  6   # Ankles
}

def evaluate_mpjpe(pred, gt, mapping):
    errors = []
    num_frames = min(len(pred), len(gt))
    
    # Indices des hanches pour l'alignement au bassin
    # Fit3D: 1 (L_Hip), 4 (R_Hip)
    # MediaPipe: 23, 24
    # SMPLX: 1, 2
    
    for f in range(num_frames):
        # Calcul du bassin pour l'alignement (Root-relative)
        if 23 in mapping and 24 in mapping: # Cas MediaPipe
            p_root = (pred[f, 23] + pred[f, 24]) / 2
        elif 1 in mapping and 2 in mapping: # Cas SMPLX
            p_root = (pred[f, 1] + pred[f, 2]) / 2
        else:
            p_root = pred[f, 0] # Fallback
            
        g_root = (gt[f, 1] + gt[f, 4]) / 2
        
        for p_idx, g_idx in mapping.items():
            p_joint = pred[f, p_idx] - p_root
            g_joint = gt[f, g_idx] - g_root
            
            if not np.any(np.isnan(p_joint)) and not np.any(np.isnan(g_joint)):
                dist = np.linalg.norm(p_joint - g_joint)
                errors.append(dist)
    
    return np.mean(errors) * 1000

def main():
    session_id = "aec7a12f-5faf-425f-aa8b-ea2e339b118f"
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(backend_dir)
    
    gt_path = os.path.join(project_root, "s03", "joints3d_25", "deadlift.json")
    tri_path = os.path.join(backend_dir, "data", "frames", session_id, "keypoints_3d.npy")
    smpl_path = os.path.join(backend_dir, "data", "frames", session_id, "smplx_result.npz")
    
    if not os.path.exists(gt_path):
        print(f"ERREUR: Ground Truth introuvable à {gt_path}")
        return

    gt = load_fit3d_gt(gt_path)
    print(f"✅ Ground Truth chargé : {gt.shape}")
    
    print("\n" + "="*40)
    print("  RÉSULTATS DE L'ÉVALUATION (MPJPE)")
    print("="*40)
    
    # 1. Évaluation de la Triangulation (Step 3)
    if os.path.exists(tri_path):
        tri = load_my_triangulation(tri_path)
        err_tri = evaluate_mpjpe(tri, gt, MP_TO_GT)
        print(f"1. Triangulation (MediaPipe 3D) : {err_tri:.2f} mm")
    else:
        print("1. Triangulation : Fichier introuvable")
        
    # 2. Évaluation du SMPL-X (Step 4)
    if os.path.exists(smpl_path):
        smpl = load_my_smplx(smpl_path)
        err_smpl = evaluate_mpjpe(smpl, gt, SMPLX_TO_GT)
        print(f"2. Modèle SMPL-X (Fitting)      : {err_smpl:.2f} mm")
    else:
        print("2. SMPL-X : Fichier introuvable")
    print("="*40)

if __name__ == "__main__":
    main()
