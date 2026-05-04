# ======================================================================================
# NOM DU FICHIER : detect_chessboard.py
# RÔLE : Ce script est le point d'entrée de ta calibration. Il parcourt tes images,
#        appelle l'intelligence de détection, et enregistre les résultats.
# ======================================================================================

from lib.annotator.file_utils import getFileList, read_json, save_json
from lib.mytools.debug_utils import mywarn
from tqdm import tqdm # Pour la jolie barre de progression
from lib.annotator import ImageFolder
from lib.annotator.chessboard import findChessboardCorners
import numpy as np
from os.path import join
import cv2
import os
import func_timeout
import threading
from lib.mytools.debug_utils import log

# --------------------------------------------------------------------------------------
# 1. GÉNÉRATION DU MODÈLE 3D (LA VÉRITÉ MATHÉMATIQUE)
# Cette fonction définit à quoi ressemble ton échiquier dans le monde réel.
# Elle dit : "Le point n°1 est à 0cm, le point n°2 est à 13.5cm à droite, etc."
# C'est ce modèle parfait qui servira de référence pour corriger tes caméras.
# --------------------------------------------------------------------------------------
def getChessboard3d(pattern, gridSize, axis='yx'):
    """
    Crée une grille de points 3D (X, Y, Z) qui représente l'échiquier réel.
    - pattern : le nombre de coins internes (ex: 4 colonnes, 3 lignes)
    - gridSize : la taille d'une case en mètres (ex: 0.135)
    """
    # Création d'une grille 2D simple (0, 1, 2, 3...)
    template = np.mgrid[0:pattern[0], 0:pattern[1]].T.reshape(-1,2)
    
    # Création d'un tableau pour stocker les points 3D (X, Y, Z)
    object_points = np.zeros((pattern[1]*pattern[0], 3), np.float32)
    
    # On définit l'orientation. Dans ton cas 'yx' (échiquier à plat au sol)
    if axis == 'xz':
        object_points[:, 0] = template[:, 0] # Axe X
        object_points[:, 2] = template[:, 1] # Axe Z (vertical)
    elif axis == 'yx':
        object_points[:, 0] = template[:, 1] # Axe X
        object_points[:, 1] = template[:, 0] # Axe Y (horizontal au sol)
    else:
        raise NotImplementedError # Erreur si l'axe n'est pas supporté
        
    # On multiplie par la taille réelle (ex: 0.135) pour avoir des mètres et non des pixels
    object_points = object_points * gridSize
    return object_points

# --------------------------------------------------------------------------------------
# 2. PRÉPARATION DES FICHIERS (LES TEMPLATES JSON)
# Avant de chercher dans les images, on prépare des "formulaires" (fichiers JSON).
# On y met la carte 3D qu'on vient de créer. Plus tard, on y ajoutera les positions 2D.
# --------------------------------------------------------------------------------------
def create_chessboard(path, image, pattern, gridSize, ext, overwrite=True):
    """
    Crée les fichiers .json de base dans le dossier 'chessboard/'.
    Chaque fichier correspond à une image de ton dataset.
    """
    print('Initialisation des fichiers de détection pour le motif {}'.format(pattern))
    
    # On génère notre modèle 3D parfait une seule fois
    keypoints3d = getChessboard3d(pattern, gridSize=gridSize, axis=args.axis)
    
    # On prépare un tableau vide pour les futurs points 2D (que l'on ne connaît pas encore)
    keypoints2d = np.zeros((keypoints3d.shape[0], 3))
    
    # On liste toutes les images présentes dans ton dossier (ex: Lb/0000.jpg, Lb/0001.jpg...)
    imgnames = getFileList(join(path, image), ext=ext)
    
    # Modèle du fichier JSON final
    template = {
        'keypoints3d': keypoints3d.tolist(), # La vérité 3D
        'keypoints2d': keypoints2d.tolist(), # Vide pour l'instant (sera rempli par OpenCV)
        'pattern': pattern,                 # Le format 4x3
        'grid_size': gridSize,              # 0.135m
        'visited': False                     # Dit au script "Je n'ai pas encore analysé cette image"
    }
    
    # On crée un fichier JSON pour chaque image trouvée
    for imgname in tqdm(imgnames, desc='Création des templates JSON'):
        annname = imgname.replace(ext, '.json') # On remplace .jpg par .json
        annname = join(path, 'chessboard', annname) # Chemin final : chessboard/cam/000.json
        
        # Si le fichier existe déjà, on le met à jour ou on le saute
        if os.path.exists(annname) and overwrite:
            data = read_json(annname)
            data['keypoints3d'] = template['keypoints3d'] # On met à jour les points 3D
            save_json(annname, data)
        elif os.path.exists(annname) and not overwrite:
            continue
        else:
            # On crée le dossier si besoin et on enregistre le template vide
            os.makedirs(os.path.dirname(annname), exist_ok=True)
            save_json(annname, template)

# --------------------------------------------------------------------------------------
# 3. LE CŒUR DU TRAVAIL : LA DÉTECTION
# Cette fonction prend une liste d'images, les ouvre, et cherche l'échiquier dedans.
# C'est ici que l'ordinateur "regarde" vraiment tes photos.
# --------------------------------------------------------------------------------------
def _detect_chessboard(datas, path, image, out, pattern):
    """
    Fonction interne lancée par chaque 'ouvrier' (thread).
    """
    for imgname, annotname in datas:
        # 1. On ouvre l'image réelle (le fichier .jpg)
        img = cv2.imread(imgname)
        
        # 2. On ouvre le fichier JSON template qu'on a créé à l'étape 2
        annots = read_json(annotname)
        
        try:
            # 3. ON APPELLE L'INTELLIGENCE (chessboard.py)
            # Cette fonction va scanner l'image et chercher les 12 coins.
            # Elle renvoie 'show' : une image avec les points dessinés dessus.
            show = findChessboardCorners(img, annots, pattern)
        except func_timeout.exceptions.FunctionTimedOut:
            # Sécurité : Si l'image est trop compliquée et bloque le calcul, on abandonne
            show = None
            
        # 4. On sauvegarde les résultats dans le fichier JSON (les coordonnées X, Y)
        save_json(annotname, annots)
        
        # 5. Si ça a marché, on enregistre une image de preuve pour toi (dans output/calibration)
        if show is not None:
            # On crée le nom du fichier de preuve
            outname = join(out, imgname.replace(path + '/{}/'.format(image), ''))
            os.makedirs(os.path.dirname(outname), exist_ok=True)
            if isinstance(show, np.ndarray):
                cv2.imwrite(outname, show) # On enregistre l'image avec les points rouges/bleus
        else:
            # Si échec, on prévient discrètement dans la console
            mywarn('[Info] Échec de détection dans : {}'.format(imgname))

# --------------------------------------------------------------------------------------
# 4. GESTION DU MULTITHREADING (TRAVAIL EN ÉQUIPE)
# Détecter 8000 images prend du temps. Cette fonction lance plusieurs ouvriers
# (threads) en même temps pour diviser le temps par 4 ou 8.
# --------------------------------------------------------------------------------------
def detect_chessboard(path, image, out, pattern, gridSize, args):
    """
    Lance la détection sur tout le dossier.
    """
    # Étape A : Créer les fichiers JSON (les formulaires vides)
    create_chessboard(path, image, pattern, gridSize, ext=args.ext, overwrite=args.overwrite3d)
    
    # Étape B : Charger la liste de toutes les images à traiter
    dataset = ImageFolder(path, image=image, annot='chessboard', ext=args.ext)
    dataset.isTmp = False
    
    # Étape C : Diviser le travail
    trange = list(range(len(dataset)))
    threads = []
    
    # On lance 'args.mp' ouvriers (par défaut 4)
    for i in range(args.mp):
        # Chaque ouvrier reçoit une partie des images (ex: 1/4 du total)
        ranges = trange[i::args.mp]
        datas = [dataset[t] for t in ranges]
        
        # On crée l'ouvrier (le thread)
        thread = threading.Thread(target=_detect_chessboard, args=(datas, path, image, out, pattern))
        thread.start() # Il commence son travail en arrière-plan
        threads.append(thread)
        
    # On attend que tous les ouvriers aient fini avant de dire "C'est prêt !"
    for thread in threads:
        thread.join()

# --------------------------------------------------------------------------------------
# 5. DÉMARRAGE DU SCRIPT
# C'est ici que le script commence quand tu tapes "python3 detect_chessboard.py ..."
# --------------------------------------------------------------------------------------
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Outil de détection d'échiquier pour calibration")
    
    # Paramètres obligatoires et optionnels (Chemin, Motif, Taille, etc.)
    parser.add_argument('path', type=str, help="Dossier racine du dataset")
    parser.add_argument('--image', type=str, default='images', help="Dossier contenant les JPG")
    parser.add_argument('--out', type=str, required=True, help="Dossier pour les images de preuve")
    parser.add_argument('--ext', type=str, default='.jpg', choices=['.jpg', '.png'])
    parser.add_argument('--pattern', type=lambda x: (int(x.split(',')[0]), int(x.split(',')[1])), default=(4, 3))
    parser.add_argument('--grid', type=float, default=0.135, help="Taille des cases en mètres")
    parser.add_argument('--mp', type=int, default=4, help="Nombre de threads (ouvriers)")
    parser.add_argument('--axis', type=str, default='yx', help="Orientation de l'échiquier")
    parser.add_argument('--overwrite3d', action='store_true', help="Recalculer les points 3D")
    
    args = parser.parse_args()
    
    # Lancement de la grosse machine de détection !
    detect_chessboard(args.path, args.image, args.out, pattern=args.pattern, gridSize=args.grid, args=args)

# FIN DU FICHIER