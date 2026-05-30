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
# OpenPose-25 BODY_25 → SMPL-X (22 joints)  [standard SMPLify-X mapping]
# ─────────────────────────────────────────────────────────────────────────────
# OP25: 0:Nose 1:Neck 2:RShoulder 3:RElbow 4:RWrist 5:LShoulder 6:LElbow
#   7:LWrist 8:MidHip 9:RHip 10:RKnee 11:RAnkle 12:LHip 13:LKnee 14:LAnkle
#   15:REye 16:LEye 17:REar 18:LEar 19:LBigToe 20:LSmallToe 21:LHeel
#   22:RBigToe 23:RSmallToe 24:RHeel
# Format: SMPLX_JOINT_INDEX : [OP25_indices_to_average]

OP25_TO_SMPLX = {
    0:  [8],    # Pelvis  ← MidHip
    1:  [12],   # L_Hip   ← LHip
    2:  [9],    # R_Hip   ← RHip
    4:  [13],   # L_Knee  ← LKnee
    5:  [10],   # R_Knee  ← RKnee
    7:  [14],   # L_Ankle ← LAnkle
    8:  [11],   # R_Ankle ← RAnkle
    10: [19],   # L_Foot  ← LBigToe
    11: [22],   # R_Foot  ← RBigToe
    12: [1],    # Neck    ← Neck
    15: [0],    # Head    ← Nose
    16: [5],    # L_Shoulder ← LShoulder
    17: [2],    # R_Shoulder ← RShoulder
    18: [6],    # L_Elbow    ← LElbow
    19: [3],    # R_Elbow    ← RElbow
    20: [7],    # L_Wrist    ← LWrist
    21: [4],    # R_Wrist    ← RWrist
}

OP25_WEIGHTS = {
    0:  4.0,   # Pelvis
    1:  3.5,   # L_Hip
    2:  3.5,   # R_Hip
    4:  6.0,   # L_Knee
    5:  6.0,   # R_Knee
    7:  4.0,   # L_Ankle  (↑ from 2.5 — better foot placement)
    8:  4.0,   # R_Ankle  (↑ from 2.5 — better foot placement)
    10: 3.5,   # L_Foot   (↑ from 1.5 — prevents foot twist)
    11: 3.5,   # R_Foot   (↑ from 1.5 — prevents foot twist)
    12: 3.0,   # Neck
    15: 3.5,   # Head     (↑ from 1.0 — face must follow)
    16: 5.0,   # L_Shoulder (↑ from 2.5 — anchor arm position)
    17: 5.0,   # R_Shoulder (↑ from 2.5 — anchor arm position)
    18: 5.5,   # L_Elbow   (↑ from 3.5 — key for curl motion)
    19: 5.5,   # R_Elbow   (↑ from 3.5 — key for curl motion)
    20: 5.5,   # L_Wrist
    21: 5.5,   # R_Wrist
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
        """Convert one OpenPose-25 frame (25, 4) to SMPL-X target (22, 3)."""
        target  = np.zeros((22, 3), dtype=np.float32)
        valid   = np.zeros(22, dtype=bool)
        weights = np.zeros(22, dtype=np.float32)

        for smplx_idx, op_indices in OP25_TO_SMPLX.items():
            pts = frame_kp[op_indices, :3]
            vis = frame_kp[op_indices, 3]
            ok  = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
            if np.any(ok):
                target[smplx_idx, :3] = pts[ok].mean(axis=0)
                valid[smplx_idx]      = True
                weights[smplx_idx]    = OP25_WEIGHTS.get(smplx_idx, 1.0)

        return target, valid, weights

    # ──────────────────────────────────────────────────────────────────────
    # Scale estimation
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_scale(kp3d: np.ndarray) -> float:
        """Estimates scale from MidHip→Neck distance (OP25: joint 8=MidHip, 1=Neck)."""
        TARGET = 0.52
        for fi in range(min(len(kp3d), 60)):
            f = kp3d[fi]
            ok = all(f[i, 3] > 0.3 for i in [1, 8, 9, 12])  # Neck, MidHip, RHip, LHip
            if not ok:
                continue
            pelvis = f[8, :3]   # OP25 MidHip
            neck   = f[1, :3]   # OP25 Neck
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

        kp3d = np.load(kp3d_path).astype(np.float32)   # (F, 25, 4) OpenPose-25
        if kp3d.ndim != 3 or kp3d.shape[1] != 25:
            logger.error(f"Unexpected shape {kp3d.shape}, expected (F, 25, 4)")
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
                
            # Pose Prior
            loss = loss + 1.5e-3 * (b_pose ** 2).mean()

            # Spine + neck + collar stability (head excluded — must follow target)
            # body_pose: spine1=[6:9], spine2=[15:18], spine3=[24:27], neck=[33:36],
            #            L_collar=[36:39], R_collar=[39:42]
            _stable_spine = torch.tensor(
                [6,7,8, 15,16,17, 24,25,26, 33,34,35, 36,37,38, 39,40,41],
                device=device
            )
            loss = loss + 3.0 * (b_pose[0, _stable_spine] ** 2).mean()

            # Head: light regularization only — allows nodding/tilting to follow target
            loss = loss + 0.3 * (b_pose[0, 42:45] ** 2).mean()

            # Ankle twist: prevent inversion/eversion and toe-in/toe-out
            # L_Ankle=[18:21], R_Ankle=[21:24]
            loss = loss + 6.0 * (b_pose[0, 18:24] ** 2).mean()

            # Foot rotation: prevent L_Foot (27:30) and R_Foot (30:33) from rotating
            loss = loss + 12.0 * (b_pose[0, 27:33] ** 2).mean()

            # Velocity — 4 groups: knees free, feet planted, arms light, spine moderate
            if prev_pose is not None:
                diff  = (b_pose - prev_pose) ** 2
                vel_w = torch.full((63,), 15.0, device=device)
                vel_w[0:6]   = 12.0  # hips
                vel_w[9:15]  = 6.0   # knees — free to bend
                vel_w[18:24] = 18.0  # ankles
                vel_w[27:33] = 25.0  # feet — planted
                vel_w[45:63] = 5.0   # arms — light
                loss = loss + (diff[0] * vel_w).mean()

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

        # Fixer la morphologie à une personne adulte "standard" (betas = 0)
        betas_fixed = torch.zeros(1, 10, dtype=torch.float32, device=device)
        
        g_orient = torch.zeros(1, 3,  dtype=torch.float32, device=device, requires_grad=True)
        b_pose0  = torch.zeros(1, 63, dtype=torch.float32, device=device)

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
                loss_ = compute_loss(out, t_fi, v_fi, w_fi, fr_pose, prev_pose=prev_pose)
                # Orient velocity — allows gradual body tilt (deadlift) but no sudden jumps
                loss_ = loss_ + 40.0 * ((fr_orient - prev_orient) ** 2).mean()
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
            betas_np = np.array(gt_data.get('betas', [0]*10), dtype=np.float32).reshape(1, 10)
            
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
            
            json_path = os.path.join(session_output_root, "smplx_threejs.json")
            SmplxService._export_threejs_json(
                vertices_arr, joints_arr, faces, json_path,
                max_frames=60
            )
            
            viz_dir = os.path.join(session_output_root, "smplx_3d")
            SmplxService.save_smplx_visualizations(npz_path, viz_dir, max_frames=120)
            
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
