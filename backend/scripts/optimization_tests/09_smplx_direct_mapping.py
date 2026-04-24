import os
import json
import numpy as np
import torch
import smplx
import cv2
from tqdm import tqdm

# --- CHEMINS ---
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
gt_json_path = os.path.join(backend_dir, "..", "s03", "smplx", "deadlift.json")
session_id = "a876149a-9221-42a3-ae64-3ff448ff1e66"
kp3d_path = os.path.join(backend_dir, "data", "frames", session_id, "keypoints_3d.npy")
models_dir = os.path.join(backend_dir, "data", "smplx_models")

# --- MAPPING DIRECT MEDIAPIPE (33) -> SMPL-X (22) ---
# On évite OpenPose Body25 ! On mappe directement.
# Format : SMPLX_JOINT_INDEX : [MediaPipe_Indices_To_Average]
MP33_TO_SMPLX = {
    0:  [23, 24], # Pelvis (milieu des hanches)
    1:  [23],     # L_Hip
    2:  [24],     # R_Hip
    4:  [25],     # L_Knee
    5:  [26],     # R_Knee
    7:  [27],     # L_Ankle
    8:  [28],     # R_Ankle
    10: [31],     # L_Foot (Big toe)
    11: [32],     # R_Foot (Big toe)
    12: [11, 12], # Neck (milieu des épaules)
    16: [11],     # L_Shoulder
    17: [12],     # R_Shoulder
    18: [13],     # L_Elbow
    19: [14],     # R_Elbow
    20: [15],     # L_Wrist
    21: [16],     # R_Wrist
}

MP33_WEIGHTS = {
    0: 3.5, 1: 3.5, 2: 3.5, 
    4: 3.0, 5: 3.0, 
    7: 2.5, 8: 2.5, 
    10: 1.5, 11: 1.5,
    12: 2.0, 
    16: 2.5, 17: 2.5, 
    18: 2.0, 19: 2.0, 
    20: 1.5, 21: 1.5
}

def rotmat_to_axis_angle(matrices):
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
    global_orient_mat = np.array(data['global_orient'], dtype=np.float32)
    body_pose_mat = np.array(data['body_pose'], dtype=np.float32)
    global_orient_aa = rotmat_to_axis_angle(global_orient_mat).reshape(-1, 3)
    body_pose_aa = rotmat_to_axis_angle(body_pose_mat).reshape(-1, 21 * 3)
    return {
        'transl': torch.tensor(data['transl'], dtype=torch.float32),
        'global_orient': torch.tensor(global_orient_aa, dtype=torch.float32),
        'body_pose': torch.tensor(body_pose_aa, dtype=torch.float32),
        'betas': torch.tensor(data['betas'], dtype=torch.float32) if 'betas' in data else torch.zeros(1, 10)
    }

def align_and_compute_errors(pred_joints, gt_joints, pred_vertices, gt_vertices):
    num_frames = min(pred_joints.shape[0], gt_joints.shape[0])
    pa_mpjpe_erreurs = []
    pa_v2v_erreurs = []
    for f in range(num_frames):
        gt_j, pred_j = gt_joints[f], pred_joints[f]
        gt_v, pred_v = gt_vertices[f], pred_vertices[f]
        mu_gt_j, mu_pred_j = np.mean(gt_j, axis=0), np.mean(pred_j, axis=0)
        gt_j_c, pred_j_c = gt_j - mu_gt_j, pred_j - mu_pred_j
        scale_gt, scale_pred = np.linalg.norm(gt_j_c), np.linalg.norm(pred_j_c)
        if scale_gt < 1e-6 or scale_pred < 1e-6: continue
        gt_j_s, pred_j_s = gt_j_c / scale_gt, pred_j_c / scale_pred
        H = pred_j_s.T @ gt_j_s
        U, S, Vt = np.linalg.svd(H)
        R = Vt.T @ U.T
        if np.linalg.det(R) < 0:
            Vt[-1, :] *= -1
            R = Vt.T @ U.T
        pred_j_aligned = (pred_j_c @ R) * (scale_gt / scale_pred) + mu_gt_j
        pa_mpjpe_erreurs.append(np.mean(np.linalg.norm(gt_j - pred_j_aligned, axis=1)))
        pred_v_aligned = ((pred_v - mu_pred_j) @ R) * (scale_gt / scale_pred) + mu_gt_j
        pa_v2v_erreurs.append(np.mean(np.linalg.norm(gt_v - pred_v_aligned, axis=1)))
    return np.mean(pa_v2v_erreurs) * 1000, np.mean(pa_mpjpe_erreurs) * 1000

def process_mp_frame(frame_kp):
    """Convertit 1 frame MediaPipe en cibles SMPL-X directes"""
    target = np.zeros((22, 3), dtype=np.float32)
    valid = np.zeros(22, dtype=bool)
    weights = np.zeros(22, dtype=np.float32)
    
    for smplx_idx, mp_indices in MP33_TO_SMPLX.items():
        pts = frame_kp[mp_indices, :3]
        vis = frame_kp[mp_indices, 3]
        ok = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
        
        if np.any(ok):
            target[smplx_idx, :] = pts[ok].mean(axis=0)
            valid[smplx_idx] = True
            weights[smplx_idx] = MP33_WEIGHTS.get(smplx_idx, 1.0)
            
    return target, valid, weights

def main():
    print("=== 09. TEST MAPPING DIRECT MEDIAPIPE -> SMPL-X ===")
    device = torch.device('cpu')
    
    # 1. Charger GT
    print("⏳ Chargement GT...")
    gt_params = load_gt_smplx_params(gt_json_path)
    num_gt_frames = gt_params['transl'].shape[0]
    
    body_model = smplx.create(models_dir, model_type='smplx', gender='neutral', 
                              use_pca=False, batch_size=num_gt_frames).to(device)
    
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
    gt_joints = gt_output.joints[:, :22, :].numpy()
    
    # 2. Charger nos Keypoints
    print("⏳ Chargement des prédictions MediaPipe...")
    kp3d = np.load(kp3d_path).astype(np.float32)
    num_frames = min(gt_vertices.shape[0], kp3d.shape[0])
    
    # Auto-scale
    TARGET = 0.52
    d = float(np.linalg.norm(((kp3d[0, 11, :3] + kp3d[0, 12, :3]) / 2) - ((kp3d[0, 23, :3] + kp3d[0, 24, :3]) / 2)))
    scale = TARGET / d if d > 1e-4 else 1.0
    kp3d[:, :, :3] *= scale
    
    # SMPL-X batch size 1 for fitting
    fit_model = smplx.create(models_dir, model_type='smplx', gender='neutral', 
                             use_pca=False, batch_size=1).to(device)
                             
    def compute_loss(output, target, valid, weights, b_pose):
        smplx_joints = output.joints[0, :22, :]
        loss = torch.tensor(0.0, dtype=torch.float32, device=device)
        n_pairs = 0
        for i in range(22):
            if valid[i]:
                tgt = torch.tensor(target[i, :3], dtype=torch.float32, device=device)
                loss = loss + weights[i] * ((smplx_joints[i] - tgt) ** 2).sum()
                n_pairs += 1
        if n_pairs: loss = loss / n_pairs
        loss = loss + 1e-3 * (b_pose ** 2).mean() # Basic pose prior
        return loss

    pred_vertices = []
    pred_joints_smpl = []
    
    fr_orient = torch.zeros(1, 3, dtype=torch.float32, device=device, requires_grad=True)
    fr_pose = torch.zeros(1, 63, dtype=torch.float32, device=device, requires_grad=True)
    fr_transl = torch.zeros(1, 3, dtype=torch.float32, device=device, requires_grad=True)
    betas_fixed = torch.zeros(1, 10, dtype=torch.float32, device=device)
    
    # Set rough initial orientation to match the UI default
    fr_orient.data = torch.tensor([[-2.007, -0.262, -0.262]], dtype=torch.float32)
    
    print("⏳ Optimisation SMPL-X (Mapping direct)...")
    for fi in tqdm(range(num_frames)):
        target, valid, weights = process_mp_frame(kp3d[fi])
        
        # Warm start from previous
        fr_orient_opt = fr_orient.detach().clone().requires_grad_(True)
        fr_pose_opt = fr_pose.detach().clone().requires_grad_(True)
        fr_transl_opt = fr_transl.detach().clone().requires_grad_(True)
        
        opt = torch.optim.LBFGS([fr_orient_opt, fr_pose_opt, fr_transl_opt], lr=1.0, max_iter=20, line_search_fn="strong_wolfe")
        
        def closure():
            opt.zero_grad()
            out = fit_model(betas=betas_fixed, global_orient=fr_orient_opt, body_pose=fr_pose_opt, transl=fr_transl_opt)
            loss = compute_loss(out, target, valid, weights, fr_pose_opt)
            loss.backward()
            return loss
            
        if valid.sum() >= 4:
            opt.step(closure)
            opt.step(closure)
            
        with torch.no_grad():
            fr_pose_opt.clamp_(-2 * np.pi, 2 * np.pi)
            
        fr_orient = fr_orient_opt.detach()
        fr_pose = fr_pose_opt.detach()
        fr_transl = fr_transl_opt.detach()
        
        with torch.no_grad():
            out = fit_model(betas=betas_fixed, global_orient=fr_orient, body_pose=fr_pose, transl=fr_transl, return_verts=True)
            pred_vertices.append(out.vertices[0].numpy())
            pred_joints_smpl.append(out.joints[0, :22].numpy())
            
    pred_vertices = np.array(pred_vertices)
    pred_joints_smpl = np.array(pred_joints_smpl)
    
    print("⏳ Évaluation (PA-V2V)...")
    v2v_mean_mm, pa_mpjpe_mm = align_and_compute_errors(
        pred_joints_smpl, 
        gt_joints[:num_frames], 
        pred_vertices, 
        gt_vertices[:num_frames]
    )
        
    print("\n================ RÉSULTATS (MAPPING DIRECT) ================")
    print(f"👉 PA-V2V Error (Mesh)     : {v2v_mean_mm:.2f} mm")
    print(f"👉 PA-MPJPE (Joints SMPL)  : {pa_mpjpe_mm:.2f} mm")
    print(f"👉 Gain PA-V2V vs Baseline : {147.53 - v2v_mean_mm:.2f} mm d'amélioration !")
    print(f"👉 Gain PA-MPJPE vs Base   : {101.94 - pa_mpjpe_mm:.2f} mm d'amélioration !")
    print("============================================================\n")

if __name__ == "__main__":
    main()
