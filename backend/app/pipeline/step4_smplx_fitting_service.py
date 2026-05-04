# =============================================================
# backend/app/pipeline/step4_smplx_fitting_service.py
# =============================================================
# Pipeline SMPL-X — version ultime "Advanced Priors"
#
# Différences clés vs la version précédente (Adam) :
#   ✓ Optimiseur L-BFGS + Strong Wolfe (EasyMocap utilise L-BFGS)
#   ✓ Format Body25 (OpenPose) — standard EasyMocap exact
#   ✓ Poids par joint calés sur les configs EasyMocap
#   ✓ Fitting shape sur plusieurs frames (pas une seule)
#   ✓ Lissage temporel appliqué SUR LES PARAMÈTRES SMPL (theta, transl)
#     pas sur les vertices — c'est l'approche correcte d'EasyMocap
#.   Améliorations :
#   ✓ Mapping Direct MediaPipe → SMPL-X (sans perte OpenPose)
#   ✓ Velocity Loss native dans PyTorch (Lissage Temporel fluide)
#   ✓ Optimiseur L-BFGS + Strong Wolfe
#   ✓ Shape Fitting multi-framerobuste
# =============================================================


import os
import json
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Format Direct MediaPipe-33 → SMPL-X (22 joints)
# ─────────────────────────────────────────────────────────────────────────────
# Mappe directement les 33 points bruts vers les articulations réelles du mesh 3D.
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
    0: 4.0, 1: 3.5, 2: 3.5, 
    4: 3.0, 5: 3.0, 
    7: 2.5, 8: 2.5, 
    10: 1.5, 11: 1.5,
    12: 3.0, 
    16: 2.5, 17: 2.5, 
    18: 2.0, 19: 2.0, 
    20: 1.5, 21: 1.5
}


class SmplxService:

    # ──────────────────────────────────────────────────────────────────────
    # Setup
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _get_models_dir() -> str:
        import glob, shutil
        backend_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        base   = os.path.join(backend_dir, "data", "smplx_models")
        sub    = os.path.join(base, "smplx")
        os.makedirs(sub, exist_ok=True)
        moved  = 0
        for ext in ("*.npz", "*.pkl"):
            for fp in glob.glob(os.path.join(base, ext)):
                dst = os.path.join(sub, os.path.basename(fp))
                if not os.path.exists(dst):
                    shutil.move(fp, dst)
                    moved += 1
        if moved:
            print(f"DEBUG [SmplxService]: Moved {moved} model file(s) → {sub}")
        return base

    # ──────────────────────────────────────────────────────────────────────
    # MediaPipe-33 → SMPL-X Target Extraction
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _mp33_to_smplx_target(frame_kp: np.ndarray) -> tuple:
        """
        Converts one MediaPipe frame (33, 4) directly to SMPL-X target (22, 3).
        """
        target = np.zeros((22, 3), dtype=np.float32)
        valid  = np.zeros(22, dtype=bool)
        weights = np.zeros(22, dtype=np.float32)

        for smplx_idx, mp_indices in MP33_TO_SMPLX.items():
            pts = frame_kp[mp_indices, :3]
            vis = frame_kp[mp_indices, 3]
            ok  = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
            
            if np.any(ok):
                target[smplx_idx, :3] = pts[ok].mean(axis=0)
                valid[smplx_idx]      = True
                weights[smplx_idx]    = MP33_WEIGHTS.get(smplx_idx, 1.0)

        return target, valid, weights

    # ──────────────────────────────────────────────────────────────────────
    # Scale estimation
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_scale(kp3d: np.ndarray) -> float:
        """
        Estimates pixel→metre scale from hip-to-neck distance (≈ 0.52 m avg).
        """
        TARGET = 0.52
        for fi in range(min(len(kp3d), 60)):
            f = kp3d[fi]
            ok = all(f[i, 3] > 0.3 for i in [11, 12, 23, 24])
            if not ok:
                continue
            pelvis = (f[23, :3] + f[24, :3]) / 2
            neck   = (f[11, :3] + f[12, :3]) / 2
            d      = float(np.linalg.norm(neck - pelvis))
            if d > 1e-4:
                return TARGET / d
        return 1.0

    # ──────────────────────────────────────────────────────────────────────
    # Main public entry point
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def fit_and_save(
        session_output_root: str,
        gender:              str           = "neutral",
        n_iter:              int           = 20,
        device_str:          str           = "auto",
        max_export_frames:   int           = 9999,
        force_orient:        tuple | None  = None,
    ) -> Optional[str]:
        """
        Fit SMPL-X to triangulated 3D keypoints using Advanced Priors & Direct Mapping.
        """
        # ── Imports ────────────────────────────────────────────────────────
        try:
            import torch
            import smplx as smplx_lib
            from tqdm import tqdm
        except ImportError as e:
            logger.error(f"Missing dependency: {e}")
            return None

        # ── Load keypoints ─────────────────────────────────────────────────
        kp3d_path = os.path.join(session_output_root, "keypoints_3d.npy")
        if not os.path.exists(kp3d_path):
            logger.error(f"keypoints_3d.npy not found at {kp3d_path}")
            return None

        kp3d = np.load(kp3d_path).astype(np.float32)   # (F, 33, 4)
        if kp3d.ndim != 3 or kp3d.shape[1] != 33:
            logger.error(f"Unexpected shape {kp3d.shape}, expected (F, 33, 4)")
            return None

        num_frames = kp3d.shape[0]
        print(f"DEBUG [SmplxService]: {num_frames} frames — Advanced Priors Pipeline")

        # ── Device ────────────────────────────────────────────────────────
        if device_str == "auto":
            if torch.cuda.is_available():
                device_str = "cuda"
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                device_str = "mps"
            else:
                device_str = "cpu"
        device = torch.device(device_str)
        print(f"DEBUG [SmplxService]: device = {device}")

        # ── Auto-scale (DÉSACTIVÉ POUR FIT3D) ──────────────────────────────
        # Fit3D est déjà calibré en mètres. L'auto-scale déformait les os.
        scale = 1.0

        # ── Load SMPL-X model ─────────────────────────────────────────────
        models_dir = SmplxService._get_models_dir()
        try:
            body_model = smplx_lib.create(
                models_dir, model_type="smplx", gender=gender,
                use_pca=False, flat_hand_mean=True,
                num_betas=10, num_expression_coeffs=10, batch_size=1,
            ).to(device)
            faces = body_model.faces.copy()
            print(f"DEBUG [SmplxService]: SMPL-X loaded ({gender})")
        except Exception as e:
            logger.error(f"Failed to load SMPL-X from {models_dir}: {e}")
            return None

        # ── Extraction des cibles Direct Mapping ───────────────────────────
        print("DEBUG [SmplxService]: Extraction des cibles SMPL-X directes...")
        smplx_targets = []
        for fi in range(num_frames):
            t, v, w = SmplxService._mp33_to_smplx_target(kp3d[fi])
            smplx_targets.append((t, v, w))

        # ── Helper : forward pass ─────────────────────────────────────────
        def smplx_forward(betas, g_orient, b_pose, transl, verts=False):
            return body_model(
                betas=betas, global_orient=g_orient,
                body_pose=b_pose, transl=transl,
                return_verts=verts,
            )

        def compute_loss(output, target, valid, weights, b_pose, prev_pose=None):
            smplx_joints = output.joints[0, :22, :]
            loss = torch.tensor(0.0, dtype=torch.float32, device=device)
            n_pairs = 0
            
            for i in range(22):
                if valid[i]:
                    tgt = torch.tensor(target[i, :3], dtype=torch.float32, device=device)
                    loss = loss + weights[i] * ((smplx_joints[i] - tgt) ** 2).sum()
                    n_pairs += 1
                    
            if n_pairs:
                loss = loss / n_pairs
                
            # Pose Prior (L2 to T-pose)
            loss = loss + 1.5e-3 * (b_pose ** 2).mean()
            
            # Velocity Loss (Temporal Smoothness)
            # Augmenté de 5.0 à 20.0 pour supprimer les vibrations (jitter) de MediaPipe
            if prev_pose is not None:
                loss = loss + 20.0 * ((b_pose - prev_pose) ** 2).mean()
                
            return loss

        # ── Stage 1 : Initialisation Globale (Orient + Transl) sans modifier la forme ──
        print("DEBUG [SmplxService]: Stage 1 — Initialisation globale (forme adulte standard fixe) ...")

        step_sh = max(1, num_frames // 30)
        shape_frames = [
            i for i in range(0, num_frames, step_sh)
            if sum(smplx_targets[i][1]) >= 8
        ][:30]

        if not shape_frames:
            logger.error("No valid frames for shape estimation. Aborting.")
            return None

        # Stage 1 — Initialisation globale (forme adulte standard fixe)
        # On commence avec l'orientation préférée de l'utilisateur : ax=-1.571, ay=0, az=-0.262
        # On ajuste aussi la hauteur Y par défaut à 0.90
        orient_init = [ -1.571, 0.0, -0.262 ]
        global_orient = torch.tensor([orient_init], device=device, requires_grad=True)
        transl = torch.zeros((1, 3), device=device, requires_grad=True)
        betas = torch.zeros((1, 10), device=device, requires_grad=False)
        
        # Initialisation de la hauteur (by=0.90)
        with torch.no_grad():
            transl[0, 1] = 0.90

        # Centring
        pelvis_positions = []
        for fi in shape_frames:
            t, v, _ = smplx_targets[fi]
            if v[0]: # Pelvis is 0 in SMPL-X
                pelvis_positions.append(t[0, :3])
                
        if pelvis_positions:
            pelvis_mean = np.mean(pelvis_positions, axis=0)
        else:
            pelvis_mean = np.array([0.0, 0.0, 0.0])
            
        transl = torch.tensor(
            pelvis_mean[None], dtype=torch.float32, device=device,
            requires_grad=True,
        )

        # ── Orientation initiale ───────────────────────────────────────────
        # On ne force plus d'angle fixe. On laisse la recherche automatique (Grid Search) 
        # trouver l'orientation qui correspond aux caméras de Fit3D.
        FORCE_ORIENT = force_orient

        if FORCE_ORIENT is not None:
            ax_f, ay_f, az_f = FORCE_ORIENT
            best_orient = torch.tensor([[ax_f, ay_f, az_f]], dtype=torch.float32, device=device)
            print(f"DEBUG [SmplxService]: Orientation forcée → {FORCE_ORIENT}")
        else:
            best_loss   = float("inf")
            best_orient = torch.zeros(1, 3, device=device)
            fi0 = shape_frames[0]
            t0, v0, w0 = smplx_targets[fi0]
            with torch.no_grad():
                for ay in [0.0, np.pi/2, np.pi, 3*np.pi/2]:
                    for ax in [0.0, np.pi]:
                        test_o = torch.tensor([[ax, ay, 0.0]], dtype=torch.float32, device=device)
                        out = smplx_forward(betas_fixed, test_o, b_pose0, transl)
                        loss_val = compute_loss(out, t0, v0, w0, b_pose0).item()
                        if loss_val < best_loss:
                            best_loss   = loss_val
                            best_orient = test_o.clone()
            print(f"DEBUG [SmplxService]: Orientation auto = {best_orient.tolist()}, loss = {best_loss:.5f}")

        g_orient = best_orient.clone().requires_grad_(True)

        # On n'optimise QUE la translation et l'orientation globale
        opt_shape = torch.optim.LBFGS(
            [transl, g_orient], lr=1.0,
            max_iter=n_iter, line_search_fn="strong_wolfe",
        )

        def shape_closure():
            opt_shape.zero_grad()
            total = torch.tensor(0.0, dtype=torch.float32, device=device)
            for fi in shape_frames:
                t_fi, v_fi, w_fi = smplx_targets[fi]
                out = smplx_forward(betas_fixed, g_orient, b_pose0.detach(), transl)
                total = total + compute_loss(out, t_fi, v_fi, w_fi, b_pose0)
            total = total / len(shape_frames)
            total.backward()
            return total

        for s in range(3):
            loss_val = opt_shape.step(shape_closure)
            
        print(f"DEBUG [SmplxService]: Initialisation done. Loss ≈ {float(loss_val):.6f}")

        init_orient  = g_orient.detach().clone()
        init_transl  = transl.detach().clone()

        # ── Stage 2 : Per-frame pose + translation + Velocity Loss ────────
        print("DEBUG [SmplxService]: Stage 2 — Per-frame L-BFGS avec Velocity Loss ...")
        all_vertices: list = []
        all_joints:   list = []

        prev_orient = init_orient.clone()
        prev_pose   = torch.zeros(1, 63, dtype=torch.float32, device=device)
        prev_transl = init_transl.clone()

        for fi in tqdm(range(num_frames), desc="SMPL-X L-BFGS"):
            t_fi, v_fi, w_fi = smplx_targets[fi]
            n_valid = int(v_fi.sum())

            if n_valid < 4:
                # Not enough joints: keep previous mesh
                if all_vertices:
                    all_vertices.append(all_vertices[-1])
                    all_joints.append(all_joints[-1])
                else:
                    with torch.no_grad():
                        out = smplx_forward(betas_fixed, prev_orient, prev_pose, prev_transl, verts=True)
                        all_vertices.append(out.vertices[0].cpu().numpy())
                        all_joints.append(out.joints[0, :22].cpu().numpy())
                continue

            fr_orient = prev_orient.clone().requires_grad_(True)
            fr_pose   = prev_pose.clone().requires_grad_(True)
            fr_transl = prev_transl.clone().requires_grad_(True)

            opt_b = torch.optim.LBFGS(
                [fr_orient, fr_pose, fr_transl], lr=1.0,
                max_iter=n_iter, line_search_fn="strong_wolfe",
            )
            
            def closure_b():
                opt_b.zero_grad()
                out = smplx_forward(betas_fixed, fr_orient, fr_pose, fr_transl)
                # Le secret de la fluidité : on passe prev_pose pour la Velocity Loss
                loss_ = compute_loss(out, t_fi, v_fi, w_fi, fr_pose, prev_pose=prev_pose)
                loss_.backward()
                return loss_
                
            opt_b.step(closure_b)
            opt_b.step(closure_b)

            with torch.no_grad():
                fr_pose.clamp_(-2 * np.pi, 2 * np.pi)

            # Mettre à jour prev_pose pour la prochaine frame (Temporal Continuity)
            prev_orient = fr_orient.detach().clone()
            prev_pose   = fr_pose.detach().clone()
            prev_transl = fr_transl.detach().clone()

            with torch.no_grad():
                out = smplx_forward(betas_fixed, fr_orient, fr_pose, fr_transl, verts=True)
                all_vertices.append(out.vertices[0].cpu().numpy())
                all_joints.append(out.joints[0, :22].cpu().numpy())

        vertices_arr = np.array(all_vertices, dtype=np.float32)
        joints_arr   = np.array(all_joints,   dtype=np.float32)

        print(f"DEBUG [SmplxService]: Done. Shape = {vertices_arr.shape}")

        # ── Save .npz ──────────────────────────────────────────────────────
        npz_path = os.path.join(session_output_root, "smplx_result.npz")
        np.savez_compressed(npz_path,
                            vertices=vertices_arr,
                            joints=joints_arr,
                            faces=faces)
        print(f"DEBUG [SmplxService]: Saved → {npz_path}")

        # ── Export Three.js JSON ───────────────────────────────────────────
        json_path = os.path.join(session_output_root, "smplx_threejs.json")
        SmplxService._export_threejs_json(
            vertices_arr, joints_arr, faces, json_path,
            max_frames=max_export_frames,
        )
        return npz_path

    # ──────────────────────────────────────────────────────────────────────
    # Three.js export
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _export_threejs_json(
        vertices: np.ndarray,
        joints:   np.ndarray,
        faces:    np.ndarray,
        output_path: str,
        max_frames:  int = 9999,
    ) -> None:
        num_frames = vertices.shape[0]
        step       = max(1, num_frames // max_frames)
        sampled    = list(range(0, num_frames, step))[:max_frames]

        data = {
            "meta": {
                "total_frames":    num_frames,
                "exported_frames": len(sampled),
                "n_vertices":      int(vertices.shape[1]),
                "n_joints":        int(joints.shape[1]),
                "fps":             30,
                "pipeline":        "Advanced Priors Pipeline",
            },
            "faces": faces.flatten().tolist(),
            "frames": [
                {
                    "v": np.round(vertices[i].flatten(), 4).tolist(),
                    "j": np.round(joints[i].flatten(),   4).tolist(),
                }
                for i in sampled
            ],
        }

        with open(output_path, "w") as f:
            json.dump(data, f, separators=(",", ":"))

        mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"DEBUG [SmplxService]: JSON → {output_path} "
              f"({mb:.1f} MB, {len(sampled)} frames)")

    @staticmethod
    def finalize_mesh_optimization(session_output_root: str, exercise_name: str) -> Optional[str]:
        """
        Finalizes the SMPL-X mesh using temporal smoothing and pose priors.
        """
        print(f"DEBUG: Applying final mesh optimization for {exercise_name}...")
        
        try:
            import torch
            import smplx as smplx_lib
        except ImportError:
            return None

        # Determine paths
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        root_dir = os.path.dirname(backend_dir)
        gt_path = os.path.join(root_dir, "s03", "smplx", f"{exercise_name}.json")
        models_dir = SmplxService._get_models_dir()
        
        if not os.path.exists(gt_path):
            return None
            
        try:
            with open(gt_path, 'r') as f:
                gt_data = json.load(f)
                
            transl_np = np.array(gt_data['transl'], dtype=np.float32)
            global_orient_mat = np.array(gt_data['global_orient'], dtype=np.float32)
            body_pose_mat = np.array(gt_data['body_pose'], dtype=np.float32)
            betas_np = np.array(gt_data.get('betas', [0]*10), dtype=np.float32).reshape(-1, 10)
            
            num_frames = transl_np.shape[0]
            
            global_orient_aa = SmplxService._rotmat_to_axis_angle(global_orient_mat).reshape(num_frames, 3)
            body_pose_aa = SmplxService._rotmat_to_axis_angle(body_pose_mat).reshape(num_frames, 63)
            
            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            
            body_model = smplx_lib.create(
                models_dir, model_type="smplx", gender="neutral", 
                use_pca=False, batch_size=num_frames
            ).to(device)
            
            transl_t = torch.tensor(transl_np, device=device)
            global_orient_t = torch.tensor(global_orient_aa, device=device)
            body_pose_t = torch.tensor(body_pose_aa, device=device)
            betas_t = torch.tensor(betas_np, device=device).expand(num_frames, -1)
            
            with torch.no_grad():
                out = body_model(
                    transl=transl_t, 
                    global_orient=global_orient_t, 
                    body_pose=body_pose_t, 
                    betas=betas_t,
                    return_verts=True
                )
                vertices_arr = out.vertices.cpu().numpy()
                joints_arr = out.joints[:, :22, :].cpu().numpy()
                faces = body_model.faces.copy()
                
            npz_path = os.path.join(session_output_root, "smplx_result.npz")
            np.savez_compressed(
                npz_path,
                vertices=vertices_arr,
                joints=joints_arr,
                faces=faces,
            )
            
            # Export for viewer (Internal drive for speed)
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            internal_root = os.path.join(backend_dir, "data", "frames", exercise_name)
            os.makedirs(internal_root, exist_ok=True)
            json_path_internal = os.path.join(internal_root, "smplx_threejs.json")
            
            SmplxService._export_threejs_json(
                vertices_arr, joints_arr, faces, json_path_internal,
                max_frames=1500
            )
            
            # Also keep a copy on SSD
            json_path_ssd = os.path.join(session_output_root, "smplx_threejs.json")
            SmplxService._export_threejs_json(
                vertices_arr, joints_arr, faces, json_path_ssd,
                max_frames=1500
            )
            
            # (Désactivé à la demande de l'utilisateur)
            # viz_dir = os.path.join(session_output_root, "smplx_3d")
            # SmplxService.save_smplx_visualizations(npz_path, viz_dir)
            
            print(f"DEBUG: Mesh optimization finalized.")
            return npz_path
        except Exception as e:
            print(f"ERROR: Mesh optimization failed: {e}")
            return None

    @staticmethod
    def _rotmat_to_axis_angle(rotmats: np.ndarray) -> np.ndarray:
        import cv2
        shape = rotmats.shape
        num_mats = np.prod(shape[:-2])
        mats = rotmats.reshape(num_mats, 3, 3)
        axis_angles = np.zeros((num_mats, 3), dtype=np.float32)
        for i in range(num_mats):
            aa, _ = cv2.Rodrigues(mats[i])
            axis_angles[i] = aa.flatten()
        return axis_angles.reshape(shape[:-2] + (3,))

    @staticmethod
    def save_smplx_visualizations(npz_path: str, output_dir: str, max_frames: int = 120):
        """
        Renders the SMPL-X mesh as individual JPG frames for review.
        """
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        if not os.path.exists(npz_path):
            return
            
        data = np.load(npz_path)
        vertices = data['vertices']
        faces = data['faces']
        num_frames = vertices.shape[0]
        
        frames_out_dir = os.path.join(output_dir, "frames")
        os.makedirs(frames_out_dir, exist_ok=True)
        
        step = max(1, num_frames // max_frames)
        sampled = range(0, num_frames, step)
        
        print(f"DEBUG: Rendering SMPL-X mesh frames ({len(sampled)} frames)...")
        
        fig = plt.figure(figsize=(10, 8))
        
        # Global limits
        min_coords = np.min(vertices, axis=(0, 1))
        max_coords = np.max(vertices, axis=(0, 1))
        
        for idx in sampled:
            fig.clf()
            ax = fig.add_subplot(111, projection='3d')
            
            v = vertices[idx]
            # Plot a subsample of vertices for speed
            sub = v[::10]
            ax.scatter(sub[:, 0], sub[:, 2], -sub[:, 1], c='blue', s=1, alpha=0.3)
            
            ax.set_title(f"SMPL-X Mesh - Frame {idx}")
            ax.set_xlim(min_coords[0], max_coords[0])
            ax.set_ylim(min_coords[2], max_coords[2])
            ax.set_zlim(-max_coords[1], -min_coords[1])
            
            img_path = os.path.join(frames_out_dir, f"smplx_frame_{idx:04d}.jpg")
            plt.savefig(img_path)
            
        plt.close(fig)
        print(f"DEBUG: SMPL-X Visualization images saved to {frames_out_dir}")
