import os
import sys
import argparse
import shutil

# Ajouter le backend au path pour pouvoir importer les modules
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.pipeline.step1_frame_extractor_service import VideoService
from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService
from app.pipeline.step4_smplx_fitting_service import SmplxService

def run_test_pipeline(exercise_name):
    print(f"🚀 Lancement du pipeline complet pour l'exercice: {exercise_name} (Test Dataset)")
    
    dataset_root = "/Volumes/SSD_Ikram/test dataset"
    cameras = ["Lb", "Lf", "Rb", "Rf"]
    
    video_paths = []
    for cam in cameras:
        # Some videos are .MOV, some might be .mp4. We check.
        mov_path = os.path.join(dataset_root, f"videos {cam}", f"{exercise_name}.MOV")
        mp4_path = os.path.join(dataset_root, f"videos {cam}", f"{exercise_name}.mp4")
        if os.path.exists(mov_path):
            video_paths.append(mov_path)
        elif os.path.exists(mp4_path):
            video_paths.append(mp4_path)
        else:
            video_paths.append(mov_path) # Fallback to print error on MOV
    
    missing = [p for p in video_paths if not os.path.exists(p)]
    if missing:
        print(f"❌ Erreur: Vidéos manquantes pour {exercise_name}:")
        for m in missing:
            print(f"  - {m}")
        return

    output_root = f"/Volumes/SSD_Ikram/3D-Human-Motion-Comparison/{exercise_name}"
    os.makedirs(output_root, exist_ok=True)
    
    local_viewer_dir = os.path.join(current_dir, "backend", "data", "frames", exercise_name)
    os.makedirs(local_viewer_dir, exist_ok=True)
    
    print(f"📂 Traitement complet sur SSD: {output_root}")
    
    try:
        # Phase 1: Extraction
        print("\n--- PHASE 1: Extraction de frames ---")
        for i, path in enumerate(video_paths):
            angle_id = i + 1
            temp_folder = os.path.join(output_root, f"temp{angle_id}")
            print(f"Extraction {path} -> {temp_folder}")
            VideoService.extract_frames(path, temp_folder)
            
        # Phase 2: MediaPipe 2D
        print("\n--- PHASE 2: MediaPipe 2D Pose ---")
        angle_results_count = 0
        for i in range(1, 5):
            temp_folder = os.path.join(output_root, f"temp{i}")
            keypoints_file = os.path.join(output_root, f"keypoints_angle{i}.npy")
            if os.path.exists(temp_folder) and os.listdir(temp_folder):
                # save_annotated=True ensures we see the 2D results for debugging
                success = PoseService.extract_keypoints(temp_folder, keypoints_file, save_annotated=True)
                if success: angle_results_count += 1
                
        # Phase 3: Triangulation 3D
        keypoints_3d_file = None
        if angle_results_count >= 2:
            print("\n--- PHASE 3: Triangulation 3D (Résolution: 1920x1440) ---")
            # PASSING THE CORRECT RESOLUTION 1920x1440
            keypoints_3d_file = TriangulationService.triangulate(
                output_root, exercise_name, dataset_type="test_dataset",
                img_w=1920, img_h=1440
            )
            
            # Save 3D vis
            if keypoints_3d_file:
                results_3d_dir = os.path.join(output_root, "results_3d")
                TriangulationService.save_3d_visualizations(keypoints_3d_file, results_3d_dir)
        else:
            print(f"❌ Échec Phase 2: Pas assez de vues valides ({angle_results_count}/4).")
            return
            
        # Refinement is bypassed for test_dataset inside refine_3d_keypoints
        TriangulationService.refine_3d_keypoints(output_root, exercise_name, dataset_type="test_dataset")
        
        # Phase 4: SMPL-X
        if keypoints_3d_file and os.path.exists(keypoints_3d_file):
            print("\n--- PHASE 4: Optimisation SMPL-X ---")
            SmplxService.fit_and_save(output_root, n_iter=20)
        else:
            print("❌ Échec Phase 3: Fichier keypoints_3d_file introuvable.")
            return

        # Copie JSON localement
        ssd_json = os.path.join(output_root, "smplx_threejs.json")
        local_json = os.path.join(local_viewer_dir, "smplx_threejs.json")
        
        if os.path.exists(ssd_json):
            shutil.copy2(ssd_json, local_json)
            print(f"\n✅ Fichier JSON copié localement pour le viewer: {local_json}")
            
        print(f"\n✅ Pipeline terminé avec succès pour {exercise_name}!")
        print(f"🔗 Visualisation: http://localhost:8000/api/v1/sessions/{exercise_name}/viewer")
        
    except Exception as e:
        print(f"❌ Échec du pipeline: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Lancer le pipeline sur Test Dataset")
    parser.add_argument("exercise", help="Nom de l'exercice (ex: deadlift)")
    args = parser.parse_args()
    
    run_test_pipeline(args.exercise)
