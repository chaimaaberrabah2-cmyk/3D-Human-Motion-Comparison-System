import os
import sys

# Ajouter le backend au path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.routes.analysis import process_analysis

def run_pipeline(exercise_name):
    print(f"🚀 Lancement du pipeline Test Dataset pour: {exercise_name}")
    
    test_dataset_dir = "/Volumes/SSD_Ikram/test dataset"
    
    # Mapping exact des caméras comme dans la calibration
    camera_dirs = {
        "50591643Lb": "videos Lb",
        "58860488RB": "videos Rb",
        "60457274RF": "videos Rf",
        "65906101LF": "videos Lf"
    }
    
    # Construire les chemins
    video_paths = []
    for cam_id, cam_dir in camera_dirs.items():
        # Essayer mp4 puis MOV
        mp4_path = os.path.join(test_dataset_dir, cam_dir, f"{exercise_name}.mp4")
        mov_path = os.path.join(test_dataset_dir, cam_dir, f"{exercise_name}.MOV")
        
        if os.path.exists(mp4_path):
            video_paths.append(mp4_path)
        elif os.path.exists(mov_path):
            video_paths.append(mov_path)
        else:
            print(f"❌ Erreur: Vidéo manquante pour la caméra {cam_dir} ({exercise_name}.mp4 ou .MOV)")
            return

    # Dossier de sortie
    output_root = os.path.join(current_dir, "backend", "data", "frames", f"test_{exercise_name}")
    os.makedirs(output_root, exist_ok=True)
    
    print(f"📂 Sortie: {output_root}")
    
    # Lancer le traitement
    try:
        # On passe 'ikram_dataset' comme exercise pour qu'il charge ikram_dataset.json !
        process_analysis(
            video_paths=video_paths,
            output_root=output_root,
            exercise="ikram_dataset" 
        )
        print(f"\n✅ Pipeline terminé avec succès pour {exercise_name}!")
        print(f"🔗 Visualisation: http://localhost:8000/api/v1/sessions/test_{exercise_name}/viewer")
    except Exception as e:
        print(f"❌ Échec du pipeline: {e}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise")
    args = parser.parse_args()
    run_pipeline(args.exercise)
