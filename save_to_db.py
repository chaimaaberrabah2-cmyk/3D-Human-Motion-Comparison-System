import os
import sys
import json
import numpy as np

# Ajouter le backend au path
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.database.setup import SessionLocal, engine, Base
from app.database.models import Movement

def save_exercise_to_db(name, category, difficulty, description, instructions, orientation):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    # Chemins vers les fichiers générés (SUR LE SSD)
    ssd_resultat_dir = f"/Volumes/Ikram's SSD/3D-Human-Motion-Comparison-System/resultat/frames/{name}"
    json_path = os.path.join(ssd_resultat_dir, "smplx_threejs.json")
    npy_path = os.path.join(ssd_resultat_dir, "keypoints_3d.npy")
    
    # Chemins des médias (sur le SSD comme demandé)
    ssd_base_path = "/Volumes/Ikram's SSD/3D-Human-Motion-Comparison-System"
    thumbnail_path = None  # À ajouter plus tard avec les photos réelles
    
    cameras = ["50591643Lb", "58860488RB", "60457274RF", "65906101LF"]
    
    # Chemins des vidéos pour les 4 caméras
    ref_video_paths = {}
    for cam in cameras:
        ref_video_paths[cam] = f"{ssd_base_path}/s03/videos/{cam}/{name}.mp4"
    
    # Calibration des caméras (Lecture des VRAIS fichiers)
    camera_calibration = {}
    
    for cam in cameras:
        calib_path = os.path.join(current_dir, "s03", "camera_parameters", cam, f"{name}.json")
        if os.path.exists(calib_path):
            with open(calib_path, 'r') as f:
                camera_calibration[cam] = json.load(f)
        else:
            print(f"⚠️ Calibration introuvable pour {cam}")
            
    # On stocke uniquement LES CHEMINS vers les gros fichiers 3D (comme on l'a convenu)
    smpl_ref_path = json_path if os.path.exists(json_path) else None
    joints_3d_path = npy_path if os.path.exists(npy_path) else None
    
    print(f"Traitement de {name}...")
    
    existing = db.query(Movement).filter(Movement.name == name).first()
    
    if existing:
        print(f"Mise à jour de l'exercice existant dans la BD...")
        existing.category = category
        existing.difficulty = difficulty
        existing.description = description
        existing.instructions = instructions
        existing.orientation = orientation
        existing.thumbnail_path = thumbnail_path
        existing.reference_video_path = ref_video_paths
        existing.camera_calibration = camera_calibration
        existing.smpl_ref = smpl_ref_path
        existing.joints_3d = joints_3d_path
    else:
        print(f"Création d'un nouvel exercice dans la BD...")
        new_mov = Movement(
            name=name,
            category=category,
            difficulty=difficulty,
            description=description,
            instructions=instructions,
            orientation=orientation,
            thumbnail_path=thumbnail_path,
            reference_video_path=ref_video_paths,
            camera_calibration=camera_calibration,
            smpl_ref=smpl_ref_path,
            joints_3d=joints_3d_path
        )
        db.add(new_mov)
        
    try:
        db.commit()
        print(f"✅ {name} enregistré avec succès dans la base de données avec TOUTES les colonnes !")
    except Exception as e:
        db.rollback()
        print(f"❌ Erreur lors de l'enregistrement: {e}")
    finally:
        db.close()

if __name__ == '__main__':
    instructions = [
        "Commence par des cercles de hanches et des rotations de buste légères.",
        "Effectue des talons-fesses sur place pour réveiller les ischio-jambiers.",
        "Ajoute des balancements de bras latéraux pour ouvrir la cage thoracique.",
        "Enchaîne avec des squats au poids du corps suivis d'une extension des bras.",
        "Termine par des respirations amples pour stabiliser le rythme cardiaque."
    ]
    orientation = {"ax": -1.571, "ay": 0.0, "az": -1.658, "by": 0.90}  # Valeurs optimales
    description = "Routine d'échauffement complète (Warmup 9) axée sur la préparation cardiovasculaire et la mobilité dynamique des grandes chaînes musculaires."
    
    save_exercise_to_db(
        name="warmup_9", 
        category="Échauffement / Mobilité", 
        difficulty="Débutant", 
        description=description,
        instructions=instructions, 
        orientation=orientation
    )










