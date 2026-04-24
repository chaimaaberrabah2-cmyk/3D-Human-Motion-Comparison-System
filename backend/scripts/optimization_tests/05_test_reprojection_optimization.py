import numpy as np
from scipy.optimize import least_squares

# Optimisation via Minimisation de l'Erreur de Reprojection.
# C'est la technique Ultime. 
# Au lieu de faire une seule équation algébrique "DLT", on lance une boucle "d'Essai-Erreur".

def projet_point(point_3d, matrice_camera):
    """Fonction utilitaire: Projette un point 3D en 2D sur l'image d'une caméra."""
    point_homogene = np.array([point_3d[0], point_3d[1], point_3d[2], 1.0])
    projection = matrice_camera @ point_homogene
    # Normalisation
    u = projection[0] / projection[2]
    v = projection[1] / projection[2]
    return np.array([u, v])

def fonction_erreur(point_3d_candidat, points_2d_connus, matrices_cameras):
    """
    C'est la fonction que l'optimiseur va essayer de minimiser (de rendre égale à O).
    """
    erreurs = []
    
    for i in range(len(points_2d_connus)):
        point_reprojeté = projet_point(point_3d_candidat, matrices_cameras[i])
        
        # La différence entre "Où le point devrait atterrir" et "Où le modèle IA 2D l'a mis"
        erreur_x = point_reprojeté[0] - points_2d_connus[i][0]
        erreur_y = point_reprojeté[1] - points_2d_connus[i][1]
        
        erreurs.append(erreur_x)
        erreurs.append(erreur_y)
        
    return np.array(erreurs)

def optimiser_point_3d():
    print("--- 5. TEST DE LA MINIMISATION D'ERREUR (REPROJECTION) ---\n")
    
    # On commence par une estimation initiale brute (par exemple, obtenue avec la DLT classique)
    point_3d_initial = np.array([0.0, 0.0, 5.0]) 
    
    # On a les matrices de nos caméras
    mat1 = np.array([[1000, 0, 500, 0], [0, 1000, 500, 0], [0, 0, 1, 0]])
    mat2 = np.array([[1000, 0, 520, -100], [0, 1000, 500, 0], [0, 0, 1, 0]])
    
    # Les détections réelles des caméras
    points_2d = [
        np.array([500, 500]),
        np.array([518, 500])
    ]
    
    print(f"Point Initial (Estimation DLT): {point_3d_initial}")
    
    # On lance l'algorithme "Levenberg-Marquardt" via scipy
    resultat = least_squares(fonction_erreur, 
                             x0=point_3d_initial, 
                             args=(points_2d, [mat1, mat2]))
                             
    point_3d_parfait = resultat.x
    
    print(f"Point Calculé Parfaitement : {point_3d_parfait}")
    print("\n💡 INTERPRÉTATION : La machine a bougé le point 3D millimètre par millimètre virtuellement jusqu'à trouver l'endroit parfait qui satisfait toutes les caméras en même temps.")
    print("\n✅ TÂCHE 5 TERMINÉE : Tu possèdes maintenant toutes les bases mathématiques pour écrire ton chapitre sur l'optimisation !")

if __name__ == "__main__":
    optimiser_point_3d()
