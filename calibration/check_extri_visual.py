import cv2
import numpy as np
import os

def read_opencv_matrix(node):
    rows = node.getNode('rows').real()
    cols = node.getNode('cols').real()
    data = node.getNode('data')
    mat = np.zeros(int(rows * cols), dtype=np.float32)
    for i in range(data.size()):
        mat[i] = data.at(i).real()
    return mat.reshape((int(rows), int(cols)))

def read_yaml(path):
    fs = cv2.FileStorage(path, cv2.FILE_STORAGE_READ)
    if not fs.isOpened(): return None
    names_node = fs.getNode('names')
    names = []
    for i in range(names_node.size()):
        names.append(names_node.at(i).string())
    
    cameras = {}
    for name in names:
        cam = {}
        if not fs.getNode(f'K_{name}').empty():
            cam['K'] = read_opencv_matrix(fs.getNode(f'K_{name}'))
            cam['dist'] = read_opencv_matrix(fs.getNode(f'dist_{name}'))
        if not fs.getNode(f'R_{name}').empty():
            cam['R'] = read_opencv_matrix(fs.getNode(f'R_{name}'))
            cam['T'] = read_opencv_matrix(fs.getNode(f'T_{name}'))
        cameras[name] = cam
    fs.release()
    return cameras

base = "/Volumes/Ikram's SSD/test dataset/easymocap_calib/extri"
intri_path = os.path.join(base, "intri.yml")
extri_path = os.path.join(base, "extri.yml")

intri_cams = read_yaml(intri_path)
extri_cams = read_yaml(extri_path)

out_dir = os.path.join(base, "output", "visual_check")
os.makedirs(out_dir, exist_ok=True)

for cam in extri_cams:
    K = intri_cams[cam]['K']
    dist = intri_cams[cam]['dist']
    R = extri_cams[cam]['R']
    T = extri_cams[cam]['T']
    
    img_path = os.path.join(base, "images", cam, "000500.jpg")
    img = cv2.imread(img_path)
    if img is None: continue
    
    # Draw axes
    try:
        cv2.drawFrameAxes(img, K, dist, R, T, 0.5, 3)
    except AttributeError:
        # Fallback if drawFrameAxes is not available
        axis = np.float32([[0,0,0], [0.5,0,0], [0,0.5,0], [0,0,-0.5]]).reshape(-1,3)
        imgpts, _ = cv2.projectPoints(axis, R, T, K, dist)
        imgpts = np.int32(imgpts).reshape(-1,2)
        img = cv2.line(img, tuple(imgpts[0]), tuple(imgpts[1]), (0,0,255), 3) # X red
        img = cv2.line(img, tuple(imgpts[0]), tuple(imgpts[2]), (0,255,0), 3) # Y green
        img = cv2.line(img, tuple(imgpts[0]), tuple(imgpts[3]), (255,0,0), 3) # Z blue
        
    out_file = os.path.join(out_dir, f"{cam}_axes.jpg")
    cv2.imwrite(out_file, img)
    print(f"Saved {out_file}")

