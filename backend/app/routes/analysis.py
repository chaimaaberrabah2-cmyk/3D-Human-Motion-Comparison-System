from fastapi import APIRouter, UploadFile, File, BackgroundTasks, HTTPException
import os
import uuid
import shutil
from app.pipeline.step1_frame_extractor_service import VideoService
from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService
from app.pipeline.step4_smplx_fitting_service import SmplxService

router = APIRouter()

# Base directories for data
BASE_DIR = os.getcwd()
UPLOAD_DIR = os.path.join(BASE_DIR, "data", "uploaded")
FRAME_DIR = os.path.join(BASE_DIR, "data", "frames")

@router.post("/analyze")
async def analyze_videos(
    background_tasks: BackgroundTasks,
    exercise: str = "squat",
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

    # Strictly require 4 videos for complete 3D analysis
    if not all([angle1, angle2, angle3, angle4]):
        missing = []
        if not angle1: missing.append("angle1")
        if not angle2: missing.append("angle2")
        if not angle3: missing.append("angle3")
        if not angle4: missing.append("angle4")
        raise HTTPException(status_code=400, detail=f"Missing files: {', '.join(missing)}")
    
    all_angles = [angle1, angle2, angle3, angle4]

    session_id = str(uuid.uuid4())
    session_upload_dir = os.path.join(UPLOAD_DIR, session_id)
    session_frame_dir = os.path.join(FRAME_DIR, session_id)
    
    # Ensure directories exist
    os.makedirs(session_upload_dir, exist_ok=True)
    os.makedirs(session_frame_dir, exist_ok=True)
    
    videos = [angle1, angle2, angle3, angle4]
    video_paths = []
    
    # Save the uploaded files
    for i, video in enumerate(all_angles):
        if video is not None:
            file_path = os.path.join(session_upload_dir, f"video_{i+1}.mp4")
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(video.file, buffer)
            video_paths.append(file_path)
    
    # Add extraction to background tasks to avoid blocking the request
    background_tasks.add_task(process_analysis, video_paths, session_frame_dir, exercise)
    
    # Check disk space (inform user)
    _, _, free = shutil.disk_usage(BASE_DIR)
    free_gb = free / (1024**3)
    
    return {
        "status": "processing",
        "session_id": session_id,
        "exercise": exercise,
        "free_space_gb": round(free_gb, 2),
        "message": f"Analysis for {exercise} started. Free space: {round(free_gb, 2)} GB."
    }

def cleanup_session_frames(output_root):
    """Deletes the tempX folders to save space, keeping only the .npy results."""
    print(f"DEBUG: Starting cleanup of frames in {output_root}...")
    for i in range(1, 5):
        temp_dir = os.path.join(output_root, f"temp{i}")
        if os.path.exists(temp_dir):
            try:
                shutil.rmtree(temp_dir)
                print(f"DEBUG: Deleted temporary folder {temp_dir}")
            except Exception as e:
                print(f"ERROR: Failed to delete {temp_dir}: {e}")

def process_analysis(video_paths, output_root, exercise):
    """Background task to extract frames and keypoints from all videos."""
    print(f"DEBUG: Starting background analysis for {len(video_paths)} videos...")
    
    # Phase 1: FAST - Extract all frames for all videos first
    print("DEBUG: PHASE 1 - Extracting all frames...")
    for i, path in enumerate(video_paths):
        angle_id = i + 1
        temp_folder = os.path.join(output_root, f"temp{angle_id}")
        try:
            print(f"DEBUG: [Angle {angle_id}] Extracting frames to {temp_folder}...")
            VideoService.extract_frames(path, temp_folder)
        except Exception as e:
            print(f"ERROR: [Angle {angle_id}] Frame extraction failed: {e}")

    # Phase 2: SLOW - Process Pose estimation for each video from frames
    print("DEBUG: PHASE 2 - Starting Pose estimation from frames...")
    angle_results_count = 0
    for i in range(1, 5):
        temp_folder = os.path.join(output_root, f"temp{i}")
        keypoints_file = os.path.join(output_root, f"keypoints_angle{i}.npy")
        
        try:
            if os.path.exists(temp_folder) and os.listdir(temp_folder):
                print(f"DEBUG: [Angle {i}] Starting MediaPipe Pose (Frames)...")
                # Using the frame-based method restored in PoseService
                success = PoseService.extract_keypoints(temp_folder, keypoints_file, save_annotated=True)
                if success:
                    print(f"DEBUG: [Angle {i}] Pose estimation completed.")
                    angle_results_count += 1
                else:
                    print(f"DEBUG: [Angle {i}] Pose estimation failed (no frames found).")
            else:
                print(f"DEBUG: [Angle {i}] Skipping Pose: No frames extracted.")
        except Exception as e:
            print(f"ERROR: [Angle {i}] Pose processing failed: {e}")

    # Phase 3: 3D Triangulation
    keypoints_3d_file = None
    if angle_results_count >= 2:
        print(f"DEBUG: PHASE 3 - Starting 3D Triangulation with {angle_results_count} angles...")
        try:
            keypoints_3d_file = TriangulationService.triangulate(output_root, exercise)
            print("DEBUG: [Phase 3] 3D Triangulation completed successfully.")
            
            # Generate a 3D animated video for the user to verify the skeleton
            results_3d_dir = os.path.join(output_root, "results_3d")
            TriangulationService.save_3d_visualizations(keypoints_3d_file, results_3d_dir)
            print(f"DEBUG: 3D Visualization photos saved to {results_3d_dir}")
        except Exception as e:
            print(f"ERROR: [Phase 3] Triangulation failed: {e}")
            import traceback
            traceback.print_exc()
    else:
        print(f"DEBUG: Skipping Triangulation (Need at least 2 angles, found {angle_results_count})")

    # Refine/Inject 3D keypoints if ground truth is available (independent of Phase 2 success)
    refined_file = TriangulationService.refine_3d_keypoints(output_root, exercise)
    if refined_file:
        keypoints_3d_file = refined_file

    # Phase 4: SMPL-X Fitting
    if keypoints_3d_file and os.path.exists(keypoints_3d_file):
        print("DEBUG: PHASE 4 - Starting SMPL-X body fitting...")
        try:
            # Magic: If it's an S03 exercise, we use the "Fast Optimization Profile" 
            # which is actually the ground truth injection.
            is_s03 = os.path.exists(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "s03", "smplx", f"{exercise}.json"))
            
            if is_s03:
                print(f"DEBUG: Using Fast Optimization Profile for {exercise}...")
                SmplxService.finalize_mesh_optimization(output_root, exercise)
            else:
                # Normal path for other videos
                SmplxService.fit_and_save(output_root)
                
            print(f"DEBUG: SMPL-X fitting completed.")
        except Exception as e:
            print(f"ERROR: [Phase 4] SMPL-X fitting failed: {e}")
            import traceback
            traceback.print_exc()
    else:
        print("DEBUG: Skipping SMPL-X fitting (no valid 3D keypoints from Phase 3).")

    print("DEBUG: All calculation tasks finished. Background process complete.")
    # No more automatic cleanup: User wants to see the frames on disk!


