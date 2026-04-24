import os
import json
import numpy as np
import sys
from scipy.signal import savgol_filter
import cv2


# Ajouter le backend au sys.path pour les imports
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(backend_dir)

from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService

# --- DICTIONNAIRE DE TRADUCTION DES POINTS ---
# C'est le plus gros problème de la recherche en Mocap :
# Ton algorithme actuel (MediaPipe) détecte 33 points.
# Le fichier Vérité Absolue (Fit3D) détecte 25 points.
# Pour calculer une erreur (MPJPE), on doit comparer les mêmes choses !
FIT3D_TO_MEDIAPIPE = {
    10: 0,   # Tête -> Nez
    11: 11,  # Épaule Gauche -> Épaule Gauche
    12: 13,  # Coude Gauche -> Coude Gauche
    13: 15,  # Poignet Gauche -> Poignet Gauche
    14: 12,  # Épaule Droite -> Épaule Droite
    15: 14,  # Coude Droit -> Coude Droit
    16: 16,  # Poignet Droit -> Poignet Droit
    1: 23,   # Hanche Gauche -> Hanche Gauche
    2: 25,   # Genou Gauche -> Genou Gauche
    3: 27,   # Cheville Gauche -> Cheville Gauche
    4: 24,   # Hanche Droite -> Hanche Droite
    5: 26,   # Genou Droit -> Genou Droit
    6: 28,   # Cheville Droite -> Cheville Droite
}
def triangulate_with_reproj_filter(P_list, pts_list, seuil_px=15.0):
    """Triangule puis retire les caméras dont l'erreur de reprojection > seuil_px pixels."""
    from app.pipeline.step3_3d_keypoints_service import TriangulationService
    
    # 1. Première triangulation avec toutes les caméras
    pt_3d = TriangulationService._triangulate_n_views(P_list, pts_list)
    if np.any(np.isnan(pt_3d)):
        return pt_3d
    
    # 2. Reprojection : vérifier chaque caméra
    pt_h = np.append(pt_3d, 1.0)  # Coordonnées homogènes [X,Y,Z,1]
    bonnes_cams = []
    bons_pts = []
    
    for i in range(len(P_list)):
        x2d, y2d = pts_list[i]
        if np.isnan(x2d):
            continue
        proj = P_list[i] @ pt_h
        proj_x = proj[0] / proj[2]
        proj_y = proj[1] / proj[2]
        erreur = np.sqrt((proj_x - x2d)**2 + (proj_y - y2d)**2)
        if erreur < seuil_px:
            bonnes_cams.append(P_list[i])
            bons_pts.append([x2d, y2d])
    
    # 3. Re-trianguler avec seulement les bonnes caméras
    if len(bonnes_cams) >= 2:
        return TriangulationService._triangulate_n_views(bonnes_cams, bons_pts)
    return pt_3d

def load_fit3d_gt(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
        return np.array(data['joints3d_25'])

def load_camera_matrices(camera_ids, calib_root, exercise_name="deadlift"):
    matrices = []
    K_list = []
    dist_list = []
    for cam_id in camera_ids:
        json_path = os.path.join(calib_root, cam_id, f"{exercise_name}.json")
        with open(json_path, 'r') as f:
            data = json.load(f)
        
        # Intrinsèques AVEC distorsion (car les pixels MediaPipe sont distordus)
        intr = data["intrinsics_w_distortion"]
        fx, fy = intr["f"][0]
        cx, cy = intr["c"][0]
        K = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], dtype=np.float64)
        
        k1, k2, k3 = intr["k"][0]
        p1, p2 = intr["p"][0]
        dist_coeffs = np.array([k1, k2, p1, p2, k3], dtype=np.float64)
        
        R = np.array(data["extrinsics"]["R"], dtype=np.float64)
        Camera_Center = np.array(data["extrinsics"]["T"], dtype=np.float64).reshape(3, 1)
        T = -R @ Camera_Center
        
        P = K @ np.hstack((R, T))
        matrices.append(P)
        K_list.append(K)
        dist_list.append(dist_coeffs)
    return matrices, K_list, dist_list


def run_real_evaluation():
    print("--- LANCEMENT DE L'ÉVALUATION RÉELLE DU PIPELINE (S03 SQUAT) ---")
    
    # 1. Chemins
    s03_dir = os.path.join(backend_dir, "..", "s03")
    videos_dir = os.path.join(s03_dir, "videos")
    calib_dir = os.path.join(s03_dir, "camera_parameters")
    gt_file = os.path.join(s03_dir, "joints3d_25", "squat.json")
    
    output_dir = os.path.join(backend_dir, "data", "benchmark_output")
    os.makedirs(output_dir, exist_ok=True)
    
    camera_ids = ["65906101LF", "60457274RF", "50591643Lb", "58860488RB"]
    
    # 2. Vérification Ground Truth
    if not os.path.exists(gt_file):
        print(f"❌ Fichier Ground Truth manquant : {gt_file}")
        return
        
    gt_3d = load_fit3d_gt(gt_file)
    print(f"✅ Ground truth chargé : {gt_3d.shape[0]} frames.")

    # 3. Traiter les vidéos (Extraction 2D MediaPipe)
    print("\n--- ÉTAPE 1 : Extraction IA 2D ---")
    points_2d_cameras = []
    
    for i, cam_id in enumerate(camera_ids):
        video_path = os.path.join(videos_dir, cam_id, "squat.mp4")
        out_npy = os.path.join(output_dir, f"cam_{i}_2d.npy")
        # Forcer model_complexity=2 pour plus de précision
        if not os.path.exists(out_npy):
            print(f"⏳ Traitement de la vidéo {cam_id} (cela peut prendre quelques minutes)...")
            success = PoseService.extract_keypoints_from_video(video_path, out_npy)
            if not success:
                print(f"❌ Échec de MediaPipe sur {video_path}")
                return
        else:
            print(f"✅ Points 2D déjà calculés pour {cam_id}.")
            
        points_2d_cameras.append(np.load(out_npy))
        # LISSAGE 2D AVANT TRIANGULATION
    print("🔧 Lissage 2D pre-triangulation...")
    for cam_idx in range(4):
        data_2d = points_2d_cameras[cam_idx]
        for joint_idx in range(33):
            for axis in range(2):
                signal = data_2d[:, joint_idx, axis]
                if not np.any(np.isnan(signal)):
                    data_2d[:, joint_idx, axis] = savgol_filter(signal, window_length=7, polyorder=2)
        
    # 4. Triangulation 3D personnalisée pour l'évaluation
    print("\n--- ÉTAPE 2 : Triangulation 3D ---")
    matrices, K_list, dist_list = load_camera_matrices(camera_ids, calib_dir, "deadlift")
    
    num_frames = min(gt_3d.shape[0], min(len(pts) for pts in points_2d_cameras))
    print(f"Alignement des vidéos : Analyse sur {num_frames} frames.")
    
    our_3d_predictions = []
    IMG_WIDTH, IMG_HEIGHT = 900, 900 # Résolution standard Fit3D
    
    for f_idx in range(num_frames):
        frame_3d_points = []
        for l_idx in range(33): # 33 points mediapipe
            pts_2d = []
            for cam_idx in range(4):
                kp = points_2d_cameras[cam_idx][f_idx, l_idx]
                vis = kp[3]
                if not np.isnan(kp[0]) and vis > 0.5:
                    x_pix, y_pix = kp[0] * IMG_WIDTH, kp[1] * IMG_HEIGHT
                    # Corriger la distorsion de la lentille
                    pt = np.array([[[x_pix, y_pix]]], dtype=np.float64)
                    pt_undist = cv2.undistortPoints(pt, K_list[cam_idx], dist_list[cam_idx], P=K_list[cam_idx])
                    pts_2d.append([pt_undist[0,0,0], pt_undist[0,0,1]])

                else:
                    pts_2d.append([np.nan, np.nan])
            
            pt_3d = triangulate_with_reproj_filter(matrices, pts_2d, seuil_px=15.0)
            frame_3d_points.append(pt_3d)
        our_3d_predictions.append(frame_3d_points)
        
    our_3d_predictions = np.array(our_3d_predictions)

    # LISSAGE TEMPOREL (Savitzky-Golay)
    # window_length=11 : on regarde 11 frames autour pour lisser
    # polyorder=3 : on utilise un polynôme de degré 3
    print("🔧 Application du lissage temporel Savitzky-Golay...")
    for joint_idx in range(33):
        for axis in range(3):  # X, Y, Z
            signal = our_3d_predictions[:, joint_idx, axis]
            if not np.any(np.isnan(signal)):
                our_3d_predictions[:, joint_idx, axis] = savgol_filter(signal, window_length=11, polyorder=3)

    # 5. Calcul du VRAI MPJPE (En utilisant le dictionnaire de traduction)
    print("\n--- ÉTAPE 3 : PA-MPJPE (Procrustes Aligned) ---")
    
    # Dictionnaire inversé pour extraire les points communs
    fit3d_indices = list(FIT3D_TO_MEDIAPIPE.keys())
    mp_indices = list(FIT3D_TO_MEDIAPIPE.values())
    
    erreurs_par_frame = []
    
    for f_idx in range(num_frames):
        # Extraire les 13 points communs pour cette frame
        gt_points = gt_3d[f_idx, fit3d_indices, :]
        our_points = our_3d_predictions[f_idx, mp_indices, :]
        
        # 1. Centrer les deux squelettes (soustraire la moyenne)
        gt_center = np.mean(gt_points, axis=0)
        our_center = np.mean(our_points, axis=0)
        gt_centered = gt_points - gt_center
        our_centered = our_points - our_center
        
        # 2. Trouver l'échelle optimale
        scale_gt = np.sqrt(np.sum(gt_centered ** 2))
        scale_our = np.sqrt(np.sum(our_centered ** 2))
        
        if scale_gt < 1e-6 or scale_our < 1e-6:
            continue
            
        gt_scaled = gt_centered / scale_gt
        our_scaled = our_centered / scale_our
        
        # 3. Trouver la rotation optimale (SVD)
        H = our_scaled.T @ gt_scaled
        U, S, Vt = np.linalg.svd(H)
        R_optimal = Vt.T @ U.T
        
        # Corriger les réflexions
        if np.linalg.det(R_optimal) < 0:
            Vt[-1, :] *= -1
            R_optimal = Vt.T @ U.T
        
        # 4. Appliquer la transformation complète
        our_aligned = (our_centered @ R_optimal) * (scale_gt / scale_our)
        
        # 5. Erreur par articulation
        erreur_frame = np.linalg.norm(gt_centered - our_aligned, axis=1)
        erreurs_par_frame.append(np.mean(erreur_frame))
    
    pa_mpjpe_m = np.mean(erreurs_par_frame)
    pa_mpjpe_mm = pa_mpjpe_m * 1000
    mediane_mm = np.median(erreurs_par_frame) * 1000
    
    print(f"\n================ RÉVÉLATION FINALE ===============")
    print(f"👉 PA-MPJPE MOYEN  : {pa_mpjpe_mm:.2f} mm")
    print(f"👉 PA-MPJPE MÉDIAN : {mediane_mm:.2f} mm")
    print(f"==================================================")

if __name__ == "__main__":
    run_real_evaluation()
