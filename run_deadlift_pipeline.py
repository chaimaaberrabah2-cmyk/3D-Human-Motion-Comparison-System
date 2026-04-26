import os
import sys
import shutil

# Ajouter le backend au path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.routes.analysis import process_analysis

def run_pipeline_for_deadlift():
    session_id = "deadlift"
    output_root = os.path.join(current_dir, "backend", "data", "frames", session_id)
    
    # Chemins des vidéos qu'on a préparées
    video_paths = [
        os.path.join(output_root, "uploaded", f"camera{i}.mp4")
        for i in range(1, 5)
    ]
    
    # Vérification
    for p in video_paths:
        if not os.path.exists(p):
            print(f"Erreur: Vidéo manquante {p}")
            return

    print(f"🚀 Lancement du pipeline complet pour la session: {session_id}")
    print(f"📂 Sortie: {output_root}")
    
    # Appel de la fonction native de ton pipeline
    process_analysis(
        video_paths=video_paths,
        output_root=output_root,
        exercise="deadlift"
    )

if __name__ == "__main__":
    run_pipeline_for_deadlift()
