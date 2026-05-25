import os
import json
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)

MP33_TO_SMPLX = {
    0:  [23, 24], # Pelvis
    1:  [23],     # L_Hip
    2:  [24],     # R_Hip
    4:  [25],     # L_Knee
    5:  [26],     # R_Knee
    7:  [27],     # L_Ankle
    8:  [28],     # R_Ankle
    10: [31],     # L_Foot / Big toe
    11: [32],     # R_Foot / Big toe
    12: [11, 12], # Neck
    16: [11],     # L_Shoulder
    17: [12],     # R_Shoulder
    18: [13],     # L_Elbow
    19: [14],     # R_Elbow
    20: [15],     # L_Wrist
    21: [16],     # R_Wrist
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

class SmplxSmplifyService:
    @staticmethod
    def _get_models_dir() -> str:
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        models_dir = os.path.join(backend_dir, "data", "smplx_models")
        return models_dir

    @staticmethod
    def _preprocess_keypoints(kp3d: np.ndarray) -> np.ndarray:
        from scipy.signal import savgol_filter
        kp = kp3d.copy()
        vis = kp[:, :, 3]
        invalid = (vis < 0.25) | np.isnan(kp[:, :, :3]).any(axis=2)
        kp[invalid, :3] = np.nan
        
        num_frames, num_joints, _ = kp.shape
        for j in range(num_joints):
            for c in range(3):
                arr = kp[:, j, c]
                nans = np.isnan(arr)
                if not nans.all():
                    x = np.arange(num_frames)
                    arr[nans] = np.interp(x[nans], x[~nans], arr[~nans])
                else:
                    arr[:] = 0.0

        win = min(11, num_frames if num_frames % 2 == 1 else num_frames - 1)
        if win >= 5:
            for j in range(num_joints):
                for c in range(3):
                    kp[:, j, c] = savgol_filter(kp[:, j, c], window_length=win, polyorder=3)
        return kp

    @staticmethod
    def _mp33_to_smplx_target(frame_kp: np.ndarray):
        target = np.zeros((55, 3), dtype=np.float32)
        valid  = np.zeros(55, dtype=bool)
        weights = np.zeros(55, dtype=np.float32)

        for smplx_idx, mp_indices in MP33_TO_SMPLX.items():
            pts = frame_kp[mp_indices, :3]
            vis = frame_kp[mp_indices, 3]
            ok  = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
            
            if np.any(ok):
                target[smplx_idx, :3] = pts[ok].mean(axis=0)
                valid[smplx_idx]      = True
                weights[smplx_idx]    = MP33_WEIGHTS.get(smplx_idx, 1.0)
        return target, valid, weights

    @staticmethod
    def _compute_analytical_ik(kp3d: np.ndarray) -> dict:
        import cv2
        num_frames = kp3d.shape[0]
        transl = np.zeros((num_frames, 3), dtype=np.float32)
        global_orient = np.zeros((num_frames, 3), dtype=np.float32)
        body_pose = np.zeros((num_frames, 63), dtype=np.float32)

        def rotate_vector_to_vector(a, b):
            v = np.cross(a, b)
            c = np.dot(a, b)
            s = np.linalg.norm(v)
            if s < 1e-6:
                if c > 0: return np.eye(3, dtype=np.float32)
                else:
                    ortho = np.array([0.0, 1.0, 0.0] if abs(a[0]) > 0.9 else [1.0, 0.0, 0.0], dtype=np.float32)
                    ortho -= np.dot(ortho, a) * a
                    ortho /= np.linalg.norm(ortho) + 1e-8
                    K = np.array([[0, -ortho[2], ortho[1]], [ortho[2], 0, -ortho[0]], [-ortho[1], ortho[0], 0]], dtype=np.float32)
                    return np.eye(3, dtype=np.float32) + 2 * np.dot(K, K)
            K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]], dtype=np.float32)
            return np.eye(3, dtype=np.float32) + K + np.dot(K, K) * (1.0 - c) / (s ** 2)

        def matrix_to_axis_angle(R):
            aa, _ = cv2.Rodrigues(R.astype(np.float32))
            return aa.flatten()

        def hinge_joint_rotation(parent_dir, child_dir, hinge_axis_local, parent_R):
            child_local = np.dot(parent_R.T, child_dir)
            parent_local = np.dot(parent_R.T, parent_dir)
            axis = np.array(hinge_axis_local, dtype=np.float32)
            axis /= np.linalg.norm(axis) + 1e-8
            child_proj = child_local - np.dot(child_local, axis) * axis
            parent_proj = parent_local - np.dot(parent_local, axis) * axis
            cn = np.linalg.norm(child_proj)
            pn = np.linalg.norm(parent_proj)
            if cn < 1e-6 or pn < 1e-6: return np.eye(3, dtype=np.float32)
            child_proj /= cn
            parent_proj /= pn
            cos_angle = np.clip(np.dot(parent_proj, child_proj), -1.0, 1.0)
            angle = np.arccos(cos_angle)
            cross = np.cross(parent_proj, child_proj)
            if np.dot(cross, axis) < 0: angle = -angle
            K = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]], dtype=np.float32)
            return np.eye(3, dtype=np.float32) + np.sin(angle) * K + (1 - np.cos(angle)) * np.dot(K, K)

        for fi in range(num_frames):
            f = kp3d[fi, :, :3]
            l_hip, r_hip = f[23], f[24]
            l_shoulder, r_shoulder = f[11], f[12]
            l_knee, r_knee = f[25], f[26]
            l_ankle, r_ankle = f[27], f[28]
            l_toe, r_toe = f[31], f[32]
            l_elbow, r_elbow = f[13], f[14]
            l_wrist, r_wrist = f[15], f[16]
            l_hand_mid = (f[17] + f[19]) / 2.0
            r_hand_mid = (f[18] + f[20]) / 2.0

            pelvis = (l_hip + r_hip) / 2.0
            transl[fi] = pelvis

            hip_vec = l_hip - r_hip
            shoulder_mid = (l_shoulder + r_shoulder) / 2.0
            spine_vec = shoulder_mid - pelvis

            y_axis = spine_vec / (np.linalg.norm(spine_vec) + 1e-8)
            x_axis = hip_vec / (np.linalg.norm(hip_vec) + 1e-8)
            x_axis -= np.dot(x_axis, y_axis) * y_axis
            x_axis /= (np.linalg.norm(x_axis) + 1e-8)
            z_axis = np.cross(x_axis, y_axis)
            z_axis /= (np.linalg.norm(z_axis) + 1e-8)

            R_pelvis = np.column_stack((x_axis, y_axis, z_axis))
            global_orient[fi] = matrix_to_axis_angle(R_pelvis)

            # Left leg
            d_l_thigh = (l_knee - l_hip) / (np.linalg.norm(l_knee - l_hip) + 1e-8)
            d_l_shin = (l_ankle - l_knee) / (np.linalg.norm(l_ankle - l_knee) + 1e-8)
            d_l_foot = (l_toe - l_ankle) / (np.linalg.norm(l_toe - l_ankle) + 1e-8)
            R_l_hip = rotate_vector_to_vector(np.array([0, -1, 0]), np.dot(R_pelvis.T, d_l_thigh))
            R_thigh_abs = np.dot(R_pelvis, R_l_hip)
            R_l_knee = hinge_joint_rotation(d_l_thigh, d_l_shin, [1, 0, 0], R_thigh_abs)
            R_shin_abs = np.dot(R_thigh_abs, R_l_knee)
            R_l_ankle = rotate_vector_to_vector(np.array([0, 0, 1]), np.dot(R_shin_abs.T, d_l_foot))

            # Right leg
            d_r_thigh = (r_knee - r_hip) / (np.linalg.norm(r_knee - r_hip) + 1e-8)
            d_r_shin = (r_ankle - r_knee) / (np.linalg.norm(r_ankle - r_knee) + 1e-8)
            d_r_foot = (r_toe - r_ankle) / (np.linalg.norm(r_toe - r_ankle) + 1e-8)
            R_r_hip = rotate_vector_to_vector(np.array([0, -1, 0]), np.dot(R_pelvis.T, d_r_thigh))
            R_thigh_abs_r = np.dot(R_pelvis, R_r_hip)
            R_r_knee = hinge_joint_rotation(d_r_thigh, d_r_shin, [1, 0, 0], R_thigh_abs_r)
            R_shin_abs_r = np.dot(R_thigh_abs_r, R_r_knee)
            R_r_ankle = rotate_vector_to_vector(np.array([0, 0, 1]), np.dot(R_shin_abs_r.T, d_r_foot))

            # Left Arm
            d_l_arm = (l_elbow - l_shoulder) / (np.linalg.norm(l_elbow - l_shoulder) + 1e-8)
            d_l_forearm = (l_wrist - l_elbow) / (np.linalg.norm(l_wrist - l_elbow) + 1e-8)
            d_l_hand = (l_hand_mid - l_wrist) / (np.linalg.norm(l_hand_mid - l_wrist) + 1e-8)
            R_l_shoulder = rotate_vector_to_vector(np.array([1, 0, 0]), np.dot(R_pelvis.T, d_l_arm))
            R_arm_abs = np.dot(R_pelvis, R_l_shoulder)
            R_l_elbow = hinge_joint_rotation(d_l_arm, d_l_forearm, [0, 1, 0], R_arm_abs)
            R_forearm_abs = np.dot(R_arm_abs, R_l_elbow)
            R_l_wrist = rotate_vector_to_vector(np.array([1, 0, 0]), np.dot(R_forearm_abs.T, d_l_hand))

            # Right Arm
            d_r_arm = (r_elbow - r_shoulder) / (np.linalg.norm(r_elbow - r_shoulder) + 1e-8)
            d_r_forearm = (r_wrist - r_elbow) / (np.linalg.norm(r_wrist - r_elbow) + 1e-8)
            d_r_hand = (r_hand_mid - r_wrist) / (np.linalg.norm(r_hand_mid - r_wrist) + 1e-8)
            R_r_shoulder = rotate_vector_to_vector(np.array([-1, 0, 0]), np.dot(R_pelvis.T, d_r_arm))
            R_arm_abs_r = np.dot(R_pelvis, R_r_shoulder)
            R_r_elbow = hinge_joint_rotation(d_r_arm, d_r_forearm, [0, 1, 0], R_arm_abs_r)
            R_forearm_abs_r = np.dot(R_arm_abs_r, R_r_elbow)
            R_r_wrist = rotate_vector_to_vector(np.array([-1, 0, 0]), np.dot(R_forearm_abs_r.T, d_r_hand))

            frame_pose = np.zeros((21, 3), dtype=np.float32)
            frame_pose[0] = matrix_to_axis_angle(R_l_hip)
            frame_pose[1] = matrix_to_axis_angle(R_r_hip)
            frame_pose[3] = matrix_to_axis_angle(R_l_knee)
            frame_pose[4] = matrix_to_axis_angle(R_r_knee)
            frame_pose[6] = matrix_to_axis_angle(R_l_ankle)
            frame_pose[7] = matrix_to_axis_angle(R_r_ankle)
            frame_pose[15] = matrix_to_axis_angle(R_l_shoulder)
            frame_pose[16] = matrix_to_axis_angle(R_r_shoulder)
            frame_pose[17] = matrix_to_axis_angle(R_l_elbow)
            frame_pose[18] = matrix_to_axis_angle(R_r_elbow)
            frame_pose[19] = matrix_to_axis_angle(R_l_wrist)
            frame_pose[20] = matrix_to_axis_angle(R_r_wrist)

            body_pose[fi] = frame_pose.flatten()

        return {
            "transl": transl,
            "global_orient": global_orient,
            "body_pose": body_pose
        }

    @staticmethod
    def fit_and_save(
        session_output_root: str,
        gender: str = "neutral",
        device_str: str = "auto",
        max_export_frames: int = 9999
    ) -> Optional[str]:
        try:
            import torch
            import smplx as smplx_lib
            from tqdm import tqdm
            from scipy.ndimage import gaussian_filter1d
        except ImportError as e:
            logger.error(f"Dépendance manquante : {e}")
            return None

        kp3d_path = os.path.join(session_output_root, "keypoints_3d.npy")
        if not os.path.exists(kp3d_path):
            return None

        kp3d_raw = np.load(kp3d_path).astype(np.float32)
        num_frames = kp3d_raw.shape[0]
        kp3d = SmplxSmplifyService._preprocess_keypoints(kp3d_raw)

        if device_str == "auto":
            if torch.cuda.is_available(): device_str = "cuda"
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available(): device_str = "mps"
            else: device_str = "cpu"
        device = torch.device(device_str)
        print(f"DEBUG [SMPLify]: Périphérique = {device}, Frames = {num_frames}")

        # Calcul de l'initialisation analytique IK (évite les minima locaux)
        print("DEBUG [SMPLify]: Calcul de l'initialisation analytique IK...")
        init_poses = SmplxSmplifyService._compute_analytical_ik(kp3d)

        # Détection du sol
        ankle_y = np.stack([kp3d[:, 27, 1], kp3d[:, 28, 1], kp3d[:, 31, 1], kp3d[:, 32, 1]], axis=1)
        ankle_vel_y = np.abs(np.diff(ankle_y[:, :2], axis=0, prepend=ankle_y[:1, :2]))
        mean_vel = ankle_vel_y.mean(axis=1)
        static_mask = mean_vel < 0.005
        y_floor = np.percentile(ankle_y[static_mask].min(axis=1), 10) if static_mask.sum() > 5 else np.percentile(ankle_y.min(axis=1), 5)
        print(f"DEBUG [SMPLify]: Sol détecté à Y = {y_floor:.4f}")

        body_model = smplx_lib.create(
            SmplxSmplifyService._get_models_dir(), model_type="smplx", gender=gender,
            use_pca=False, flat_hand_mean=True,
            num_betas=10, num_expression_coeffs=10, batch_size=1
        ).to(device)
        faces = body_model.faces.copy()

        # Variables d'optimisation
        opt_transl = torch.zeros(1, 3, requires_grad=True, device=device)
        opt_global_orient = torch.zeros(1, 3, requires_grad=True, device=device)
        opt_body_pose = torch.zeros(1, 63, requires_grad=True, device=device)
        
        # Poids de pose L2. Renforcer fortement coudes et genoux
        pose_prior_weights = torch.ones(63, device=device) * 0.1
        pose_prior_weights[3*3:4*3] = 5.0   # L_Knee
        pose_prior_weights[4*3:5*3] = 5.0   # R_Knee
        pose_prior_weights[17*3:18*3] = 5.0 # L_Elbow
        pose_prior_weights[18*3:19*3] = 5.0 # R_Elbow
        
        res_transl = np.zeros((num_frames, 3), dtype=np.float32)
        res_global_orient = np.zeros((num_frames, 3), dtype=np.float32)
        res_body_pose = np.zeros((num_frames, 63), dtype=np.float32)

        prev_body_pose = None
        prev_transl = None
        prev_global_orient = None
        
        print("DEBUG [SMPLify]: Début de l'optimisation L-BFGS frame-par-frame...")
        for fi in tqdm(range(num_frames)):
            target_np, valid_np, weights_np = SmplxSmplifyService._mp33_to_smplx_target(kp3d[fi])
            target_t = torch.tensor(target_np, device=device).unsqueeze(0)
            weights_t = torch.tensor(weights_np, device=device).unsqueeze(0).unsqueeze(-1)
            
            # Initialisation hybride : analytique pour la première frame / pour éviter le drift,
            # ou warm-start lissé
            if fi == 0:
                opt_transl.data[:] = torch.tensor(init_poses['transl'][fi], device=device)
                opt_global_orient.data[:] = torch.tensor(init_poses['global_orient'][fi], device=device)
                opt_body_pose.data[:] = torch.tensor(init_poses['body_pose'][fi], device=device)
            else:
                # Initialisation par mélange : 70% de la frame précédente optimisée (warm-start)
                # et 30% de la frame actuelle analytique (pour réinjecter la vraie info 3D et guider l'optimiseur)
                opt_transl.data[:] = 0.7 * prev_transl + 0.3 * torch.tensor(init_poses['transl'][fi], device=device)
                opt_global_orient.data[:] = 0.7 * prev_global_orient + 0.3 * torch.tensor(init_poses['global_orient'][fi], device=device)
                opt_body_pose.data[:] = 0.7 * prev_body_pose + 0.3 * torch.tensor(init_poses['body_pose'][fi], device=device)
            
            optimizer = torch.optim.LBFGS(
                [opt_transl, opt_global_orient, opt_body_pose],
                max_iter=35 if fi == 0 else 8,
                line_search_fn="strong_wolfe",
                tolerance_change=1e-5
            )

            def closure():
                optimizer.zero_grad()
                out = body_model(
                    transl=opt_transl,
                    global_orient=opt_global_orient,
                    body_pose=opt_body_pose,
                    betas=torch.zeros((1, 10), device=device),
                    left_hand_pose=torch.zeros((1, 45), device=device),
                    right_hand_pose=torch.zeros((1, 45), device=device),
                    jaw_pose=torch.zeros((1, 3), device=device),
                    leye_pose=torch.zeros((1, 3), device=device),
                    reye_pose=torch.zeros((1, 3), device=device),
                    expression=torch.zeros((1, 10), device=device)
                )
                
                # Data Loss
                pred_joints = out.joints[:, :55]
                data_loss = (weights_t * (pred_joints - target_t) ** 2).sum() * 1.5
                
                # Pose Prior Loss (L2)
                pose_loss = (pose_prior_weights * (opt_body_pose ** 2)).sum() * 0.5
                
                # Ground Anchoring Loss
                foot_joints = pred_joints[:, [7, 8, 10, 11], 1]
                min_y, _ = foot_joints.min(dim=1)
                floor_loss = torch.relu(y_floor - min_y).sum() * 100.0
                
                # Temporal Velocity Loss
                temp_loss = 0.0
                if prev_body_pose is not None:
                    temp_loss += ((opt_body_pose - prev_body_pose)**2).sum() * 400.0
                    temp_loss += ((opt_transl - prev_transl)**2).sum() * 400.0
                    temp_loss += ((opt_global_orient - prev_global_orient)**2).sum() * 400.0

                total_loss = data_loss + pose_loss + floor_loss + temp_loss
                total_loss.backward()
                return total_loss

            optimizer.step(closure)
            
            prev_body_pose = opt_body_pose.clone().detach()
            prev_transl = opt_transl.clone().detach()
            prev_global_orient = opt_global_orient.clone().detach()
            
            res_transl[fi] = opt_transl.detach().cpu().numpy()[0]
            res_global_orient[fi] = opt_global_orient.detach().cpu().numpy()[0]
            res_body_pose[fi] = opt_body_pose.detach().cpu().numpy()[0]

        # Post-lissage (Gaussian) lourd pour assurer la fluidité absolue
        print("DEBUG [SMPLify]: Lissage post-optimisation...")
        for j in range(21):
            for c in range(3):
                res_body_pose[:, j*3 + c] = gaussian_filter1d(res_body_pose[:, j*3 + c], sigma=1.5)
        for c in range(3):
            res_global_orient[:, c] = gaussian_filter1d(res_global_orient[:, c], sigma=1.5)
            res_transl[:, c] = gaussian_filter1d(res_transl[:, c], sigma=1.5)

        # Batch Forward pass pour générer les maillages finaux
        print("DEBUG [SMPLify]: Génération des maillages finaux...")
        all_vertices, all_joints = [], []
        batch_size = 64
        for i in range(0, num_frames, batch_size):
            end_idx = min(i + batch_size, num_frames)
            n_b = end_idx - i
            with torch.no_grad():
                out = body_model(
                    transl=torch.tensor(res_transl[i:end_idx], device=device),
                    global_orient=torch.tensor(res_global_orient[i:end_idx], device=device),
                    body_pose=torch.tensor(res_body_pose[i:end_idx], device=device),
                    betas=torch.zeros((n_b, 10), device=device),
                    left_hand_pose=torch.zeros((n_b, 45), device=device),
                    right_hand_pose=torch.zeros((n_b, 45), device=device),
                    jaw_pose=torch.zeros((n_b, 3), device=device),
                    leye_pose=torch.zeros((n_b, 3), device=device),
                    reye_pose=torch.zeros((n_b, 3), device=device),
                    expression=torch.zeros((n_b, 10), device=device),
                    return_verts=True
                )
                all_vertices.append(out.vertices.cpu().numpy())
                all_joints.append(out.joints[:, :22, :].cpu().numpy())

        vertices_arr = np.concatenate(all_vertices, axis=0)
        joints_arr = np.concatenate(all_joints, axis=0)

        npz_path = os.path.join(session_output_root, "smplx_result.npz")
        np.savez_compressed(npz_path, vertices=vertices_arr, joints=joints_arr, faces=faces)
        
        json_path = os.path.join(session_output_root, "smplx_threejs.json")
        SmplxSmplifyService._export_threejs_json(vertices_arr, joints_arr, faces, json_path, max_frames=max_export_frames)
        
        print(f"DEBUG [SMPLify]: Terminé ! Output = {npz_path}")
        return npz_path

    @staticmethod
    def _export_threejs_json(vertices, joints, faces, output_path, max_frames=9999):
        num_f = min(vertices.shape[0], max_frames)
        data = {
            "meta": {
                "total_frames":    num_f,
                "exported_frames": num_f,
                "n_vertices":      int(vertices.shape[1]),
                "n_joints":        int(joints.shape[1]),
                "fps":             30,
                "pipeline":        "SMPLify-X Optimization Pipeline",
            },
            "faces": faces.flatten().tolist(),
            "frames": [
                {
                    "v": np.round(vertices[i].flatten(), 4).tolist(),
                    "j": np.round(joints[i].flatten(),   4).tolist(),
                }
                for i in range(num_f)
            ],
        }
        with open(output_path, "w") as f:
            json.dump(data, f, separators=(",", ":"))
        mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"DEBUG [SMPLify]: JSON généré → {output_path} ({mb:.1f} MB, {num_f} frames)")
