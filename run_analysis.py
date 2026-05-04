import os
import sys
import argparse

# Ajouter le backend au path pour pouvoir importer les modules
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.routes.analysis import process_analysis

def run_pipeline(exercise_name):
    print(f"🚀 Lancement du pipeline complet pour l'exercice: {exercise_name}")
    
    # Chemins des vidéos sources (Basés sur la structure réelle de s03)
    cameras = ["50591643Lb", "58860488RB", "60457274RF", "65906101LF"]
    video_paths = [
        f"s03/videos/{cam}/{exercise_name}.mp4" for cam in cameras
    ]
    
    # Vérifier que les vidéos existent
    missing = [p for p in video_paths if not os.path.exists(p)]
    if missing:
        print(f"❌ Erreur: Vidéos manquantes pour {exercise_name}:")
        for m in missing:
            print(f"  - {m}")
        return

    # Dossier de sortie principal sur le SSD (pour ne pas saturer le disque local)
    output_root = f"/Volumes/Ikram's SSD/3D-Human-Motion-Comparison-System/resultat/frames/{exercise_name}"
    os.makedirs(output_root, exist_ok=True)
    
    # Dossier local juste pour le viewer
    local_viewer_dir = os.path.join(current_dir, "backend", "data", "frames", exercise_name)
    os.makedirs(local_viewer_dir, exist_ok=True)
    
    print(f"📂 Traitement complet sur SSD: {output_root}")
    
    # Lancer le traitement complet (Step 1 à 4) sur le SSD
    try:
        process_analysis(
            video_paths=video_paths,
            output_root=output_root,
            exercise=exercise_name
        )
        
        # Copier uniquement le JSON localement pour que le viewer web fonctionne
        import shutil
        ssd_json = os.path.join(output_root, "smplx_threejs.json")
        local_json = os.path.join(local_viewer_dir, "smplx_threejs.json")
        
        if os.path.exists(ssd_json):
            shutil.copy2(ssd_json, local_json)
            print(f"✅ Fichier JSON copié localement pour le viewer: {local_json}")
            
        print(f"\n✅ Pipeline terminé avec succès pour {exercise_name}!")
        print(f"🔗 Visualisation: http://localhost:8000/api/v1/sessions/{exercise_name}/viewer")
    except Exception as e:
        print(f"❌ Échec du pipeline: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Lancer le pipeline 3D Human Motion")
    parser.add_argument("exercise", help="Nom de l'exercice (ex: deadlift, warmup9)")
    args = parser.parse_args()
    
    run_pipeline(args.exercise)
