import json
import numpy as np
import os

# Ce fichier t'explique la fonction MATHÉMATIQUE de l'Évaluation : Le MPJPE.
# MPJPE veut dire "Mean Per Joint Position Error" (Erreur moyenne de position par articulation).
# C'est la métrique standard mondiale pour évaluer l'estimation de pose 3D.

def load_gt_data(chemin_fichier):
    with open(chemin_fichier, 'r') as f:
        data = json.load(f)
        return np.array(data['joints3d_25'])

def calculate_mpjpe(predictions_3d, ground_truth_3d):
    """
    Calcule l'erreur moyenne entre les prédictions de ton algorithme et la réalité.
    
    predictions_3d : array de forme [frames, 25, 3] (Tes résultats)
    ground_truth_3d : array de forme [frames, 25, 3] (Les résultats VICON Fit3D)
    
    Retourne l'erreur moyenne en MÈTRES (ou millimètres, selon ton format).
    """
    # 1. On vérifie que les tailles sont exactement les mêmes
    assert predictions_3d.shape == ground_truth_3d.shape, "❌ Erreur : Format de données incompatible"
    
    # 2. La Distance Euclidienne
    # Mathématiques : distance = racine_carrée(diff_x^2 + diff_y^2 + diff_z^2)
    diff = predictions_3d - ground_truth_3d
    distances = np.linalg.norm(diff, axis=2) # Axis 2 correspond aux 3 coordonnées [X, Y, Z]
    
    # 3. La Moyenne Globale
    # On fait la moyenne de toutes ces distances pour obtenir un seul chiffre final.
    mpjpe = np.mean(distances)
    
    return mpjpe

def simulation_baseline():
    print("--- 1. CALCUL DU MPJPE (BASELINE) ---\n")
    chemin_gt = "s03/joints3d_25/squat.json"
    
    if not os.path.exists(chemin_gt):
        print(f"❌ ERREUR: Fichier introuvable ({chemin_gt})")
        return
        
    gt_3d = load_gt_data(chemin_gt)
    print(f"✅ Ground Truth VICON chargé. ({len(gt_3d)} frames)")
    
    # --------------------------------------------------------------------------
    # SIMULATION D'ERREUR POUR L'EXEMPLE
    # Comme nous n'avons pas encore connecté la vraie fonction de ton TriangulationService,
    # nous allons simuler les prédictions de ton algorithme en ajoutant du "bruit" au Ground Truth.
    # Disons que ton algorithme actuel fait une erreur moyenne de 8 centimètres (0.08m) = 80mm.
    # --------------------------------------------------------------------------
    
    # On copie le GT, mais on ajoute un décalage aléatoire (bruit)
    bruit_moteur = np.random.normal(loc=0.0, scale=0.08, size=gt_3d.shape)
    mes_predictions_actuelles = gt_3d + bruit_moteur
    
    # CALCUL !
    erreur_en_metres = calculate_mpjpe(mes_predictions_actuelles, gt_3d)
    erreur_en_millimetres = erreur_en_metres * 1000
    
    print(f"\n--- RÉSULTATS DE L'ÉVALUATION ---")
    print(f"👉 Ton MPJPE actuel est estimé à : {erreur_en_metres:.4f} mètres.")
    print(f"👉 Soit : {erreur_en_millimetres:.2f} mm d'erreur en moyenne par articulation.")
    
    print("\n💡 INTERPRÉTATION : Si le vrai genou est à la position X, ton algorithme dit qu'il se trouve (en moyenne) à 80mm de cette position.")
    print("\n✅ TÂCHE 2 TERMINÉE : Tu as compris comment évaluer officiellement ton système.")

if __name__ == "__main__":
    simulation_baseline()
