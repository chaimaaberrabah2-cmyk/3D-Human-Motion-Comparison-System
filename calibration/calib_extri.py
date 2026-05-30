a"""
Extrinsic calibration from synchronized chessboard JSON detections.
Reads  calibration/output/extri_chessboard/{cam}/*.json
Reads  calibration/output/intri.yml
Writes calibration/output/extri.yml

Strategy: for each frame where ALL cameras detect the board, solve PnP per camera.
Average R (via Rodrigues mean) and T over all valid frames.
"""

import os, sys, json, glob
import numpy as np
import cv2

CAMERAS = ["Lb", "Lf", "Rb", "Rf"]


def load_detections(chessboard_root: str) -> dict:
    """Load {cam: {frame_id: (pts3d, pts2d)}} from JSON files."""
    data = {}
    for cam in CAMERAS:
        folder = os.path.join(chessboard_root, cam)
        cam_data = {}
        for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
            fid = os.path.splitext(os.path.basename(path))[0]
            with open(path) as f:
                d = json.load(f)
            if not d.get("visited", True):
                continue
            pts3d = np.ascontiguousarray(d["keypoints3d"], dtype=np.float32)
            pts2d = np.array(d["keypoints2d"], dtype=np.float32)[:, :2].copy().reshape(-1, 1, 2)
            cam_data[fid] = (pts3d, pts2d)
        data[cam] = cam_data
        print(f"  {cam}: {len(cam_data)} frames with detections")
    return data


def load_intri(intri_yml: str) -> dict:
    fs = cv2.FileStorage(intri_yml, cv2.FILE_STORAGE_READ)
    result = {}
    for cam in CAMERAS:
        K    = fs.getNode(f"K_{cam}").mat()
        dist = fs.getNode(f"dist_{cam}").mat()
        result[cam] = (K, dist)
    fs.release()
    return result


def mean_rotation(rvecs: list) -> np.ndarray:
    """Average a list of rotation vectors via mean of rotation matrices."""
    mats = [cv2.Rodrigues(r)[0] for r in rvecs]
    mean_mat = np.mean(mats, axis=0)
    # Project back to SO(3) via SVD
    U, _, Vt = np.linalg.svd(mean_mat)
    R = U @ Vt
    if np.linalg.det(R) < 0:
        R = -R
    return R


def calib_extri(chessboard_root: str, intri_yml: str, out_yml: str):
    detections = load_detections(chessboard_root)
    intrinsics  = load_intri(intri_yml)

    # Find frames where ALL cameras have a detection
    frame_sets = [set(detections[cam].keys()) for cam in CAMERAS]
    common_frames = sorted(frame_sets[0].intersection(*frame_sets[1:]))
    print(f"\n  Common frames (all cameras): {len(common_frames)}")

    if len(common_frames) < 10:
        print("❌ Not enough synchronized frames. Check chessboard JSONs.")
        sys.exit(1)

    # Per-camera: collect rvec, tvec from solvePnP over all common frames
    cam_rvecs = {cam: [] for cam in CAMERAS}
    cam_tvecs = {cam: [] for cam in CAMERAS}

    failed = 0
    for fid in common_frames:
        for cam in CAMERAS:
            K, dist = intrinsics[cam]
            pts3d, pts2d = detections[cam][fid]
            try:
                ok, rvec, tvec = cv2.solvePnP(
                    pts3d, pts2d, K, dist,
                    flags=cv2.SOLVEPNP_ITERATIVE,
                )
                if ok:
                    cam_rvecs[cam].append(rvec.flatten())
                    cam_tvecs[cam].append(tvec.flatten())
            except cv2.error:
                failed += 1
    if failed:
        print(f"  (skipped {failed} failed solvePnP calls)")

    fs = cv2.FileStorage(out_yml, cv2.FILE_STORAGE_WRITE)
    fs.write("names", CAMERAS)

    for cam in CAMERAS:
        rvecs = cam_rvecs[cam]
        tvecs = cam_tvecs[cam]
        if len(rvecs) < 5:
            print(f"  ⚠️  {cam}: not enough valid PnP solutions, skipping")
            continue

        rvecs_arr = np.array(rvecs)
        tvecs_arr = np.array(tvecs)

        # Use RANSAC-style median for robustness
        med_rvec = np.median(rvecs_arr, axis=0)
        med_tvec = np.median(tvecs_arr, axis=0)

        Rot, _ = cv2.Rodrigues(med_rvec)

        # Camera center C = -R^T @ T
        C = (-Rot.T @ med_tvec).tolist()

        fs.write(f"R_{cam}",   med_rvec.reshape(3, 1))
        fs.write(f"Rot_{cam}", Rot)
        fs.write(f"T_{cam}",   med_tvec.reshape(3, 1))

        print(f"  {cam}: {len(rvecs)} frames used  |  C={[round(v,3) for v in C]}")

    fs.release()
    print(f"\n✅ extri.yml saved → {out_yml}")


if __name__ == "__main__":
    root            = os.path.dirname(os.path.abspath(__file__))
    chessboard_root = os.path.join(root, "output", "extri_chessboard")
    intri_yml       = os.path.join(root, "output", "intri.yml")
    out_yml         = os.path.join(root, "output", "extri.yml")
    calib_extri(chessboard_root, intri_yml, out_yml)
