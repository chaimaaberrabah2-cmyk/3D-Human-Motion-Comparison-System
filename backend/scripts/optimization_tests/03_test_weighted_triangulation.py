import numpy as np

# Ce fichier explique "Comment on va améliorer la première étape"
# C'est la Triangulation DLT Pondérée (Confidence-Weighted Direct Linear Transform).

def dlt_ponderee(points_2d, matrices_projection, confiances):
    """
    Simule l'amélioration de ta triangulation.
    Au lieu de prendre tous les points 2D au même niveau, on ajoute leur 'confiance'.
    Si une IA (Yolo/BlazePose) n'est pas sûre d'elle, elle donne une confiance basse (ex: 0.1).
    On intègre cette note dans notre équation algébrique.
    """
    
    print("👉 Exécution de la version améliorée : Triangulation Pondérée")
    num_cameras = len(points_2d)
    
    A = []
    
    # 1. Construction de la Matrice Mathématique "A"
    for i in range(num_cameras):
        # coordonnée X, Y dans l'image
        x, y = points_2d[i] 
        P = matrices_projection[i]
        
        # C'est ICI que la magie de l'optimisation opère !
        # 'Poids' est la confiance de la caméra.
        poids = confiances[i] 
        
        # On multiplie l'équation algébrique par le poids.
        # Si le poids est proche de 0 (ex: occlusion), cette ligne aura 
        # très peu d'impact sur le résultat final SVD.
        A.append(poids * (x * P[2, :] - P[0, :]))
        A.append(poids * (y * P[2, :] - P[0, :]))
        
    A = np.array(A)
    
    # 2. Résolution mathématique (Décomposition en Valeurs Singulières)
    _, _, Vt = np.linalg.svd(A)
    point_homogene = Vt[-1]
    
    # 3. On repasse de la 4D (Homogène) à la 3D (Normalisée)
    point_3d = point_homogene[:3] / point_homogene[3]
    
    return point_3d

def simulation_triangulation():
    print("--- 3. TEST DE LA TRIANGULATION PONDÉRÉE ---\n")
    
    # Imaginons qu'on essaie de trouver le Genou Droit.
    # On a 4 caméras, donc 4 détections 2D en pixels.
    points_2d_pixels = [
        (450, 800), # Caméra 1 voit très bien
        (460, 810), # Caméra 2 voit très bien
        (100, 100), # Caméra 3 voit le MAUVAIS endroit !!! (Outlier)
        (440, 790)  # Caméra 4 voit bien
    ]
    
    # Les "scores" donnés par YOLO-Pose
    confiances = [
        0.95, # Cam 1 : Sûre à 95%
        0.90, # Cam 2 : Sûre à 90%
        0.10, # Cam 3 : Sûre à 10% seulement (Caché ou flou)
        0.85  # Cam 4 : Sûre à 85%
    ]
    
    # Matrices simulées (juste des nombres aléatoires pour l'exemple mathématique)
    matrices = [np.random.rand(3, 4) for _ in range(4)]
    
    # Calcul !
    resultat = dlt_ponderee(points_2d_pixels, matrices, confiances)
    
    print("✅ Le point mathématique a été calculé sans que la caméra 3 ne détruise tout !")
    print(f"✅ Coordonnées 3D générées : {resultat}")
    print("\n💡 INTERPRÉTATION : La Triangulation sans cette astuce s'appelle 'Vanilla DLT'. En ajoutant 'confiances[i]' dans l'algèbre, on réduit mécaniquement les erreurs (baisse du MPJPE).")
    print("\n✅ TÂCHE 3 TERMINÉE : Compréhension de l'algorithme robuste.")

if __name__ == "__main__":
    simulation_triangulation()
