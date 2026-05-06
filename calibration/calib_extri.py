# ======================================================================================
# NOM DU FICHIER : calib_extri.py
# RÔLE : Ce script calcule les paramètres "extrinsèques" de tes caméras.
#        Il détermine la position (X, Y, Z) et l'orientation (Rotation) de chaque 
#        caméra dans ta pièce par rapport à ton échiquier.
# ======================================================================================

# Importation de l'outil pour enregistrer les paramètres intrinsèques
from lib.mytools.camera_utils import write_intri
# Importation de os pour naviguer dans les dossiers
import os
# Importation de glob pour chercher des fichiers images
from glob import glob
# Importation de join pour créer des chemins propres
from os.path import join
# Importation de numpy pour les calculs de matrices de rotation et position
import numpy as np
# Importation d'OpenCV pour le calcul de pose (PnP)
import cv2
# Importation des outils de lecture/écriture de fichiers de calibration
from lib.mytools import read_intri, write_extri, read_json
# Importation de l'outil d'avertissement personnalisé
from lib.mytools.debug_utils import mywarn

# 1. INITIALISATION PAR DÉFAUT (Si on n'a pas de fichier intri.yml)
# Cette fonction crée des paramètres de lentille "estimés" si tu n'as pas fait l'étape précédente.
# --------------------------------------------------------------------------------------
def init_intri(path, image):
    # On liste les caméras
    camnames = sorted(os.listdir(join(path, image)))
    cameras = {}
    for ic, cam in enumerate(camnames):
        # On prend la première image de chaque caméra
        imagenames = sorted(glob(join(path, image, cam, '*.jpg')))
        assert len(imagenames) > 0
        imgname = imagenames[0]
        img = cv2.imread(imgname)
        # On récupère la résolution (ex: 1080x1920)
        height, width = img.shape[0], img.shape[1]
        # On estime une focale par défaut (basée sur la résolution)
        focal = 1.2*max(height, width) 
        # On crée une matrice K standard (centre de l'image, focale estimée)
        K = np.array([focal, 0., width/2, 0., focal, height/2, 0. ,0., 1.]).reshape(3, 3)
        # On met la distorsion à zéro
        dist = np.zeros((1, 5))
        cameras[cam] = {
            'K': K,
            'dist': dist
        }
    return cameras

# 2. LE CALCUL DE POSE (PnP - Perspective-n-Point)
# C'est ici qu'on calcule où est la caméra par rapport à l'échiquier.
# --------------------------------------------------------------------------------------
def solvePnP(k3d, k2d, K, dist, flag, tryextri=False):
    # On prépare les points 2D
    k2d = np.ascontiguousarray(k2d[:, :2])
    
    # OPTION AVANCÉE : Essayer plusieurs positions de départ pour éviter de se tromper
    if tryextri:
        # Fonction interne pour tester une position et calculer l'erreur
        def closure(rvec, tvec):
            # On affine la position avec OpenCV
            ret, rvec, tvec = cv2.solvePnP(k3d, k2d, K, dist, rvec, tvec, True, flags=flag)
            # On reprojette les points 3D sur l'image pour vérifier si ça colle
            points2d_repro, xxx = cv2.projectPoints(k3d, rvec, tvec, K, dist)
            kpts_repro = points2d_repro.squeeze()
            # On calcule l'erreur moyenne en pixels
            err = np.linalg.norm(points2d_repro.squeeze() - k2d, axis=1).mean()
            return err, rvec, tvec, kpts_repro
            
        # On simule un cercle de 7 mètres autour du centre pour tester toutes les vues
        height_guess = 2.1 # Hauteur estimée des caméras
        radius_guess = 7.  # Distance estimée
        infos = []
        for theta in np.linspace(0, 2*np.pi, 180): # On teste 180 angles différents
            st = np.sin(theta)
            ct = np.cos(theta)
            # Position théorique de la caméra
            center = np.array([radius_guess*ct, radius_guess*st, height_guess]).reshape(3, 1)
            # Rotation pour qu'elle regarde vers le centre (0,0,0)
            R = np.array([
                [-st, ct,  0],
                [0,    0, -1],
                [-ct, -st, 0]
            ])
            tvec = - R @ center
            rvec = cv2.Rodrigues(R)[0]
            # On teste cette position
            err, rvec, tvec, kpts_repro = closure(rvec, tvec)
            infos.append({'err': err, 'repro': kpts_repro, 'rvec': rvec, 'tvec': tvec})
            
        # On garde la position qui a la plus petite erreur
        infos.sort(key=lambda x:x['err'])
        err, rvec, tvec, kpts_repro = infos[0]['err'], infos[0]['rvec'], infos[0]['tvec'], infos[0]['repro']
    else:
        # MÉTHODE STANDARD : OpenCV cherche tout seul sans aide
        ret, rvec, tvec = cv2.solvePnP(k3d, k2d, K, dist, flags=flag)
        # Calcul de l'erreur de reprojection
        points2d_repro, xxx = cv2.projectPoints(k3d, rvec, tvec, K, dist)
        kpts_repro = points2d_repro.squeeze()
        err = np.linalg.norm(points2d_repro.squeeze() - k2d, axis=1).mean()
        
    return err, rvec, tvec, kpts_repro

# 3. LA FONCTION PRINCIPALE DE CALIBRATION EXTRINSÈQUE
# --------------------------------------------------------------------------------------
def calib_extri(path, image, intriname, image_id):
    # Liste des caméras
    camnames = sorted(os.listdir(join(path, image)))
    camnames = [c for c in camnames if os.path.isdir(join(path, image, c))]
    
    # Chargement des paramètres de lentilles (Intrinsèques)
    if intriname is None:
        # Si on n'a rien, on initialise par défaut
        intri = init_intri(path, image)
    else:
        # On lit le fichier intri.yml généré par le script précédent
        assert os.path.exists(intriname), intriname
        intri = read_intri(intriname)
        # Si on n'a qu'une seule caméra dans le fichier, on l'applique à toutes
        if len(intri.keys()) == 1:
            key0 = list(intri.keys())[0]
            for cam in camnames:
                intri[cam] = intri[key0].copy()
                
    extri = {}
    # Méthode de calcul (Iterative est la plus stable)
    methods = [cv2.SOLVEPNP_ITERATIVE]
    
    # Pour chaque caméra...
    for ic, cam in enumerate(camnames):
        # On cherche les JSON de détection
        chessnames = sorted(glob(join(path, 'chessboard', cam, '*.json')))
        assert len(chessnames) > 0, cam
        # On prend UNE SEULE image pour caler la caméra (image_id)
        # Souvent la première frame où l'échiquier est bien visible par toutes les caméras
        chessname = chessnames[image_id]
        
        # On lit les points détectés
        data = read_json(chessname)
        k3d = np.array(data['keypoints3d'], dtype=np.float32)
        k2d = np.array(data['keypoints2d'], dtype=np.float32)
        
        # On vérifie que les listes correspondent
        if k3d.shape[0] != k2d.shape[0]:
            mywarn('k3d {} doesnot match k2d {}'.format(k3d.shape, k2d.shape))
            length = min(k3d.shape[0], k2d.shape[0])
            k3d = k3d[:length]
            k2d = k2d[:length]
            
        # On ne garde que les points qui ont été réellement détectés (confiance > 0)
        valididx = k2d[:, 2] > 0
        if valididx.sum() < 4: # Il faut au moins 4 points pour calculer une position 3D
            print('[ERROR] Échec : Pas assez de points pour la caméra {}'.format(cam))
            continue
            
        k3d = k3d[valididx]
        k2d = k2d[valididx]
        
        # OPTION : Essayer d'ajuster la focale en même temps (si activé)
        if args.tryfocal:
            infos = []
            for focal in range(500, 5000, 10):
                dist = intri[cam]['dist']
                K = intri[cam]['K'].copy()
                K[0, 0] = focal
                K[1, 1] = focal
                for flag in methods:
                    err, rvec, tvec, kpts_repro = solvePnP(k3d, k2d, K, dist, flag)
                    infos.append({'focal': focal, 'err': err, 'rvec': rvec, 'tvec': tvec})
            infos.sort(key=lambda x:x['err'])
            err, rvec, tvec = infos[0]['err'], infos[0]['rvec'], infos[0]['tvec']
            focal = infos[0]['focal']
            intri[cam]['K'][0, 0] = focal
            intri[cam]['K'][1, 1] = focal
        else:
            # CALCUL NORMAL DE LA POSITION
            K, dist = intri[cam]['K'], intri[cam]['dist']
            err, rvec, tvec, kpts_repro = solvePnP(k3d, k2d, K, dist, flag=cv2.SOLVEPNP_ITERATIVE)
            
        # On enregistre les résultats extrinsèques
        extri[cam] = {}
        extri[cam]['Rvec'] = rvec # Vecteur de rotation
        extri[cam]['R'] = cv2.Rodrigues(rvec)[0] # Matrice de rotation 3x3
        extri[cam]['T'] = tvec # Vecteur de translation
        
        # On calcule le centre de la caméra dans le monde (en mètres)
        center = - extri[cam]['R'].T @ tvec
        print('Caméra {} : Position => {}, Erreur = {:.3f} pixels'.format(cam, center.squeeze(), err))
        
    # On sauvegarde les fichiers finaux
    write_intri(join(path, 'intri.yml'), intri)
    write_extri(join(path, 'extri.yml'), extri)

# 4. CONFIGURATION DES OPTIONS (ARGPARSE)
# --------------------------------------------------------------------------------------
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    # Chemin du projet
    parser.add_argument('path', type=str)
    # Dossier des images
    parser.add_argument('--image', type=str, default='images')
    # Chemin vers le fichier intri.yml (obligatoire pour un bon résultat)
    parser.add_argument('--intri', type=str, default=None)
    # Extension des images
    parser.add_argument('--ext', type=str, default='.jpg')
    # ID de l'image à utiliser pour caler les caméras (ex: frame 0)
    parser.add_argument('--image_id', type=int, default=0)
    # Options avancées
    parser.add_argument('--tryfocal', action='store_true')
    parser.add_argument('--tryextri', action='store_true')
    
    args = parser.parse_args()
    # On lance le calcul
    calib_extri(args.path, args.image, intriname=args.intri, image_id=args.image_id)