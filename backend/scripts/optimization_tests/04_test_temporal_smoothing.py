import numpy as np
from scipy.signal import savgol_filter

# Lissage Temporel (Temporal Smoothing)
# C'est la technique n°2 pour baisser l'erreur.
# Un humain ne fait pas de mouvements de téléportation, mais notre caméra parfois bug 
# et place le point du nez à 1 mètre de sa position en 1 seule frame (le "jittering").
# Nous utilisons un filtre de traitement du signal pour lisser la courbe.

def lissage_temporel(mouvement_3d_brut):
    """
    Applique le filtre de Savitzky-Golay.
    mouvement_3d_brut : Array de forme (N_frames, 3) pour UNE seule articulation.
    """
    
    # Paramètres du filtre
    taille_fenetre = 11  # Le nombre de frames regardées pour lisser (doit être impair)
    ordre_polynome = 3   # Ajustement algorithmique
    
    # Si la vidéo est trop courte, on ne lisse pas.
    if len(mouvement_3d_brut) < taille_fenetre:
        return mouvement_3d_brut
        
    mouvement_lisse = np.zeros_like(mouvement_3d_brut)
    
    # On applique le filtre séparément sur l'axe X, puis Y, puis Z.
    for axe in range(3):
        mouvement_lisse[:, axe] = savgol_filter(mouvement_3d_brut[:, axe], 
                                                window_length=taille_fenetre, 
                                                polyorder=ordre_polynome)
                                                
    return mouvement_lisse

def test_lissage():
    print("--- 4. TEST DU LISSAGE TEMPOREL D'UNE ARTICULATION ---\n")
    
    # 1. On fabrique une fausse trajectoire parfaite (un nez qui avance doucement)
    frames = 50
    trajectoire_parfaite = np.linspace([0, 0, 0], [1, 1, 1], frames)
    
    # 2. Le détecteur 2D est mauvais, il introduit du tremblement ("jitter")
    bruit = np.random.normal(0, 0.05, trajectoire_parfaite.shape)
    trajectoire_bruitée = trajectoire_parfaite + bruit
    
    # À la frame 25, on ajoute un énorme bug de Yolo-Pose (Outlier monumental)
    trajectoire_bruitée[25] = [2.0, 2.0, 2.0] 
    
    # 3. L'algorithme de protection s'active
    trajectoire_reparee = lissage_temporel(trajectoire_bruitée)
    
    print(f"👉 Avant (Erreur Frame 25) : {trajectoire_bruitée[25]}")
    print(f"👉 Après Lissage (Frame 25) : {trajectoire_reparee[25]}")
    
    print("\n💡 INTERPRÉTATION : La trajectoire a été lissée en prenant compte des valeurs passées et futures. L'erreur énorme de la frame 25 a été mathématiquement étouffée.")
    print("\n✅ TÂCHE 4 TERMINÉE : Le Jitter est l'ennemi de ton MPJPE. Ce script t'apprend comment l'éliminer.")

if __name__ == "__main__":
    test_lissage()
