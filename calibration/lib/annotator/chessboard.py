# Module de détection de l'échiquier (Chessboard Logic)
# Importation de numpy pour les calculs sur les grilles de points
import numpy as np
# Importation d'OpenCV pour le traitement d'image et la détection de coins
import cv2
# Importation pour gérer le temps d'attente maximum d'une fonction
from func_timeout import func_set_timeout

# Fonction pour créer les points 3D théoriques de l'échiquier
def getChessboard3d(pattern, gridSize, axis='xy'):
    # Crée un tableau de zéros pour stocker les coordonnées (x,y,z)
    object_points = np.zeros((pattern[1]*pattern[0], 3), np.float32)
    # Crée une grille de base (0,0), (1,0)... pour le motif choisi
    object_points[:,:2] = np.mgrid[0:pattern[0], 0:pattern[1]].T.reshape(-1,2)
    # Inverse les colonnes X et Y pour correspondre au standard OpenCV
    object_points[:, [0, 1]] = object_points[:, [1, 0]]
    # Multiplie par la taille réelle des cases (mètres)
    object_points = object_points * gridSize
    # Gère l'axe Z si demandé (format spécifique)
    if axis == 'zx':
        object_points = object_points[:, [1, 2, 0]]
    # Retourne les points 3D mathématiques
    return object_points

# Fonction interne pour détecter les coins avec OpenCV
def _findChessboardCorners(img, pattern, debug):
    # Définit les critères de précision pour la détection de sous-pixels
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)
    
    # Tentative avec la méthode SB (Sector Based), très robuste aux reflets
    try:
        # Cherche la grille de manière exhaustive et précise
        ret, corners = cv2.findChessboardCornersSB(img, pattern, flags=cv2.CALIB_CB_ACCURACY + cv2.CALIB_CB_EXHAUSTIVE)
        # Si trouvé, on retourne les points nettoyés
        if ret:
            return True, corners.squeeze()
    except AttributeError:
        # En cas d'absence de la fonction SB dans cette version d'OpenCV
        pass
        
    # Méthode standard de secours (Adaptive Thresholding + Normalization)
    retval, corners = cv2.findChessboardCorners(img, pattern, 
        flags=cv2.CALIB_CB_ADAPTIVE_THRESH + cv2.CALIB_CB_NORMALIZE_IMAGE + cv2.CALIB_CB_FILTER_QUADS)
    # Si rien n'est trouvé, on retourne un échec
    if not retval:
        return False, None
    # Affine la position des coins au niveau du pixel (SubPix)
    corners = cv2.cornerSubPix(img, corners, (11, 11), (-1, -1), criteria)
    # Retourne les points
    return True, corners.squeeze()

# Fonction principale de détection (C'est ici que nos filtres agissent)
@func_set_timeout(5) # Limite le calcul à 5 secondes par image
def findChessboardCorners(img, annots, pattern, debug=False):
    # On regarde si l'image a déjà été traitée avec succès
    conf = sum([v[2] for v in annots['keypoints2d']])
    # Si déjà visitée et détection valide, on ne refait rien
    if annots['visited'] and conf > 0:
        return True
    # Si déjà visitée mais échec, on arrête
    elif annots['visited']:
        return None
    # Marque l'image comme étant en cours de visite
    annots['visited'] = True
    
    # Récupère les dimensions de l'image (Hauteur, Largeur)
    h, w = img.shape[:2]
    # Applique un recadrage (Crop) pour ignorer les bords inutiles de l'image
    margin_w = int(w * 0.1) # 10% de marge à gauche et à droite
    margin_h = int(h * 0.05) # 5% de marge en haut et en bas
    img_cropped = img[margin_h:h-margin_h, margin_w:w-margin_w]
    
    # Conversion en niveaux de gris
    gray_orig = cv2.cvtColor(img_cropped, cv2.COLOR_BGR2GRAY)
    # Amélioration du contraste (CLAHE) pour mieux voir dans les zones sombres
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    gray_orig = clahe.apply(gray_orig)
    
    # Variable pour stocker les meilleurs coins détectés
    best_corners = None
    # Création des points 2D théoriques pour la validation homographique
    objp = np.zeros((pattern[0]*pattern[1], 2), np.float32)
    objp[:,:2] = np.mgrid[0:pattern[0], 0:pattern[1]].T.reshape(-1, 2)

    # Teste deux échelles d'image (Taille réelle et 50%) pour plus de robustesse
    for scale in [1.0, 0.5]:
        sw = int(gray_orig.shape[1] * scale)
        sh = int(gray_orig.shape[0] * scale)
        # Redimensionnement
        gray = cv2.resize(gray_orig, (sw, sh), interpolation=cv2.INTER_AREA)
        
        # Teste l'image normale ET l'image avec une bordure blanche (Padding)
        for padded in [False, True]:
            test_img = gray
            pad = int(100 * scale) if padded else 0
            if padded:
                # Ajoute une bordure blanche pour aider OpenCV si l'échiquier touche le bord
                test_img = cv2.copyMakeBorder(gray, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=255)
            
            # Appel de la fonction de détection OpenCV
            ret, corners = _findChessboardCorners(test_img, pattern, debug)
            # Si une grille est trouvée
            if ret:
                corners = corners.reshape(-1, 2)
                # Remise à l'échelle si on avait ajouté une bordure ou réduit l'image
                if pad > 0:
                    corners[:, 0] -= pad
                    corners[:, 1] -= pad
                corners /= scale
                
                # Remet les points dans les coordonnées de l'image originale (avant le crop)
                corners[:, 0] += margin_w
                corners[:, 1] += margin_h
                
                # --- ÉTAPE DE VALIDATION ROBUSTE (Nos filtres) ---
                # 1. Filtre Homographique : Vérifie si la grille est plane et cohérente
                H, mask = cv2.findHomography(objp, corners, cv2.RANSAC, 5.0)
                # On exige que TOUS les points (100%) soient cohérents avec la grille
                if H is not None and mask.sum() == len(objp):
                    # 2. Erreur de reprojection : Vérifie la précision géométrique
                    proj = cv2.perspectiveTransform(objp.reshape(-1, 1, 2), H).reshape(-1, 2)
                    err = np.linalg.norm(proj - corners, axis=1).mean()
                    # Si l'erreur est trop grande (> 5 pixels), c'est une fausse détection
                    if err > 5.0:
                        continue
                    
                    # 3. Vérification de Convexité : Évite les grilles tordues ou repliées
                    hull = cv2.convexHull(corners.astype(np.float32))
                    if not cv2.isContourConvex(hull):
                        continue
                    
                    # 4. Filtre de Surface (AREA) : Rejette les petits motifs sur les murs lointains
                    # L'échiquier doit occuper au moins 5% de la surface totale de l'image
                    area = cv2.contourArea(hull)
                    if area < (h * w * 0.05):
                        continue
                    
                    # 5. Vérification de Régularité : Empêche de sauter des cases
                    grid = corners.reshape(pattern[1], pattern[0], 2)
                    # Mesure les distances entre les colonnes
                    dx = np.linalg.norm(grid[:, 1:] - grid[:, :-1], axis=2)
                    # Mesure les distances entre les lignes
                    dy = np.linalg.norm(grid[1:, :] - grid[:-1, :], axis=2)
                    # Si une distance est trop différente des autres (ratio > 1.5), c'est faux
                    if dx.max() > dx.min() * 1.5 or dy.max() > dy.min() * 1.5:
                        continue
                    
                    # 6. Filtre de Position : L'échiquier doit être vers le bas (sol)
                    # On rejette si le centre de la grille est dans les 30% supérieurs (fenêtres/murs)
                    center_y = corners[:, 1].mean()
                    if center_y < (h * 0.3):
                        continue
                        
                    # Si tous les tests sont passés, on a trouvé notre échiquier !
                    best_corners = corners
                    break # On arrête de chercher pour cette image
                else:
                    continue # Sinon on teste l'image suivante ou l'échelle suivante
        # Si on a trouvé, on sort de la boucle d'échelle
        if best_corners is not None: break
                
    # Si après tous les tests rien n'est valide, on retourne un échec
    if best_corners is None:
        return None
            
    # Succès ! Préparation de l'image de debug avec les points dessinés
    corners = best_corners
    show = img.copy()
    show = cv2.drawChessboardCorners(show, pattern, corners.reshape(-1, 1, 2).astype(np.float32), True)
    # On ajoute un point de confiance pour chaque coin dans l'annotation
    corners = np.hstack((corners, np.ones((corners.shape[0], 1))))
    # On sauvegarde les points 2D finalisés dans le dictionnaire
    annots['keypoints2d'] = corners.tolist()
    # Retourne l'image de debug pour affichage
    return show