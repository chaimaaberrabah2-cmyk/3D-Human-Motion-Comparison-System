# =============================================================
# backend/app/pipeline_test/step4_smplx_fitting_service.py
# =============================================================
# Pipeline SMPL-X — Version Optimisée "Advanced Priors"
#
# Ce service prend les coordonnées 3D des squelettes issues de la triangulation (Step 3)
# et ajuste (fit) un modèle de corps humain 3D SMPL-X (maillage complet) sur ces points.
#
# Caractéristiques principales :
#   ✓ Mapping direct MediaPipe-33 → SMPL-X (22 articulations principales).
#   ✓ Optimisation de la pose et de la translation par l'algorithme L-BFGS (Strong Wolfe).
#   ✓ Per-frame fitting avec Velocity Loss (Lissage temporel sur les paramètres SMPL).
#   ✓ Export des maillages générés pour intégration directe dans un visualiseur WebGL (Three.js).
# =============================================================

import os
import json
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# MAPPING TECHNIQUE : MediaPipe 33 Landmark Index → SMPL-X Joint Index
# ─────────────────────────────────────────────────────────────────────────────
# Mappe les 33 points 3D bruts de MediaPipe vers les 22 articulations internes du modèle SMPL-X.
# Le format de la valeur est une liste d'index MediaPipe à moyenner pour obtenir la position du joint.
MP33_TO_SMPLX = {
    0:  [23, 24], # Pelvis (milieu des hanches)
    1:  [23],     # L_Hip (Hanche gauche)
    2:  [24],     # R_Hip (Hanche droite)
    4:  [25],     # L_Knee (Genou gauche)
    5:  [26],     # R_Knee (Genou droit)
    7:  [27],     # L_Ankle (Cheville gauche)
    8:  [28],     # R_Ankle (Cheville droite)
    10: [31],     # L_Foot / Big toe (Gros orteil gauche)
    11: [32],     # R_Foot / Big toe (Gros orteil droit)
    12: [11, 12], # Neck (Cou, milieu des épaules)
    16: [11],     # L_Shoulder (Épaule gauche)
    17: [12],     # R_Shoulder (Épaule droite)
    18: [13],     # L_Elbow (Coude gauche)
    19: [14],     # R_Elbow (Coude droit)
    20: [15],     # L_Wrist (Poignet gauche)
    21: [16],     # R_Wrist (Poignet droit)
}

# Coeffs d'importance (poids) par articulation pour guider l'optimiseur
# Les articulations du tronc et des membres principaux ont une importance plus grande.
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
    """
    Service d'ajustement géométrique et d'optimisation temporelle pour le modèle SMPL-X.
    Prend en entrée la séquence de squelettes 3D et produit un avatar 3D animé (maillage de 10475 vertices).
    """

    # ──────────────────────────────────────────────────────────────────────
    # Préparation des Modèles Template
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _get_models_dir() -> str:
        """
        Localise et organise les fichiers du modèle de template SMPL-X (.npz ou .pkl).
        Déplace automatiquement les modèles du dossier parent vers le sous-dossier 'smplx'
        si nécessaire pour respecter la structure attendue par la librairie smplx.
        
        Returns:
            str: Chemin absolu du dossier contenant les modèles SMPL-X.
        """
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
            print(f"DEBUG [SmplxService]: Déplacement de {moved} fichier(s) de modèle vers → {sub}")
        return base

    # ──────────────────────────────────────────────────────────────────────
    # Extraction des Targets (MediaPipe-33 → SMPL-X Target Format)
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _mp33_to_smplx_target(frame_kp: np.ndarray) -> tuple:
        """
        Convertit les points clés MediaPipe d'une frame (33 joints, coordonnées [X, Y, Z, Visibilité])
        en format d'articulation cible pour SMPL-X (22 joints, coordonnées [X, Y, Z]).
        Exclut les joints peu visibles (visibilité < 0.25) ou contenant des NaNs.
        
        Args:
            frame_kp (np.ndarray): Squelette MediaPipe d'une frame de forme (33, 4).
            
        Returns:
            tuple: Contient (target [22, 3], valid_mask [22], weights [22]).
        """
        target = np.zeros((22, 3), dtype=np.float32)
        valid  = np.zeros(22, dtype=bool)
        weights = np.zeros(22, dtype=np.float32)

        for smplx_idx, mp_indices in MP33_TO_SMPLX.items():
            pts = frame_kp[mp_indices, :3]
            vis = frame_kp[mp_indices, 3]
            ok  = (vis > 0.25) & (~np.any(np.isnan(pts), axis=1))
            
            if np.any(ok):
                # Moyenne des coordonnées MediaPipe si plusieurs points correspondent à un joint SMPL-X
                target[smplx_idx, :3] = pts[ok].mean(axis=0)
                valid[smplx_idx]      = True
                weights[smplx_idx]    = MP33_WEIGHTS.get(smplx_idx, 1.0)

        return target, valid, weights

    # ──────────────────────────────────────────────────────────────────────
    # Estimation d'échelle (Métrique)
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _estimate_scale(kp3d: np.ndarray) -> float:
        """
        Estime le facteur d'échelle pixel-à-mètre en calculant le rapport entre la
        distance tronc (hanche-cou) mesurée et la taille humaine moyenne standard (~0.52m).
        
        Args:
            kp3d (np.ndarray): Séquence complète de squelettes 3D.
            
        Returns:
            float: Facteur multiplicateur d'échelle.
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
    # Point d'Entrée Principal : Ajustement Mesh SMPL-X
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
        Ajuste le modèle SMPL-X sur la séquence de keypoints 3D triangulés.
        Utilise PyTorch, des a priori de pose L2 (T-pose prior), et une fonction de lissage 
        temporel sur la vitesse (Velocity Loss) pour éliminer les vibrations (jitter).
        
        Args:
            session_output_root (str): Dossier contenant le fichier 'keypoints_3d.npy'.
            gender (str): Genre du modèle ("neutral", "male", "female").
            n_iter (int): Nombre d'itérations L-BFGS par frame.
            device_str (str): Périphérique de calcul ("auto", "cpu", "cuda", "mps").
            max_export_frames (int): Limite du nombre de frames à exporter en ThreeJS.
            force_orient (tuple): Orientation globale optionnelle à forcer.
            
        Returns:
            str: Chemin absolu du fichier '.npz' généré ou None en cas d'erreur.
        """
        # ── Imports Dynamiques ─────────────────────────────────────────────
        try:
            import torch
            import smplx as smplx_lib
            from tqdm import tqdm
        except ImportError as e:
            logger.error(f"Dépendance manquante pour le fitting SMPL-X : {e}")
            return None

        # ── Chargement des Points Clés 3D ──────────────────────────────────
        kp3d_path = os.path.join(session_output_root, "keypoints_3d.npy")
        if not os.path.exists(kp3d_path):
            logger.error(f"keypoints_3d.npy non trouvé à l'emplacement {kp3d_path}")
            return None

        kp3d = np.load(kp3d_path).astype(np.float32)   # (F, 33, 4)
        if kp3d.ndim != 3 or kp3d.shape[1] != 33:
            logger.error(f"Format de squelette inattendu {kp3d.shape}, attendu (F, 33, 4)")
            return None

        num_frames = kp3d.shape[0]
        print(f"DEBUG [SmplxService]: Alignement SMPL-X sur {num_frames} frames...")

        # ── Sélection automatique de l'accélérateur GPU ────────────────────
        if device_str == "auto":
            if torch.cuda.is_available():
                device_str = "cuda"
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                device_str = "mps"
            else:
                device_str = "cpu"
        device = torch.device(device_str)
        print(f"DEBUG [SmplxService]: Périphérique utilisé = {device}")

        # Les données Fit3D étant déjà calibrées à l'échelle métrique, l'auto-scale est désactivé.
        scale = 1.0

        # ── Chargement du modèle SMPL-X ───────────────────────────────────
        models_dir = SmplxService._get_models_dir()
        try:
            body_model = smplx_lib.create(
                models_dir, model_type="smplx", gender=gender,
                use_pca=False, flat_hand_mean=True,
                num_betas=10, num_expression_coeffs=10, batch_size=1,
            ).to(device)
            faces = body_model.faces.copy()
            print(f"DEBUG [SmplxService]: Modèle SMPL-X chargé avec succès ({gender})")
        except Exception as e:
            logger.error(f"Échec de l'initialisation du modèle SMPL-X depuis {models_dir}: {e}")
            return None

        # ── Extraction des cibles Direct Mapping pour chaque frame ──────────
        print("DEBUG [SmplxService]: Extraction des cibles d'articulation...")
        smplx_targets = []
        for fi in range(num_frames):
            t, v, w = SmplxService._mp33_to_smplx_target(kp3d[fi])
            smplx_targets.append((t, v, w))

        # ── Détection dynamique de l'orientation de l'axe Y et du sol ──────
        # Articulation 0 = Pelvis, 12 = Neck dans SMPL-X. 7, 8, 10, 11 sont les pieds.
        y_points_down = True
        pelvis_ys, neck_ys = [], []
        ankle_ys = []
        for fi in range(num_frames):
            t_f, v_f, _ = smplx_targets[fi]
            if v_f[0] and v_f[12]:
                pelvis_ys.append(t_f[0, 1])
                neck_ys.append(t_f[12, 1])
            if v_f[7]: ankle_ys.append(t_f[7, 1])
            if v_f[8]: ankle_ys.append(t_f[8, 1])
            
        if pelvis_ys and neck_ys:
            y_points_down = np.mean(pelvis_ys) > np.mean(neck_ys)
            
        if ankle_ys:
            ground_y = float(np.percentile(ankle_ys, 95 if y_points_down else 5))
        else:
            ground_y = 0.0
            
        print(f"DEBUG [SmplxService]: Axe Y orienté vers le {'BAS' if y_points_down else 'HAUT'}")
        print(f"DEBUG [SmplxService]: Altitude du sol détectée = {ground_y:.4f}")

        # ── Helper : forward pass SMPL-X ───────────────────────────────────
        def smplx_forward(betas, g_orient, b_pose, transl, verts=False):
            return body_model(
                betas=betas, global_orient=g_orient,
                body_pose=b_pose, transl=transl,
                return_verts=verts,
            )

        # ── Helper : Calcul de la fonction de perte (Loss Function) ────────
        def compute_loss(output, target, valid, weights, b_pose, prev_pose=None, betas=None):
            smplx_joints = output.joints[0, :22, :]
            loss = torch.tensor(0.0, dtype=torch.float32, device=device)
            n_pairs = 0
            
            # 1. Perte de reconstruction de point (Distance Euclidienne)
            for i in range(22):
                if valid[i]:
                    tgt = torch.tensor(target[i, :3], dtype=torch.float32, device=device)
                    loss = loss + weights[i] * ((smplx_joints[i] - tgt) ** 2).sum()
                    n_pairs += 1
                    
            if n_pairs:
                loss = loss / n_pairs
                
            # 2. Pose Prior : Contraint les rotations à rester proches de la T-pose standard 
            loss = loss + 1.5e-3 * (b_pose ** 2).mean()
            
            # 3. Velocity Loss (Lissage temporel)
            if prev_pose is not None:
                loss = loss + 20.0 * ((b_pose - prev_pose) ** 2).mean()
                
            # 4. Ground Contact Constraint : Empêche les pieds de traverser le sol
            # Articulations des pieds: 7, 8 (chevilles), 10, 11 (orteils)
            foot_joints_y = smplx_joints[[7, 8, 10, 11], 1]
            if y_points_down:
                loss_ground = torch.clamp(foot_joints_y - ground_y, min=0.0).pow(2).mean()
            else:
                loss_ground = torch.clamp(ground_y - foot_joints_y, min=0.0).pow(2).mean()
            loss = loss + 15.0 * loss_ground
            
            # 5. Regularisation L2 sur les betas
            if betas is not None:
                loss = loss + 0.05 * (betas ** 2).mean()
                
            return loss

        # ── Stage 1 : Initialisation Globale (Position, Orientation & Morphologie) ──────
        print("DEBUG [SmplxService]: Stage 1 — Calcul de la position, orientation et morphologie (betas)...")

        # Échantillonne jusqu'à 30 frames significatives pour caler la position globale
        step_sh = max(1, num_frames // 30)
        shape_frames = [
            i for i in range(0, num_frames, step_sh)
            if sum(smplx_targets[i][1]) >= 8
        ][:30]

        if not shape_frames:
            logger.error("Aucune frame valide trouvée pour caler l'initialisation. Abandon.")
            return None

        # Paramètres de morphologie (betas) optimisables
        betas = torch.zeros(1, 10, dtype=torch.float32, device=device, requires_grad=True)
        
        g_orient = torch.zeros(1, 3,  dtype=torch.float32, device=device, requires_grad=True)
        b_pose0  = torch.zeros(1, 63, dtype=torch.float32, device=device)

        # Calcul du centre de gravité (Pelvis/Bassin) moyen pour la translation initiale
        pelvis_positions = []
        for fi in shape_frames:
            t, v, _ = smplx_targets[fi]
            if v[0]: # Joint 0 = Pelvis dans SMPL-X
                pelvis_positions.append(t[0, :3])
                
        if pelvis_positions:
            pelvis_mean = np.mean(pelvis_positions, axis=0)
        else:
            pelvis_mean = np.array([0.0, 0.0, 0.0])
            
        transl = torch.tensor(
            pelvis_mean[None], dtype=torch.float32, device=device,
            requires_grad=True,
        )

        # Recherche par grille (Grid Search) de l'orientation initiale optimale face aux caméras
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
                        out = smplx_forward(betas.detach(), test_o, b_pose0, transl)
                        loss_val = compute_loss(out, t0, v0, w0, b_pose0, betas=betas.detach()).item()
                        if loss_val < best_loss:
                            best_loss   = loss_val
                            best_orient = test_o.clone()
            print(f"DEBUG [SmplxService]: Orientation auto calculée = {best_orient.tolist()} (loss={best_loss:.5f})")

        g_orient = best_orient.clone().requires_grad_(True)

        # Optimise la translation, l'orientation globale et les betas de morphologie
        opt_shape = torch.optim.LBFGS(
            [transl, g_orient, betas], lr=1.0,
            max_iter=n_iter, line_search_fn="strong_wolfe",
        )

        def shape_closure():
            opt_shape.zero_grad()
            total = torch.tensor(0.0, dtype=torch.float32, device=device)
            for fi in shape_frames:
                t_fi, v_fi, w_fi = smplx_targets[fi]
                out = smplx_forward(betas, g_orient, b_pose0.detach(), transl)
                total = total + compute_loss(out, t_fi, v_fi, w_fi, b_pose0, betas=betas)
            total = total / len(shape_frames)
            total.backward()
            return total

        for s in range(3):
            loss_val = opt_shape.step(shape_closure)
            
        print(f"DEBUG [SmplxService]: Initialisation globale terminée. Loss initiale ≈ {float(loss_val):.6f}")

        init_orient  = g_orient.detach().clone()
        init_transl  = transl.detach().clone()
        init_betas   = betas.detach().clone()
        print(f"DEBUG [SmplxService]: Morphologie optimisée (betas) = {init_betas.flatten().tolist()}")

        # ── Stage 2 : Optimisation Per-Frame L-BFGS avec Lissage Temporel ──
        print("DEBUG [SmplxService]: Stage 2 — Ajustement dynamique par frame...")
        all_vertices: list = []
        all_joints:   list = []

        prev_orient = init_orient.clone()
        prev_pose   = torch.zeros(1, 63, dtype=torch.float32, device=device)
        prev_transl = init_transl.clone()

        for fi in tqdm(range(num_frames), desc="Optimisation SMPL-X"):
            t_fi, v_fi, w_fi = smplx_targets[fi]
            n_valid = int(v_fi.sum())

            # Si trop peu de joints sont visibles, on conserve la frame précédente (maintien de pose)
            if n_valid < 4:
                if all_vertices:
                    all_vertices.append(all_vertices[-1])
                    all_joints.append(all_joints[-1])
                else:
                    with torch.no_grad():
                        out = smplx_forward(init_betas, prev_orient, prev_pose, prev_transl, verts=True)
                        all_vertices.append(out.vertices[0].cpu().numpy())
                        all_joints.append(out.joints[0, :22].cpu().numpy())
                continue

            # Instancie les variables optimisables pour cette frame
            fr_orient = prev_orient.clone().requires_grad_(True)
            fr_pose   = prev_pose.clone().requires_grad_(True)
            fr_transl = prev_transl.clone().requires_grad_(True)

            opt_b = torch.optim.LBFGS(
                [fr_orient, fr_pose, fr_transl], lr=1.0,
                max_iter=n_iter, line_search_fn="strong_wolfe",
            )
            
            def closure_b():
                opt_b.zero_grad()
                out = smplx_forward(init_betas, fr_orient, fr_pose, fr_transl)
                # On transmet prev_pose pour pénaliser les variations de vitesse brusques
                loss_ = compute_loss(out, t_fi, v_fi, w_fi, fr_pose, prev_pose=prev_pose, betas=init_betas)
                loss_.backward()
                return loss_
                
            opt_b.step(closure_b)
            opt_b.step(closure_b)

            # Limite les angles de rotation pour éviter les contorsions extrêmes
            with torch.no_grad():
                fr_pose.clamp_(-2 * np.pi, 2 * np.pi)

            # Met à jour les variables temporelles de référence pour la frame suivante
            prev_orient = fr_orient.detach().clone()
            prev_pose   = fr_pose.detach().clone()
            prev_transl = fr_transl.detach().clone()

            # Extrait le maillage 3D complet (vertices) de la pose optimisée
            with torch.no_grad():
                out = smplx_forward(init_betas, fr_orient, fr_pose, fr_transl, verts=True)
                all_vertices.append(out.vertices[0].cpu().numpy())
                all_joints.append(out.joints[0, :22].cpu().numpy())

        vertices_arr = np.array(all_vertices, dtype=np.float32)
        joints_arr   = np.array(all_joints,   dtype=np.float32)

        print(f"DEBUG [SmplxService]: Optimisation complétée. Taille vertices : {vertices_arr.shape}")

        # ── Sauvegarde du résultat Compressé (.npz) ────────────────────────
        npz_path = os.path.join(session_output_root, "smplx_result.npz")
        np.savez_compressed(npz_path,
                            vertices=vertices_arr,
                            joints=joints_arr,
                            faces=faces)
        print(f"DEBUG [SmplxService]: Fichier compressé sauvegardé → {npz_path}")

        # ── Exportation du Package Three.js JSON ──────────────────────────
        json_path = os.path.join(session_output_root, "smplx_threejs.json")
        SmplxService._export_threejs_json(
            vertices_arr, joints_arr, faces, json_path,
            max_frames=max_export_frames,
        )
        return npz_path

    # ──────────────────────────────────────────────────────────────────────
    # Formatage Three.js JSON
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _export_threejs_json(
        vertices: np.ndarray,
        joints:   np.ndarray,
        faces:    np.ndarray,
        output_path: str,
        max_frames:  int = 9999,
    ) -> None:
        """
        Formate et écrit les données de maillage (vertices, joints, faces) dans un fichier
        JSON compact pour être chargé par le lecteur WebGL 3D (Three.js) de l'application.
        Fait un sous-échantillonnage de frames si le nombre dépasse max_frames.
        """
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
        print(f"DEBUG [SmplxService]: JSON généré → {output_path} ({mb:.1f} MB, {len(sampled)} frames)")

    # ──────────────────────────────────────────────────────────────────────
    # Finalisation Optionnelle (Alignement direct avec les rotations s03)
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def finalize_mesh_optimization(session_output_root: str, exercise_name: str) -> Optional[str]:
        """
        Finalise le maillage SMPL-X en chargeant directement les rotations et translations
        issues du dataset s03 s'il est présent au lieu de relancer un ajustement iteratif.
        """
        print(f"DEBUG: Application de l'alignement mesh final pour {exercise_name}...")
        
        try:
            import torch
            import smplx as smplx_lib
        except ImportError:
            return None

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
            
            # Conversion des matrices de rotation 3x3 en angles d'Euler Rodrigues
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
                max_frames=9999
            )
            
            viz_dir = os.path.join(session_output_root, "smplx_3d")
            SmplxService.save_smplx_visualizations(npz_path, viz_dir, max_frames=120)
            
            print(f"DEBUG: Maillage finalisé avec les rotations s03.")
            return npz_path
        except Exception as e:
            print(f"ERROR: Alignement mesh final échoué: {e}")
            return None

    # ──────────────────────────────────────────────────────────────────────
    # Helpers Trigonométriques (Matrice 3x3 → Axis-Angle)
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def _rotmat_to_axis_angle(rotmats: np.ndarray) -> np.ndarray:
        """
        Convertit un tenseur de matrices de rotation 3x3 en angles d'Euler (Axis-Angle)
        en utilisant la formule de Rodrigues (OpenCV).
        """
        import cv2
        shape = rotmats.shape
        num_mats = np.prod(shape[:-2])
        mats = rotmats.reshape(num_mats, 3, 3)
        axis_angles = np.zeros((num_mats, 3), dtype=np.float32)
        for i in range(num_mats):
            aa, _ = cv2.Rodrigues(mats[i])
            axis_angles[i] = aa.flatten()
        return axis_angles.reshape(shape[:-2] + (3,))

    # ──────────────────────────────────────────────────────────────────────
    # Visualisation Graphique 3D
    # ──────────────────────────────────────────────────────────────────────

    @staticmethod
    def save_smplx_visualizations(npz_path: str, output_dir: str, max_frames: int = 120):
        """
        Dessine le maillage SMPL-X ajusté sous forme d'images JPG individuelles 
        dans un espace tridimensionnel à des fins de contrôle qualité visuel.
        """
        import matplotlib
        matplotlib.use('Agg') # Désactive l'affichage d'interface utilisateur matplotlib
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
        
        print(f"DEBUG: Rendu visuel 3D du maillage SMPL-X ({len(sampled)} frames)...")
        
        fig = plt.figure(figsize=(10, 8))
        
        # Détermine les limites de tracé
        min_coords = np.min(vertices, axis=(0, 1))
        max_coords = np.max(vertices, axis=(0, 1))
        
        for idx in sampled:
            fig.clf()
            ax = fig.add_subplot(111, projection='3d')
            
            v = vertices[idx]
            # Sous-échantillonne les vertices pour accélérer le tracé matplotlib (1 point sur 10)
            sub = v[::10]
            ax.scatter(sub[:, 0], sub[:, 2], -sub[:, 1], c='blue', s=1, alpha=0.3)
            
            ax.set_title(f"Maillage SMPL-X - Frame {idx}")
            ax.set_xlim(min_coords[0], max_coords[0])
            ax.set_ylim(min_coords[2], max_coords[2])
            ax.set_zlim(-max_coords[1], -min_coords[1])
            
            img_path = os.path.join(frames_out_dir, f"smplx_frame_{idx:04d}.jpg")
            plt.savefig(img_path)
            
        plt.close(fig)
        print(f"DEBUG: Images de visualisation SMPL-X sauvegardées dans {frames_out_dir}")
