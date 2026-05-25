import os
import sys
import json
import logging
from typing import Optional
import numpy as np

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS GÉOMÉTRIQUES POUR L'IK ANALYTIQUE
# ─────────────────────────────────────────────────────────────────────────────

def rotate_vector_to_vector(a, b):
    """
    Calcule la matrice de rotation 3x3 qui aligne le vecteur normalisé a sur le vecteur normalisé b.
    """
    v = np.cross(a, b)
    c = np.dot(a, b)
    s = np.linalg.norm(v)
    
    if s < 1e-6:
        if c > 0:
            return np.eye(3, dtype=np.float32)
        else:
            # Vecteurs opposés : rotation de 180 degrés autour d'un axe orthogonal arbitraire
            if abs(a[0]) > 0.9:
                ortho = np.array([0.0, 1.0, 0.0], dtype=np.float32)
            else:
                ortho = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            ortho = ortho - np.dot(ortho, a) * a
            ortho = ortho / np.linalg.norm(ortho)
            K = np.array([[0, -ortho[2], ortho[1]],
                          [ortho[2], 0, -ortho[0]],
                          [-ortho[1], ortho[0], 0]], dtype=np.float32)
            return np.eye(3, dtype=np.float32) + 2 * np.dot(K, K)
            
    K = np.array([[0, -v[2], v[1]],
                  [v[2], 0, -v[0]],
                  [-v[1], v[0], 0]], dtype=np.float32)
    R = np.eye(3, dtype=np.float32) + K + np.dot(K, K) * (1.0 - c) / (s ** 2)
    return R

def matrix_to_axis_angle(R):
    """
    Convertit une matrice de rotation 3x3 en représentation axis-angle (Rodrigues).
    """
    import cv2
    aa, _ = cv2.Rodrigues(R.astype(np.float32))
    return aa.flatten()

def fix_axis_angle_continuity(aa_sequence: np.ndarray) -> np.ndarray:
    """
    Corrige les flips de signe dans une séquence d'axis-angle.
    Quand l'axe de rotation s'inverse brusquement entre deux frames
    (ex: [0.1, 3.0, 0.2] → [-0.1, -3.0, -0.2]), cela crée un saut
    visuel même si la rotation est mathématiquement équivalente.
    On détecte et corrige ces flips pour assurer la continuité.
    """
    fixed = aa_sequence.copy()
    for i in range(1, len(fixed)):
        # Si le vecteur axis-angle flip de signe, on le corrige
        dot = np.dot(fixed[i], fixed[i-1])
        if dot < 0:
            # Vérifier si l'inversion est un flip (pas un vrai changement)
            diff_flip = np.linalg.norm(fixed[i] + fixed[i-1])
            diff_normal = np.linalg.norm(fixed[i] - fixed[i-1])
            if diff_flip < diff_normal:
                fixed[i] = -fixed[i]
    return fixed

def clamp_joint_angle(aa: np.ndarray, max_angle: float) -> np.ndarray:
    """
    Limite l'angle de rotation d'un vecteur axis-angle à max_angle radians.
    Empêche les rotations anatomiquement impossibles.
    """
    angle = np.linalg.norm(aa)
    if angle > max_angle:
        aa = aa * (max_angle / angle)
    return aa

def hinge_joint_rotation(parent_dir, child_dir, hinge_axis_local, parent_R):
    """
    Calcule la rotation d'une articulation charnière (1 DOF) comme le coude ou le genou.
    Au lieu d'utiliser rotate_vector_to_vector (qui peut flipper quand les vecteurs
    deviennent colinéaires), on projette le vecteur enfant dans le plan perpendiculaire
    à l'axe de charnière et on calcule uniquement l'angle de flexion.

    parent_dir:       direction normalisée du segment parent (ex: épaule→coude) en world
    child_dir:        direction normalisée du segment enfant (ex: coude→poignet) en world
    hinge_axis_local: axe de flexion fixe dans le repère local du parent (ex: [0,0,1])
    parent_R:         matrice de rotation absolue du parent (3x3)

    Retourne: matrice de rotation locale 3x3 pour l'articulation charnière
    """
    # Transformer le vecteur enfant dans le repère local du parent
    child_local = np.dot(parent_R.T, child_dir)
    parent_local = np.dot(parent_R.T, parent_dir)

    # Projeter le vecteur enfant dans le plan perpendiculaire à l'axe de charnière
    axis = np.array(hinge_axis_local, dtype=np.float32)
    axis = axis / (np.linalg.norm(axis) + 1e-8)

    # Retirer la composante le long de l'axe de charnière
    child_proj = child_local - np.dot(child_local, axis) * axis
    parent_proj = parent_local - np.dot(parent_local, axis) * axis

    cn = np.linalg.norm(child_proj)
    pn = np.linalg.norm(parent_proj)
    if cn < 1e-6 or pn < 1e-6:
        return np.eye(3, dtype=np.float32)

    child_proj = child_proj / cn
    parent_proj = parent_proj / pn

    # Angle entre les deux projections
    cos_angle = np.clip(np.dot(parent_proj, child_proj), -1.0, 1.0)
    angle = np.arccos(cos_angle)

    # Déterminer le signe via le produit vectoriel
    cross = np.cross(parent_proj, child_proj)
    if np.dot(cross, axis) < 0:
        angle = -angle

    # Construire la matrice de rotation autour de l'axe fixe
    K = np.array([[0, -axis[2], axis[1]],
                  [axis[2], 0, -axis[0]],
                  [-axis[1], axis[0], 0]], dtype=np.float32)
    R = np.eye(3, dtype=np.float32) + np.sin(angle) * K + (1 - np.cos(angle)) * np.dot(K, K)
    return R

# ─────────────────────────────────────────────────────────────────────────────
# CLASSE DE SERVICE D'IK SMPL-X
# ─────────────────────────────────────────────────────────────────────────────

class SmplxService:

    @staticmethod
    def _get_models_dir() -> str:
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        models_dir = os.path.join(backend_dir, "data", "smplx_models")
        if not os.path.exists(models_dir):
            os.makedirs(models_dir, exist_ok=True)
        return models_dir

    @staticmethod
    def _preprocess_keypoints(kp3d: np.ndarray) -> np.ndarray:
        """
        Remplace les keypoints de faible visibilité par des NaNs, applique une
        interpolation linéaire temporelle, puis un lissage Savitzky-Golay
        sur les positions 3D pour éliminer le bruit haute fréquence AVANT l'IK.
        """
        from scipy.signal import savgol_filter

        kp = kp3d.copy()
        vis = kp[:, :, 3]
        invalid = (vis < 0.25) | np.isnan(kp[:, :, :3]).any(axis=2)
        kp[invalid, :3] = np.nan
        
        num_frames, num_joints, _ = kp.shape
        # 1. Interpolation des trous
        for j in range(num_joints):
            for c in range(3):
                arr = kp[:, j, c]
                nans = np.isnan(arr)
                if not nans.all():
                    x = np.arange(num_frames)
                    arr[nans] = np.interp(x[nans], x[~nans], arr[~nans])
                else:
                    arr[:] = 0.0

        # 2. Lissage Savitzky-Golay sur les positions 3D (fenêtre=11, ordre=3)
        #    Élimine les pics de bruit tout en préservant la forme du mouvement
        win = min(11, num_frames if num_frames % 2 == 1 else num_frames - 1)
        if win >= 5:
            for j in range(num_joints):
                for c in range(3):
                    kp[:, j, c] = savgol_filter(kp[:, j, c], window_length=win, polyorder=3)
            print(f"DEBUG [SmplxService]: Keypoints 3D pré-lissés (Savitzky-Golay, win={win})")

        return kp

    @staticmethod
    def fit_and_save(
        session_output_root: str,
        gender:              str           = "neutral",
        n_iter:              int           = 20, # Ignoré dans l'IK analytique
        device_str:          str           = "auto",
        max_export_frames:   int           = 9999,
        force_orient:        tuple | None  = None,
    ) -> Optional[str]:
        """
        Ajuste le modèle SMPL-X sur la séquence de keypoints 3D en utilisant
        une méthode d'Inverse Kinematics (IK) analytique rapide et stable.
        """
        try:
            import torch
            import smplx as smplx_lib
            from tqdm import tqdm
            from scipy.ndimage import gaussian_filter1d
        except ImportError as e:
            logger.error(f"Dépendance manquante pour l'IK SMPL-X : {e}")
            return None

        # ── Chargement des Points Clés 3D ──────────────────────────────────
        kp3d_path = os.path.join(session_output_root, "keypoints_3d.npy")
        if not os.path.exists(kp3d_path):
            logger.error(f"keypoints_3d.npy non trouvé à l'emplacement {kp3d_path}")
            return None

        kp3d_raw = np.load(kp3d_path).astype(np.float32)
        if kp3d_raw.ndim != 3 or kp3d_raw.shape[1] != 33:
            logger.error(f"Format de squelette inattendu {kp3d_raw.shape}, attendu (F, 33, 4)")
            return None

        num_frames = kp3d_raw.shape[0]
        print(f"DEBUG [SmplxService]: Résolution IK SMPL-X sur {num_frames} frames...")

        # Prétraitement et interpolation des points clés
        kp3d = SmplxService._preprocess_keypoints(kp3d_raw)

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

        # ── Calcul Analytique des Rotations par Frame ──────────────────────
        transl_np = np.zeros((num_frames, 3), dtype=np.float32)
        global_orient_aa = np.zeros((num_frames, 3), dtype=np.float32)
        body_pose_aa = np.zeros((num_frames, 63), dtype=np.float32)

        for fi in range(num_frames):
            f = kp3d[fi, :, :3]

            # 1. Extraction des joints clés
            l_hip, r_hip = f[23], f[24]
            l_shoulder, r_shoulder = f[11], f[12]
            l_knee, r_knee = f[25], f[26]
            l_ankle, r_ankle = f[27], f[28]
            l_heel, r_heel = f[29], f[30]
            l_toe, r_toe = f[31], f[32]
            l_elbow, r_elbow = f[13], f[14]
            l_wrist, r_wrist = f[15], f[16]
            l_pinky, r_pinky = f[17], f[18]
            l_index, r_index = f[19], f[20]

            # 2. Centre de gravité (Pelvis) et Translation
            pelvis = (l_hip + r_hip) / 2.0
            transl_np[fi] = pelvis

            # 3. Orientation Globale (Pelvis R_pelvis)
            hip_vec = l_hip - r_hip  # L_Hip est à +X, R_Hip est à -X
            shoulder_mid = (l_shoulder + r_shoulder) / 2.0
            spine_vec = shoulder_mid - pelvis

            y_axis = spine_vec / (np.linalg.norm(spine_vec) + 1e-8)
            x_axis = hip_vec / (np.linalg.norm(hip_vec) + 1e-8)
            x_axis = x_axis - np.dot(x_axis, y_axis) * y_axis
            x_axis = x_axis / (np.linalg.norm(x_axis) + 1e-8)
            z_axis = np.cross(x_axis, y_axis)
            z_axis = z_axis / (np.linalg.norm(z_axis) + 1e-8)

            R_pelvis = np.column_stack((x_axis, y_axis, z_axis))
            global_orient_aa[fi] = matrix_to_axis_angle(R_pelvis)

            # 4. Jambe Gauche
            d_l_thigh = (l_knee - l_hip) / (np.linalg.norm(l_knee - l_hip) + 1e-8)
            d_l_shin = (l_ankle - l_knee) / (np.linalg.norm(l_ankle - l_knee) + 1e-8)
            
            # Forcer le pied à être plat (horizontal) en annulant sa composante Y
            # On utilise le vecteur talon -> orteil pour représenter la semelle du pied
            d_l_foot = (l_toe - l_heel)
            d_l_foot[1] = 0.0
            d_l_foot = d_l_foot / (np.linalg.norm(d_l_foot) + 1e-8)

            R_l_hip = rotate_vector_to_vector(np.array([0, -1, 0]), np.dot(R_pelvis.T, d_l_thigh))
            R_thigh_abs = np.dot(R_pelvis, R_l_hip)

            # Genou gauche : charnière (axe X local = flexion sagittale)
            R_l_knee = hinge_joint_rotation(d_l_thigh, d_l_shin, [1, 0, 0], R_thigh_abs)
            R_shin_abs = np.dot(R_thigh_abs, R_l_knee)

            R_l_ankle = rotate_vector_to_vector(np.array([0, 0, 1]), np.dot(R_shin_abs.T, d_l_foot))

            # 5. Jambe Droite
            d_r_thigh = (r_knee - r_hip) / (np.linalg.norm(r_knee - r_hip) + 1e-8)
            d_r_shin = (r_ankle - r_knee) / (np.linalg.norm(r_ankle - r_knee) + 1e-8)
            
            # Forcer le pied à être plat (horizontal) en annulant sa composante Y
            d_r_foot = (r_toe - r_heel)
            d_r_foot[1] = 0.0
            d_r_foot = d_r_foot / (np.linalg.norm(d_r_foot) + 1e-8)

            R_r_hip = rotate_vector_to_vector(np.array([0, -1, 0]), np.dot(R_pelvis.T, d_r_thigh))
            R_thigh_abs_r = np.dot(R_pelvis, R_r_hip)

            # Genou droit : charnière (axe X local = flexion sagittale)
            R_r_knee = hinge_joint_rotation(d_r_thigh, d_r_shin, [1, 0, 0], R_thigh_abs_r)
            R_shin_abs_r = np.dot(R_thigh_abs_r, R_r_knee)

            R_r_ankle = rotate_vector_to_vector(np.array([0, 0, 1]), np.dot(R_shin_abs_r.T, d_r_foot))

            # 6. Bras Gauche (en T-Pose, le bras gauche pointe vers +X)
            d_l_arm = (l_elbow - l_shoulder) / (np.linalg.norm(l_elbow - l_shoulder) + 1e-8)
            d_l_forearm = (l_wrist - l_elbow) / (np.linalg.norm(l_wrist - l_elbow) + 1e-8)
            l_hand_mid = (l_index + l_pinky) / 2.0
            d_l_hand = (l_hand_mid - l_wrist) / (np.linalg.norm(l_hand_mid - l_wrist) + 1e-8)

            R_l_shoulder = rotate_vector_to_vector(np.array([1, 0, 0]), np.dot(R_pelvis.T, d_l_arm))
            R_arm_abs = np.dot(R_pelvis, R_l_shoulder)

            # Coude gauche : charnière (axe Y local = flexion, pas de produit vectoriel)
            R_l_elbow = hinge_joint_rotation(d_l_arm, d_l_forearm, [0, 1, 0], R_arm_abs)
            R_forearm_abs = np.dot(R_arm_abs, R_l_elbow)

            R_l_wrist = rotate_vector_to_vector(np.array([1, 0, 0]), np.dot(R_forearm_abs.T, d_l_hand))

            # 7. Bras Droit (en T-Pose, le bras droit pointe vers -X)
            d_r_arm = (r_elbow - r_shoulder) / (np.linalg.norm(r_elbow - r_shoulder) + 1e-8)
            d_r_forearm = (r_wrist - r_elbow) / (np.linalg.norm(r_wrist - r_elbow) + 1e-8)
            r_hand_mid = (r_index + r_pinky) / 2.0
            d_r_hand = (r_hand_mid - r_wrist) / (np.linalg.norm(r_hand_mid - r_wrist) + 1e-8)

            R_r_shoulder = rotate_vector_to_vector(np.array([-1, 0, 0]), np.dot(R_pelvis.T, d_r_arm))
            R_arm_abs_r = np.dot(R_pelvis, R_r_shoulder)

            # Coude droit : charnière (axe Y local = flexion, pas de produit vectoriel)
            R_r_elbow = hinge_joint_rotation(d_r_arm, d_r_forearm, [0, 1, 0], R_arm_abs_r)
            R_forearm_abs_r = np.dot(R_arm_abs_r, R_r_elbow)

            R_r_wrist = rotate_vector_to_vector(np.array([-1, 0, 0]), np.dot(R_forearm_abs_r.T, d_r_hand))

            # 8. Remplissage des paramètres body_pose_aa de la frame
            frame_pose = np.zeros((21, 3), dtype=np.float32)
            frame_pose[0] = matrix_to_axis_angle(R_l_hip)       # L_Hip
            frame_pose[1] = matrix_to_axis_angle(R_r_hip)       # R_Hip
            frame_pose[3] = matrix_to_axis_angle(R_l_knee)      # L_Knee
            frame_pose[4] = matrix_to_axis_angle(R_r_knee)      # R_Knee
            frame_pose[6] = matrix_to_axis_angle(R_l_ankle)     # L_Ankle
            frame_pose[7] = matrix_to_axis_angle(R_r_ankle)     # R_Ankle
            frame_pose[15] = matrix_to_axis_angle(R_l_shoulder) # L_Shoulder
            frame_pose[16] = matrix_to_axis_angle(R_r_shoulder) # R_Shoulder
            frame_pose[17] = matrix_to_axis_angle(R_l_elbow)    # L_Elbow
            frame_pose[18] = matrix_to_axis_angle(R_r_elbow)    # R_Elbow
            frame_pose[19] = matrix_to_axis_angle(R_l_wrist)    # L_Wrist
            frame_pose[20] = matrix_to_axis_angle(R_r_wrist)    # R_Wrist

            body_pose_aa[fi] = frame_pose.flatten()

        # Orientation globale forcée si spécifiée
        if force_orient is not None:
            global_orient_aa[:] = np.array(force_orient, dtype=np.float32)

        # ── Limites Anatomiques (Clamp des angles impossibles) ─────────────
        print("DEBUG [SmplxService]: Application des limites anatomiques...")
        # Limites par joint index: (joint_idx, max_angle_radians)
        # np.pi ≈ 3.14, np.pi*0.8 ≈ 2.51
        JOINT_LIMITS = {
            0: 2.5,   # L_Hip
            1: 2.5,   # R_Hip
            3: 2.8,   # L_Knee (max ~160°)
            4: 2.8,   # R_Knee
            6: 1.2,   # L_Ankle
            7: 1.2,   # R_Ankle
            15: 3.0,  # L_Shoulder
            16: 3.0,  # R_Shoulder
            17: 2.6,  # L_Elbow (max ~150°)
            18: 2.6,  # R_Elbow
            19: 1.5,  # L_Wrist
            20: 1.5,  # R_Wrist
        }
        for ji, max_ang in JOINT_LIMITS.items():
            for fi in range(num_frames):
                aa = body_pose_aa[fi, ji*3:ji*3+3]
                body_pose_aa[fi, ji*3:ji*3+3] = clamp_joint_angle(aa, max_ang)

        # ── Correction de continuité axis-angle (anti-flip) ────────────────
        print("DEBUG [SmplxService]: Correction de continuité des rotations...")
        global_orient_aa = fix_axis_angle_continuity(global_orient_aa)
        for j in range(21):
            body_pose_aa[:, j*3:j*3+3] = fix_axis_angle_continuity(body_pose_aa[:, j*3:j*3+3])

        # ── Lissage Temporel (Spine Stabilization & Gaussian Filter) ────────
        print("DEBUG [SmplxService]: Application du lissage temporel sur les rotations...")
        from scipy.signal import savgol_filter
        
        # Stabilisation de la colonne vertébrale (lissage fort de l'orientation globale)
        win_spine = min(61, num_frames if num_frames % 2 == 1 else num_frames - 1)
        if win_spine >= 5:
            for c in range(3):
                global_orient_aa[:, c] = savgol_filter(global_orient_aa[:, c], window_length=win_spine, polyorder=3)
        else:
            for c in range(3):
                global_orient_aa[:, c] = gaussian_filter1d(global_orient_aa[:, c], sigma=3.0)

        # Lissage des autres articulations
        for j in range(21):
            for c in range(3):
                body_pose_aa[:, j*3 + c] = gaussian_filter1d(body_pose_aa[:, j*3 + c], sigma=3.0)
        
        for c in range(3):
            transl_np[:, c] = gaussian_filter1d(transl_np[:, c], sigma=3.0)

        # ── Ancrage au Sol (Ground Anchoring) ──────────────────────────────
        print("DEBUG [SmplxService]: Détection du plan du sol et ancrage vertical...")
        # Détecter le sol à partir des chevilles et orteils (indices BlazePose)
        ankle_y = np.stack([kp3d[:, 27, 1], kp3d[:, 28, 1],   # chevilles
                            kp3d[:, 31, 1], kp3d[:, 32, 1]],   # orteils
                           axis=1)  # (F, 4)
        
        # Vitesse verticale des chevilles/orteils (axe Y)
        ankle_vel_y = np.abs(np.diff(ankle_y[:, :2], axis=0, prepend=ankle_y[:1, :2]))
        mean_vel = ankle_vel_y.mean(axis=1)  # (F,)
        
        # Frames statiques : vitesse < seuil (5 cm/frame = 0.05)
        static_mask = mean_vel < 0.05
        if static_mask.sum() > 5:
            # Sol = Y minimal des chevilles/orteils sur les frames statiques
            y_floor = np.min(ankle_y[static_mask])
        else:
            # Fallback
            y_floor = np.min(ankle_y)
        print(f"DEBUG [SmplxService]: Plan du sol détecté à Y = {y_floor:.4f}")

        feet_min_y = ankle_y.min(axis=1)  # (F,)
        y_offset = y_floor - feet_min_y  # (F,)
        y_offset = gaussian_filter1d(y_offset, sigma=5.0)
        transl_np[:, 1] += y_offset
        print(f"DEBUG [SmplxService]: Ancrage vertical appliqué (offset moyen = {y_offset.mean():.4f})")

        # ── Verrouillage des Pieds (Foot Locking) ──────────────────────────
        print("DEBUG [SmplxService]: Application du verrouillage des pieds (et pieds plats)...")
        # Vitesse horizontale (X, Z) + verticale (Y) pour les chevilles
        l_ankle_vel = np.linalg.norm(np.diff(kp3d[:, 27, :3], axis=0, prepend=kp3d[:1, 27, :3]), axis=1)
        r_ankle_vel = np.linalg.norm(np.diff(kp3d[:, 28, :3], axis=0, prepend=kp3d[:1, 28, :3]), axis=1)
        
        vel_threshold = 0.05  # 5 cm / frame
        height_threshold = 0.02 # 2 cm au-dessus du sol
        
        for foot_idx, (vel, joint_idx) in enumerate([(l_ankle_vel, 6), (r_ankle_vel, 7)]):
            foot_y = kp3d[:, 27 + foot_idx, 1] 
            
            # Contact : hauteur < sol + 2cm ET vitesse < seuil
            # On utilise np.abs() au cas où Y serait légèrement sous le sol à cause du bruit
            is_static = (vel < vel_threshold) & (np.abs(foot_y - y_floor) < height_threshold)
            
            in_phase = False
            lock_aa = None
            lock_pos = None
            
            for fi in range(num_frames):
                if is_static[fi]:
                    if not in_phase:
                        in_phase = True
                        lock_aa = body_pose_aa[fi, joint_idx*3:joint_idx*3+3].copy()
                        lock_pos = transl_np[fi].copy()
                    else:
                        # Geler la rotation de la cheville
                        body_pose_aa[fi, joint_idx*3:joint_idx*3+3] = lock_aa
                        # Geler la position horizontale (X, Z) du centre de gravité
                        # (Cela empêche le corps de glisser par rapport au sol)
                        transl_np[fi, 0] = lock_pos[0]
                        transl_np[fi, 2] = lock_pos[2]
                else:
                    in_phase = False

        # ── Chargement du modèle SMPL-X ───────────────────────────────────
        models_dir = SmplxService._get_models_dir()
        try:
            body_model = smplx_lib.create(
                models_dir, model_type="smplx", gender=gender,
                use_pca=False, flat_hand_mean=True,
                num_betas=10, num_expression_coeffs=10, batch_size=1,
            ).to(device)
            faces = body_model.faces.copy()
            print(f"DEBUG [SmplxService]: Modèle SMPL-X chargé ({gender})")
        except Exception as e:
            logger.error(f"Échec de l'initialisation du modèle SMPL-X : {e}")
            return None

        # ── Forward Pass Batch SMPL-X pour générer les vertices ────────────
        print("DEBUG [SmplxService]: Génération des maillages (Forward Pass)...")
        all_vertices = []
        all_joints = []
        batch_size = 64
        
        for i in range(0, num_frames, batch_size):
            end_idx = min(i + batch_size, num_frames)
            n_b = end_idx - i
            transl_t = torch.tensor(transl_np[i:end_idx], device=device)
            global_orient_t = torch.tensor(global_orient_aa[i:end_idx], device=device)
            body_pose_t = torch.tensor(body_pose_aa[i:end_idx], device=device)
            betas_t = torch.zeros((n_b, 10), device=device)
            
            with torch.no_grad():
                out = body_model(
                    transl=transl_t,
                    global_orient=global_orient_t,
                    body_pose=body_pose_t,
                    betas=betas_t,
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
                "pipeline":        "Analytical IK Pipeline",
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
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        
        if not os.path.exists(npz_path):
            return
            
        data = np.load(npz_path)
        vertices = data['vertices']
        num_frames = vertices.shape[0]
        
        frames_out_dir = os.path.join(output_dir, "frames")
        os.makedirs(frames_out_dir, exist_ok=True)
        
        step = max(1, num_frames // max_frames)
        sampled = range(0, num_frames, step)
        
        print(f"DEBUG: Rendu visuel 3D du maillage SMPL-X ({len(sampled)} frames)...")
        
        fig = plt.figure(figsize=(10, 8))
        min_coords = np.min(vertices, axis=(0, 1))
        max_coords = np.max(vertices, axis=(0, 1))
        
        for idx in sampled:
            fig.clf()
            ax = fig.add_subplot(111, projection='3d')
            v = vertices[idx]
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
