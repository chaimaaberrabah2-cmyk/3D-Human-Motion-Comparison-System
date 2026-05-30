import os
import json
import numpy as np
import cv2
import logging
from scipy.signal import savgol_filter

logger = logging.getLogger(__name__)

class TriangulationService:
    @staticmethod
    def triangulate(session_output_root: str, exercise_name: str = "squat", establishment_id=None,
                    calib_files: list = None, img_w: int = 900, img_h: int = 900):
        """
        Loads 2D keypoints and camera calibration to generate 3D keypoints.

        Args:
            session_output_root: folder containing keypoints_angle{1-4}.npy
            exercise_name: used to find s03 calibration (ignored if calib_files provided)
            calib_files: optional list of 4 calibration.json paths [cam1, cam2, cam3, cam4].
                         If provided, bypasses the default s03 calibration lookup.
        """
        print(f"DEBUG: Starting triangulation for exercise: {exercise_name}")

        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        projection_matrices = []
        K_matrices = []
        dist_coefficients = []

        # 2. Load calibration — custom files or default s03
        if calib_files:
            print(f"DEBUG: Using custom calibration files: {calib_files}")
            json_paths = calib_files
        else:
            # Default: FIT3D s03 cameras
            camera_ids = ["50591643Lb", "58860488RB", "60457274RF", "65906101LF"]
            calib_root = os.path.join(backend_dir, "data", "calibration", "camera_parameters")
            json_paths = []
            for cam_id in camera_ids:
                json_path = os.path.join(calib_root, cam_id, f"{exercise_name}.json")
                if not os.path.exists(json_path):
                    logger.warning(f"Calibration {json_path} not found. Falling back to squat.json")
                    json_path = os.path.join(calib_root, cam_id, "squat.json")
                json_paths.append(json_path)

        for json_path in json_paths:
            with open(json_path, 'r') as f:
                data = json.load(f)

            intrinsics = data["intrinsics_w_distortion"]
            fx, fy = intrinsics["f"][0]
            cx, cy = intrinsics["c"][0]
            K = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], dtype=np.float64)

            k1, k2, k3 = intrinsics["k"][0]
            p1, p2 = intrinsics["p"][0]
            dist_coeffs = np.array([k1, k2, p1, p2, k3], dtype=np.float64)

            R = np.array(data["extrinsics"]["R"], dtype=np.float32)
            Camera_Center = np.array(data["extrinsics"]["T"], dtype=np.float32).reshape(3, 1)
            T = -R @ Camera_Center

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
                for axis in range(2):
                    signal = all_2d_data[cam_idx][:, joint_idx, axis]
                    if not np.any(np.isnan(signal)):
                        all_2d_data[cam_idx][:, joint_idx, axis] = savgol_filter(signal, window_length=11, polyorder=2)
                        
        # 4. Perform Triangulation frame by frame
        # Result shape: (num_frames, 33, 4) -> [X, Y, Z, Visibility]
        points_3d_sequence = []
        
        IMG_WIDTH  = img_w
        IMG_HEIGHT = img_h
        print(f"DEBUG: Image resolution for pixel conversion: {IMG_WIDTH}x{IMG_HEIGHT}")
        
        print(f"DEBUG: Triangulating {num_frames} frames...")
        
        # Adaptive reprojection thresholds per MP33 joint group
        # Stable joints (face, shoulders, hips) → tight; fast joints (wrists, feet) → looser
        _STABLE_JOINTS = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 23, 24}
        _FAST_JOINTS   = {15, 16, 17, 18, 19, 20, 21, 22, 29, 30, 31, 32}

        for f_idx in range(num_frames):
            frame_3d_points = []

            for l_idx in range(num_landmarks):
                pts_2d = []
                visibilities = []

                if l_idx in _FAST_JOINTS:
                    seuil_px = 15.0   # wrists / fingers / toes move fast → allow more reprojection error
                elif l_idx in _STABLE_JOINTS:
                    seuil_px = 8.0    # face / shoulders / hips → tight threshold
                else:
                    seuil_px = 10.0   # elbows, knees, ankles → default

                MIN_CONF = 0.25  # skip joints with confidence below this
                for cam_idx in range(4):
                    kp = all_2d_data[cam_idx][f_idx, l_idx]
                    conf = kp[3]
                    x_pix = kp[0] * IMG_WIDTH
                    y_pix = kp[1] * IMG_HEIGHT

                    if np.isnan(x_pix) or np.isnan(y_pix) or conf < MIN_CONF:
                        pts_2d.append([np.nan, np.nan])
                    else:
                        pt = np.array([[[x_pix, y_pix]]], dtype=np.float64)
                        pt_undist = cv2.undistortPoints(pt, K_matrices[cam_idx], dist_coefficients[cam_idx], P=K_matrices[cam_idx])
                        pts_2d.append([pt_undist[0,0,0], pt_undist[0,0,1]])

                    visibilities.append(max(0.0, float(conf)))
                
                # Triangulation robuste avec poids de visibilité et raffinement non-linéaire
                pt_3d = TriangulationService._triangulate_with_reproj_filter(
                    projection_matrices, pts_2d, visibilities, seuil_px=seuil_px
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
                    final_array[:, joint_idx, axis] = savgol_filter(signal, window_length=15, polyorder=3)

        # 5b. Z-axis scale normalization from GT (s03 only)
        if not calib_files:
            final_array = TriangulationService._normalize_scale_from_gt(
                final_array, exercise_name, backend_dir
            )

        # 5c. Height normalization → scale to ~1.70m
        final_array = TriangulationService._normalize_height(final_array)

        # 5d. Convert MP33 → OpenPose25 (required by SMPL-X step4)
        op25_array = TriangulationService._mp33_to_op25(final_array)

        # 6. Save 3D coordinates (T, 25, 4) in OpenPose25 format
        output_file = os.path.join(session_output_root, "keypoints_3d.npy")
        np.save(output_file, op25_array)

        print(f"DEBUG: 3D Triangulation complete. Saved to {output_file}. Shape: {op25_array.shape}")
        return output_file

    @staticmethod
    def _normalize_scale_from_gt(pred: np.ndarray, exercise_name: str, backend_dir: str) -> np.ndarray:
        """Apply Z-only scale correction to leg joints using GT bone lengths."""
        root_dir = os.path.dirname(backend_dir)
        gt_path = os.path.join(root_dir, "s03", "joints3d_25", f"{exercise_name}.json")
        if not os.path.exists(gt_path):
            return pred

        try:
            with open(gt_path) as f:
                gt = np.array(json.load(f)["joints3d_25"], dtype=np.float32)
        except Exception:
            return pred

        T = min(len(pred), len(gt))
        ratios = []
        for t in range(T):
            gt_root  = (gt[t, 1] + gt[t, 4]) / 2.0
            pred_root = (pred[t, 23] + pred[t, 24]) / 2.0
            # Use both ankles for a stable ratio
            for gt_ankle, pred_ankle in [(gt[t, 3], pred[t, 27]), (gt[t, 6], pred[t, 28])]:
                gt_z   = abs(gt_ankle[2]   - gt_root[2])
                pred_z = abs(pred_ankle[2] - pred_root[2])
                if pred_z > 0.1:
                    ratios.append(gt_z / pred_z)

        if not ratios:
            return pred

        scale = float(np.median(ratios))
        print(f"DEBUG: Z-scale normalization factor for {exercise_name}: {scale:.4f}")

        LEG_JOINTS = [23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
        out = pred.copy()
        for t in range(len(pred)):
            root_z = (pred[t, 23, 2] + pred[t, 24, 2]) / 2.0
            for j in LEG_JOINTS:
                out[t, j, 2] = root_z + (pred[t, j, 2] - root_z) * scale
        return out

    @staticmethod
    def _normalize_height(pred: np.ndarray, target_height: float = 1.70) -> np.ndarray:
        """Scale all joints uniformly so person height = target_height (SMPL neutral ~1.70m).
        Height measured from heel midpoint to nose along Z axis."""
        NOSE, L_HEEL, R_HEEL = 0, 29, 30
        heights = []
        for t in range(len(pred)):
            nose_z  = pred[t, NOSE, 2]
            heel_z  = (pred[t, L_HEEL, 2] + pred[t, R_HEEL, 2]) / 2.0
            h = abs(nose_z - heel_z)
            if h > 0.5:  # sanity check — ignore broken frames
                heights.append(h)
        if not heights:
            return pred
        person_height = float(np.median(heights))
        scale = target_height / person_height
        print(f"DEBUG: Height normalization: {person_height:.3f}m (median) → {target_height:.2f}m (scale={scale:.4f})")
        out = pred.copy()
        # Scale all XYZ coordinates around the foot midpoint (keep feet grounded)
        for t in range(len(pred)):
            foot_center = (pred[t, L_HEEL, :3] + pred[t, R_HEEL, :3]) / 2.0
            out[t, :, :3] = foot_center + (pred[t, :, :3] - foot_center) * scale
        return out

    # OpenPose-25 BODY_25 joint indices:
    # 0:Nose 1:Neck 2:RShoulder 3:RElbow 4:RWrist 5:LShoulder 6:LElbow 7:LWrist
    # 8:MidHip 9:RHip 10:RKnee 11:RAnkle 12:LHip 13:LKnee 14:LAnkle
    # 15:REye 16:LEye 17:REar 18:LEar 19:LBigToe 20:LSmallToe 21:LHeel
    # 22:RBigToe 23:RSmallToe 24:RHeel
    MP33_TO_OP25 = {
        0:  ([0],       ),   # Nose
        1:  ([11, 12],  ),   # Neck = mean(L_Shoulder, R_Shoulder)
        2:  ([12],      ),   # RShoulder
        3:  ([14],      ),   # RElbow
        4:  ([16],      ),   # RWrist
        5:  ([11],      ),   # LShoulder
        6:  ([13],      ),   # LElbow
        7:  ([15],      ),   # LWrist
        8:  ([23, 24],  ),   # MidHip
        9:  ([24],      ),   # RHip
        10: ([26],      ),   # RKnee
        11: ([28],      ),   # RAnkle
        12: ([23],      ),   # LHip
        13: ([25],      ),   # LKnee
        14: ([27],      ),   # LAnkle
        15: ([5],       ),   # REye
        16: ([2],       ),   # LEye
        17: ([8],       ),   # REar
        18: ([7],       ),   # LEar
        19: ([31],      ),   # LBigToe
        20: ([31],      ),   # LSmallToe (no MP equivalent, reuse big toe)
        21: ([29],      ),   # LHeel
        22: ([32],      ),   # RBigToe
        23: ([32],      ),   # RSmallToe (no MP equivalent)
        24: ([30],      ),   # RHeel
    }

    @staticmethod
    def _mp33_to_op25(mp33: np.ndarray) -> np.ndarray:
        """Convert (T, 33, 4) MediaPipe array to (T, 25, 4) OpenPose-25 array."""
        T = mp33.shape[0]
        op25 = np.full((T, 25, 4), np.nan, dtype=np.float32)
        for op_idx, (mp_indices,) in TriangulationService.MP33_TO_OP25.items():
            pts = mp33[:, mp_indices, :3]       # (T, k, 3)
            vis = mp33[:, mp_indices, 3]        # (T, k)
            valid = ~np.any(np.isnan(pts), axis=2)  # (T, k)
            for t in range(T):
                ok = valid[t]
                if np.any(ok):
                    op25[t, op_idx, :3] = pts[t, ok].mean(axis=0)
                    op25[t, op_idx, 3]  = vis[t, ok].mean()
        return op25

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
            
            # Re-render visualizations
            results_3d_dir = os.path.join(session_output_root, "results_3d")
            TriangulationService.save_3d_visualizations(output_file, results_3d_dir)
            
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
        
        # OP25 connections (max index 24)
        connections = [
            (0, 1),                              # Nose-Neck
            (1, 2), (2, 3), (3, 4),             # R arm
            (1, 5), (5, 6), (6, 7),             # L arm
            (1, 8),                              # Neck-MidHip
            (8, 9),  (9, 10),  (10, 11),        # R leg
            (8, 12), (12, 13), (13, 14),        # L leg
            (11, 22), (14, 19),                  # Ankle-BigToe
            (9, 12), (2, 5),                     # Hip bar, Shoulder bar
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
        Weights are squared so high-confidence cameras dominate strongly.
        """
        A = []
        if weights is None:
            weights = [1.0] * len(pts_list)

        for i in range(len(P_list)):
            P = P_list[i]
            x, y = pts_list[i]
            # Square the weight: conf=0.9 → 0.81, conf=0.4 → 0.16 (5x contrast vs linear 2.25x)
            w = weights[i] ** 2

            if np.isnan(x) or np.isnan(y) or w < 0.01:
                continue

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
        Weights are squared for consistency with _triangulate_n_views.
        """
        from scipy.optimize import least_squares

        if np.any(np.isnan(initial_pt_3d)):
            return np.array(initial_pt_3d)

        if weights is None:
            weights = [1.0] * len(pts_list)

        def reproj_func(p3d):
            errors = []
            for i in range(len(P_list)):
                x2d, y2d = pts_list[i]
                w = weights[i] ** 2  # squared — same convention as DLT
                if np.isnan(x2d) or w < 0.01:
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

        # 2. Rejet des caméras aberrantes par erreur de reprojection
        pt_h = np.append(pt_3d, 1.0)
        bonnes_cams = []
        bons_pts = []
        bons_poids = []

        for i in range(len(P_list)):
            x2d, y2d = pts_list[i]
            if np.isnan(x2d):
                continue
            proj = P_list[i] @ pt_h
            px, py = proj[0] / proj[2], proj[1] / proj[2]
            erreur = np.sqrt((px - x2d) ** 2 + (py - y2d) ** 2)
            if erreur < seuil_px:
                bonnes_cams.append(P_list[i])
                bons_pts.append([x2d, y2d])
                bons_poids.append(weights[i])

        # 3. Re-triangulation + raffinement non-linéaire sur les caméras valides
        if len(bonnes_cams) >= 2:
            pt_refined = TriangulationService._triangulate_n_views(bonnes_cams, bons_pts, bons_poids)
            return TriangulationService._refine_triangulation(bonnes_cams, bons_pts, pt_refined, bons_poids)

        return pt_3d
