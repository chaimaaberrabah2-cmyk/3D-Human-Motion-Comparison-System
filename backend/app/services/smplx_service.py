# =============================================================
# backend/app/services/smplx_service.py
# =============================================================
# Service de fitting SMPL-X.
#
# Pipeline :
#   1. Charge les keypoints 3D triangulés (keypoints_3d.npy)
#   2. Remappe 33 landmarks MediaPipe → 22 joints SMPL-X
#   3. Phase 1 : Optimise la forme du corps (betas) sur 50 itérations
#   4. Phase 2 : Optimise la pose par frame via gradient descent (PyTorch)
#   5. Sauvegarde smplx_result.npz (vertices, joints, faces)
#   6. Exporte smplx_threejs.json (downsampled pour affichage web)
# =============================================================

import os
import json
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# MediaPipe landmark index → SMPL-X body joint index mapping
# SMPL-X 22 body joints:
#  0:pelvis 1:l_hip 2:r_hip 3:spine1 4:l_knee 5:r_knee 6:spine2
#  7:l_ankle 8:r_ankle 9:spine3 10:l_foot 11:r_foot 12:neck
#  13:l_collar 14:r_collar 15:head 16:l_shoulder 17:r_shoulder
#  18:l_elbow 19:r_elbow 20:l_wrist 21:r_wrist
# ---------------------------------------------------------------------------
MP_TO_SMPLX: dict[int, list[int]] = {
    0:  [23, 24],      # pelvis     ← avg(left_hip, right_hip)
    1:  [23],          # left_hip
    2:  [24],          # right_hip
    3:  [11, 12, 23, 24],  # spine1 ← avg shoulders + hips
    4:  [25],          # left_knee
    5:  [26],          # right_knee
    6:  [11, 12],      # spine2     ← avg shoulders
    7:  [27],          # left_ankle
    8:  [28],          # right_ankle
    9:  [11, 12],      # spine3     ← avg shoulders (upper back)
    12: [11, 12],      # neck       ← avg(left_shoulder, right_shoulder)
    15: [0],           # head       ← nose
    16: [11],          # left_shoulder
    17: [12],          # right_shoulder
    18: [13],          # left_elbow
    19: [14],          # right_elbow
    20: [15],          # left_wrist
    21: [16],          # right_wrist
}


class SmplxService:

    @staticmethod
    def _get_models_dir() -> str:
        """Returns absolute path to backend/data/smplx_models/"""
        import glob
        import shutil
        backend_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        base_models_dir = os.path.join(backend_dir, "data", "smplx_models")
        smplx_subfolder = os.path.join(base_models_dir, "smplx")
        
        # The smplx library expects files in {base_models_dir}/smplx
        # If files are directly in base_models_dir, move them to the subfolder.
        if not os.path.exists(smplx_subfolder):
            os.makedirs(smplx_subfolder, exist_ok=True)
            
        for ext in ["*.npz", "*.pkl"]:
            for filepath in glob.glob(os.path.join(base_models_dir, ext)):
                filename = os.path.basename(filepath)
                dest = os.path.join(smplx_subfolder, filename)
                shutil.move(filepath, dest)
                logger.info(f"Moved {filename} to {smplx_subfolder}")

        return base_models_dir

    @staticmethod
    def _build_target_joints(frame_kp: np.ndarray):
        """
        Convert one frame of MediaPipe keypoints (33, 4) into SMPL-X target
        joints (22, 3) with a validity mask.

        Args:
            frame_kp: np.ndarray of shape (33, 4) — [x, y, z, visibility]

        Returns:
            target : np.ndarray (22, 3)
            valid  : np.ndarray (22,) bool
        """
        n_smplx = 22
        target = np.zeros((n_smplx, 3), dtype=np.float32)
        valid = np.zeros(n_smplx, dtype=bool)

        for smplx_idx, mp_indices in MP_TO_SMPLX.items():
            if smplx_idx >= n_smplx:
                continue
            pts = frame_kp[mp_indices, :3]         # (N, 3)
            # IMPORTANT: Target coordinates from OpenCV are Y pointing down, Z forward.
            # We invert Y and Z to map to standard OpenGL (SMPL-X) natively without causing a mirror effect.
            pts[:, 1] = -pts[:, 1]
            pts[:, 2] = -pts[:, 2]
            
            vis = frame_kp[mp_indices, 3]          # (N,)
            vis_mask = vis > 0.3
            if np.any(vis_mask):
                target[smplx_idx] = pts[vis_mask].mean(axis=0)
                valid[smplx_idx] = True

        return target, valid

    # ------------------------------------------------------------------
    # Main public method
    # ------------------------------------------------------------------
    @staticmethod
    def fit_and_save(
        session_output_root: str,
        gender: str = "neutral",
        n_iter: int = 25,
        device_str: str = "auto",
        max_export_frames: int = 9000,
    ) -> Optional[str]:
        """
        Fit SMPL-X to triangulated 3D keypoints and save results.

        Args:
            session_output_root : path containing keypoints_3d.npy
            gender              : 'neutral' | 'male' | 'female'
            n_iter              : gradient descent steps per frame
            device_str          : 'auto' | 'cpu' | 'cuda' | 'mps'
            max_export_frames   : max frames in Three.js JSON export

        Returns:
            Path to smplx_result.npz, or None if failed.
        """
        try:
            import torch
            import smplx as smplx_lib
            from tqdm import tqdm
        except ImportError as e:
            logger.error(f"Missing dependency for SMPL-X fitting: {e}")
            return None

        kp3d_path = os.path.join(session_output_root, "keypoints_3d.npy")
        if not os.path.exists(kp3d_path):
            logger.error(f"keypoints_3d.npy not found at {kp3d_path}")
            return None

        # ----- Select device -----
        if device_str == "auto":
            if torch.cuda.is_available():
                device_str = "cuda"
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                device_str = "mps"
            else:
                device_str = "cpu"
        device = torch.device(device_str)
        print(f"DEBUG [SmplxService]: Using device → {devi
        # ----- Load 3D keypoints -----
        kp3d = np.load(kp3d_path)          # (F, 33, 4)
        num_frames = kp3d.shape[0]
        
        # TEMPORAL SMOOTHING: Fixes hand & joint jitter (shakes)
        import scipy.ndimage
        print(f"DEBUG [SmplxService]: Applying temporal Gaussian smoothing to {num_frames} frames...")
        kp3d[:, :, :3] = scipy.ndimage.gaussian_filter1d(kp3d[:, :, :3], sigma=1.5, axis=0)
        
        print(f"DEBUG [SmplxService]: Fitting all {num_frames} frames as requested...")

        # ----- Scale Normalization to METERS -----
        # Find first valid frame to calculate torso length
        first_valid_frame = 0
        for fi in range(min(num_frames, 30)):
            tgt, v = SmplxService._build_target_joints(kp3d[fi])
            if v[0] and v[12]: # Pelvis (0) and Neck (12) are valid
                d = np.linalg.norm(tgt[12] - tgt[0])
                if d > 0:
                    scale_factor = 0.50 / d # Standard SMPL torso is ~0.50 meters
                    kp3d[:, :, :3] *= scale_factor
                    print(f"DEBUG [SmplxService]: Auto-scaling points to meters (Factor: {scale_factor:.5f}, Target Torso was: {d:.2f})")
                    break

        # ----- Load SMPL-X model -----
        models_dir = SmplxService._get_models_dir()
        try:
            body_model = smplx_lib.create(
                models_dir,
                model_type="smplx",
                gender=gender,
                use_pca=False,
                flat_hand_mean=True,
                num_betas=10,
                num_expression_coeffs=10,
                batch_size=1,
            ).to(device)
            faces = body_model.faces.copy()
        except Exception as e:
            logger.error(f"Failed to load SMPL-X model from {models_dir}: {e}")
            return None

        # ----- Find first valid frame -----
        first_valid_frame = None
        for fi in range(min(num_frames, 30)):
            _, v = SmplxService._build_target_joints(kp3d[fi])
            if v.sum() >= 8:
                first_valid_frame = fi
                break

        if first_valid_frame is None:
            logger.warning("No valid frames found. Aborting SMPL-X fitting.")
            return None

        # ----- Stage 1: Shape estimation (first valid frame) -----
        betas = torch.zeros(1, 10, dtype=torch.float32, device=device, requires_grad=True)
        transl = torch.zeros(1, 3, dtype=torch.float32, device=device, requires_grad=True)
        g_orient = torch.zeros(1, 3, dtype=torch.float32, device=device, requires_grad=True)
        b_pose = torch.zeros(1, 63, dtype=torch.float32, device=device, requires_grad=True)

        target_np, valid_np = SmplxService._build_target_joints(kp3d[first_valid_frame])
        target_t = torch.tensor(target_np, dtype=torch.float32, device=device)
        valid_t = torch.tensor(valid_np, dtype=torch.bool, device=device)

        # Rough pelvis centering
        pelvis_target = target_np[0] 
        transl.data = torch.tensor(pelvis_target[None], dtype=torch.float32, device=device)

        # Initialize orientation by testing 4 cardinal directions to avoid local minima
        best_loss = float('inf')
        best_angle = 0.0
        with torch.no_grad():
            for angle in [0.0, np.pi/2, np.pi, 3*np.pi/2]:
                test_orient = torch.tensor([[0.0, angle, 0.0]], dtype=torch.float32, device=device)
                out = body_model(
                    betas=betas, global_orient=test_orient, body_pose=b_pose, transl=transl, return_verts=False
                )
                loss = ((out.joints[0, :22][valid_t] - target_t[valid_t]) ** 2).mean().item()
                if loss < best_loss:
                    best_loss = loss
                    best_angle = angle
        
        g_orient = torch.tensor([[0.0, best_angle, 0.0]], dtype=torch.float32, device=device, requires_grad=True)

        opt_shape = torch.optim.Adam([betas, transl, g_orient], lr=0.04)
        for _ in range(60):
            opt_shape.zero_grad()
            out = body_model(
                betas=betas,
                global_orient=g_orient.detach(),
                body_pose=b_pose.detach(),
                transl=transl,
                return_verts=False,
            )
            pred_j = out.joints[0, :22, :]
            loss = ((pred_j[valid_t] - target_t[valid_t]) ** 2).mean()
            loss.backward()
            opt_shape.step()

        betas_fixed = betas.detach().clone()
        print(f"DEBUG [SmplxService]: Shape fitting complete. Starting pose fitting...")

        # ----- Stage 2: Per-frame pose fitting -----
        all_vertices: list[np.ndarray] = []
        all_joints: list[np.ndarray] = []

        prev_orient = g_orient.detach().clone()
        prev_pose = b_pose.detach().clone()
        prev_transl = transl.detach().clone()

        for fi in tqdm(range(num_frames), desc="SMPL-X pose fitting"):
            target_np, valid_np = SmplxService._build_target_joints(kp3d[fi])
            target_t = torch.tensor(target_np, dtype=torch.float32, device=device)
            valid_t = torch.tensor(valid_np, dtype=torch.bool, device=device)

            if valid_t.sum() < 5:
                # Fallback: reuse previous frame
                if all_vertices:
                    all_vertices.append(all_vertices[-1])
                    all_joints.append(all_joints[-1])
                else:
                    with torch.no_grad():
                        out = body_model(betas=betas_fixed, return_verts=True)
                        all_vertices.append(out.vertices[0].cpu().numpy())
                        all_joints.append(out.joints[0, :22].cpu().numpy())
                continue

            # Warm-start from previous frame
            fr_orient = prev_orient.clone().requires_grad_(True)
            fr_pose = prev_pose.clone().requires_grad_(True)
            fr_transl = prev_transl.clone().requires_grad_(True)

            opt = torch.optim.Adam([fr_orient, fr_pose, fr_transl], lr=0.04)
            for _ in range(n_iter):
                opt.zero_grad()
                out = body_model(
                    betas=betas_fixed,
                    global_orient=fr_orient,
                    body_pose=fr_pose,
                    transl=fr_transl,
                    return_verts=False,
                )
                pred_j = out.joints[0, :22, :]
                loss = ((pred_j[valid_t] - target_t[valid_t]) ** 2).mean()
                loss += 0.001 * (fr_pose ** 2).mean()   # pose regularizer
                loss.backward()
                opt.step()

            # Save optimized params for warm-start
            prev_orient = fr_orient.detach().clone()
            prev_pose = fr_pose.detach().clone()
            prev_transl = fr_transl.detach().clone()

            with torch.no_grad():
                out = body_model(
                    betas=betas_fixed,
                    global_orient=fr_orient,
                    body_pose=fr_pose,
                    transl=fr_transl,
                    return_verts=True,
                )
                all_vertices.append(out.vertices[0].cpu().numpy())
                all_joints.append(out.joints[0, :22].cpu().numpy())

        vertices_arr = np.array(all_vertices, dtype=np.float32)   # (T, 10475, 3)
        joints_arr = np.array(all_joints, dtype=np.float32)       # (T, 22,    3)

        # ----- Save .npz -----
        npz_path = os.path.join(session_output_root, "smplx_result.npz")
        np.savez_compressed(
            npz_path,
            vertices=vertices_arr,
            joints=joints_arr,
            faces=faces,
        )
        print(f"DEBUG [SmplxService]: Saved smplx_result.npz → {npz_path}")

        # ----- Export Three.js JSON (lightweight) -----
        json_path = os.path.join(session_output_root, "smplx_threejs.json")
        SmplxService._export_threejs_json(
            vertices_arr, joints_arr, faces, json_path,
            max_frames=max_export_frames,
        )

        return npz_path

    # ------------------------------------------------------------------
    # Three.js export
    # ------------------------------------------------------------------
    @staticmethod
    def _export_threejs_json(
        vertices: np.ndarray,
        joints: np.ndarray,
        faces: np.ndarray,
        output_path: str,
        max_frames: int = 60,
    ) -> None:
        """
        Export SMPL-X data as a compact JSON optimized for Three.js rendering.
        Vertices and joints are quantised to float32 and downsampled.
        """
        num_frames = vertices.shape[0]
        step = max(1, num_frames // max_frames)
        sampled = list(range(0, num_frames, step))[:max_frames]

        data = {
            "meta": {
                "total_frames": num_frames,
                "exported_frames": len(sampled),
                "n_vertices": int(vertices.shape[1]),
                "n_joints": int(joints.shape[1]),
                "fps": 30,
            },
            "faces": faces.flatten().tolist(),
            "frames": [
                {
                    "v": np.round(vertices[i].flatten(), 4).tolist(),  # vertices flat
                    "j": np.round(joints[i].flatten(), 4).tolist(),    # joints flat
                }
                for i in sampled
            ],
        }

        with open(output_path, "w") as f:
            json.dump(data, f, separators=(",", ":"))

        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"DEBUG [SmplxService]: Three.js JSON → {output_path} ({size_mb:.1f} MB)")
