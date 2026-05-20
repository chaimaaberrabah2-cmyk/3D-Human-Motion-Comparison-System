import os
import sys
import argparse
import shutil
import json

# Ajouter le backend au path pour pouvoir importer les modules
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

# Import services from the duplicate pipeline_test folder
from app.pipeline_test.step1_frame_extractor_service import VideoService
from app.pipeline_test.step2_2d_keypoints_service import PoseService
from app.pipeline_test.step3_3d_keypoints_service import TriangulationService
from app.pipeline_test.step4_smplx_fitting_service import SmplxService

def update_status(output_root: str, status_str: str, progress_percent: int):
    try:
        os.makedirs(output_root, exist_ok=True)
        status_file = os.path.join(output_root, "status.json")
        with open(status_file, "w") as f:
            json.dump({
                "status": status_str,
                "progress_percent": progress_percent
            }, f)
    except Exception as e:
        print(f"ERROR updating status file: {e}")

def local_process_analysis(video_paths, output_root, exercise):
    """Background task logic duplicated here to import services from pipeline_test."""
    print(f"DEBUG: Starting custom background analysis for {len(video_paths)} videos...")
    update_status(output_root, "Phase 1/4: Starting frame extraction...", 5)
    
    # Phase 1: FAST - Extract all frames for all videos first
    print("DEBUG: PHASE 1 - Extracting all frames...")
    for i, path in enumerate(video_paths):
        angle_id = i + 1
        temp_folder = os.path.join(output_root, f"temp{angle_id}")
        try:
            print(f"DEBUG: [Angle {angle_id}] Extracting frames to {temp_folder}...")
            update_status(output_root, f"Phase 1/4: Extracting frames - Camera {angle_id}/4...", 5 + angle_id * 5)
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
                update_status(output_root, f"Phase 2/4: MediaPipe 2D Pose estimation - Camera {i}/4...", 25 + (i - 1) * 10)
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
        update_status(output_root, "Phase 3/4: Starting 3D Triangulation...", 65)
        try:
            # Under the hood, this uses pipeline_test/step3_3d_keypoints_service.py which uses ikram_dataset.json
            keypoints_3d_file = TriangulationService.triangulate(output_root, exercise)
            print("DEBUG: [Phase 3] 3D Triangulation completed successfully.")
            
            update_status(output_root, "Phase 3/4: Generating 3D skeleton visualization...", 75)
            results_3d_dir = os.path.join(output_root, "results_3d")
            TriangulationService.save_3d_visualizations(keypoints_3d_file, results_3d_dir)
            print(f"DEBUG: 3D Visualization photos saved to {results_3d_dir}")
        except Exception as e:
            print(f"ERROR: [Phase 3] Triangulation failed: {e}")
            import traceback
            traceback.print_exc()
    else:
        print(f"DEBUG: Skipping Triangulation (Need at least 2 angles, found {angle_results_count})")

    # Phase 4: SMPL-X Fitting
    if keypoints_3d_file and os.path.exists(keypoints_3d_file):
        print("DEBUG: PHASE 4 - Starting SMPL-X body fitting...")
        update_status(output_root, "Phase 4/4: Fitting 3D SMPL-X body mesh to movement...", 85)
        try:
            SmplxService.fit_and_save(output_root)
            print(f"DEBUG: SMPL-X fitting completed.")
            update_status(output_root, "Phase 4/4: Finalizing ThreeJS 3D viewer package...", 95)
        except Exception as e:
            print(f"ERROR: [Phase 4] SMPL-X fitting failed: {e}")
            import traceback
            traceback.print_exc()
    else:
        print("DEBUG: Skipping SMPL-X fitting (no valid 3D keypoints from Phase 3).")

def run_pipeline(exercise_name):
    print(f"🚀 Lancement du pipeline test complet pour l'exercice: {exercise_name}")
    
    # Chemins des vidéos sources pour le dataset custom
    cameras = ["Lb", "Rb", "Rf", "Lf"]
    dataset_dir = "/Volumes/SSD_Ikram/test dataset"
    video_paths = [
        os.path.join(dataset_dir, f"videos {cam}", f"{exercise_name}.mp4") for cam in cameras
    ]
    
    # Vérifier que les vidéos existent
    missing = [p for p in video_paths if not os.path.exists(p)]
    if missing:
        print(f"❌ Erreur: Vidéos manquantes pour {exercise_name}:")
        for m in missing:
            print(f"  - {m}")
        return

    # Dossier de sortie
    output_root = os.path.join(current_dir, "backend", "data", "frames", f"custom_{exercise_name}")
    os.makedirs(output_root, exist_ok=True)
    
    print(f"📂 Sortie: {output_root}")
    
    # Lancer le traitement local avec les modules de pipeline_test
    try:
        local_process_analysis(
            video_paths=video_paths,
            output_root=output_root,
            exercise="ikram_dataset"
        )
        print(f"\n✅ Pipeline de test terminé avec succès pour {exercise_name}!")
        print(f"🔗 Visualisation: http://localhost:8000/api/v1/sessions/custom_{exercise_name}/viewer")
    except Exception as e:
        print(f"❌ Échec du pipeline de test: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Lancer le pipeline 3D Human Motion (Test Dataset)")
    parser.add_argument("exercise", help="Nom de l'exercice (ex: deadlift, squat)")
    args = parser.parse_args()
    
    run_pipeline(args.exercise)
