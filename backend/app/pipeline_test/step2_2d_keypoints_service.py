import os
import cv2
import glob
import numpy as np
import mediapipe as mp
import logging

logger = logging.getLogger(__name__)

class PoseService:
    """
    Service class responsible for 2D human pose estimation using MediaPipe BlazePose.
    
    This service is the second step of the motion analysis pipeline. It extracts 
    2D skeleton keypoints (landmarks) from images (frames) or video files. These 2D 
    keypoints are then used for subsequent 3D triangulation.
    """

    @staticmethod
    def extract_keypoints(frames_dir: str, output_filepath: str, save_annotated: bool = True) -> bool:
        """
        Extracts 2D keypoints from a sequence of pre-extracted frame images stored in a directory.

        This method reads the JPEG files sequentially, processes them with MediaPipe to get
        human pose landmarks, and optionally saves annotated images with the skeleton overlaid.
        
        Args:
            frames_dir (str): Path to the directory containing the source frame images.
            output_filepath (str): File path where the resulting 2D keypoints (.npy file) will be saved.
            save_annotated (bool): If True, overlays the skeleton on the images and saves them in a
                                   subdirectory named 'annotated' inside frames_dir.
            
        Returns:
            bool: True if keypoints were successfully extracted and saved, False otherwise.
        """
        # Step 1: Retrieve and sort all frame files in the input directory.
        # Sorting ensures the temporal sequence of the movement is preserved.
        frame_pattern = os.path.join(frames_dir, "*.jpg")
        frame_files = sorted(glob.glob(frame_pattern))
        
        if not frame_files:
            logger.warning(f"No frames found in directory: {frames_dir}")
            return False
            
        # Step 2: Reference MediaPipe Pose and Drawing solutions.
        # Accessing them from the already imported 'mp' module prevents IDE/linter unresolved import warnings.
        mp_pose = mp.solutions.pose
        mp_drawing = mp.solutions.drawing_utils
        mp_drawing_styles = mp.solutions.drawing_styles
        
        # Step 3: Configure and instantiate the MediaPipe Pose object.
        # - static_image_mode=False: Optimizes processing for sequence/video frames by tracking landmarks.
        # - model_complexity=1: Balances detection accuracy and CPU execution speed.
        # - enable_segmentation=False: Disables segmentation masks since we only need the joints.
        pose = mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            enable_segmentation=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        all_keypoints = []
        
        # Step 4: Prepare the annotated output directory if enabled.
        annotated_dir = os.path.join(frames_dir, "annotated")
        if save_annotated:
            os.makedirs(annotated_dir, exist_ok=True)
            print(f"DEBUG: Annotated directory created at: {annotated_dir}")
            
        logger.info(f"Starting keypoint extraction for {len(frame_files)} frames from {frames_dir}")
        
        # Step 5: Process each frame image.
        for frame_file in frame_files:
            # Read the image from disk.
            image = cv2.imread(frame_file)
            if image is None:
                logger.error(f"Failed to read image: {frame_file}")
                # If a frame fails to load, insert NaNs to keep the sequence index alignment correct.
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
                continue
                
            # OpenCV loads images in BGR format, but MediaPipe expects RGB format.
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            # Run the MediaPipe BlazePose pipeline on the frame.
            results = pose.process(image_rgb)
            
            if results.pose_landmarks:
                # Step 5a: Extract coordinates for all 33 keypoints.
                # Each joint contains normalized coordinates (x, y, z) and a visibility score.
                landmarks = []
                for lm in results.pose_landmarks.landmark:
                    landmarks.append([lm.x, lm.y, lm.z, lm.visibility])
                all_keypoints.append(landmarks)
                
                # Step 5b: Draw and save annotated frame if requested.
                if save_annotated:
                    mp_drawing.draw_landmarks(
                        image,
                        results.pose_landmarks,
                        mp_pose.POSE_CONNECTIONS,
                        landmark_drawing_spec=mp_drawing_styles.get_default_pose_landmarks_style()
                    )
                    base_name = os.path.basename(frame_file)
                    annotated_filename = os.path.join(annotated_dir, base_name)
                    cv2.imwrite(annotated_filename, image)
            else:
                # If no human or pose is detected, pad the index with NaNs to maintain temporal alignment.
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
                
            frame_idx = len(all_keypoints)
            if frame_idx % 100 == 0:
                print(f"DEBUG: [Pose] Processed {frame_idx}/{len(frame_files)} frames...")
                
        # Step 6: Clean up the MediaPipe instance.
        pose.close()
        
        # Step 7: Save the results array as a .npy file.
        # The output array shape is (num_frames, 33, 4).
        keypoints_array = np.array(all_keypoints, dtype=np.float32)
        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
        np.save(output_filepath, keypoints_array)
        
        print(f"DEBUG: Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        logger.info(f"Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        
        return True

    @staticmethod
    def extract_keypoints_from_video(video_path: str, output_filepath: str) -> bool:
        """
        Directly extracts 2D pose keypoints from a video file without saving intermediate frames to disk.
        
        This method is useful for faster processing when separate frame images are not required.
        
        Args:
            video_path (str): Path to the source video file.
            output_filepath (str): File path where the resulting 2D keypoints (.npy file) will be saved.
            
        Returns:
            bool: True if keypoints were successfully extracted and saved, False otherwise.
        """
        # Step 1: Reference MediaPipe solutions directly.
        mp_pose = mp.solutions.pose
        
        # Step 2: Open the video stream.
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"Failed to open video file: {video_path}")
            return False
            
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print(f"DEBUG: Processing video {video_path} ({total_frames} frames)...")
        
        # Step 3: Initialize the Pose object.
        # - model_complexity=2: High complexity model for maximum tracking accuracy.
        # - min_tracking_confidence=0.7: Higher threshold to reduce jitter.
        pose = mp_pose.Pose(
            static_image_mode=False, 
            model_complexity=2,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.7
        )
        
        all_keypoints = []
        frame_idx = 0
        
        # Step 3: Stream and process frames one by one.
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            # Convert OpenCV's BGR layout to MediaPipe's expected RGB format.
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(image_rgb)
            
            if results.pose_landmarks:
                # Extract keypoints (x, y, z, visibility)
                landmarks = [[lm.x, lm.y, lm.z, lm.visibility] for lm in results.pose_landmarks.landmark]
                all_keypoints.append(landmarks)
            else:
                # If pose tracking fails, pad with NaNs to keep sequence length consistent.
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
            
            frame_idx += 1
            if frame_idx % 100 == 0:
                print(f"DEBUG: [Pose] Processed {frame_idx}/{total_frames} frames...")
                
        # Step 4: Release resources.
        cap.release()
        pose.close()
        
        if not all_keypoints:
            print("ERROR: No keypoints extracted from video.")
            return False
            
        # Step 5: Convert coordinates and save as a binary NumPy file (.npy).
        keypoints_array = np.array(all_keypoints, dtype=np.float32)
        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
        np.save(output_filepath, keypoints_array)
        print(f"DEBUG: Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        
        return True
