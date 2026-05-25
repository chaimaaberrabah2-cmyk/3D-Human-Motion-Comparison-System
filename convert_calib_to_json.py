import cv2
import numpy as np
import os
import json

def read_opencv_matrix(node):
    if node.empty(): return None
    rows = int(node.getNode('rows').real())
    cols = int(node.getNode('cols').real())
    data = node.getNode('data')
    mat = np.zeros(rows * cols, dtype=np.float32)
    for i in range(data.size()):
        mat[i] = data.at(i).real()
    return mat.reshape((rows, cols))

def convert_calibration(intri_path, extri_path, output_dir, exercise_name="deadlift"):
    # Load intri
    fs_in = cv2.FileStorage(intri_path, cv2.FILE_STORAGE_READ)
    fs_ex = cv2.FileStorage(extri_path, cv2.FILE_STORAGE_READ)
    
    names_node = fs_in.getNode('names')
    names = [names_node.at(i).string() for i in range(names_node.size())]
    
    for cam in names:
        K = read_opencv_matrix(fs_in.getNode(f'K_{cam}'))
        dist = read_opencv_matrix(fs_in.getNode(f'dist_{cam}'))
        R_vec = read_opencv_matrix(fs_ex.getNode(f'R_{cam}'))
        T_vec = read_opencv_matrix(fs_ex.getNode(f'T_{cam}'))
        R_mat = read_opencv_matrix(fs_ex.getNode(f'Rot_{cam}'))
        
        # Fit3D JSON structure
        # f: focal length (fx, fy)
        # c: principal point (cx, cy)
        # k: radial distortion (k1, k2, k3)
        # p: tangential distortion (p1, p2)
        # R: rotation matrix (3x3)
        # T: camera center in world coordinates!
        # Wait, OpenCV T is translation vector, t = -R * C => C = -R^T * t
        
        C = -np.dot(R_mat.T, T_vec)
        
        json_data = {
            "intrinsics_w_distortion": {
                "f": [[float(K[0,0]), float(K[1,1])]],
                "c": [[float(K[0,2]), float(K[1,2])]],
                "k": [[float(dist[0,0]), float(dist[0,1]), float(dist[0,4])]],
                "p": [[float(dist[0,2]), float(dist[0,3])]]
            },
            "extrinsics": {
                "R": R_mat.tolist(),
                "T": C.flatten().tolist()
            }
        }
        
        # Save to output_dir/cam/exercise_name.json
        cam_dir = os.path.join(output_dir, cam)
        os.makedirs(cam_dir, exist_ok=True)
        out_path = os.path.join(cam_dir, f"{exercise_name}.json")
        with open(out_path, 'w') as f:
            json.dump(json_data, f, indent=4)
        print(f"Saved {out_path}")
        
    fs_in.release()
    fs_ex.release()

if __name__ == "__main__":
    base = "/Volumes/Ikram's SSD/test dataset/easymocap_calib/extri"
    intri = os.path.join(base, "intri.yml")
    extri = os.path.join(base, "extri.yml")
    
    out_dir = "/Volumes/Ikram's SSD/3D-Human-Motion-Comparison-System/backend/data/calibration/test_dataset"
    convert_calibration(intri, extri, out_dir, exercise_name="deadlift")
