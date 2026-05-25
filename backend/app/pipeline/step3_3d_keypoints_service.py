import os
import json
import numpy as np
import cv2
import logging
from scipy.signal import savgol_filter
from app.database.setup import SessionLocal
from app.database.models import Establishment

logger = logging.getLogger(__name__)

class TriangulationService:
    """
    Service class responsible for 3D human joint reconstruction (triangulation)
    from multiple synchronized 2D camera views.
    
    This service is the third step of the motion analysis pipeline. It takes the
    2D pose keypoint arrays from multiple angles, applies 2D temporal smoothing,
    corrects camera lens distortion, triangulates the coordinates into 3D using 
    projection matrices (from camera calibration JSONs), and finally filters/refines
    the result.
    """

    @staticmethod
    def triangulate(session_output_root: str, exercise_name: str = "deadlift", establishment_id: int = None) -> str:
        """
        Loads 2D keypoints and camera calibration to generate 3D keypoints using
        multi-view triangulation.
        
        Args:
            session_output_root (str): The folder containing the 2D keypoints .npy files
                                       for each angle.
            exercise_name (str): Name of the exercise to fetch the correct calibration JSON.
                                 Defaults to "deadlift".
            establishment_id (int): Optional ID of the establishment to load database calibration from.
                                 
        Returns:
            str: Path to the generated 3D keypoints .npy file.
            
        Raises:
            Exception: If any of the required 2D angle keypoint files are missing.
        """
        # Step 1: Mapping aligned with run_analysis.py camera order.
        # Maps the sequential angles to their corresponding hardware camera identifier.
        # Video 1: 50591643Lb, Video 2: 58860488RB, Video 3: 60457274RF, Video 4: 65906101LF
        camera_ids = ["50591643Lb", "58860488RB", "60457274RF", "65906101LF"]
        
        # Determine base directory for calibration files.
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        calib_root = os.path.join(backend_dir, "data", "calibration", "camera_parameters")
        
        print(f"DEBUG: Starting triangulation for exercise: {exercise_name}")
        
        projection_matrices = []
        K_matrices = []
        dist_coefficients = []
        
        # Step 2: Load calibration metrics and build the Projection Matrices (P = K * [R|T]).
        db_calibration = None
        if establishment_id is not None:
            try:
                db = SessionLocal()
                establishment = db.query(Establishment).filter(Establishment.establishment_id == establishment_id).first()
                if establishment and establishment.calibration_data:
                    db_calibration = establishment.calibration_data
                    print(f"DEBUG: Found database calibration data for establishment {establishment_id}")
            except Exception as e:
                logger.error(f"Error querying database calibration: {e}")
            finally:
                if 'db' in locals():
                    db.close()

        for cam_id in camera_ids:
            data = None
            if db_calibration:
                if cam_id in db_calibration:
                    data = db_calibration[cam_id]
                    print(f"DEBUG: Using database calibration for camera {cam_id}")
                elif str(cam_id) in db_calibration:
                    data = db_calibration[str(cam_id)]
                    print(f"DEBUG: Using database calibration for camera {cam_id}")

            if data is None:
                json_path = os.path.join(calib_root, cam_id, f"{exercise_name}.json")
                if not os.path.exists(json_path):
                    # Fallback to squat if exercise-specific calibration is missing.
                    logger.warning(f"Calibration file {json_path} not found. Falling back to squat.json")
                    json_path = os.path.join(calib_root, cam_id, "squat.json")
                
                with open(json_path, 'r') as f:
                    data = json.load(f)
                
            # Intrinsic camera matrix (K) - accounts for focal lengths (f) and principal points (c).
            intrinsics = data["intrinsics_w_distortion"]
            fx, fy = intrinsics["f"][0]
            cx, cy = intrinsics["c"][0]
            K = np.array([
                [fx, 0, cx],
                [0, fy, cy],
                [0, 0, 1]
            ], dtype=np.float64)
            
            # Lens distortion coefficients (radial: k1, k2, k3; tangential: p1, p2).
            k1, k2, k3 = intrinsics["k"][0]
            p1, p2 = intrinsics["p"][0]
            dist_coeffs = np.array([k1, k2, p1, p2, k3], dtype=np.float64)
            
            # Extrinsic Parameters R (Rotation Matrix) and Camera Center (Translation).
            R = np.array(data["extrinsics"]["R"], dtype=np.float32)
            Camera_Center = np.array(data["extrinsics"]["T"], dtype=np.float32).reshape(3, 1)
            
            # Translate Camera Center back to OpenCV translation vector: t = -R * C.
            T = -R @ Camera_Center 
            
            # Combine Extrinsic and Intrinsic to form the Projection Matrix P.
            Rt = np.hstack((R, T))
            P = K @ Rt
            projection_matrices.append(P)
            K_matrices.append(K)
            dist_coefficients.append(dist_coeffs)
            
        # Step 3: Load the 2D keypoints extracted from the 4 video views.
        all_2d_data = []
        for i in range(1, 5):
            npy_path = os.path.join(session_output_root, f"keypoints_angle{i}.npy")
            if not os.path.exists(npy_path):
                raise Exception(f"Missing 2D data for angle {i}: {npy_path}")
            all_2d_data.append(np.load(npy_path))
            
        # Align frame counts using the minimum sequence length to avoid out-of-bounds indices.
        num_frames = min(data.shape[0] for data in all_2d_data)
        num_landmarks = all_2d_data[0].shape[1]  # Normally 33 landmarks for MediaPipe BlazePose
        
        # Step 3.5: Pre-triangulation 2D temporal smoothing.
        # Applies a Savitzky-Golay filter to smooth 2D keypoint trajectory over time.
        # Window size is 11, polynomial order is 2.
        print("DEBUG: Lissage 2D pre-triangulation...")
        for cam_idx in range(4):
            for joint_idx in range(num_landmarks):
                for axis in range(2):  # Apply to X and Y coordinates only
                    signal = all_2d_data[cam_idx][:, joint_idx, axis]
                    if not np.any(np.isnan(signal)):
                        all_2d_data[cam_idx][:, joint_idx, axis] = savgol_filter(signal, window_length=11, polyorder=2)
                        
        # Step 4: Perform multi-view triangulation frame by frame.
        # Output shape will be (num_frames, 33, 4) -> [X, Y, Z, average_visibility]
        points_3d_sequence = []
        
        # MediaPipe resolution - confirmed as 900x900
        IMG_WIDTH = 900
        IMG_HEIGHT = 900
        
        print(f"DEBUG: Triangulating {num_frames} frames...")
        
        for f_idx in range(num_frames):
            frame_3d_points = []
            
            for l_idx in range(num_landmarks):
                pts_2d = []
                visibilities = []
                
                # Retrieve and undistort coordinates from each view
                for cam_idx in range(4):
                    kp = all_2d_data[cam_idx][f_idx, l_idx]
                    x_pix = kp[0] * IMG_WIDTH
                    y_pix = kp[1] * IMG_HEIGHT
                    
                    if np.isnan(x_pix) or np.isnan(y_pix):
                        pts_2d.append([np.nan, np.nan])
                    else:
                        # Correct lens distortion based on camera intrinsic/distortion arrays
                        pt = np.array([[[x_pix, y_pix]]], dtype=np.float64)
                        pt_undist = cv2.undistortPoints(pt, K_matrices[cam_idx], dist_coefficients[cam_idx], P=K_matrices[cam_idx])
                        pts_2d.append([pt_undist[0,0,0], pt_undist[0,0,1]])
                        
                    visibilities.append(kp[3])
                
                # Robust triangulation with RANSAC-like reprojection filter and non-linear least squares optimization
                pt_3d = TriangulationService._triangulate_with_reproj_filter(
                    projection_matrices, pts_2d, visibilities, seuil_px=10.0
                )
                
                avg_visibility = np.mean(visibilities)
                frame_3d_points.append([pt_3d[0], pt_3d[1], pt_3d[2], avg_visibility])
            
            points_3d_sequence.append(frame_3d_points)
            
            if (f_idx + 1) % 100 == 0:
                print(f"DEBUG: Triangulated {f_idx + 1}/{num_frames} frames...")

        # Step 5: Post-triangulation 3D trajectory smoothing.
        # Applies a Savitzky-Golay filter to clean up residual 3D coordinate jitter.
        # Window size is 15, polynomial order is 3.
        final_array = np.array(points_3d_sequence, dtype=np.float32)
        print("DEBUG: Lissage 3D post-triangulation...")
        for joint_idx in range(num_landmarks):
            for axis in range(3):
                signal = final_array[:, joint_idx, axis]
                if not np.any(np.isnan(signal)):
                    final_array[:, joint_idx, axis] = savgol_filter(signal, window_length=15, polyorder=3)
                    
        # Step 6: Save the final 3D coordinates.
        output_file = os.path.join(session_output_root, "keypoints_3d.npy")
        np.save(output_file, final_array)
        
        print(f"DEBUG: 3D Triangulation complete. Saved to {output_file}. Shape: {final_array.shape}")
        return output_file

    @staticmethod
    def refine_3d_keypoints(session_output_root: str, exercise_name: str) -> str:
        """
        Refines the 3D keypoints by aligning them to an anatomical atlas (ground truth json file from s03).
        Maps Human3.6M format to MediaPipe indexing structures.
        
        [COMMENTED OUT FOR RAW EVALUATION]
        This function has been commented out to prevent overwriting the raw mathematical triangulation
        results with the ground-truth Human3.6M coordinates. This allows observing the actual output
        of the triangulation algorithms.
        
        Args:
            session_output_root (str): The folder containing the triangulated 'keypoints_3d.npy'.
            exercise_name (str): Name of the exercise to retrieve corresponding ground truth files.
            
        Returns:
            str: Path to the original triangulated 'keypoints_3d.npy' file.
        """
        print(f"DEBUG: [SANS RAFFINEMENT] Utilisation directe des points triangulés (sans écrasement GT s03/Human3D).")
        
        # Le code ci-dessous est conservé en commentaire pour référence à Human3D / s03 :
        """
        # Determine paths
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
            
            # Index mapping dictionary: Human3.6M index (key) -> MediaPipe index (value)
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
            
            # Re-render visualizations using the refined keypoints
            results_3d_dir = os.path.join(session_output_root, "results_3d")
            TriangulationService.save_3d_visualizations(output_file, results_3d_dir)
            
            print(f"DEBUG: 3D Refinement completed successfully.")
            return output_file
        except Exception as e:
            print(f"ERROR: 3D Refinement failed: {e}")
            return None
        """
        output_file = os.path.join(session_output_root, "keypoints_3d.npy")
        return output_file

    @staticmethod
    def save_3d_visualizations(npy_path: str, output_dir: str):
        """
        Renders the sequence of 3D skeleton joints as individual JPEG images for inspection.
        
        Args:
            npy_path (str): Path to the 3D keypoints numpy file (.npy).
            output_dir (str): Folder where the rendered images will be saved.
        """
        import matplotlib
        matplotlib.use('Agg')  # Force matplotlib to use a non-interactive backend
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        if not os.path.exists(npy_path):
            return
            
        data = np.load(npy_path)
        num_frames = data.shape[0]
        if num_frames == 0:
            return
            
        # Create a directory specific for the 3D frames
        frames_out_dir = os.path.join(output_dir, "frames")
        os.makedirs(frames_out_dir, exist_ok=True)
        
        # Define connection pairs to draw skeleton lines between joints
        connections = [
            (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), # Arms
            (11, 23), (12, 24), (23, 24), (23, 25), (24, 26), # Torso/Hips
            (25, 27), (26, 28), (27, 29), (28, 30), (29, 31), (30, 32) # Legs
        ]
        
        print(f"DEBUG: Rendering full 3D skeleton frames ({num_frames} frames)...")
        
        fig = plt.figure(figsize=(8, 6), dpi=100)
        
        # Compute global min/max bounds across the dataset to keep viewport axis ranges static
        valid_data = data[~np.isnan(data[:, :, 0])]
        if len(valid_data) == 0:
            print("ERROR: No valid 3D points found.")
            return
            
        min_x, max_x = np.nanmin(data[:, :, 0]), np.nanmax(data[:, :, 0])
        min_y, max_y = np.nanmin(data[:, :, 1]), np.nanmax(data[:, :, 1])
        min_z, max_z = np.nanmin(data[:, :, 2]), np.nanmax(data[:, :, 2])
        
        # Render each frame one by one
        for idx in range(num_frames):
            fig.clf()
            ax = fig.add_subplot(111, projection='3d')
            
            points = data[idx]
            x, y, z = points[:, 0], points[:, 1], points[:, 2]
            valid = ~np.isnan(x)
            
            if np.any(valid):
                # Draw joint points
                ax.scatter(x[valid], z[valid], -y[valid], c='red', s=20)
                
                # Draw skeleton connection lines
                for start, end in connections:
                    if valid[start] and valid[end]:
                        ax.plot([x[start], x[end]], [z[start], z[end]], [-y[start], -y[end]], c='blue', linewidth=2)
            
            ax.set_title(f"3D Skeleton - Frame {idx}")
            
            # Apply static axis limits to prevent camera perspective jumping
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
    def _triangulate_n_views(P_list, pts_list, weights=None) -> list:
        """
        Calculates the 3D position of a point from multiple 2D views using the
        weighted Direct Linear Transform (DLT) algorithm.
        
        Args:
            P_list (list): List of 3x4 projection matrices (one per view).
            pts_list (list): List of 2D [x, y] coordinates corresponding to each view.
            weights (list): List of confidence weights (e.g., visibilities) for each view.
            
        Returns:
            list: The calculated [X, Y, Z] 3D coordinates, or [NaN, NaN, NaN] if insufficient views.
        """
        A = []
        if weights is None:
            weights = [1.0] * len(pts_list)
            
        for i in range(len(P_list)):
            P = P_list[i]
            x, y = pts_list[i]
            w = weights[i]
            
            # Skip invalid coordinates or views with extremely low visibility/confidence
            if np.isnan(x) or np.isnan(y) or w < 0.1:
                continue
                
            # Weighted homography equations from projection matrix rows
            A.append(w * (x * P[2, :] - P[0, :]))
            A.append(w * (y * P[2, :] - P[1, :]))
            
        # We need at least 2 valid cameras (generating 4 equations) to reconstruct 3D
        if len(A) < 4:
            return [np.nan, np.nan, np.nan]
            
        A = np.array(A)
        # Solve the homogeneous system A * X = 0 using Singular Value Decomposition (SVD)
        _, _, vh = np.linalg.svd(A)
        X = vh[-1, :]
        X /= X[3]  # Convert back from homogeneous coordinates
        
        return X[:3]

    @staticmethod
    def _refine_triangulation(P_list, pts_list, initial_pt_3d, weights=None) -> np.ndarray:
        """
        Refines the initial DLT 3D coordinate estimation by performing non-linear
        optimization (Levenberg-Marquardt) to minimize reprojection errors.
        
        Args:
            P_list (list): List of 3x4 projection matrices.
            pts_list (list): List of 2D [x, y] coordinates.
            initial_pt_3d (list/np.ndarray): The initial 3D coordinates from DLT.
            weights (list): List of weights for each view.
            
        Returns:
            np.ndarray: The optimized [X, Y, Z] 3D coordinates.
        """
        from scipy.optimize import least_squares
        
        if np.any(np.isnan(initial_pt_3d)):
            return np.array(initial_pt_3d)
            
        if weights is None:
            weights = [1.0] * len(pts_list)

        # Objective function to minimize: the weighted Euclidean distance between
        # the projected 3D point and the observed 2D coordinate on each camera plane.
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
    def _triangulate_with_reproj_filter(P_list, pts_list, weights, seuil_px=10.0) -> list:
        """
        Triangulates a point across multiple views, identifies and filters out outlier camera views 
        exceeding the reprojection error threshold, and refines the final 3D point.
        
        Args:
            P_list (list): List of projection matrices.
            pts_list (list): List of 2D coordinates.
            weights (list): List of visibility weights.
            seuil_px (float): Maximum allowed pixel distance for reprojection errors (defaults to 10px).
            
        Returns:
            list: The final filtered and refined [X, Y, Z] coordinates.
        """
        # Step 1: Compute initial guess using Direct Linear Transform (DLT)
        pt_3d = TriangulationService._triangulate_n_views(P_list, pts_list, weights)
        if np.any(np.isnan(pt_3d)):
            return pt_3d
        
        # Step 2: Calculate reprojection errors to filter outlier views
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
            
            # Keep only camera views with reprojection error below threshold
            if erreur < seuil_px:
                bonnes_cams.append(P_list[i])
                bons_pts.append([x2d, y2d])
                bons_poids.append(weights[i])
        
        # Step 3: Re-triangulate and perform Non-Linear refinement using inlier cameras only
        if len(bonnes_cams) >= 2:
            pt_refined = TriangulationService._triangulate_n_views(bonnes_cams, bons_pts, bons_poids)
            if not np.any(np.isnan(pt_refined)):
                return TriangulationService._refine_triangulation(bonnes_cams, bons_pts, pt_refined, bons_poids)
            
        return pt_3d
