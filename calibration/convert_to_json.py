"""
Convert EasyMocap intri.yml + extri.yml → calibration.json (one per camera).

calibration.json format:
  intrinsics_w_distortion:
    f: [[fx, fy]]
    c: [[cx, cy]]
    k: [[k1, k2, k3]]   (radial)
    p: [[p1, p2]]        (tangential)
  extrinsics:
    R: [[...3x3...]]     rotation matrix (world→cam)
    T: [x, y, z]         camera center C = -R^T @ T_opencv
"""

import os, json
import cv2


def _read_yml(path: str) -> dict:
    fs = cv2.FileStorage(path, cv2.FILE_STORAGE_READ)
    if not fs.isOpened():
        raise FileNotFoundError(f"Cannot open {path}")
    return fs


def convert(intri_yml: str, extri_yml: str, out_root: str, cameras: list):
    fs_intri = cv2.FileStorage(intri_yml, cv2.FILE_STORAGE_READ)
    fs_extri = cv2.FileStorage(extri_yml, cv2.FILE_STORAGE_READ)

    if not fs_intri.isOpened():
        raise FileNotFoundError(f"Cannot open {intri_yml}")
    if not fs_extri.isOpened():
        raise FileNotFoundError(f"Cannot open {extri_yml}")

    for cam in cameras:
        # ── Intrinsics ────────────────────────────────────────────────────────
        # EasyMocap uses K_{cam} / dist_{cam} keys
        K    = fs_intri.getNode(f"K_{cam}").mat()     # 3×3
        dist = fs_intri.getNode(f"dist_{cam}").mat()  # 1×5

        if K is None or K.size == 0:
            print(f"  ⚠️  {cam}: intrinsics not found in {intri_yml}, skipping")
            continue

        dist = dist.flatten()   # [k1, k2, p1, p2, k3]
        fx, fy = float(K[0, 0]), float(K[1, 1])
        cx, cy = float(K[0, 2]), float(K[1, 2])
        k1, k2 = float(dist[0]), float(dist[1])
        p1, p2 = float(dist[2]), float(dist[3])
        k3     = float(dist[4]) if len(dist) > 4 else 0.0

        # ── Extrinsics ────────────────────────────────────────────────────────
        # EasyMocap uses Rot_{cam} (3×3) and T_{cam} (3×1)
        Rot = fs_extri.getNode(f"Rot_{cam}").mat()   # 3×3 rotation matrix
        T   = fs_extri.getNode(f"T_{cam}").mat()     # 3×1 OpenCV translation

        if Rot is None or Rot.size == 0:
            # Fall back to axis-angle R_{cam} → convert via Rodrigues
            Rvec = fs_extri.getNode(f"R_{cam}").mat()
            if Rvec is None or Rvec.size == 0:
                print(f"  ⚠️  {cam}: extrinsics not found in {extri_yml}, skipping")
                continue
            Rot, _ = cv2.Rodrigues(Rvec.flatten())

        T = T.flatten()  # [tx, ty, tz]

        # Camera center: C = -R^T @ T
        C = (-Rot.T @ T).tolist()
        R_rows = Rot.tolist()

        # ── Write JSON ────────────────────────────────────────────────────────
        cam_out_dir = os.path.join(out_root, cam)
        os.makedirs(cam_out_dir, exist_ok=True)
        out_path = os.path.join(cam_out_dir, "calibration.json")

        calib = {
            "intrinsics_w_distortion": {
                "f": [[fx, fy]],
                "c": [[cx, cy]],
                "k": [[k1, k2, k3]],
                "p": [[p1, p2]],
            },
            "extrinsics": {
                "R": R_rows,
                "T": C,
            },
        }

        with open(out_path, "w") as f:
            json.dump(calib, f, indent=4)

        print(f"  ✓  {cam} → {out_path}")
        print(f"       f=({fx:.1f},{fy:.1f})  c=({cx:.1f},{cy:.1f})  C={[round(v,3) for v in C]}")

    fs_intri.release()
    fs_extri.release()
    print("\n✅ conversion complete")


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--intri",    required=True, help="Path to intri.yml")
    p.add_argument("--extri",    required=True, help="Path to extri.yml")
    p.add_argument("--out",      required=True, help="Output root directory")
    p.add_argument("--cameras",  nargs="+", default=["Lb", "Lf", "Rb", "Rf"])
    args = p.parse_args()

    convert(args.intri, args.extri, args.out, args.cameras)
