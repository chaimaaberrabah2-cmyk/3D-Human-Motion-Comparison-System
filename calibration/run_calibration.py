"""
Full calibration pipeline — self-contained, no EasyMocap dependency.

Steps:
  1. (optional) Extract frames from extrinsic calibration videos
  2. (optional) Detect chessboard corners  → output/intri_chessboard/ + output/extri_chessboard/
  3. Calibrate intrinsics per camera       → output/intri.yml
  4. Calibrate extrinsics multi-camera     → output/extri.yml
  5. Convert intri.yml + extri.yml         → output/{Lb,Lf,Rb,Rf}/calibration.json

Chessboard: 3×4 inner corners, 135mm squares
Cameras: Lb, Lf, Rb, Rf
"""

import os, sys, subprocess, cv2, json

# ── Config ────────────────────────────────────────────────────────────────────
ROOT        = os.path.dirname(os.path.abspath(__file__))
VIDEO_ROOT  = "/Volumes/SSD_Ikram/test dataset"
CALIB_OUT   = os.path.join(ROOT, "output")
CAMERAS     = ["Lb", "Lf", "Rb", "Rf"]
PATTERN_ROWS = 4      # inner corners (height direction)
PATTERN_COLS = 3      # inner corners (width direction)
GRID_SIZE    = 0.135  # metres per square
MAX_FRAMES   = 150
FRAME_STEP   = 5
PYTHON       = "/Users/HP/.pyenv/versions/3.11.7/bin/python3"

# ── Paths ─────────────────────────────────────────────────────────────────────
intri_chessboard = os.path.join(CALIB_OUT, "intri_chessboard")
extri_chessboard = os.path.join(CALIB_OUT, "extri_chessboard")
intri_yml        = os.path.join(CALIB_OUT, "intri.yml")
extri_yml        = os.path.join(CALIB_OUT, "extri.yml")


# ── Step 1: Extract frames ────────────────────────────────────────────────────
def extract_frames():
    print("\n═══ STEP 1: Extract frames from extrinsic calibration videos ═══")
    for cam in CAMERAS:
        for ext in ["MOV", "mp4"]:
            video = os.path.join(VIDEO_ROOT, f"videos {cam}", f"extrinsic.{ext}")
            if os.path.exists(video):
                break
        else:
            print(f"⚠️  No extrinsic video found for {cam}")
            continue

        intri_dir = os.path.join(CALIB_OUT, "intri_images", cam)
        extri_dir = os.path.join(CALIB_OUT, "extri_images", cam)
        os.makedirs(intri_dir, exist_ok=True)
        os.makedirs(extri_dir, exist_ok=True)

        cap   = cv2.VideoCapture(video)
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps   = cap.get(cv2.CAP_PROP_FPS)
        print(f"  {cam}: {video} ({total} frames @ {fps:.1f}fps)")

        fi, saved_intri, saved_extri = 0, 0, 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if fi % FRAME_STEP == 0 and saved_intri < MAX_FRAMES:
                cv2.imwrite(os.path.join(intri_dir, f"{fi:06d}.jpg"), frame)
                saved_intri += 1
            cv2.imwrite(os.path.join(extri_dir, f"{fi:06d}.jpg"), frame)
            saved_extri += 1
            fi += 1
        cap.release()
        print(f"    → {saved_intri} intri frames, {saved_extri} extri frames")


# ── Step 2: Detect chessboard ─────────────────────────────────────────────────
def detect_chessboard():
    print("\n═══ STEP 2: Detect chessboard corners ═══")
    detect_script = os.path.join(ROOT, "detect_chessboard.py")
    if not os.path.exists(detect_script):
        print("❌ detect_chessboard.py not found. Run --skip-detect if detection already done.")
        sys.exit(1)

    for mode in ["intri", "extri"]:
        images_root = os.path.join(CALIB_OUT, f"{mode}_images")
        out_root    = os.path.join(CALIB_OUT, f"{mode}_chessboard")
        subprocess.run([
            PYTHON, detect_script,
            images_root,
            "--out",     out_root,
            "--pattern", str(PATTERN_ROWS), str(PATTERN_COLS),
            "--grid",    str(GRID_SIZE),
        ], check=True)


# ── Step 3: Calibrate intrinsics ──────────────────────────────────────────────
def calib_intri():
    print("\n═══ STEP 3: Calibrate intrinsics ═══")
    from calib_intri import calib_intri as _run
    _run(intri_chessboard, intri_yml)


# ── Step 4: Calibrate extrinsics ──────────────────────────────────────────────
def calib_extri():
    print("\n═══ STEP 4: Calibrate extrinsics ═══")
    from calib_extri import calib_extri as _run
    _run(extri_chessboard, intri_yml, extri_yml)


# ── Step 5: Convert YMLs → calibration.json ──────────────────────────────────
def convert_to_json():
    print("\n═══ STEP 5: Convert to calibration.json ═══")
    from convert_to_json import convert
    convert(intri_yml, extri_yml, CALIB_OUT, CAMERAS)


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    sys.path.insert(0, ROOT)

    p = argparse.ArgumentParser()
    p.add_argument("--skip-extract", action="store_true")
    p.add_argument("--skip-detect",  action="store_true")
    p.add_argument("--skip-intri",   action="store_true")
    p.add_argument("--skip-extri",   action="store_true")
    p.add_argument("--convert-only", action="store_true")
    args = p.parse_args()

    if args.convert_only:
        convert_to_json()
        sys.exit(0)

    if not args.skip_extract: extract_frames()
    if not args.skip_detect:  detect_chessboard()
    if not args.skip_intri:   calib_intri()
    if not args.skip_extri:   calib_extri()
    convert_to_json()

    print("\n✅ Calibration complete! JSON files in calibration/output/{Lb,Lf,Rb,Rf}/calibration.json")
