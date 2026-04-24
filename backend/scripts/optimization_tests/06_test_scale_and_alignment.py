import os
import json
import numpy as np
import sys

# Ajouter le backend au sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(backend_dir)

from app.pipeline.step3_3d_keypoints_service import TriangulationService

def load_camera_matrices(camera_ids, calib_root, exercise_name="squat"):
    matrices_standard = []
    matrices_center = []
    
    for cam_id in camera_ids:
        json_path = os.path.join(calib_root, cam_id, f"{exercise_name}.json")
        with open(json_path, 'r') as f:
            data = json.load(f)
            
        intrinsics = data["intrinsics_wo_distortion"]
        K = np.array([
            [intrinsics["f"][0], 0, intrinsics["c"][0]], 
            [0, intrinsics["f"][1], intrinsics["c"][1]], 
            [0, 0, 1]
        ], dtype=np.float32)
        
        R = np.array(data["extrinsics"]["R"], dtype=np.float32)
        T_raw = np.array(data["extrinsics"]["T"], dtype=np.float32).reshape(3, 1)
        
        # Hypothèse 1 : T_raw est le vecteur de translation "t" d'OpenCV
        P_standard = K @ np.hstack((R, T_raw))
        matrices_standard.append(P_standard)
        
        # Hypothèse 2 : T_raw est le centre de la caméra "C" dans le monde
        # En OpenCV, t = -R * C
        t_center = -R @ T_raw
        P_center = K @ np.hstack((R, t_center))
        matrices_center.append(P_center)
        
    return matrices_standard, matrices_center

def analyser_erreur_5_metres():
    print("--- 6. ENQUÊTE SUR L'ERREUR DE 5 MÈTRES (ALIGNEMENT & ÉCHELLE) ---\n")
    
    # On sait déjà que la résolution 900x900 est la bonne (je l'ai vérifié).
    # Le problème vient donc de la géométrie de l'espace 3D !
    
    # 1. Chemins
    s03_dir = os.path.join(backend_dir, "..", "s03")
    calib_dir = os.path.join(s03_dir, "camera_parameters")
    gt_file = os.path.join(s03_dir, "joints3d_25", "squat.json")
    output_dir = os.path.join(backend_dir, "data", "benchmark_output")
    camera_ids = ["65906101LF", "60457274RF", "50591643Lb", "58860488RB"]
    
    # 2. Charger le Ground Truth
    with open(gt_file, 'r') as f:
        gt_3d = np.array(json.load(f)['joints3d_25'])
        
    # 3. Charger les 2D (Déjà calculés, ça sera instantané !)
    points_2d_cameras = []
    for i in range(4):
        points_2d_cameras.append(np.load(os.path.join(output_dir, f"cam_{i}_2d.npy")))
        
    matrices_standard, matrices_center = load_camera_matrices(camera_ids, calib_dir, "squat")
    
    # 4. On isole UN SEUL POINT pour comprendre : Le Nez (Index 0) à la Frame 0.
    IMG_WIDTH, IMG_HEIGHT = 900, 900
    pts_2d_nez = []
    for cam_idx in range(4):
        kp = points_2d_cameras[cam_idx][0, 0] # Frame 0, Landmark 0 (Nez Mediapipe)
        pts_2d_nez.append([kp[0] * IMG_WIDTH, kp[1] * IMG_HEIGHT])
        
    nez_3d_predit_standard = TriangulationService._triangulate_n_views(matrices_standard, pts_2d_nez)
    nez_3d_predit_center = TriangulationService._triangulate_n_views(matrices_center, pts_2d_nez)
    nez_3d_vrai = gt_3d[0, 0] # Frame 0, Landmark 0 (Nez Fit3D)
    
    print("================== COMPARAISON DIRECTE ==================")
    print(f"👉 VRAI Nez (Fit3D)           : X={nez_3d_vrai[0]:.2f}, Y={nez_3d_vrai[1]:.2f}, Z={nez_3d_vrai[2]:.2f} (en mètres)")
    print(f"👉 H1: NOTRE Nez (T=t OpenCV) : X={nez_3d_predit_standard[0]:.2f}, Y={nez_3d_predit_standard[1]:.2f}, Z={nez_3d_predit_standard[2]:.2f}")
    print(f"👉 H2: NOTRE Nez (T=Centre)   : X={nez_3d_predit_center[0]:.2f}, Y={nez_3d_predit_center[1]:.2f}, Z={nez_3d_predit_center[2]:.2f}")
    
    norme_vrai = np.linalg.norm(nez_3d_vrai)
    norme_standard = np.linalg.norm(nez_3d_predit_standard)
    norme_center = np.linalg.norm(nez_3d_predit_center)
    
    print("\n================== DIAGNOSTIC DE L'IA ==================")
    print(f"Distances : Vrai={norme_vrai:.2f}m | H1={norme_standard:.2f}m | H2={norme_center:.2f}m")
    
    meilleure = "H1" if abs(norme_vrai - norme_standard) < abs(norme_vrai - norme_center) else "H2"
    print(f"\n💡 CONCLUSION : La meilleure hypothèse mathématique est {meilleure}.")
    if meilleure == "H2":
        print("Il faut modifier `TriangulationService.triangulate()` pour utiliser t = -R @ T_raw.")

if __name__ == "__main__":
    analyser_erreur_5_metres()
