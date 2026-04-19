# =============================================================
# backend/app/services/smplx_service.py
# =============================================================
# Pipeline SMPL-X — qualité EasyMocap.
#
# Différences clés vs la version précédente (Adam) :
#   ✓ Optimiseur L-BFGS + Strong Wolfe (EasyMocap utilise L-BFGS)
#   ✓ Format Body25 (OpenPose) — standard EasyMocap exact
#   ✓ Poids par joint calés sur les configs EasyMocap
#   ✓ Fitting shape sur plusieurs frames (pas une seule)
#   ✓ Lissage temporel appliqué SUR LES PARAMÈTRES SMPL (theta, transl)
#     pas sur les vertices — c'est l'approche correcte d'EasyMocap
# =============================================================

import os
import json
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Format Body25 (OpenPose — standard EasyMocap)
#
# Body25 indices :
#  0:Nose       1:Neck       2:RShoulder  3:RElbow    4:RWrist
#  5:LShoulder  6:LElbow     7:LWrist     8:MidHip
#  9:RHip      10:RKnee     11:RAnkle   12:LHip     13:LKnee   14:LAnkle
# 15:REye      16:LEye      17:REar     18:LEar
# 19:LBigToe  20:LSmallToe 21:LHeel    22:RBigToe  23:RSmallToe 24:RHeel
#
# Conversion MediaPipe-33 → Body25
# ─────────────────────────────────────────────────────────────────────────────
# fmt: off
MP33_TO_BODY25: dict = {
    0:  [0],       # Nose        ← nose
    1:  [11, 12],  # Neck        ← avg(l_shoulder, r_shoulder)
    2:  [12],      # RShoulder
    3:  [14],      # RElbow
    4:  [16],      # RWrist
    5:  [11],      # LShoulder
    6:  [13],      # LElbow
    7:  [15],      # LWrist
    8:  [23, 24],  # MidHip      ← avg(l_hip, r_hip)
    9:  [24],      # RHip
    10: [26],      # RKnee
    11: [28],      # RAnkle
    12: [23],      # LHip
    13: [25],      # LKnee
    14: [27],      # LAnkle
    # 15-18 : face — non disponibles en 3D fiable avec notre setup → skip
    19: [31],      # LBigToe
    21: [29],      # LHeel
    22: [32],      # RBigToe
    24: [30],      # RHeel
}

# Poids Body25 — calibrés sur les configs EasyMocap (body25.yml)
# 0 = joint désactivé (non fiable ou absent)
BODY25_WEIGHTS: dict = {
    0:  0.0,   # Nose         — désactivé (bruit en 3D)
    1:  2.0,   # Neck
    2:  2.5,   # RShoulder
    3:  2.0,   # RElbow
    4:  1.5,   # RWrist
    5:  2.5,   # LShoulder
    6:  2.0,   # LElbow
    7:  1.5,   # LWrist
    8:  3.5,   # MidHip       — ROOT, très important
    9:  3.5,   # RHip
    10: 3.0,   # RKnee        — clé pour les squats
    11: 2.5,   # RAnkle
    12: 3.5,   # LHip
    13: 3.0,   # LKnee
    14: 2.5,   # LAnkle
    19: 1.5,   # LBigToe
    21: 1.5,   # LHeel
    22: 1.5,   # RBigToe
    24: 1.5,   # RHeel
}

# Correspondance Body25 → joint SMPL-X (22 body joints)
# Seuls les joints qui ont une correspondance directe dans l'arbre cinématique
BODY25_TO_SMPLX: dict = {
    8:  0,   # MidHip    → pelvis   (0)
    12: 1,   # LHip      → l_hip    (1)
    9:  2,   # RHip      → r_hip    (2)
    13: 4,   # LKnee     → l_knee   (4)
    10: 5,   # RKnee     → r_knee   (5)
    14: 7,   # LAnkle    → l_ankle  (7)
    11: 8,   # RAnkle    → r_ankle  (8)
    1:  12,  # Neck      → neck     (12)
    5:  16,  # LShoulder → l_shoulder (16)
    2:  17,  # RShoulder → r_shoulder (17)
    6:  18,  # LElbow    → l_elbow  (18)
    3:  19,  # RElbow    → r_elbow  (19)
    7:  20,  # LWrist    → l_wrist  (20)
    4:  21,  # RWrist    → r_wrist  (21)
    19: 10,  # LBigToe   → l_foot   (10)
    22: 11,  # RBigToe   → r_foot   (11)
}
# fmt: on


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
    # MediaPipe-33 → Body25
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _mp33_to_body25(frame_kp: np.ndarray) -> tuple:
        """
        Converts one MediaPipe frame (33, 4) to Body25 (25, 4).

        Returns:
            body25  : (25, 4) [x, y, z, conf]
            valid   : (25,)   bool mask
            weights : (25,)   float weights
        """
        body25  = np.zeros((25, 4), dtype=np.float32)
        valid   = np.zeros(25,      dtype=bool)
        weights = np.zeros(25,      dtype=np.float32)

        for b25_idx, mp_indices in MP33_TO_BODY25.items():
            pts = frame_kp[mp_indices, :3]
            vis = frame_kp[mp_indices, 3]
            ok  = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
            w   = BODY25_WEIGHTS.get(b25_idx, 0.0)
            if np.any(ok) and w > 0:
                body25[b25_idx, :3] = pts[ok].mean(axis=0)
                body25[b25_idx,  3] = vis[ok].mean()
                valid[b25_idx]      = True
                weights[b25_idx]    = w

        return body25, valid, weights

    # ──────────────────────────────────────────────────────────────────────
    # Scale estimation
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_scale(kp3d: np.ndarray) -> float:
        """
        Estimates pixel→metre scale from hip-to-neck distance (≈ 0.52 m avg).
        Returns 1.0 if estimation fails.
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
        gender:              str   = "neutral",
        n_iter:              int   = 20,
        device_str:          str   = "auto",
        max_export_frames:   int   = 9999,
    ) -> Optional[str]:
        """
        Fit SMPL-X to triangulated 3D keypoints using an EasyMocap-quality
        pipeline (Body25 format, L-BFGS optimizer, temporal param smoothing).

        Args:
            session_output_root : folder containing keypoints_3d.npy
            gender              : 'neutral' | 'male' | 'female'
            n_iter              : L-BFGS max_iter per outer step
            device_str          : 'auto' | 'cpu' | 'cuda' | 'mps'
            max_export_frames   : cap for Three.js JSON (9999 = all)

        Returns:
            Path to smplx_result.npz, or None on failure.
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
        print(f"DEBUG [SmplxService]: {num_frames} frames — Body25 / L-BFGS pipeline")

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

        # ── Auto-scale ────────────────────────────────────────────────────
        scale = SmplxService._estimate_scale(kp3d)
        if abs(scale - 1.0) > 0.01:
            kp3d[:, :, :3] *= scale
            print(f"DEBUG [SmplxService]: scale factor = {scale:.5f}")

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

        # ── Convert all frames to Body25 ──────────────────────────────────
        print("DEBUG [SmplxService]: Converting MediaPipe-33 → Body25 ...")
        body25_seq = []
        for fi in range(num_frames):
            b25, valid, wt = SmplxService._mp33_to_body25(kp3d[fi])
            body25_seq.append((b25, valid, wt))

        # ── Helper : forward pass ─────────────────────────────────────────
        def smplx_forward(betas, g_orient, b_pose, transl, verts=False):
            return body_model(
                betas=betas, global_orient=g_orient,
                body_pose=b_pose, transl=transl,
                return_verts=verts,
            )

        def compute_loss(output, target_b25, valid_b25, weights_b25, b_pose):
            """
            Loss matching EasyMocap: joint alignment + pose regularisation.
            Uses Body25 ↔ SMPL-X joint mapping.
            """
            smplx_joints = output.joints[0, :22, :]  # (22, 3)
            loss = torch.tensor(0.0, dtype=torch.float32, device=device)
            n_pairs = 0
            for b25_idx, smplx_idx in BODY25_TO_SMPLX.items():
                if not valid_b25[b25_idx]:
                    continue
                w   = float(weights_b25[b25_idx])
                tgt = torch.tensor(
                    target_b25[b25_idx, :3], dtype=torch.float32, device=device
                )
                loss = loss + w * ((smplx_joints[smplx_idx] - tgt) ** 2).sum()
                n_pairs += 1
            if n_pairs:
                loss = loss / n_pairs
            # Pose prior: L2 on body angles (EasyMocap uses w_pose=1e-3)
            loss = loss + 1e-3 * (b_pose ** 2).mean()
            return loss

        # ── Stage 1 : Shape estimation (multi-frame, EasyMocap approach) ──
        print("DEBUG [SmplxService]: Stage 1 — multi-frame shape fitting ...")

        # Collect valid frames (up to 30) well-spread across the sequence
        step_sh = max(1, num_frames // 30)
        shape_frames = [
            i for i in range(0, num_frames, step_sh)
            if sum(body25_seq[i][1]) >= 8
        ][:30]

        if not shape_frames:
            logger.error("No valid frames for shape estimation. Aborting.")
            return None

        betas    = torch.zeros(1, 10, dtype=torch.float32, device=device,
                               requires_grad=True)
        g_orient = torch.zeros(1, 3,  dtype=torch.float32, device=device,
                               requires_grad=True)
        b_pose0  = torch.zeros(1, 63, dtype=torch.float32, device=device)

        # Centring: place pelvis at mean pelvis position
        pelvis_positions = []
        for fi in shape_frames:
            b25, v, _ = body25_seq[fi]
            if v[8]:
                pelvis_positions.append(b25[8, :3])
        if pelvis_positions:
            pelvis_mean = np.mean(pelvis_positions, axis=0)
        else:
            pelvis_mean = np.array([0.0, 0.0, 0.0])
        transl = torch.tensor(
            pelvis_mean[None], dtype=torch.float32, device=device,
            requires_grad=True,
        )

        # 8-direction orientation search
        best_loss  = float("inf")
        best_orient = torch.zeros(1, 3, device=device)
        fi0 = shape_frames[0]
        b25_0, v0, w0 = body25_seq[fi0]
        with torch.no_grad():
            for ay in [0.0, np.pi/2, np.pi, 3*np.pi/2]:
                for ax in [0.0, np.pi]:
                    test_o = torch.tensor([[ax, ay, 0.0]],
                                          dtype=torch.float32, device=device)
                    out = smplx_forward(betas, test_o, b_pose0, transl)
                    loss_val = compute_loss(out, b25_0, v0, w0, b_pose0).item()
                    if loss_val < best_loss:
                        best_loss   = loss_val
                        best_orient = test_o.clone()

        g_orient = best_orient.clone().requires_grad_(True)
        print(f"DEBUG [SmplxService]: Best orient = {best_orient.tolist()}, "
              f"loss = {best_loss:.5f}")

        # L-BFGS shape + transl fit over multiple frames
        opt_shape = torch.optim.LBFGS(
            [betas, transl, g_orient], lr=1.0,
            max_iter=n_iter, line_search_fn="strong_wolfe",
        )

        def shape_closure():
            opt_shape.zero_grad()
            total = torch.tensor(0.0, dtype=torch.float32, device=device)
            for fi in shape_frames:
                b25_fi, v_fi, w_fi = body25_seq[fi]
                out = smplx_forward(betas, g_orient, b_pose0.detach(), transl)
                total = total + compute_loss(out, b25_fi, v_fi, w_fi, b_pose0)
            total = total / len(shape_frames)
            total += 5e-3 * (betas ** 2).mean()  # shape prior (EasyMocap: w_shape=5e-3)
            total.backward()
            return total

        for s in range(3):  # 3 outer L-BFGS steps
            loss_val = opt_shape.step(shape_closure)
        print(f"DEBUG [SmplxService]: Shape fit done. Loss ≈ {float(loss_val):.6f}")

        betas_fixed  = betas.detach().clone()
        init_orient  = g_orient.detach().clone()
        init_transl  = transl.detach().clone()

        # ── Stage 2 : Per-frame pose + translation (L-BFGS) ───────────────
        print("DEBUG [SmplxService]: Stage 2 — per-frame L-BFGS pose fitting ...")
        all_vertices: list = []
        all_joints:   list = []

        # Store SMPL parameters for temporal smoothing on params (not verts)
        smpl_orients: list = []
        smpl_poses:   list = []
        smpl_transls: list = []

        prev_orient = init_orient.clone()
        prev_pose   = torch.zeros(1, 63, dtype=torch.float32, device=device)
        prev_transl = init_transl.clone()

        for fi in tqdm(range(num_frames), desc="SMPL-X L-BFGS per-frame"):
            b25_fi, v_fi, w_fi = body25_seq[fi]
            n_valid = int(v_fi.sum())

            if n_valid < 4:
                # Not enough joints: reuse previous params
                smpl_orients.append(prev_orient.detach().cpu().numpy())
                smpl_poses.append(prev_pose.detach().cpu().numpy())
                smpl_transls.append(prev_transl.detach().cpu().numpy())
                if all_vertices:
                    all_vertices.append(all_vertices[-1])
                    all_joints.append(all_joints[-1])
                else:
                    with torch.no_grad():
                        out = smplx_forward(
                            betas_fixed, prev_orient, prev_pose,
                            prev_transl, verts=True,
                        )
                        all_vertices.append(out.vertices[0].cpu().numpy())
                        all_joints.append(out.joints[0, :22].cpu().numpy())
                continue

            # Warm-start from previous frame
            fr_orient = prev_orient.clone().requires_grad_(True)
            fr_pose   = prev_pose.clone().requires_grad_(True)
            fr_transl = prev_transl.clone().requires_grad_(True)

            # ── Stage 2A: rough placement (transl + orient, 1 L-BFGS step) ─
            opt_a = torch.optim.LBFGS(
                [fr_transl, fr_orient], lr=1.0,
                max_iter=n_iter, line_search_fn="strong_wolfe",
            )
            def closure_a():
                opt_a.zero_grad()
                out = smplx_forward(
                    betas_fixed, fr_orient, fr_pose.detach(), fr_transl
                )
                loss_ = compute_loss(out, b25_fi, v_fi, w_fi, fr_pose.detach())
                loss_.backward()
                return loss_
            opt_a.step(closure_a)

            # ── Stage 2B: fine pose (all params, 2 L-BFGS steps) ───────────
            fr_orient = fr_orient.detach().clone().requires_grad_(True)
            fr_transl = fr_transl.detach().clone().requires_grad_(True)

            opt_b = torch.optim.LBFGS(
                [fr_orient, fr_pose, fr_transl], lr=1.0,
                max_iter=n_iter, line_search_fn="strong_wolfe",
            )
            def closure_b():
                opt_b.zero_grad()
                out = smplx_forward(
                    betas_fixed, fr_orient, fr_pose, fr_transl
                )
                loss_ = compute_loss(out, b25_fi, v_fi, w_fi, fr_pose)
                loss_.backward()
                return loss_
            opt_b.step(closure_b)
            opt_b.step(closure_b)  # second outer step

            # Clamp to prevent gimbal lock
            with torch.no_grad():
                fr_pose.clamp_(-2 * np.pi, 2 * np.pi)

            # Store SMPL parameters (for temporal smoothing later)
            smpl_orients.append(fr_orient.detach().cpu().numpy())
            smpl_poses.append(fr_pose.detach().cpu().numpy())
            smpl_transls.append(fr_transl.detach().cpu().numpy())

            # Update warm-start
            prev_orient = fr_orient.detach().clone()
            prev_pose   = fr_pose.detach().clone()
            prev_transl = fr_transl.detach().clone()

            with torch.no_grad():
                out = smplx_forward(
                    betas_fixed, fr_orient, fr_pose, fr_transl, verts=True
                )
                all_vertices.append(out.vertices[0].cpu().numpy())
                all_joints.append(out.joints[0, :22].cpu().numpy())

        # ── Stage 3 : Temporal smoothing on SMPL PARAMETERS (EasyMocap) ───
        # EasyMocap smooths thetas/translations THEN re-runs the model.
        # This avoids mesh distortion from smoothing vertices directly.
        print("DEBUG [SmplxService]: Stage 3 — smoothing SMPL params ...")
        try:
            from scipy.ndimage import gaussian_filter1d
            sigma = 1.5
            orients_arr = gaussian_filter1d(
                np.concatenate(smpl_orients, axis=0), sigma, axis=0)   # (F, 3)
            poses_arr   = gaussian_filter1d(
                np.concatenate(smpl_poses,   axis=0), sigma, axis=0)   # (F, 63)
            transls_arr = gaussian_filter1d(
                np.concatenate(smpl_transls, axis=0), sigma, axis=0)   # (F, 3)

            print("DEBUG [SmplxService]: Re-running model with smoothed params ...")
            all_vertices = []
            all_joints   = []
            with torch.no_grad():
                for fi in tqdm(range(num_frames), desc="Re-render smoothed"):
                    out = smplx_forward(
                        betas_fixed,
                        torch.tensor(orients_arr[fi][None],
                                     dtype=torch.float32, device=device),
                        torch.tensor(poses_arr[fi][None],
                                     dtype=torch.float32, device=device),
                        torch.tensor(transls_arr[fi][None],
                                     dtype=torch.float32, device=device),
                        verts=True,
                    )
                    all_vertices.append(out.vertices[0].cpu().numpy())
                    all_joints.append(out.joints[0, :22].cpu().numpy())
        except ImportError:
            print("DEBUG [SmplxService]: scipy not available — skipping param smoothing")

        vertices_arr = np.array(all_vertices, dtype=np.float32)   # (T, 10475, 3)
        joints_arr   = np.array(all_joints,   dtype=np.float32)   # (T,    22, 3)

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
                "pipeline":        "EasyMocap-quality Body25/LBFGS",
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

    # ──────────────────────────────────────────────────────────────────────
    # (kept for compatibility)
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _smooth_keypoints(kp3d: np.ndarray, sigma: float = 1.5) -> np.ndarray:
        T, N, _ = kp3d.shape
        smoothed = kp3d.copy()
        radius = int(3 * sigma)
        x = np.arange(-radius, radius + 1)
        kernel = np.exp(-0.5 * (x / sigma) ** 2)
        kernel /= kernel.sum()
        for n in range(N):
            for c in range(3):
                pad = np.pad(kp3d[:, n, c], radius, mode="edge")
                smoothed[:, n, c] = np.convolve(pad, kernel, mode="valid")
        return smoothed
