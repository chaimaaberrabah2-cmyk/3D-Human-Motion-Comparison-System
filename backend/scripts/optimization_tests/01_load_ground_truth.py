import json
import numpy as np
import os

# Ce fichier a pour but de comprendre la VÉRITÉ ABSOLUE (Ground Truth - GT)
# fournie par les capteurs de pointe de la base de données Fit3D.

def analyser_ground_truth(chemin_fichier="s03/joints3d_25/squat.json"):
    print(f"--- 1. LECTURE DU FICHIER: {chemin_fichier} ---")
    
    if not os.path.exists(chemin_fichier):
        print(f"❌ ERREUR: Fichier introuvable. Assure-toi que tu le lances depuis la racine du projet.")
        return
        
    with open(chemin_fichier, 'r') as f:
        data = json.load(f)
        
    # Le fichier Fit3D est un dictionnaire qui contient la clé 'joints3d_25'
    # Cette clé contient la liste des frames.
    # Chaque frame contient une liste d'articulations (joints).
    # Chaque articulation est une liste de 3 coordonnées [X, Y, Z].
    
    gt_array = np.array(data['joints3d_25'])
    
    print("\n--- 2. DIMENSIONS DES DONNÉES (SHAPE) ---")
    print("Forme du tableau Numpy : ", gt_array.shape)
    
    if len(gt_array.shape) == 3:
        num_frames = gt_array.shape[0]
        num_joints = gt_array.shape[1]
        num_axes = gt_array.shape[2]
        
        print(f"✅ Vidéo capturée sur {num_frames} frames (images).")
        print(f"✅ Squelette VICON composé de {num_joints} points (articulations).")
        print(f"✅ Espace 3D : {num_axes} axes (X, Y, Z).")
    
    print("\n--- 3. ÉCHANTILLON (La première frame) ---")
    # Prenons la première image de la vidéo, et affichons la première articulation (Le nez ou le bassin généralement)
    premiere_frame_premier_point = gt_array[0][0]
    
    print(f"Coordonnées [X, Y, Z] du point n°0 à la Frame 0 : {premiere_frame_premier_point}")
    
    # Explication de l'échelle :
    # Si les chiffres sont petits (ex: 0.10, 1.45), c'est en MÈTRES.
    # Si les chiffres sont grands (ex: 100.5, 1450.2), c'est en MILLIMÈTRES.
    
    if abs(premiere_frame_premier_point[2]) < 10:
        print("💡 ANALYSE ÉCHELLE : Les valeurs semblent être en MÈTRES (ex: 1.45m).")
    else:
        print("💡 ANALYSE ÉCHELLE : Les valeurs semblent être en MILLIMÈTRES (ex: 1450mm).")
        
    print("\n✅ TÂCHE 1 TERMINÉE. Tu as compris à quoi ressemble ton point de comparaison ! L'objectif final sera de demander à ton algorithme de s'approcher le plus possible de ces chiffres X,Y,Z.")

if __name__ == "__main__":
    analyser_ground_truth()
