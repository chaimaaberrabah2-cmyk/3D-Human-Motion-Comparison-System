import os
import cv2
import glob
import numpy as np
import mediapipe as mp
import logging

logger = logging.getLogger(__name__)

class PoseService:
    @staticmethod
    def extract_keypoints(frames_dir: str, output_filepath: str, save_annotated: bool = True):
        """
        Extracts 2D keypoints from a sequence of frames using MediaPipe BlazePose.
        
        Args:
            frames_dir (str): Path to the directory containing the frame images.
            output_filepath (str): Path to save the extracted keypoints as a .npy file.
            save_annotated (bool): If True, saves the skeleton overlaid on the original images.
            
        Returns:
            bool: True if successful, False otherwise.
        """
        # Get list of frames and sort them to maintain temporal sequence
        frame_pattern = os.path.join(frames_dir, "*.jpg")
        frame_files = sorted(glob.glob(frame_pattern))
        
        if not frame_files:
            logger.warning(f"No frames found in directory: {frames_dir}")
            return False
            
        # Initialize MediaPipe Pose and drawing utils
        try:
            import mediapipe.python.solutions.pose as mp_pose
            import mediapipe.python.solutions.drawing_utils as mp_drawing
            import mediapipe.python.solutions.drawing_styles as mp_drawing_styles
        except ImportError:
            try:
                import mediapipe.solutions.pose as mp_pose
                import mediapipe.solutions.drawing_utils as mp_drawing
                import mediapipe.solutions.drawing_styles as mp_drawing_styles
            except ImportError:
                # Fallback ultime pour certaines versions
                from mediapipe.python.solutions import pose as mp_pose
                from mediapipe.python.solutions import drawing_utils as mp_drawing
                from mediapipe.python.solutions import drawing_styles as mp_drawing_styles
        
        # We use static_image_mode=False for video sequences to leverage temporal consistency
        # model_complexity=1 is lighter and faster for testing.
        pose = mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            enable_segmentation=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Array to store all frames' keypoints
        # Shape will be (num_frames, 33, 4) -> 33 landmarks, each has (x, y, z, visibility)
        all_keypoints = []
        
        # Create an 'annotated' folder only if requested
        annotated_dir = os.path.join(frames_dir, "annotated")
        if save_annotated:
            os.makedirs(annotated_dir, exist_ok=True)
            print(f"DEBUG: Annotated directory created at: {annotated_dir}")
        logger.info(f"Starting keypoint extraction for {len(frame_files)} frames from {frames_dir}")
        
        for frame_file in frame_files:
            # Read image
            image = cv2.imread(frame_file)
            if image is None:
                logger.error(f"Failed to read image: {frame_file}")
                # Append NaNs if frame is unreadable to maintain sequence length
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
                continue
                
            # Convert the BGR image to RGB before processing.
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            
            # Process with MediaPipe
            results = pose.process(image_rgb)
            
            if results.pose_landmarks:
                # Extract landmarks
                landmarks = []
                for lm in results.pose_landmarks.landmark:
                    landmarks.append([lm.x, lm.y, lm.z, lm.visibility])
                all_keypoints.append(landmarks)
                
                # Draw the pose annotation on the image
                if save_annotated:
                    mp_drawing.draw_landmarks(
                        image,
                        results.pose_landmarks,
                        mp_pose.POSE_CONNECTIONS,
                        landmark_drawing_spec=mp_drawing_styles.get_default_pose_landmarks_style()
                    )
                    # Save the annotated image back to the annotated folder
                    base_name = os.path.basename(frame_file)
                    annotated_filename = os.path.join(annotated_dir, base_name)
                    cv2.imwrite(annotated_filename, image)
            else:
                # No pose detected, fill with NaNs to keep the array shape consistent
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
                
            # Add progress logging
            frame_idx = len(all_keypoints)
            if frame_idx % 100 == 0:
                print(f"DEBUG: [Pose] Processed {frame_idx}/{len(frame_files)} frames...")
                
        # Close the pose model
        pose.close()
        
        # Convert to numpy array
        keypoints_array = np.array(all_keypoints, dtype=np.float32)
        
        # Save to file
        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
        np.save(output_filepath, keypoints_array)
        
        print(f"DEBUG: Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        logger.info(f"Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        
        return True

    @staticmethod
    def extract_keypoints_from_video(video_path: str, output_filepath: str):
        """
        Processes a video file directly, extracts pose keypoints per frame, and saves to .npy.
        Zero frames are saved as JPG to the disk.
        """
        try:
            from mediapipe.python.solutions import pose as mp_pose
        except ImportError:
            import mediapipe.solutions.pose as mp_pose
        
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"Failed to open video file: {video_path}")
            return False
            
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print(f"DEBUG: Processing video {video_path} ({total_frames} frames)...")
        
        pose = mp_pose.Pose(
            static_image_mode=False, 
            model_complexity=2,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.7
        )
        
        all_keypoints = []
        frame_idx = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
                
            # Convert BGR to RGB
            image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(image_rgb)
            
            if results.pose_landmarks:
                # Extract landmarks (x, y, z, visibility)
                landmarks = [[lm.x, lm.y, lm.z, lm.visibility] for lm in results.pose_landmarks.landmark]
                all_keypoints.append(landmarks)
            else:
                # No pose detected, fill with NaNs to keep the array shape consistent
                all_keypoints.append(np.zeros((33, 4)) * np.nan)
            
            frame_idx += 1
            if frame_idx % 100 == 0:
                print(f"DEBUG: [Pose] Processed {frame_idx}/{total_frames} frames...")
                
        cap.release()
        pose.close()
        
        if not all_keypoints:
            print("ERROR: No keypoints extracted from video.")
            return False
            
        # Convert to numpy array and save
        keypoints_array = np.array(all_keypoints, dtype=np.float32)
        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
        np.save(output_filepath, keypoints_array)
        print(f"DEBUG: Saved keypoints to {output_filepath}. Array shape: {keypoints_array.shape}")
        return True
