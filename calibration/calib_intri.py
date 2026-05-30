"""
Intrinsic calibration from chessboard JSON detections.
Reads  calibration/output/intri_chessboard/{cam}/*.json
Writes calibration/output/intri.yml
"""

import os, json, glob
import numpy as np
import cv2

CAMERAS  = ["Lb", "Lf", "Rb", "Rf"]
IMG_SIZE = (1920, 1440)   # (width, height) — same for all cameras

def load_chessboard_json(folder: str) -> tuple:
    obj_all, img_all = [], []
    skipped = 0
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        with open(path) as f:
            d = json.load(f)
        if not d.get("visited", True):
            continue
        pts3d = np.ascontiguousarray(d["keypoints3d"], dtype=np.float32)   # (N,3)
        pts2d = np.array(d["keypoints2d"], dtype=np.float32)[:, :2].copy() # (N,2)
        # Filter degenerate views (homography fails → calibrateCamera crashes)
        H, _ = cv2.findHomography(pts3d[:, :2], pts2d)
        if H is None or H.shape != (3, 3):
            skipped += 1
            continue
        obj_all.append(pts3d.reshape(-1, 1, 3))
        img_all.append(pts2d.reshape(-1, 1, 2))
    if skipped:
        print(f"    (skipped {skipped} degenerate frames)")
    return obj_all, img_all


def calib_intri(chessboard_root: str, out_yml: str):
    fs = cv2.FileStorage(out_yml, cv2.FILE_STORAGE_WRITE)

    names = CAMERAS
    # Write camera list
    fs.write("names", names)

    for cam in CAMERAS:
        folder = os.path.join(chessboard_root, cam)
        obj_pts, img_pts = load_chessboard_json(folder)
        print(f"  {cam}: {len(obj_pts)} frames with detections")

        if len(obj_pts) < 5:
            print(f"  ⚠️  {cam}: not enough frames, skipping")
            continue

        ret, K, dist, rvecs, tvecs = cv2.calibrateCamera(
            obj_pts, img_pts, IMG_SIZE,
            None, None,
            flags=cv2.CALIB_FIX_K3,
        )
        print(f"  {cam}: reprojection error = {ret:.4f} px")
        print(f"         fx={K[0,0]:.1f} fy={K[1,1]:.1f} cx={K[0,2]:.1f} cy={K[1,2]:.1f}")

        fs.write(f"K_{cam}", K)
        fs.write(f"dist_{cam}", dist)

    fs.release()
    print(f"\n✅ intri.yml saved → {out_yml}")


if __name__ == "__main__":
    root = os.path.dirname(os.path.abspath(__file__))
    chessboard_root = os.path.join(root, "output", "intri_chessboard")
    out_yml         = os.path.join(root, "output", "intri.yml")
    calib_intri(chessboard_root, out_yml)
