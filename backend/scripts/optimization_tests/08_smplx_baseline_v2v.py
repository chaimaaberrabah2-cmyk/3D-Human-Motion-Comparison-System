import os
import json
import numpy as np
import torch
import smplx
import cv2

# --- CHEMINS ---
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
gt_json_path = os.path.join(backend_dir, "..", "s03", "smplx", "deadlift.json")
# Remplace avec l'ID de ta dernière analyse
pred_npz_path = os.path.join(backend_dir, "data", "frames", "a876149a-9221-42a3-ae64-3ff448ff1e66", "smplx_result.npz")
models_dir = os.path.join(backend_dir, "data", "smplx_models")

def rotmat_to_axis_angle(matrices):
    """ Convertit un tableau de matrices (..., 3, 3) en vecteur axis-angle (..., 3) via cv2.Rodrigues """
    shape = matrices.shape
    matrices_flat = matrices.reshape(-1, 3, 3)
    axis_angles = np.zeros((matrices_flat.shape[0], 3), dtype=np.float32)
    for i in range(matrices_flat.shape[0]):
        aa, _ = cv2.Rodrigues(matrices_flat[i])
        axis_angles[i] = aa.reshape(3)
    return axis_angles.reshape(shape[:-2] + (3,))

def load_gt_smplx_params(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    global_orient_mat = np.array(data['global_orient'], dtype=np.float32) # (N, 1, 3, 3)
    body_pose_mat = np.array(data['body_pose'], dtype=np.float32)         # (N, 21, 3, 3)
    
    global_orient_aa = rotmat_to_axis_angle(global_orient_mat).reshape(-1, 3)    # (N, 3)
    body_pose_aa = rotmat_to_axis_angle(body_pose_mat).reshape(-1, 21 * 3)       # (N, 63)
    
    return {
        'transl': torch.tensor(data['transl'], dtype=torch.float32),
        'global_orient': torch.tensor(global_orient_aa, dtype=torch.float32),
        'body_pose': torch.tensor(body_pose_aa, dtype=torch.float32),
        'betas': torch.tensor(data['betas'], dtype=torch.float32) if 'betas' in data else torch.zeros(1, 10)
    }

def align_and_compute_errors(pred_joints, gt_joints, pred_vertices, gt_vertices):
    """
    Calcule le PA-MPJPE sur les joints et le PA-V2V sur les vertices.
    La transformation Procrustes (Scale, Rotation, Translation) est calculée sur les JOINTS,
    puis appliquée aux VERTICES pour ne pas fausser la morphologie.
    """
    num_frames = min(pred_joints.shape[0], gt_joints.shape[0])
    pa_mpjpe_erreurs = []
    pa_v2v_erreurs = []
    
    for f in range(num_frames):
        gt_j = gt_joints[f]
        pred_j = pred_joints[f]
        gt_v = gt_vertices[f]
        pred_v = pred_vertices[f]
        
        # 1. Centrage sur les joints
        mu_gt_j = np.mean(gt_j, axis=0)
        mu_pred_j = np.mean(pred_j, axis=0)
        
        gt_j_c = gt_j - mu_gt_j
        pred_j_c = pred_j - mu_pred_j
        
        # 2. Mise à l'échelle (Scale)
        scale_gt = np.linalg.norm(gt_j_c)
        scale_pred = np.linalg.norm(pred_j_c)
        
        if scale_gt < 1e-6 or scale_pred < 1e-6:
            continue
            
        gt_j_s = gt_j_c / scale_gt
        pred_j_s = pred_j_c / scale_pred
        
        # 3. Rotation Procrustes (SVD) sur les joints
        H = pred_j_s.T @ gt_j_s
        U, S, Vt = np.linalg.svd(H)
        R = Vt.T @ U.T
        if np.linalg.det(R) < 0:
            Vt[-1, :] *= -1
            R = Vt.T @ U.T
            
        # --- Application aux Joints ---
        pred_j_aligned = (pred_j_c @ R) * (scale_gt / scale_pred) + mu_gt_j
        err_joints = np.linalg.norm(gt_j - pred_j_aligned, axis=1)
        pa_mpjpe_erreurs.append(np.mean(err_joints))
        
        # --- Application aux Vertices ---
        # On centre les vertices avec le centre des JOINTS (mu_pred_j)
        pred_v_c = pred_v - mu_pred_j
        pred_v_aligned = (pred_v_c @ R) * (scale_gt / scale_pred) + mu_gt_j
        
        err_verts = np.linalg.norm(gt_v - pred_v_aligned, axis=1)
        pa_v2v_erreurs.append(np.mean(err_verts))
        
    return np.mean(pa_v2v_erreurs) * 1000, np.mean(pa_mpjpe_erreurs) * 1000

def main():
    print("=== 08. BASELINE SMPL-X : ÉVALUATION V2V ET JOINTS ===")
    
    if not os.path.exists(gt_json_path):
        print(f"❌ Vérité terrain introuvable : {gt_json_path}")
        return
    if not os.path.exists(pred_npz_path):
        print(f"❌ Prédiction introuvable : {pred_npz_path}")
        return
        
    device = torch.device('cpu')
    
    # 1. Charger la Vérité Terrain
    print("⏳ Chargement de la vérité terrain Fit3D...")
    gt_params = load_gt_smplx_params(gt_json_path)
    num_gt_frames = gt_params['transl'].shape[0]
    
    # 2. Générer le maillage (mesh) Ground Truth via le modèle SMPL-X
    print("⏳ Génération du mesh de référence (cela peut prendre quelques secondes)...")
    body_model = smplx.create(models_dir, model_type='smplx', gender='neutral', 
                              use_pca=False, batch_size=num_gt_frames).to(device)
    
    # Expand betas to match batch size if necessary
    if gt_params['betas'].shape[0] == 1 and num_gt_frames > 1:
        betas = gt_params['betas'].expand(num_gt_frames, -1)
    else:
        betas = gt_params['betas']
        
    with torch.no_grad():
        gt_output = body_model(
            transl=gt_params['transl'],
            global_orient=gt_params['global_orient'],
            body_pose=gt_params['body_pose'],
            betas=betas,
            return_verts=True
        )
    gt_vertices = gt_output.vertices.numpy()
    gt_joints = gt_output.joints[:, :22, :].numpy()  # On prend les 22 joints du corps principal
    
    # 3. Charger nos prédictions
    print("⏳ Chargement de nos prédictions (pipeline actuel)...")
    pred_data = np.load(pred_npz_path)
    pred_vertices = pred_data['vertices']
    pred_joints = pred_data['joints'][:, :22, :]
    
    num_frames = min(gt_vertices.shape[0], pred_vertices.shape[0])
    print(f"\n📊 Comparaison sur {num_frames} frames communes.")
    
    # 4. Calcul des erreurs PA-V2V et PA-MPJPE
    print("⏳ Alignement Procrustes et calcul des erreurs...")
    v2v_mean_mm, pa_mpjpe_mm = align_and_compute_errors(
        pred_joints[:num_frames], 
        gt_joints[:num_frames], 
        pred_vertices[:num_frames], 
        gt_vertices[:num_frames]
    )
    
    print("\n================ RÉSULTATS SMPL-X ================")
    print(f"👉 PA-V2V Error (Mesh)     : {v2v_mean_mm:.2f} mm")
    print(f"👉 PA-MPJPE (Joints SMPL)  : {pa_mpjpe_mm:.2f} mm")
    print("==================================================\n")
    print("Interprétation :")
    print("- Le PA-MPJPE évalue l'exactitude de la posture osseuse (indépendant de la taille et rotation globale).")
    print("- Le PA-V2V évalue la précision de la surface 3D (ajoute les erreurs de forme corporelle).")

if __name__ == "__main__":
    main()
