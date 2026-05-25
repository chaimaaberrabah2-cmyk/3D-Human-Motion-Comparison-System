# ======================================================================================
# NOM DU FICHIER : calib_intri.py
# RÔLE : Ce script calcule les paramètres "intrinsèques" de tes caméras.
#        Il analyse comment la lentille de chaque caméra déforme l'image (effet fisheye)
#        et calcule sa focale (le zoom) pour pouvoir corriger ces défauts.
# ======================================================================================

# Importation de shutil pour copier des fichiers (utile pour garder une trace des images utilisées)
import shutil
# Importation de random pour piocher des images au hasard si on en a trop
import random
# Importation des outils de log et d'avertissement personnalisés
from lib.mytools.debug_utils import log, mywarn
# Importation d'un outil pour visualiser les points 2D sur les images (pour le debug)
from lib.mytools.vis_base import plot_points2d
# Importation des outils pour écrire le fichier final (intri.yml) et lire le JSON
from lib.mytools import write_intri, read_json, Timer
# Importation de numpy pour tous les calculs mathématiques sur les tableaux
import numpy as np
# Importation d'OpenCV pour le cœur des calculs de calibration
import cv2
# Importation de os pour manipuler les dossiers et fichiers
import os
# Importation de join pour créer des chemins de fichiers proprement
from os.path import join
# Importation de glob pour chercher des fichiers avec des motifs (ex: *.jpg)
from glob import glob
# Importation d'un outil pour dessiner des lignes sur l'échiquier (visualisation)
from lib.annotator.chessboard import get_lines_chessboard
# Importation de tqdm pour afficher une barre de progression pendant les calculs
from tqdm import tqdm

# 1. LECTURE DES DONNÉES DÉTECTÉES
# Cette fonction lit un fichier JSON de détection et vérifie si elle est "bonne".
# --------------------------------------------------------------------------------------
def read_chess(chessname):
    # On lit le fichier JSON contenant les points 2D et 3D
    data = read_json(chessname)
    # On transforme les points 3D (la vérité) en tableau numpy
    k3d = np.array(data['keypoints3d'], dtype=np.float32)
    # On transforme les points 2D (les pixels détectés) en tableau numpy
    k2d = np.array(data['keypoints2d'], dtype=np.float32)
    
    # TEST DE VALIDITÉ : Si on a détecté moins de la moitié des points, on rejette l'image
    if (k2d[:, -1] > 0.).sum() < k2d.shape[0]//2:
        return False, k2d, k3d
        
    # Si certains points manquent mais qu'on en a assez, on ne garde que les points valides
    if k2d[:, -1].sum() < k2d.shape[0]:
        # On ne garde que les points dont le score de confiance est > 0.1
        valid = k2d[:, -1] > 0.1
        k2d = k2d[valid]
        k3d = k3d[valid]
        
    # Si tout est bon, on renvoie True et les points
    return True, k2d, k3d

# 2. NETTOYAGE ET DIVERSITÉ (Éviter d'avoir trop d'images identiques)
# Si on a 2000 images, le calcul sera trop long. On en "jette" quelques-unes
# en essayant de garder celles qui sont les plus différentes les unes des autres.
# --------------------------------------------------------------------------------------
def pop(k2ds_, k3ds_, valid_idx, imgnames, max_num):
    # On empile tous les points 2D détectés
    k2ds = np.stack(k2ds_)
    # On calcule la distance mathématique entre toutes les détections
    dist = np.linalg.norm(k2ds[:, None] - k2ds[None, :], axis=-1).mean(axis=-1)
    # On normalise par la taille de l'échiquier pour que ce soit comparable
    size = np.linalg.norm(k2ds[:, -1] - k2ds[:, 0], axis=-1)
    dist = dist / size[:, None]
    # On prépare une liste d'indices
    row = np.arange(dist.shape[0])
    # On met une valeur très haute sur la diagonale pour ne pas se comparer à soi-même
    dist[row, row] = 9999.
    # On cherche les images qui se ressemblent le plus (distance minimale)
    col = dist.argmin(axis=0)
    dist_min = dist[row, col]
    # On trie pour identifier les images les plus "redondantes"
    indices = dist_min.argsort()[:dist_min.shape[0] - max_num]
    
    # On prépare la liste des images à supprimer
    indices = indices.tolist()
    indices.sort(reverse=True, key=lambda x:col[x])
    removed = set()
    for idx in indices:
        remove_id = col[idx]
        if remove_id in removed:
            continue
        removed.add(remove_id)
        # On supprime l'image de nos listes de travail
        valid_idx.pop(remove_id)
        k2ds_.pop(remove_id)
        k3ds_.pop(remove_id)

# 3. CHARGEMENT DE TOUS LES ÉCHIQUIERS
# --------------------------------------------------------------------------------------
def load_chessboards(chessnames, imagenames, max_image, sample_image=-1, out='debug-calib'):
    # On crée un dossier pour voir quelles images ont été choisies pour la calibration
    os.makedirs(out, exist_ok=True)
    k3ds_, k2ds_, imgs = [], [], []
    valid_idx = []
    
    # On parcourt tous les fichiers JSON de détection
    for i, chessname in enumerate(tqdm(chessnames, desc='read')):
        # On lit le fichier
        flag, k2d, k3d = read_chess(chessname)
        # Si l'image est mauvaise, on passe à la suivante
        if not flag:
            continue
        # On stocke les points
        k3ds_.append(k3d)
        k2ds_.append(k2d)
        valid_idx.append(i)
        # Si on dépasse le nombre max d'images autorisées, on fait du tri
        if max_image > 0 and len(valid_idx) > max_image + int(max_image * 0.1):
            pop(k2ds_, k3ds_, valid_idx, imagenames, max_num=max_image)
            
    # Si on veut juste un échantillon aléatoire
    if sample_image > 0:
        mywarn('[calibration] Load {} images, sample {} images'.format(len(k3ds_), sample_image))
        index = [i for i in range(len(k2ds_))]
        index_sample = random.sample(index, min(sample_image, len(index)))
        valid_idx = [valid_idx[i] for i in index_sample]
        k2ds_ = [k2ds_[i] for i in index_sample]
        k3ds_ = [k3ds_[i] for i in index_sample]
    else:
        log('[calibration] Load {} images'.format(len(k3ds_)))
        
    # On copie les images sélectionnées dans le dossier de debug pour vérification
    for ii, idx in enumerate(valid_idx):
        shutil.copyfile(imagenames[idx], join(out, '{:06d}.jpg'.format(ii)))
    return k3ds_, k2ds_

# 4. CAS PARTICULIER : CAMÉRAS IDENTIQUES (SHARE INTRI)
# Si toutes tes caméras sont les mêmes (même modèle, même réglage), on calcule une seule fois.
# --------------------------------------------------------------------------------------
def calib_intri_share(path, image, ext):
    # On liste les noms des caméras
    camnames = sorted(os.listdir(join(path, image)))
    camnames = [cam for cam in camnames if os.path.isdir(join(path, image, cam))]

    # On récupère toutes les images et tous les JSON de toutes les caméras
    imagenames = sorted(glob(join(path, image, '*', '*' + ext)))
    chessnames = sorted(glob(join(path, 'chessboard', '*', '*.json')))
    
    # On charge tout en bloc
    k3ds_, k2ds_ = load_chessboards(chessnames, imagenames, args.num, args.sample, out=join(args.path, 'output'))
    
    with Timer('calibrate'):
        print('[Info] start calibration with {} detections'.format(len(k2ds_)))
        # On ouvre la première image pour avoir la résolution (ex: 1920x1080)
        gray = cv2.imread(imagenames[0], 0)
        k3ds = k3ds_
        # On prépare les points 2D (on enlève la colonne de confiance)
        k2ds = [np.ascontiguousarray(k2d[:, :-1]) for k2d in k2ds_]
        
        # LE CALCUL MAGIQUE : Calcule la matrice K et la Distorsion
        ret, K, dist, rvecs, tvecs = cv2.calibrateCamera(
            k3ds, k2ds, gray.shape[::-1], None, None,
            flags=cv2.CALIB_FIX_K3)
            
        # On applique ce résultat à toutes les caméras
        cameras = {}
        for cam in camnames:
            cameras[cam] = {
                'K': K,
                'dist': dist
            }
            
        # DEBUG : On génère des images "rectifiées" (sans distorsion) pour vérifier
        if True:
            img = cv2.imread(imagenames[0])
            h,  w = img.shape[:2]
            # On calcule la nouvelle matrice pour ne pas perdre de bords
            newcameramtx, roi = cv2.getOptimalNewCameraMatrix(K, dist, (w,h), 1, (w,h))
            # On crée une "carte de transformation"
            mapx, mapy = cv2.initUndistortRectifyMap(K, dist, None, newcameramtx, (w,h), 5)
            for imgname in tqdm(imagenames):
                img = cv2.imread(imgname)
                # On redresse l'image
                dst = cv2.remap(img, mapx, mapy, cv2.INTER_LINEAR)
                outname = join(path, 'output', os.path.basename(imgname))
                cv2.imwrite(outname, dst)
        
        # On enregistre le fichier final
        write_intri(join(path, 'output', 'intri.yml'), cameras)

# 5. CAS GÉNÉRAL : CALIBRATION INDIVIDUELLE
# On calcule les paramètres pour CHAQUE caméra séparément.
# --------------------------------------------------------------------------------------
def calib_intri(path, image, ext):
    # Liste des caméras (Lb, Lf, Rb, Rf)
    camnames = sorted(os.listdir(join(path, image)))
    camnames = [cam for cam in camnames if os.path.isdir(join(path, image, cam))]
    cameras = {}
    
    # Pour chaque caméra...
    for ic, cam in enumerate(camnames):
        # On récupère ses images et ses détections
        imagenames = sorted(glob(join(path, image, cam, '*'+ext)))
        chessnames = sorted(glob(join(path, 'chessboard', cam, '*.json')))
        
        # On charge ses échiquiers
        k3ds_, k2ds_ = load_chessboards(chessnames, imagenames, args.num, out=join(args.path, 'output', cam+'_used'))
        k3ds = k3ds_
        k2ds = [np.ascontiguousarray(k2d[:, :-1]) for k2d in k2ds_]
        
        # On récupère la taille de l'image
        gray = cv2.imread(imagenames[0], 0)
        print('>> Camera {}: {:3d} frames'.format(cam, len(k2ds)))
        
        with Timer('calibrate'):
            # CALCUL DE LA LENTILLE POUR CETTE CAMÉRA
            ret, K, dist, rvecs, tvecs = cv2.calibrateCamera(
                k3ds, k2ds, gray.shape[::-1], None, None,
                flags=cv2.CALIB_FIX_K3)
                
            # On enregistre les résultats (Matrice K et Distorsion)
            cameras[cam] = {
                'K': K,
                'dist': dist
            }
            
    # Une fois fini pour toutes les caméras, on écrit le fichier global intri.yml
    write_intri(join(path, 'output', 'intri.yml'), cameras)

# 6. POINT D'ENTRÉE (MAIN)
# --------------------------------------------------------------------------------------
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    # Le chemin de ton projet
    parser.add_argument('path', type=str, default='/home/')
    # Le nom du dossier des images (souvent 'images')
    parser.add_argument('--image', type=str, default='images')
    # L'extension des images (.jpg)
    parser.add_argument('--ext', type=str, default='.jpg', choices=['.jpg', '.png'])
    # Le nombre max d'images à utiliser pour le calcul (ex: 50 ou 100)
    parser.add_argument('--num', type=int, default=-1)
    # Si on veut un échantillon aléatoire
    parser.add_argument('--sample', type=int, default=-1)
    # Si on veut forcer une seule calibration pour toutes les caméras
    parser.add_argument('--share_intri', action='store_true')
    # Option pour supprimer des fichiers (non utilisée ici)
    parser.add_argument('--remove', action='store_true')
    
    # On récupère les arguments
    args = parser.parse_args()
    
    # On lance la fonction correspondante
    if args.share_intri:
        calib_intri_share(args.path, args.image, ext=args.ext)
    else:
        calib_intri(args.path, args.image, ext=args.ext)
