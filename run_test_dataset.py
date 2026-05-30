import os
import sys
import json
import argparse
_PYENV_PY = "/Users/HP/.pyenv/versions/3.11.7/bin/python3"
if os.path.exists(_PYENV_PY) and sys.executable != _PYENV_PY:
    os.execv(_PYENV_PY, [_PYENV_PY] + sys.argv)

current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.join(current_dir, "backend")
sys.path.append(backend_dir)

from app.pipeline.step1_frame_extractor_service import VideoService
from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService
from app.pipeline.step4_smplx_fitting_service import SmplxService

MAX_FRAMES   = 900
DATASET_ROOT  = "/Volumes/SSD_Ikram/test dataset"
CAMERAS       = ["Lb", "Lf", "Rb", "Rf"]
CALIB_ROOT    = "/Volumes/SSD_Ikram/test_dataset"   # calibration.json per camera


def save_status(output_root, phase, message):
    path = os.path.join(output_root, "status.json")
    data = {}
    if os.path.exists(path):
        try:
            data = json.load(open(path))
        except Exception:
            pass
    data["phase"] = phase
    data["message"] = message
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"\n[status] {phase}: {message}")


def run_test_pipeline(exercise_name):
    # Output named test_{exercise} to avoid overwriting reference data
    output_name = f"test_{exercise_name}"
    output_root = os.path.join(current_dir, "backend", "data", "frames", output_name)
    os.makedirs(output_root, exist_ok=True)

    print(f"🚀 Pipeline test_dataset: {exercise_name}")
    print(f"📂 Output: {output_root}")

    # ── Find videos ──────────────────────────────────────────────────────────
    video_paths = []
    for cam in CAMERAS:
        found = None
        for ext in ["MOV", "mp4"]:
            p = os.path.join(DATASET_ROOT, f"videos {cam}", f"{exercise_name}.{ext}")
            if os.path.exists(p):
                found = p
                break
        if found:
            video_paths.append(found)
        else:
            print(f"❌ Vidéo manquante: videos {cam}/{exercise_name}.[MOV|mp4]")
            return

    # ── Phase 1: Frame extraction ─────────────────────────────────────────────
    save_status(output_root, "Phase 1/4", "Extraction des frames...")
    for i, path in enumerate(video_paths):
        cam = CAMERAS[i]
        temp_folder = os.path.join(output_root, f"temp{i+1}")
        os.makedirs(temp_folder, exist_ok=True)
        print(f"\n[Phase 1] {cam}: {path}")
        VideoService.extract_frames(path, temp_folder, max_frames=MAX_FRAMES)
        n = len([f for f in os.listdir(temp_folder) if f.endswith(".jpg")])
        print(f"  → {n} frames extraites dans {temp_folder}")

    # ── Phase 2: MediaPipe 2D ─────────────────────────────────────────────────
    save_status(output_root, "Phase 2/4", "Pose 2D MediaPipe...")
    angle_results_count = 0
    for i in range(1, 5):
        temp_folder = os.path.join(output_root, f"temp{i}")
        keypoints_file = os.path.join(output_root, f"keypoints_angle{i}.npy")
        print(f"\n[Phase 2] Camera {i}: {temp_folder}")
        if os.path.exists(temp_folder) and os.listdir(temp_folder):
            success = PoseService.extract_keypoints(temp_folder, keypoints_file, save_annotated=True)
            if success:
                import numpy as np
                kp = np.load(keypoints_file)
                print(f"  → keypoints_angle{i}.npy  shape={kp.shape}  ✅")
                angle_results_count += 1
            else:
                print(f"  → ❌ Pose estimation échouée")
        else:
            print(f"  → ❌ Dossier vide ou absent")

    if angle_results_count < 2:
        save_status(output_root, "ERREUR", f"Seulement {angle_results_count}/4 angles valides")
        print(f"\n❌ Pas assez d'angles ({angle_results_count}/4). Arrêt.")
        return

    # ── Phase 3: Triangulation 3D ─────────────────────────────────────────────
    save_status(output_root, "Phase 3/4", "Triangulation 3D...")
    # Build calibration file list — one per camera, same order as CAMERAS
    calib_files = [os.path.join(CALIB_ROOT, cam, "calibration.json") for cam in CAMERAS]
    for cf in calib_files:
        if not os.path.exists(cf):
            print(f"❌ Calibration manquante: {cf}")
            return
    print(f"\n[Phase 3] Triangulation 3D avec calibration test_dataset...")
    for cam, cf in zip(CAMERAS, calib_files):
        print(f"  {cam}: {cf}")
    keypoints_3d_file = TriangulationService.triangulate(output_root, exercise_name,
                                                          calib_files=calib_files,
                                                          img_w=1920, img_h=1440)
    if not keypoints_3d_file or not os.path.exists(keypoints_3d_file):
        save_status(output_root, "ERREUR", "Triangulation échouée")
        print("❌ Triangulation échouée. Arrêt.")
        return

    import numpy as np
    kp3d = np.load(keypoints_3d_file)
    print(f"  → keypoints_3d.npy  shape={kp3d.shape}  ✅")

    print(f"\n[Phase 3] Génération visualisations 3D...")
    results_3d_dir = os.path.join(output_root, "results_3d")
    TriangulationService.save_3d_visualizations(keypoints_3d_file, results_3d_dir)
    n_imgs = len(os.listdir(results_3d_dir)) if os.path.exists(results_3d_dir) else 0
    print(f"  → {n_imgs} images sauvegardées dans results_3d/")

    # ── Phase 4: SMPL-X fitting ───────────────────────────────────────────────
    save_status(output_root, "Phase 4/4", "Fitting SMPL-X...")
    print(f"\n[Phase 4] SMPL-X body fitting...")
    SmplxService.fit_and_save(output_root)

    # Verify outputs
    smplx_npz  = os.path.join(output_root, "smplx_result.npz")
    smplx_json = os.path.join(output_root, "smplx_threejs.json")
    if os.path.exists(smplx_npz):
        d = np.load(smplx_npz)
        print(f"  → smplx_result.npz  joints={d['joints'].shape}  ✅")
    if os.path.exists(smplx_json):
        with open(smplx_json) as f:
            meta = json.load(f).get("meta", {})
        print(f"  → smplx_threejs.json  frames={meta.get('exported_frames')}  ✅")

    save_status(output_root, "Terminé", "Pipeline complet ✅")
    print(f"\n✅ Pipeline terminé! Résultats dans: {output_root}")
    print(f"\n▶  Voir le comparateur:")
    print(f"   python compare_viewer.py {output_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", help="ex: deadlift, squat, dumbbell_biceps_curls1")
    args = parser.parse_args()
    run_test_pipeline(args.exercise)
