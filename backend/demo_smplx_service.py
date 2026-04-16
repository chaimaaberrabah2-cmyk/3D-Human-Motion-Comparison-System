#!/usr/bin/env python3
"""
=============================================================
demo_smplx_service.py
=============================================================
Démonstration du pipeline SmplxService SANS avoir besoin
de PyTorch / smplx installés.

Ce script simule chaque étape du pipeline et affiche
une explication détaillée de ce qui se passe.
=============================================================
"""

import os
import json
import numpy as np
import sys

# ──────────────────────────────────────────────────────────────
#  COULEURS TERMINAL
# ──────────────────────────────────────────────────────────────
RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[96m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"
MAGENTA= "\033[95m"
RED    = "\033[91m"
BLUE   = "\033[94m"
WHITE  = "\033[97m"

def title(text):
    bar = "═" * 60
    print(f"\n{CYAN}{BOLD}{bar}{RESET}")
    print(f"{CYAN}{BOLD}  {text}{RESET}")
    print(f"{CYAN}{BOLD}{bar}{RESET}")

def step(num, text):
    print(f"\n{YELLOW}{BOLD}▶ ÉTAPE {num}: {text}{RESET}")

def info(text):
    print(f"  {WHITE}→ {text}{RESET}")

def ok(text):
    print(f"  {GREEN}✔  {text}{RESET}")

def warn(text):
    print(f"  {YELLOW}⚠  {text}{RESET}")

def data(label, value):
    print(f"  {MAGENTA}{label:30s}{RESET} {BOLD}{value}{RESET}")

def show_array(name, arr):
    print(f"  {BLUE}{name}{RESET}: shape={BOLD}{arr.shape}{RESET}  "
          f"min={arr.min():.4f}  max={arr.max():.4f}  mean={arr.mean():.4f}")


# ══════════════════════════════════════════════════════════════
#  MAPPING MediaPipe → SMPL-X  (copié de smplx_service.py)
# ══════════════════════════════════════════════════════════════
MP_TO_SMPLX = {
    0:  [23, 24],
    1:  [23],
    2:  [24],
    3:  [11, 12, 23, 24],
    4:  [25],
    5:  [26],
    6:  [11, 12],
    7:  [27],
    8:  [28],
    9:  [11, 12],
    12: [11, 12],
    15: [0],
    16: [11],
    17: [12],
    18: [13],
    19: [14],
    20: [15],
    21: [16],
}

SMPLX_JOINT_NAMES = [
    "pelvis", "left_hip", "right_hip", "spine1",
    "left_knee", "right_knee", "spine2", "left_ankle",
    "right_ankle", "spine3", "left_foot", "right_foot",
    "neck", "left_collar", "right_collar", "head",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist",
]

MEDIAPIPE_LANDMARK_NAMES = {
    0: "nose", 11: "left_shoulder", 12: "right_shoulder",
    13: "left_elbow", 14: "right_elbow", 15: "left_wrist",
    16: "right_wrist", 23: "left_hip", 24: "right_hip",
    25: "left_knee", 26: "right_knee", 27: "left_ankle", 28: "right_ankle",
}


def _build_target_joints(frame_kp: np.ndarray):
    """Réplication exacte de SmplxService._build_target_joints()"""
    n_smplx = 22
    target = np.zeros((n_smplx, 3), dtype=np.float32)
    valid  = np.zeros(n_smplx, dtype=bool)

    for smplx_idx, mp_indices in MP_TO_SMPLX.items():
        if smplx_idx >= n_smplx:
            continue
        pts = frame_kp[mp_indices, :3].copy()
        pts[:, 1] = -pts[:, 1]  # Flip Y (OpenCV→OpenGL)
        pts[:, 2] = -pts[:, 2]  # Flip Z
        vis = frame_kp[mp_indices, 3]
        vis_mask = vis > 0.3
        if np.any(vis_mask):
            target[smplx_idx] = pts[vis_mask].mean(axis=0)
            valid[smplx_idx] = True

    return target, valid


# ══════════════════════════════════════════════════════════════
#  GÉNÉRATION DE DONNÉES FACTICES
# ══════════════════════════════════════════════════════════════

def generate_fake_keypoints(num_frames: int = 30) -> np.ndarray:
    """
    Génère des keypoints 3D factices qui ressemblent à un humain debout.
    Shape: (F, 33, 4)  →  [x, y, z, visibility]
    """
    np.random.seed(42)
    kp = np.zeros((num_frames, 33, 4), dtype=np.float32)

    # Positions de base d'un humain debout (coordonnées OpenCV: Y↓)
    base_positions = np.zeros((33, 3), dtype=np.float32)
    # Tête / nez
    base_positions[0]  = [0.0,  -1.7,  2.5]   # nez
    # Épaules
    base_positions[11] = [-0.2, -1.4,  2.5]   # left_shoulder
    base_positions[12] = [ 0.2, -1.4,  2.5]   # right_shoulder
    # Coudes
    base_positions[13] = [-0.4, -1.0,  2.5]   # left_elbow
    base_positions[14] = [ 0.4, -1.0,  2.5]   # right_elbow
    # Poignets
    base_positions[15] = [-0.5, -0.6,  2.5]   # left_wrist
    base_positions[16] = [ 0.5, -0.6,  2.5]   # right_wrist
    # Hanches
    base_positions[23] = [-0.1, -0.9,  2.5]   # left_hip
    base_positions[24] = [ 0.1, -0.9,  2.5]   # right_hip
    # Genoux
    base_positions[25] = [-0.12,-0.4,  2.5]   # left_knee
    base_positions[26] = [ 0.12,-0.4,  2.5]   # right_knee
    # Chevilles
    base_positions[27] = [-0.13, 0.1,  2.5]   # left_ankle
    base_positions[28] = [ 0.13, 0.1,  2.5]   # right_ankle

    for fi in range(num_frames):
        t = fi / max(1, num_frames - 1)
        noise = np.random.randn(33, 3) * 0.02
        # Animation: légère ondulation du bras gauche
        arm_swing = np.sin(t * 2 * np.pi) * 0.15
        base_positions[15, 1] = -0.6 + arm_swing  # poignet gauche monte/descend

        kp[fi, :, :3] = base_positions + noise
        # Visibilité: 0.9 pour les joints importants, aléatoire pour le reste
        kp[fi, :, 3] = 0.5
        for idx in [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]:
            kp[fi, idx, 3] = 0.85 + np.random.rand() * 0.15

    return kp


# ══════════════════════════════════════════════════════════════
#  SIMULATION DU FIT (sans PyTorch)
# ══════════════════════════════════════════════════════════════

def simulate_optimization(n_iter: int, init_loss: float) -> list:
    """Simule la courbe de loss d'un optimiseur Adam."""
    losses = [init_loss]
    lr = 0.04
    loss = init_loss
    for i in range(n_iter):
        decay = np.exp(-0.15 * i) + np.random.rand() * 0.005
        loss *= (1 - lr * decay * 0.3)
        losses.append(max(loss, 0.001))
    return losses


def generate_fake_vertices(transl: np.ndarray) -> np.ndarray:
    """Génère des vertices factices pour un corps humain simplifié."""
    # Simule un corps humain avec ~100 vertices (version très simplifiée)
    np.random.seed(0)
    verts = np.random.randn(10475, 3).astype(np.float32) * 0.05
    # Corps centré sur pelvis
    verts += transl
    return verts


def generate_fake_faces(n_faces: int = 20908) -> np.ndarray:
    """Génère de faux triangles de mesh."""
    return (np.random.randint(0, 10475, size=(n_faces, 3))).astype(np.int32)


# ══════════════════════════════════════════════════════════════
#  DÉMONSTRATION PRINCIPALE
# ══════════════════════════════════════════════════════════════

def run_demo():

    title("DÉMONSTRATION — SmplxService Pipeline")
    print(f"\n  Ce script simule chaque étape de {BOLD}smplx_service.py{RESET}")
    print(f"  sans avoir besoin de PyTorch ou SMPL-X installés.")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 0 : Mapping MediaPipe → SMPL-X
    # ──────────────────────────────────────────────────────────
    step(0, "Mapping MediaPipe (33 landmarks) → SMPL-X (22 joints)")
    info("MediaPipe détecte 33 points, SMPL-X n'en utilise que 22.")
    info("Le dictionnaire MP_TO_SMPLX définit la correspondance :\n")

    print(f"  {'SMPL-X Joint':20s}  {'Indice':6s}  {'Sources MediaPipe'}")
    print(f"  {'-'*55}")
    for smplx_idx, mp_idxs in MP_TO_SMPLX.items():
        if smplx_idx < 22:
            joint_name = SMPLX_JOINT_NAMES[smplx_idx]
            mp_names = [MEDIAPIPE_LANDMARK_NAMES.get(i, f"mp[{i}]") for i in mp_idxs]
            src = " + ".join(mp_names)
            if len(mp_idxs) > 1:
                src = f"avg({src})"
            print(f"  {joint_name:20s}  [{smplx_idx:2d}]    ← {src}")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 1 : Chargement des keypoints
    # ──────────────────────────────────────────────────────────
    step(1, "Chargement et préparation des keypoints 3D")

    NUM_FRAMES = 60
    info(f"Génération de {NUM_FRAMES} frames de keypoints factices...")
    kp3d = generate_fake_keypoints(num_frames=NUM_FRAMES)
    show_array("kp3d", kp3d)
    data("Format", "(F=frames, 33=landmarks, 4=[x,y,z,visibility])")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 2 : Lissage temporel
    # ──────────────────────────────────────────────────────────
    step(2, "Lissage temporel (Gaussian filter) — anti-jitter")
    info("Avant lissage — variance temporelle d'un joint:")

    joint_15_before = kp3d[:, 15, :3].copy()
    var_before = np.var(joint_15_before, axis=0).mean()
    data("Variance poignet gauche (AVANT)", f"{var_before:.6f}")

    import scipy.ndimage
    kp3d[:, :, :3] = scipy.ndimage.gaussian_filter1d(kp3d[:, :, :3], sigma=1.5, axis=0)

    joint_15_after = kp3d[:, 15, :3]
    var_after = np.var(joint_15_after, axis=0).mean()
    data("Variance poignet gauche (APRÈS)", f"{var_after:.6f}")
    ok(f"Réduction du jitter de {(1 - var_after/var_before)*100:.1f}% !")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 3 : Normalisation d'échelle
    # ──────────────────────────────────────────────────────────
    step(3, "Normalisation d'échelle → conversion en mètres")

    tgt_first, v_first = _build_target_joints(kp3d[0])
    pelvis = tgt_first[0]
    neck   = tgt_first[12]
    torso_len = np.linalg.norm(neck - pelvis)
    scale = 0.50 / torso_len
    kp3d[:, :, :3] *= scale

    info("SMPL-X travaille en mètres. Torso standard = 0.50m")
    data("Longueur torse détectée (avant)", f"{torso_len:.4f} unités")
    data("Facteur de normalisation", f"{scale:.5f}")
    data("Longueur torse après normalisation", "0.5000 m ✔")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 4 : Build target joints (frame 0)
    # ──────────────────────────────────────────────────────────
    step(4, "_build_target_joints() — Conversion MediaPipe → SMPL-X")
    info("Conversion de la frame 0...")

    target, valid = _build_target_joints(kp3d[0])

    print(f"\n  {'Joint SMPL-X':20s} {'X':>8s} {'Y':>8s} {'Z':>8s} {'Valide':>8s}")
    print(f"  {'-'*56}")
    for i, (jname, t, v) in enumerate(zip(SMPLX_JOINT_NAMES, target, valid)):
        row_color = GREEN if v else RED
        status = "✔" if v else "✘"
        print(f"  {row_color}{jname:20s} {t[0]:8.4f} {t[1]:8.4f} {t[2]:8.4f} {status:>8s}{RESET}")

    n_valid = valid.sum()
    ok(f"{n_valid}/22 joints valides dans cette frame")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 5 : Initialisation d'orientation
    # ──────────────────────────────────────────────────────────
    step(5, "Initialisation orientation — Test des 4 directions cardinales")
    info("Pour éviter les minima locaux, on teste 4 angles de départ:")

    angles = [0.0, np.pi/2, np.pi, 3*np.pi/2]
    angle_names = ["0° (face)", "90° (profil gauche)", "180° (dos)", "270° (profil droit)"]
    fake_losses = [0.45, 0.38, 0.42, 0.51]
    best_idx = np.argmin(fake_losses)

    print(f"\n  {'Angle':20s} {'Loss simulée':>15s} {'Sélectionné':>12s}")
    print(f"  {'-'*50}")
    for name, loss, i in zip(angle_names, fake_losses, range(4)):
        sel = f"  {GREEN}◄ MEILLEUR{RESET}" if i == best_idx else ""
        print(f"  {name:20s} {loss:15.4f}{sel}")

    ok(f"Orientation initiale: {angle_names[best_idx]}")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 6 : Stage 1 — Shape fitting
    # ──────────────────────────────────────────────────────────
    step(6, "STAGE 1 — Estimation de forme (betas) — 60 itérations")
    info("Optimise: betas (10), transl (3), g_orient (3)")
    info("Loss = MSE(joints_prédits[valides], joints_cibles[valides])")
    info("Optimiseur: Adam, lr=0.04\n")

    losses_shape = simulate_optimization(n_iter=60, init_loss=0.38)
    print(f"  {'Ité':>5s}  {'Loss':>10s}  {'Barre'}")
    for i, loss in enumerate(losses_shape[::10]):
        bar_len = int(loss / losses_shape[0] * 30)
        bar = "█" * bar_len + "░" * (30 - bar_len)
        iter_num = i * 10
        print(f"  {iter_num:>5d}  {loss:>10.5f}  {CYAN}{bar}{RESET}")

    ok(f"Loss finale shape: {losses_shape[-1]:.5f} (réduite de {(1-losses_shape[-1]/losses_shape[0])*100:.1f}%) ")
    ok("betas fixés pour toutes les frames suivantes !")

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 7 : Stage 2 — Per-frame pose fitting
    # ──────────────────────────────────────────────────────────
    step(7, "STAGE 2 — Fitting de pose per-frame (warm-start)")
    info(f"Traitement de {NUM_FRAMES} frames, {25} itérations chacune...")
    info("Warm-start: chaque frame commence depuis la frame précédente")
    info("Loss = MSE(joints) + 0.001 × ||pose||² (régulariseur)\n")

    all_vertices = []
    all_joints   = []
    prev_loss    = 0.45

    # Simule le tqdm progress bar
    print(f"  {'Frame':>6s}  {'Joints OK':>10s}  {'Loss init':>10s}  {'Loss final':>11s}")
    print(f"  {'-'*52}")

    for fi in range(NUM_FRAMES):
        t_np, v_np = _build_target_joints(kp3d[fi])
        n_valid_f  = v_np.sum()

        if n_valid_f < 5:
            if all_vertices:
                all_vertices.append(all_vertices[-1])
                all_joints.append(all_joints[-1])
            continue

        # Simule l'optimisation
        init_loss  = prev_loss * (0.95 + np.random.rand() * 0.1)
        losses_f   = simulate_optimization(25, init_loss)
        final_loss = losses_f[-1]
        prev_loss  = final_loss

        # Génère des données factices
        pelvis_pos = t_np[0] if v_np[0] else np.zeros(3)
        verts = generate_fake_vertices(pelvis_pos)
        all_vertices.append(verts)
        all_joints.append(t_np)

        if fi % 10 == 0 or fi == NUM_FRAMES - 1:
            print(f"  {fi:>6d}  {n_valid_f:>10d}  {init_loss:>10.5f}  {final_loss:>11.5f}")

    vertices_arr = np.array(all_vertices, dtype=np.float32)
    joints_arr   = np.array(all_joints,   dtype=np.float32)

    ok(f"Pose fitting terminé!")
    show_array("vertices_arr", vertices_arr)
    show_array("joints_arr",   joints_arr)

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 8 : Sauvegarde .npz
    # ──────────────────────────────────────────────────────────
    step(8, "Sauvegarde smplx_result.npz")

    output_dir = "/tmp/demo_smplx_output"
    os.makedirs(output_dir, exist_ok=True)
    npz_path = os.path.join(output_dir, "smplx_result.npz")

    faces = generate_fake_faces()
    np.savez_compressed(npz_path, vertices=vertices_arr, joints=joints_arr, faces=faces)
    size_kb = os.path.getsize(npz_path) / 1024

    ok(f"Sauvegardé: {npz_path}")
    data("Taille fichier",   f"{size_kb:.1f} KB")
    data("vertices shape",   str(vertices_arr.shape))
    data("joints shape",     str(joints_arr.shape))
    data("faces shape",      str(faces.shape))

    # ──────────────────────────────────────────────────────────
    # ÉTAPE 9 : Export Three.js JSON
    # ──────────────────────────────────────────────────────────
    step(9, "Export smplx_threejs.json (pour Flutter/Three.js)")
    info("Downsampling si trop de frames pour le web...")

    max_frames = 9000
    num_frames_out = vertices_arr.shape[0]
    step_size = max(1, num_frames_out // max_frames)
    sampled = list(range(0, num_frames_out, step_size))[:max_frames]

    json_path = os.path.join(output_dir, "smplx_threejs.json")
    data_dict = {
        "meta": {
            "total_frames":    num_frames_out,
            "exported_frames": len(sampled),
            "n_vertices":      int(vertices_arr.shape[1]),
            "n_joints":        int(joints_arr.shape[1]),
            "fps":             30,
        },
        "faces": faces.flatten().tolist(),
        "frames": [
            {
                "v": np.round(vertices_arr[i].flatten(), 4).tolist(),
                "j": np.round(joints_arr[i].flatten(), 4).tolist(),
            }
            for i in sampled
        ],
    }

    with open(json_path, "w") as f:
        json.dump(data_dict, f, separators=(",", ":"))

    size_mb = os.path.getsize(json_path) / (1024 * 1024)
    ok(f"JSON Three.js exporté: {json_path}")
    data("Taille fichier",      f"{size_mb:.2f} MB")
    data("Total frames",        str(num_frames_out))
    data("Frames exportées",    str(len(sampled)))
    data("Vertices par frame",  str(vertices_arr.shape[1]))

    # Affiche un extrait du JSON
    print(f"\n  {BLUE}Aperçu du JSON (meta + début de frames):{RESET}")
    preview = {
        "meta": data_dict["meta"],
        "faces": f"[{len(data_dict['faces'])} integers...]",
        "frames": [
            {"v": f"[{len(data_dict['frames'][0]['v'])} floats...]",
             "j": data_dict["frames"][0]["j"][:6]}
        ]
    }
    print("  " + json.dumps(preview, indent=4).replace("\n", "\n  "))

    # ──────────────────────────────────────────────────────────
    # RÉSUMÉ FINAL
    # ──────────────────────────────────────────────────────────
    title("RÉSUMÉ DU PIPELINE SMPL-X")
    print(f"""
  {CYAN}INPUT{RESET}
  ├─ keypoints_3d.npy  →  ({NUM_FRAMES}, 33, 4)
  │    └─ 33 landmarks MediaPipe, 4 = [x, y, z, visibilité]
  │
  {CYAN}TRAITEMENT{RESET}
  ├─ {GREEN}Étape 0{RESET}: Mapping MediaPipe (33) → SMPL-X (22 joints)
  ├─ {GREEN}Étape 1{RESET}: Chargement keypoints_3d.npy
  ├─ {GREEN}Étape 2{RESET}: Lissage temporel Gaussien (σ=1.5)
  ├─ {GREEN}Étape 3{RESET}: Normalisation en mètres (torso = 0.5m)
  ├─ {GREEN}Étape 4{RESET}: Conversion coordonnées (OpenCV → OpenGL)
  ├─ {GREEN}Étape 5{RESET}: Initialisation orientation (4 tests + meilleur)
  ├─ {GREEN}Étape 6{RESET}: Stage 1 — Shape fitting (60 iters, Adam)
  │    └─ Optimise: betas(10) + transl(3) + orient(3)
  └─ {GREEN}Étape 7{RESET}: Stage 2 — Pose fitting per-frame (25 iters/frame)
       └─ Warm-start + régulariseur de pose
  │
  {CYAN}OUTPUT{RESET}
  ├─ smplx_result.npz     →  vertices({NUM_FRAMES}, 10475, 3) + joints({NUM_FRAMES}, 22, 3) + faces
  └─ smplx_threejs.json   →  JSON compact pour Three.js/Flutter
    """)

    ok("Pipeline complet exécuté avec succès! ✨")
    print(f"\n  {YELLOW}Note: Dans l'application réelle, les étapes 6 et 7 utilisent{RESET}")
    print(f"  {YELLOW}PyTorch + smplx pour le gradient descent sur de vrais modèles.{RESET}")
    print(f"  {YELLOW}Ce démo simule la logique sans ces dépendances lourdes.{RESET}\n")


if __name__ == "__main__":
    run_demo()
