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

# --- MAPPING DIRECT MEDIAPIPE -> SMPL-X ---
MP33_TO_SMPLX = {
    0:  [23, 24], 1:  [23], 2:  [24], 
    4:  [25], 5:  [26], 7:  [27], 8:  [28], 
    10: [31], 11: [32], 12: [11, 12], 
    16: [11], 17: [12], 18: [13], 19: [14], 
    20: [15], 21: [16]
}
MP33_WEIGHTS = {
    0: 4.0, 1: 3.5, 2: 3.5, 
    4: 3.0, 5: 3.0, 
    7: 2.5, 8: 2.5, 
    10: 1.5, 11: 1.5,
    12: 3.0, 
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
    print("=== 10. ADVANCED PRIORS (SHAPE + VELOCITY LOSS) ===")
    device = torch.device('cpu')
    
    # Charger GT
    with open(gt_json_path, 'r') as f: gt_data = json.load(f)
    gt_transl = torch.tensor(gt_data['transl'], dtype=torch.float32)
    gt_orient = torch.tensor(rotmat_to_axis_angle(np.array(gt_data['global_orient'], dtype=np.float32)).reshape(-1, 3), dtype=torch.float32)
    gt_pose = torch.tensor(rotmat_to_axis_angle(np.array(gt_data['body_pose'], dtype=np.float32)).reshape(-1, 63), dtype=torch.float32)
    gt_betas = torch.tensor(gt_data['betas'], dtype=torch.float32) if 'betas' in gt_data else torch.zeros(1, 10)
    
    num_gt_frames = gt_transl.shape[0]
    body_model = smplx.create(models_dir, model_type='smplx', gender='neutral', use_pca=False, batch_size=num_gt_frames).to(device)
    
    betas_expanded = gt_betas.expand(num_gt_frames, -1) if gt_betas.shape[0] == 1 else gt_betas
    with torch.no_grad():
        gt_out = body_model(transl=gt_transl, global_orient=gt_orient, body_pose=gt_pose, betas=betas_expanded, return_verts=True)
    gt_vertices, gt_joints = gt_out.vertices.numpy(), gt_out.joints[:, :22, :].numpy()
    
    # Charger KP3D
    kp3d = np.load(kp3d_path).astype(np.float32)
    num_frames = min(gt_vertices.shape[0], kp3d.shape[0])
    
    # Auto-scale
    TARGET = 0.52
    d = float(np.linalg.norm(((kp3d[0, 11, :3] + kp3d[0, 12, :3]) / 2) - ((kp3d[0, 23, :3] + kp3d[0, 24, :3]) / 2)))
    scale = TARGET / d if d > 1e-4 else 1.0
    kp3d[:, :, :3] *= scale
    
    fit_model = smplx.create(models_dir, model_type='smplx', gender='neutral', use_pca=False, batch_size=1).to(device)
    
    # Data prep
    targets, valids, weightss = [], [], []
    for fi in range(num_frames):
        t, v, w = process_mp_frame(kp3d[fi])
        targets.append(t); valids.append(v); weightss.append(w)
        
    def compute_loss(output, target, valid, weights, b_pose, prev_pose=None):
        smplx_joints = output.joints[0, :22, :]
        loss = torch.tensor(0.0, dtype=torch.float32, device=device)
        n_pairs = 0
        for i in range(22):
            if valid[i]:
                tgt = torch.tensor(target[i, :3], dtype=torch.float32, device=device)
                loss = loss + weights[i] * ((smplx_joints[i] - tgt) ** 2).sum()
                n_pairs += 1
        if n_pairs: loss = loss / n_pairs
        
        # Pose Prior (L2 to T-pose)
        loss = loss + 1.5e-3 * (b_pose ** 2).mean() 
        
        # Velocity Loss (Temporal Smoothness)
        if prev_pose is not None:
            loss = loss + 5.0 * ((b_pose - prev_pose) ** 2).mean()
            
        return loss

    # STAGE 1: SHAPE FITTING
    print("⏳ Stage 1 : Shape Fitting...")
    betas = torch.zeros(1, 10, dtype=torch.float32, device=device, requires_grad=True)
    fr_transl = torch.tensor([[0.0, 0.0, 0.0]], dtype=torch.float32, device=device, requires_grad=True)
    fr_orient = torch.tensor([[-2.007, -0.262, -0.262]], dtype=torch.float32, device=device, requires_grad=True)
    b_pose0 = torch.zeros(1, 63, dtype=torch.float32, device=device)
    
    shape_frames = [i for i in range(0, num_frames, max(1, num_frames // 15)) if valids[i].sum() >= 8][:15]
    
    opt_shape = torch.optim.LBFGS([betas, fr_transl, fr_orient], lr=1.0, max_iter=20, line_search_fn="strong_wolfe")
    def shape_closure():
        opt_shape.zero_grad()
        total = torch.tensor(0.0, dtype=torch.float32, device=device)
        for fi in shape_frames:
            out = fit_model(betas=betas, global_orient=fr_orient, body_pose=b_pose0, transl=fr_transl)
            total = total + compute_loss(out, targets[fi], valids[fi], weightss[fi], b_pose0)
        total = total / len(shape_frames) + 5e-3 * (betas ** 2).mean()
        total.backward()
        return total
        
    for _ in range(3): opt_shape.step(shape_closure)
    
    betas_fixed = betas.detach()
    print("Betas trouvés:", betas_fixed.flatten().numpy()[:3], "...")
    
    # STAGE 2: POSE FITTING + VELOCITY LOSS
    print("⏳ Stage 2 : Pose Fitting avec Velocity Loss...")
    pred_vertices, pred_joints_smpl = [], []
    
    prev_pose = b_pose0.clone()
    prev_orient = fr_orient.detach().clone()
    prev_transl = fr_transl.detach().clone()
    
    for fi in tqdm(range(num_frames)):
        target, valid, weights = targets[fi], valids[fi], weightss[fi]
        
        o_opt = prev_orient.clone().requires_grad_(True)
        p_opt = prev_pose.clone().requires_grad_(True)
        t_opt = prev_transl.clone().requires_grad_(True)
        
        opt = torch.optim.LBFGS([o_opt, p_opt, t_opt], lr=1.0, max_iter=15, line_search_fn="strong_wolfe")
        
        def closure():
            opt.zero_grad()
            out = fit_model(betas=betas_fixed, global_orient=o_opt, body_pose=p_opt, transl=t_opt)
            loss = compute_loss(out, target, valid, weights, p_opt, prev_pose=prev_pose)
            loss.backward()
            return loss
            
        if valid.sum() >= 4:
            opt.step(closure)
            opt.step(closure)
            
        with torch.no_grad():
            p_opt.clamp_(-2 * np.pi, 2 * np.pi)
            
        prev_orient, prev_pose, prev_transl = o_opt.detach(), p_opt.detach(), t_opt.detach()
        
        with torch.no_grad():
            out = fit_model(betas=betas_fixed, global_orient=prev_orient, body_pose=prev_pose, transl=prev_transl, return_verts=True)
            pred_vertices.append(out.vertices[0].numpy())
            pred_joints_smpl.append(out.joints[0, :22].numpy())
            
    print("⏳ Évaluation (PA-V2V)...")
    v2v_mean_mm, pa_mpjpe_mm = align_and_compute_errors(np.array(pred_joints_smpl), gt_joints[:num_frames], np.array(pred_vertices), gt_vertices[:num_frames])
        
    print("\n============== RÉSULTATS (SHAPE + VELOCITY LOSS) ==============")
    print(f"👉 PA-V2V Error (Mesh)     : {v2v_mean_mm:.2f} mm")
    print(f"👉 PA-MPJPE (Joints SMPL)  : {pa_mpjpe_mm:.2f} mm")
    print(f"👉 Gain PA-V2V vs Baseline : {147.53 - v2v_mean_mm:.2f} mm d'amélioration !")
    print(f"👉 Gain PA-MPJPE vs Base   : {101.94 - pa_mpjpe_mm:.2f} mm d'amélioration !")
    print("===============================================================\n")

if __name__ == "__main__":
    main()
