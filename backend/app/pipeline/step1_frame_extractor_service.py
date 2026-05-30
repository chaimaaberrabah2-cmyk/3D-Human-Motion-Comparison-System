import cv2
import os
import logging

logger = logging.getLogger(__name__)

class VideoService:
    @staticmethod
    def extract_frames(video_path: str, output_dir: str, max_frames: int = 900):
        """
        Extracts frames from a video file and saves them as images.
        Stops after max_frames frames.
        """
        os.makedirs(output_dir, exist_ok=True)
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"Error: Could not open video file {video_path}")
            raise Exception(f"Could not open video file {video_path}")

        frame_count = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_filename = os.path.join(output_dir, f"frame_{frame_count:05d}.jpg")
            success = cv2.imwrite(frame_filename, frame)
            if not success:
                print(f"ERROR: Failed to write frame {frame_count} to {frame_filename}. Is the disk full?")
                logger.error(f"Failed to write frame {frame_count} to {frame_filename}. Is the disk full?")
                break

            frame_count += 1
            if frame_count % 100 == 0:
                print(f"DEBUG: Extracted {frame_count} frames so far...")

            if frame_count >= max_frames:
                print(f"DEBUG: Reached max_frames limit ({max_frames}). Stopping extraction.")
                break

        cap.release()
        print(f"DEBUG: Extraction complete. Total frames: {frame_count}")
        logger.info(f"Extracted {frame_count} frames to {output_dir}")
        return frame_count
