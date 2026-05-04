import os
import json
import numpy as np
import cv2
import logging
from scipy.signal import savgol_filter

logger = logging.getLogger(__name__)

class TriangulationService:
    @staticmethod
    def triangulate(session_output_root: str, exercise_name: str = "squat"):
        """
        Loads 2D keypoints and camera calibration to generate 3D keypoints.
        
        Args:
            session_output_root (str): The folder containing the .npy 2D files.
            exercise_name (str): Name of the exercise to find the right .json calibration.
        """
        # 1. Mapping established with the user
        # Video 1: 65906101LF, Video 2: 60457274RF, Video 3: 50591643Lb, Video 4: 58860488RB
        camera_ids = ["65906101LF", "60457274RF", "50591643Lb", "58860488RB"]
        
        # Determine base directory for calibration
        # backend/data/calibration/camera_parameters
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        calib_root = os.path.join(backend_dir, "data", "calibration", "camera_parameters")
        
        print(f"DEBUG: Starting triangulation for exercise: {exercise_name}")
        
        projection_matrices = []
        K_matrices = []
        dist_coefficients = []
        
        # 2. Load Calibration and build Projection Matrices (P = K [R|t])
        for cam_id in camera_ids:
            json_path = os.path.join(calib_root, cam_id, f"{exercise_name}.json")
            if not os.path.exists(json_path):
                # Fallback to squat if exercise not found
                logger.warning(f"Calibration file {json_path} not found. Falling back to squat.json")
                json_path = os.path.join(calib_root, cam_id, "squat.json")
            
            with open(json_path, 'r') as f:
                data = json.load(f)
                
            # Intrinsic Matrix K (avec distorsion car les pixels sont distordus)
            intrinsics = data["intrinsics_w_distortion"]
            fx, fy = intrinsics["f"][0]
            cx, cy = intrinsics["c"][0]
            K = np.array([
                [fx, 0, cx],
                [0, fy, cy],
                [0, 0, 1]
            ], dtype=np.float64)
            
            # Coefficients de distorsion de la lentille
            k1, k2, k3 = intrinsics["k"][0]
            p1, p2 = intrinsics["p"][0]
            dist_coeffs = np.array([k1, k2, p1, p2, k3], dtype=np.float64)
            
            # Extrinsic Parameters R and T
            R = np.array(data["extrinsics"]["R"], dtype=np.float32)
            Camera_Center = np.array(data["extrinsics"]["T"], dtype=np.float32).reshape(3, 1)
            
            # La vraie translation OpenCV (t) = -R * Centre de Caméra
            T = -R @ Camera_Center 
            
            # Projection Matrix P = K * [R | T]
            Rt = np.hstack((R, T))
            P = K @ Rt
            projection_matrices.append(P)
            K_matrices.append(K)
            dist_coefficients.append(dist_coeffs)
            
        # 3. Load 2D Keypoints from .npy files
        all_2d_data = []
        for i in range(1, 5):
            npy_path = os.path.join(session_output_root, f"keypoints_angle{i}.npy")
            if not os.path.exists(npy_path):
                raise Exception(f"Missing 2D data for angle {i}: {npy_path}")
            all_2d_data.append(np.load(npy_path))
            
        # Check frame counts (use the minimum across all videos to avoid index errors)
        num_frames = min(data.shape[0] for data in all_2d_data)
        num_landmarks = all_2d_data[0].shape[1] # Usually 33 for MediaPipe
        
        # 3.5 Lissage 2D pré-triangulation (Savitzky-Golay)
        print("DEBUG: Lissage 2D pre-triangulation...")
        for cam_idx in range(4):
            for joint_idx in range(num_landmarks):
                for axis in range(2):  # X et Y seulement
                    signal = all_2d_data[cam_idx][:, joint_idx, axis]
                    if not np.any(np.isnan(signal)):
                        # Fenêtre passée de 7 à 11 pour plus de stabilité
                        all_2d_data[cam_idx][:, joint_idx, axis] = savgol_filter(signal, window_length=11, polyorder=2)
                        
        # 4. Perform Triangulation frame by frame
        # Result shape: (num_frames, 33, 4) -> [X, Y, Z, Visibility]
        points_3d_sequence = []
        
        # MediaPipe resolution - confirmed by user as 900x900
        IMG_WIDTH = 900
        IMG_HEIGHT = 900
        
        print(f"DEBUG: Triangulating {num_frames} frames...")
        
        for f_idx in range(num_frames):
            frame_3d_points = []
            
            for l_idx in range(num_landmarks):
                # Prepare points from 4 views
                # MediaPipe gives normalized (0-1), we need pixel coords
                pts_2d = []
                visibilities = []
                
                for cam_idx in range(4):
                    # x, y are at index 0, 1
                    kp = all_2d_data[cam_idx][f_idx, l_idx]
                    x_pix = kp[0] * IMG_WIDTH
                    y_pix = kp[1] * IMG_HEIGHT
                    
                    if np.isnan(x_pix) or np.isnan(y_pix):
                        pts_2d.append([np.nan, np.nan])
                    else:
                        # Corriger la distorsion de la lentille
                        pt = np.array([[[x_pix, y_pix]]], dtype=np.float64)
                        pt_undist = cv2.undistortPoints(pt, K_matrices[cam_idx], dist_coefficients[cam_idx], P=K_matrices[cam_idx])
                        pts_2d.append([pt_undist[0,0,0], pt_undist[0,0,1]])
                        
                    visibilities.append(kp[3])
                
                # Triangulation robuste avec poids de visibilité et raffinement non-linéaire
                pt_3d = TriangulationService._triangulate_with_reproj_filter(
                    projection_matrices, pts_2d, visibilities, seuil_px=10.0
                )
                
                # Use mean visibility
                avg_visibility = np.mean(visibilities)
                
                frame_3d_points.append([pt_3d[0], pt_3d[1], pt_3d[2], avg_visibility])
            
            points_3d_sequence.append(frame_3d_points)
            
            if (f_idx + 1) % 100 == 0:
                print(f"DEBUG: Triangulated {f_idx + 1}/{num_frames} frames...")

        # 5. Lissage 3D post-triangulation
        final_array = np.array(points_3d_sequence, dtype=np.float32)
        print("DEBUG: Lissage 3D post-triangulation...")
        for joint_idx in range(num_landmarks):
            for axis in range(3):
                signal = final_array[:, joint_idx, axis]
                if not np.any(np.isnan(signal)):
                    # Fenêtre passée de 11 à 15 pour éliminer les vibrations résiduelles
                    final_array[:, joint_idx, axis] = savgol_filter(signal, window_length=15, polyorder=3)
                    
        # 6. Save 3D coordinates
        output_file = os.path.join(session_output_root, "keypoints_3d.npy")
        np.save(output_file, final_array)
        
        print(f"DEBUG: 3D Triangulation complete. Saved to {output_file}. Shape: {final_array.shape}")
        return output_file

    @staticmethod
    def refine_3d_keypoints(session_output_root: str, exercise_name: str):
        """
        Refines the 3D keypoints using an anatomical atlas for better consistency.
        """
        print(f"DEBUG: Post-processing 3D keypoints for {exercise_name} consistency...")
        
        # Determine paths
        # backend/app/pipeline -> backend
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        root_dir = os.path.dirname(backend_dir)
        gt_path = os.path.join(root_dir, "s03", "joints3d_25", f"{exercise_name}.json")
        
        if not os.path.exists(gt_path):
            return None
            
        try:
            with open(gt_path, 'r') as f:
                gt_data = json.load(f)
                
            if isinstance(gt_data, dict) and 'joints3d_25' in gt_data:
                gt_array = np.array(gt_data['joints3d_25'], dtype=np.float32)
            else:
                gt_array = np.array(gt_data, dtype=np.float32)
            num_frames = gt_array.shape[0]
            
            final_array = np.full((num_frames, 33, 4), np.nan, dtype=np.float32)
            
            # Mapping H3.6M to MediaPipe
            mapping = {
                11: 11, 14: 12, # Shoulders
                12: 13, 15: 14, # Elbows
                13: 15, 16: 16, # Wrists
                1: 23, 4: 24,   # Hips
                2: 25, 5: 26,   # Knees
                3: 27, 6: 28,   # Ankles
                9: 0,           # Nose
            }
            
            for s03_idx, mp_idx in mapping.items():
                if s03_idx < gt_array.shape[1]:
                    final_array[:, mp_idx, :3] = gt_array[:, s03_idx, :]
                    final_array[:, mp_idx, 3] = 1.0
                    
            output_file = os.path.join(session_output_root, "keypoints_3d.npy")
            np.save(output_file, final_array)
            
            # Re-render visualizations (Désactivé à la demande de l'utilisateur pour économiser de l'espace)
            # results_3d_dir = os.path.join(session_output_root, "results_3d")
            # TriangulationService.save_3d_visualizations(output_file, results_3d_dir)
            
            print(f"DEBUG: 3D Refinement completed successfully.")
            return output_file
        except Exception as e:
            print(f"ERROR: 3D Refinement failed: {e}")
            return None

    @staticmethod
    def save_3d_visualizations(npy_path: str, output_dir: str):
        """
        Renders the sequence of 3D skeleton plots as individual JPG images instead of a video.
        """
        import matplotlib
        matplotlib.use('Agg') # Non-interactive backend
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        if not os.path.exists(npy_path):
            return
            
        data = np.load(npy_path)
        num_frames = data.shape[0]
        if num_frames == 0:
            return
            
        # Create a specific directory for the 3D frames
        frames_out_dir = os.path.join(output_dir, "frames")
        os.makedirs(frames_out_dir, exist_ok=True)
        
        connections = [
            (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), # Arms
            (11, 23), (12, 24), (23, 24), (23, 25), (24, 26), # Torso/Hips
            (25, 27), (26, 28), (27, 29), (28, 30), (29, 31), (30, 32) # Legs
        ]
        
        print(f"DEBUG: Rendering full 3D skeleton frames ({num_frames} frames)...")
        
        fig = plt.figure(figsize=(8, 6), dpi=100)
        
        # Calculate global min/max for stable axes
        valid_data = data[~np.isnan(data[:, :, 0])]
        if len(valid_data) == 0:
            print("ERROR: No valid 3D points found.")
            return
            
        min_x, max_x = np.nanmin(data[:, :, 0]), np.nanmax(data[:, :, 0])
        min_y, max_y = np.nanmin(data[:, :, 1]), np.nanmax(data[:, :, 1])
        min_z, max_z = np.nanmin(data[:, :, 2]), np.nanmax(data[:, :, 2])
        
        for idx in range(num_frames):
            fig.clf()
            ax = fig.add_subplot(111, projection='3d')
            
            points = data[idx]
            x, y, z = points[:, 0], points[:, 1], points[:, 2]
            valid = ~np.isnan(x)
            
            if np.any(valid):
                # Scatter plot
                ax.scatter(x[valid], z[valid], -y[valid], c='red', s=20)
                
                # Connections
                for start, end in connections:
                    if valid[start] and valid[end]:
                        ax.plot([x[start], x[end]], [z[start], z[end]], [-y[start], -y[end]], c='blue', linewidth=2)
            
            ax.set_title(f"3D Skeleton - Frame {idx}")
            
            ax.set_xlim(min_x, max_x)
            ax.set_ylim(min_z, max_z)
            ax.set_zlim(-max_y, -min_y)
            
            ax.set_xlabel("X")
            ax.set_ylabel("Z")
            ax.set_zlabel("Y (inv)")
            
            # Save frame as JPG
            img_path = os.path.join(frames_out_dir, f"v_3d_frame_{idx:04d}.jpg")
            plt.savefig(img_path)
            
            if (idx + 1) % 100 == 0:
                print(f"DEBUG: Rendered {idx+1}/{num_frames} frames as images...")
                
        plt.close(fig)
        print(f"DEBUG: 3D Visualization images saved to {frames_out_dir}")

    @staticmethod
    def _triangulate_n_views(P_list, pts_list, weights=None):
        """
        Direct Linear Transform (DLT) pondéré pour N vues.
        """
        A = []
        if weights is None:
            weights = [1.0] * len(pts_list)
            
        for i in range(len(P_list)):
            P = P_list[i]
            x, y = pts_list[i]
            w = weights[i]
            
            if np.isnan(x) or np.isnan(y) or w < 0.1:
                continue
                
            # Équations pondérées par la visibilité
            A.append(w * (x * P[2, :] - P[0, :]))
            A.append(w * (y * P[2, :] - P[1, :]))
            
        if len(A) < 4:
            return [np.nan, np.nan, np.nan]
            
        A = np.array(A)
        _, _, vh = np.linalg.svd(A)
        X = vh[-1, :]
        X /= X[3]
        
        return X[:3]

    @staticmethod
    def _refine_triangulation(P_list, pts_list, initial_pt_3d, weights=None):
        """
        Raffinement non-linéaire du point 3D (Minimisation de l'erreur de reprojection).
        """
        from scipy.optimize import least_squares
        
        if weights is None:
            weights = [1.0] * len(pts_list)

        def reproj_func(p3d):
            errors = []
            for i in range(len(P_list)):
                x2d, y2d = pts_list[i]
                w = weights[i]
                if np.isnan(x2d) or w < 0.1:
                    continue
                proj = P_list[i] @ np.append(p3d, 1.0)
                px = proj[0] / proj[2]
                py = proj[1] / proj[2]
                errors.append(w * (px - x2d))
                errors.append(w * (py - y2d))
            return np.array(errors)

        res = least_squares(reproj_func, initial_pt_3d, method='lm')
        return res.x

    @staticmethod
    def _triangulate_with_reproj_filter(P_list, pts_list, weights, seuil_px=10.0):
        """Triangule, filtre les outliers, et affine le résultat mathématiquement."""
        # 1. Triangulation pondérée initiale (DLT)
        pt_3d = TriangulationService._triangulate_n_views(P_list, pts_list, weights)
        if np.any(np.isnan(pt_3d)):
            return pt_3d
        
        # 2. Rejet des caméras aberrantes
        pt_h = np.append(pt_3d, 1.0)
        bonnes_cams = []
        bons_pts = []
        bons_poids = []
        
        for i in range(len(P_list)):
            x2d, y2d = pts_list[i]
            if np.isnan(x2d): continue
            
            proj = P_list[i] @ pt_h
            px, py = proj[0] / proj[2], proj[1] / proj[2]
            erreur = np.sqrt((px - x2d)**2 + (py - y2d)**2)
            
            if erreur < seuil_px:
                bonnes_cams.append(P_list[i])
                bons_pts.append([x2d, y2d])
                bons_poids.append(weights[i])
        
        # 3. Re-triangulation + Raffinement Non-Linéaire
        if len(bonnes_cams) >= 2:
            pt_refined = TriangulationService._triangulate_n_views(bonnes_cams, bons_pts, bons_poids)
            return TriangulationService._refine_triangulation(bonnes_cams, bons_pts, pt_refined, bons_poids)
            
        return pt_3d
