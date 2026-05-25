import os
import yaml
import json
import numpy as np

# This script parses extri.yml and intri.yml, 
# and creates the correct json format for the 3D-Human-Motion-Comparison-System.

def load_opencv_yaml(filepath):
    # OpenCV yaml has a weird %YAML:1.0 header and !!opencv-matrix tags.
    # We will parse it manually or via a quick hack since PyYAML struggles with it out of the box.
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    data = {}
    current_key = None
    matrix_data = []
    parsing_data = False
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('%') or line == '---':
            continue
            
        if line.endswith('!!opencv-matrix'):
            current_key = line.split(':')[0]
            parsing_data = False
            continue
            
        if current_key:
            if line.startswith('data:'):
                data_str = line.replace('data:', '').strip()
                if data_str.startswith('[') and data_str.endswith(']'):
                    vals = [float(x) for x in data_str[1:-1].split(',')]
                    data[current_key] = vals
                else:
                    # Multi-line data not expected here but just in case
                    pass
    return data

def convert():
    base_dir = "/Volumes/SSD_Ikram/3D-Human-Motion-Comparison-System/calibration/resultat"
    intri_path = os.path.join(base_dir, "intri.yml")
    extri_path = os.path.join(base_dir, "extri.yml")
    
    intri_data = load_opencv_yaml(intri_path)
    extri_data = load_opencv_yaml(extri_path)
    
    cams = ["Lb", "Lf", "Rb", "Rf"]
    
    # Destination
    output_dir = "/Volumes/SSD_Ikram/3D-Human-Motion-Comparison-System/backend/data/calibration/camera_parameters"
    
    for cam in cams:
        # Intrinsic
        K = np.array(intri_data[f"K_{cam}"]).reshape(3, 3)
        dist = np.array(intri_data[f"dist_{cam}"]).reshape(1, 5)
        
        fx, fy = K[0, 0], K[1, 1]
        cx, cy = K[0, 2], K[1, 2]
        
        k1, k2, p1, p2, k3 = dist[0]
        
        # Extrinsic
        Rot = np.array(extri_data[f"Rot_{cam}"]).reshape(3, 3)
        T_cv = np.array(extri_data[f"T_{cam}"]).reshape(3, 1)
        
        # Our system expects data["extrinsics"]["T"] to be the Camera Center.
        # T_cv = -Rot @ Camera_Center => Camera_Center = -Rot.T @ T_cv
        Camera_Center = -Rot.T @ T_cv
        
        json_data = {
            "intrinsics_w_distortion": {
                "f": [[float(fx), float(fy)]],
                "c": [[float(cx), float(cy)]],
                "k": [[float(k1), float(k2), float(k3)]],
                "p": [[float(p1), float(p2)]]
            },
            "extrinsics": {
                "R": Rot.tolist(),
                "T": [Camera_Center.flatten().tolist()]
            }
        }
        
        cam_dir = os.path.join(output_dir, cam)
        os.makedirs(cam_dir, exist_ok=True)
        
        out_path = os.path.join(cam_dir, "ikram_dataset.json")
        with open(out_path, 'w') as f:
            json.dump(json_data, f, indent=4)
            
        print(f"Generated {out_path}")

if __name__ == '__main__':
    convert()
