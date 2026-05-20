import cv2
import os
import logging

logger = logging.getLogger(__name__)

class VideoService:
    """
    Service class responsible for video handling and frame extraction.
    
    This service is the first step of the motion analysis pipeline. It takes an
    input video file (e.g., MP4, MOV) and extracts every individual video frame 
    as a JPEG image. These extracted frames are saved to a temporary directory 
    where subsequent stages (like 2D pose estimation) can process them.
    """

    @staticmethod
    def extract_frames(video_path: str, output_dir: str) -> int:
        """
        Extracts all individual frames from the specified video file and saves them 
        as sequentially numbered JPEG images in the output directory.

        Args:
            video_path (str): The absolute or relative path to the input video file.
            output_dir (str): The path to the directory where the extracted frame 
                              images will be saved. The directory will be created 
                              if it does not already exist.

        Returns:
            int: The total number of frames successfully extracted and saved.

        Raises:
            Exception: If the video file cannot be opened by OpenCV.
        """
        # Step 1: Ensure that the destination directory exists.
        # If it doesn't exist, create it (including any necessary parent directories).
        os.makedirs(output_dir, exist_ok=True)
        
        # Step 2: Open the video file using OpenCV's VideoCapture interface.
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"Error: Could not open video file {video_path}")
            raise Exception(f"Could not open video file {video_path}")
        
        frame_count = 0
        
        # Step 3: Loop through the video frames one by one.
        while True:
            # Read the next frame from the video stream.
            # 'ret' is a boolean indicating if the frame was successfully read.
            # 'frame' is the image data as a NumPy array (BGR format).
            ret, frame = cap.read()
            
            # If 'ret' is False, we have reached the end of the video file.
            if not ret:
                break
            
            # Step 4: Construct a padded filename for the current frame.
            # We use 5-digit padding (e.g., frame_00000.jpg, frame_00001.jpg) 
            # to ensure the files sort correctly in alphabetical order.
            frame_filename = os.path.join(output_dir, f"frame_{frame_count:05d}.jpg")
            
            # Step 5: Save the frame image to the disk.
            # cv2.imwrite returns True if the file was written successfully.
            success = cv2.imwrite(frame_filename, frame)
            if not success:
                # If writing fails, log the error and stop (usually due to disk space issues).
                print(f"ERROR: Failed to write frame {frame_count} to {frame_filename}. Is the disk full?")
                logger.error(f"Failed to write frame {frame_count} to {frame_filename}. Is the disk full?")
                break
            
            frame_count += 1
            
            # Print a progress update every 100 frames to provide feedback.
            if frame_count % 100 == 0:
                print(f"DEBUG: Extracted {frame_count} frames so far...")
        
        # Step 6: Release the video capture resource to free up system memory.
        cap.release()
        print(f"DEBUG: Extraction complete. Total frames: {frame_count}")
        logger.info(f"Extracted {frame_count} frames to {output_dir}")
        return frame_count
