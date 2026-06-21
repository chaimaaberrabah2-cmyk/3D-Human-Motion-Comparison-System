from fastapi import APIRouter, UploadFile, File, BackgroundTasks, HTTPException
import os
import uuid
import json
import shutil
import traceback
from datetime import datetime
from app.pipeline.step1_frame_extractor_service import VideoService
from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService
from app.pipeline.step4_smplx_ik_service import SmplxService

router = APIRouter()

BASE_DIR = os.getcwd()
UPLOAD_DIR = os.path.join(BASE_DIR, "data", "uploaded")
FRAME_DIR = os.path.join(BASE_DIR, "data", "frames")


@router.post("/analyze")
async def analyze_videos(
    background_tasks: BackgroundTasks,
    exercise: str = "deadlift",
    establishment_id: int = None,
    user_id: int = None,
    angle1: UploadFile = File(None),
    angle2: UploadFile = File(None),
    angle3: UploadFile = File(None),
    angle4: UploadFile = File(None),
):
    print(f"Received files: angle1={angle1.filename if angle1 else 'None'}, "
          f"angle2={angle2.filename if angle2 else 'None'}, "
          f"angle3={angle3.filename if angle3 else 'None'}, "
          f"angle4={angle4.filename if angle4 else 'None'}")

    if not all([angle1, angle2, angle3, angle4]):
        missing = [f"angle{i+1}" for i, a in enumerate([angle1, angle2, angle3, angle4]) if not a]
        raise HTTPException(status_code=400, detail=f"Missing files: {', '.join(missing)}")

    session_id = str(uuid.uuid4())
    session_upload_dir = os.path.join(UPLOAD_DIR, session_id)
    session_frame_dir = os.path.join(FRAME_DIR, session_id)
    os.makedirs(session_upload_dir, exist_ok=True)
    os.makedirs(session_frame_dir, exist_ok=True)

    video_paths = []
    for i, video in enumerate([angle1, angle2, angle3, angle4]):
        file_path = os.path.join(session_upload_dir, f"video_{i+1}.mp4")
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(video.file, buffer)
        video_paths.append(file_path)

    background_tasks.add_task(
        process_analysis, video_paths, session_frame_dir, exercise,
        establishment_id=establishment_id, user_id=user_id
    )

    _, _, free = shutil.disk_usage(BASE_DIR)
    return {
        "status": "processing",
        "session_id": session_id,
        "exercise": exercise,
        "free_space_gb": round(free / (1024 ** 3), 2),
        "message": f"Analysis for {exercise} started.",
    }


def update_status(output_root: str, status_str: str, progress_percent: int, extra_data: dict = None):
    try:
        os.makedirs(output_root, exist_ok=True)
        status_file = os.path.join(output_root, "status.json")
        data = {}
        if os.path.exists(status_file):
            try:
                with open(status_file) as f:
                    data = json.load(f)
            except Exception:
                pass

        data["status"] = status_str
        data["status_message"] = status_str
        data["progress_percent"] = progress_percent

        # Append timestamped log entry
        logs = data.get("logs", [])
        ts = datetime.now().strftime("%H:%M:%S")
        logs.append(f"[{ts}] {status_str}")
        data["logs"] = logs

        if extra_data:
            data.update(extra_data)

        with open(status_file, "w") as f:
            json.dump(data, f)
    except Exception as e:
        print(f"ERROR updating status file: {e}")


def cleanup_session_frames(output_root):
    for i in range(1, 5):
        temp_dir = os.path.join(output_root, f"temp{i}")
        if os.path.exists(temp_dir):
            try:
                shutil.rmtree(temp_dir)
            except Exception as e:
                print(f"ERROR: Failed to delete {temp_dir}: {e}")


def _get_establishment_calibration(establishment_id: int, output_root: str):
    """
    Fetch calibration from DB for the given establishment.
    Returns (calib_files, img_w, img_h) or (None, None, None) to fall back to s03.
    """
    try:
        from app.database.setup import SessionLocal
        from app.database.models import Establishment
        db = SessionLocal()
        est = db.query(Establishment).filter(
            Establishment.establishment_id == establishment_id
        ).first()
        db.close()

        if not est or not est.calibration_data:
            print(f"DEBUG: No calibration in DB for establishment {establishment_id}. Using s03 default.")
            return None, None, None

        calib_data = est.calibration_data
        cameras = calib_data.get("cameras", ["Lb", "Lf", "Rb", "Rf"])
        img_w = calib_data.get("img_w", 1920)
        img_h = calib_data.get("img_h", 1440)

        calib_dir = os.path.join(output_root, "_calibration")
        os.makedirs(calib_dir, exist_ok=True)
        calib_files = []
        for cam in cameras:
            cam_data = calib_data.get(cam)
            if not cam_data:
                print(f"WARNING: Missing calibration for camera {cam}. Using s03 default.")
                return None, None, None
            cam_file = os.path.join(calib_dir, f"{cam}_calibration.json")
            with open(cam_file, "w") as f:
                json.dump(cam_data, f)
            calib_files.append(cam_file)

        print(f"DEBUG: Using establishment calibration for {cameras}, img={img_w}x{img_h}")
        return calib_files, img_w, img_h

    except Exception as e:
        print(f"WARNING: Could not load establishment calibration: {e}")
        return None, None, None


def _save_performance_to_db(user_id: int, exercise: str, score_res: dict, output_root: str):
    """Save completed analysis to the performances table."""
    try:
        from app.database.setup import SessionLocal
        from app.database.models import Performance, Movement
        db = SessionLocal()

        movement = db.query(Movement).filter(Movement.name == exercise).first()
        if not movement:
            db.close()
            print(f"WARNING: Movement '{exercise}' not found in DB. Skipping performance save.")
            return

        perf = Performance(
            user_id=user_id,
            movement_id=movement.movement_id,
            score=score_res.get("score_out_of_100"),
            feedback_txt=json.dumps(score_res.get("feedbacks", [])),
            results_3d={"session_path": output_root},
        )
        db.add(perf)
        db.commit()
        db.refresh(perf)
        db.close()
        print(f"DEBUG: Performance saved with id={perf.performance_id}")
    except Exception as e:
        print(f"ERROR saving performance to DB: {e}")
        traceback.print_exc()


def process_analysis(video_paths, output_root, exercise, establishment_id=None, user_id=None):
    """Background task: extract frames, pose, triangulate, fit SMPL-X, score."""
    print(f"DEBUG: Starting background analysis for {len(video_paths)} videos...")
    update_status(output_root, "Phase 1/4: Starting frame extraction...", 5)

    # ── Phase 1: Frame extraction ────────────────────────────────────────────
    for i, path in enumerate(video_paths):
        angle_id = i + 1
        temp_folder = os.path.join(output_root, f"temp{angle_id}")
        try:
            update_status(output_root, f"Phase 1/4: Extracting frames — Camera {angle_id}/4...", 5 + angle_id * 5)
            VideoService.extract_frames(path, temp_folder)
        except Exception as e:
            print(f"ERROR: [Angle {angle_id}] Frame extraction failed: {e}")

    # ── Phase 2: 2D Pose estimation ──────────────────────────────────────────
    update_status(output_root, "Phase 2/4: Running MediaPipe 2D pose detection...", 25)
    angle_results_count = 0
    for i in range(1, 5):
        temp_folder = os.path.join(output_root, f"temp{i}")
        keypoints_file = os.path.join(output_root, f"keypoints_angle{i}.npy")
        try:
            if os.path.exists(temp_folder) and os.listdir(temp_folder):
                update_status(output_root, f"Phase 2/4: MediaPipe 2D pose — Camera {i}/4...", 25 + (i - 1) * 10)
                success = PoseService.extract_keypoints(temp_folder, keypoints_file, save_annotated=True)
                if success:
                    angle_results_count += 1
                    update_status(output_root, f"Phase 2/4: Camera {i}/4 pose done ✓", 25 + i * 10)
        except Exception as e:
            print(f"ERROR: [Angle {i}] Pose processing failed: {e}")

    # ── Phase 3: 3D Triangulation ────────────────────────────────────────────
    keypoints_3d_file = None
    if angle_results_count >= 2:
        update_status(output_root, "Phase 3/4: Triangulating 3D skeleton (DLT solver)...", 65)

        # Determine calibration: use establishment's if available, else s03 default
        calib_files, img_w, img_h = None, None, None
        if establishment_id:
            calib_files, img_w, img_h = _get_establishment_calibration(establishment_id, output_root)

        try:
            kwargs = {}
            if calib_files:
                kwargs["calib_files"] = calib_files
            if img_w:
                kwargs["img_w"] = img_w
            if img_h:
                kwargs["img_h"] = img_h
            keypoints_3d_file = TriangulationService.triangulate(output_root, exercise, **kwargs)
            update_status(output_root, "Phase 3/4: Generating 3D skeleton visualizations...", 75)
            TriangulationService.save_3d_visualizations(
                keypoints_3d_file, os.path.join(output_root, "results_3d")
            )
            update_status(output_root, "Phase 3/4: 3D triangulation complete ✓", 78)

            # ── Auto exercise detection ──────────────────────────────────────
            try:
                from app.comparaison.auto_detect import detect_exercise
                detection = detect_exercise(keypoints_3d_file, FRAME_DIR)
                det_name = detection.get("detected") or "unclear"
                det_conf = detection.get("confidence", 0.0)
                update_status(
                    output_root,
                    f"Auto-detected exercise: {det_name} (confidence={det_conf:.0%})",
                    80,
                    extra_data={"detected_exercise": detection},
                )
            except Exception as e:
                print(f"WARNING: Auto-detect failed: {e}")

        except Exception as e:
            print(f"ERROR: [Phase 3] Triangulation failed: {e}")
            traceback.print_exc()
    else:
        update_status(output_root, f"Phase 3/4: Skipped (only {angle_results_count}/4 cameras valid)", 65)

    # ── Phase 4: SMPL-X Fitting ──────────────────────────────────────────────
    if keypoints_3d_file and os.path.exists(keypoints_3d_file):
        update_status(output_root, "Phase 4/4: Fitting SMPL-X body mesh (L-BFGS optimizer)...", 85)
        try:
            SmplxService.fit_and_save(output_root)
            update_status(output_root, "Phase 4/4: SMPL-X fitting complete ✓. Packaging 3D viewer...", 95)
        except Exception as e:
            print(f"ERROR: [Phase 4] SMPL-X fitting failed: {e}")
            traceback.print_exc()
    else:
        update_status(output_root, "Phase 4/4: Skipped SMPL-X (no valid 3D keypoints)", 85)

    # ── Phase 5: Comparison Scoring ──────────────────────────────────────────
    comparison_results = None
    score_res = {}
    if keypoints_3d_file and os.path.exists(keypoints_3d_file):
        update_status(output_root, "Phase 5/5: Comparing against expert reference (DTW)...", 96)
        try:
            from app.comparaison.angle_score import generate_angle_score
            ref_path = os.path.join(FRAME_DIR, exercise, "keypoints_3d.npy")
            if os.path.exists(ref_path):
                score_res = generate_angle_score(ref_path, keypoints_3d_file)
                comparison_results = {
                    "score": score_res.get("score_out_of_100", 0.0),
                    "mean_angle_error_deg": score_res.get("mean_angle_error_deg", 0.0),
                    "dtw_normalized_distance": score_res.get("dtw_normalized_distance", 0.0),
                    "aligned_frames_count": score_res.get("aligned_frames_count", 0),
                    "per_joint_errors_deg": score_res.get("per_joint_errors_deg", {}),
                    "feedbacks": score_res.get("feedbacks", []),
                }
                update_status(output_root, "Complete: 3D Body Reconstruction is ready!", 100,
                              extra_data={"comparison_results": comparison_results})
            else:
                update_status(output_root, "Complete: 3D Body Reconstruction is ready!", 100)
        except Exception as e:
            print(f"ERROR: [Phase 5] Scoring failed: {e}")
            traceback.print_exc()
            update_status(output_root, "Complete: 3D Body Reconstruction is ready!", 100)
    else:
        update_status(output_root, "Complete: 3D Body Reconstruction is ready!", 100)

    # ── Save Performance to DB ───────────────────────────────────────────────
    if user_id and comparison_results:
        _save_performance_to_db(user_id, exercise, score_res, output_root)

    print("DEBUG: Background process complete.")
