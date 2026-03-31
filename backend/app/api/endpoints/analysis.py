from fastapi import APIRouter, UploadFile, File, BackgroundTasks, HTTPException
import os
import uuid
import shutil
from app.services.video_service import VideoService

router = APIRouter()

# Base directories for data
# points to the 'backend' folder
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
UPLOAD_DIR = os.path.join(BASE_DIR, "data", "uploaded")
FRAME_DIR = os.path.join(BASE_DIR, "data", "frames")

@router.post("/analyze")
async def analyze_videos(
    background_tasks: BackgroundTasks,
    angle1: UploadFile = File(None),
    angle2: UploadFile = File(None),
    angle3: UploadFile = File(None),
    angle4: UploadFile = File(None)
):
    """
    Receives 4 videos, saves them, and starts frame extraction in the background.
    """
    # Debug logging
    print(f"Received files: angle1={angle1.filename if angle1 else 'None'}, "
          f"angle2={angle2.filename if angle2 else 'None'}, "
          f"angle3={angle3.filename if angle3 else 'None'}, "
          f"angle4={angle4.filename if angle4 else 'None'}")

    if not all([angle1, angle2, angle3, angle4]):
        missing = []
        if not angle1: missing.append("angle1")
        if not angle2: missing.append("angle2")
        if not angle3: missing.append("angle3")
        if not angle4: missing.append("angle4")
        raise HTTPException(status_code=400, detail=f"Missing files: {', '.join(missing)}")

    session_id = str(uuid.uuid4())
    session_upload_dir = os.path.join(UPLOAD_DIR, session_id)
    session_frame_dir = os.path.join(FRAME_DIR, session_id)
    
    # Ensure directories exist
    os.makedirs(session_upload_dir, exist_ok=True)
    os.makedirs(session_frame_dir, exist_ok=True)
    
    videos = [angle1, angle2, angle3, angle4]
    video_paths = []
    
    # Save the uploaded files
    for i, video in enumerate(videos):
        file_path = os.path.join(session_upload_dir, f"video_{i+1}.mp4")
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(video.file, buffer)
        video_paths.append(file_path)
    
    # Add extraction to background tasks to avoid blocking the request
    background_tasks.add_task(process_analysis, video_paths, session_frame_dir)
    
    return {
        "status": "processing",
        "session_id": session_id,
        "message": "Videos received. Frame extraction started in background."
    }

def process_analysis(video_paths, output_root):
    """Background task to extract frames from all videos."""
    for i, path in enumerate(video_paths):
        # User requested folders: temp1, temp2, temp3, temp4
        temp_folder = os.path.join(output_root, f"temp{i+1}")
        VideoService.extract_frames(path, temp_folder)
        
        # We no longer cleanup the video file here because the user
        # wants to keep it in the 'uploaded' directory.

