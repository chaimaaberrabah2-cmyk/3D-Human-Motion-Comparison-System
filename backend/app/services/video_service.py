import cv2
import os
import logging

logger = logging.getLogger(__name__)

class VideoService:
    @staticmethod
    def extract_frames(video_path: str, output_dir: str):
        """
        Extracts all frames from a video file and saves them as images in the specified directory.
        
        Args:
            video_path (str): Path to the source video file.
            output_dir (str): Path to the directory where frames will be saved.
        """
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        # Open the video file
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"Error: Could not open video file {video_path}")
            raise Exception(f"Could not open video file {video_path}")
        
        frame_count = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Save frame as JPEG file
            frame_filename = os.path.join(output_dir, f"frame_{frame_count:05d}.jpg")
            success = cv2.imwrite(frame_filename, frame)
            if not success:
                logger.error(f"Failed to write frame {frame_count} to {frame_filename}. Is the disk full?")
                break
            frame_count += 1
        
        cap.release()
        logger.info(f"Extracted {frame_count} frames to {output_dir}")
        return frame_count
