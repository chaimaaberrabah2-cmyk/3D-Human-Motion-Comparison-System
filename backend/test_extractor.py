import cv2
import numpy as np
import os
import sys

# Add the project root to path so we can import app modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.services.video_service import VideoService

def create_dummy_video(path, frames=5):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*'mp4v'), 10, (100, 100))
    for i in range(frames):
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        img.fill(64 + i * 20)
        cv2.putText(img, f"F:{i}", (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        out.write(img)
    out.release()
    print(f"Created dummy video at {path}")

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    session_id = "demo_session123"
    
    upload_dir = os.path.join(base_dir, "data", "uploads", session_id)
    frames_dir = os.path.join(base_dir, "data", "frames", session_id)
    
    print(f"--- Démarrage du test d'extraction ---")
    
    # Simulate receiving 4 videos
    for i in range(1, 5):
        video_path = os.path.join(upload_dir, f"video_{i}.mp4")
        temp_folder = os.path.join(frames_dir, f"temp{i}")
        
        create_dummy_video(video_path, frames=5)
        
        print(f"Extraction des frames pour la vidéo {i} vers {temp_folder}...")
        count = VideoService.extract_frames(video_path, temp_folder)
        print(f"-> Succès : {count} frames extraites.")
        
    print(f"--- Fichiers dans les dossiers ---")
    for i in range(1, 5):
        temp_folder = os.path.join(frames_dir, f"temp{i}")
        files = os.listdir(temp_folder)
        print(f"\nDossier : {temp_folder}")
        for f in files:
            print(f"  - {f}")

if __name__ == "__main__":
    main()
