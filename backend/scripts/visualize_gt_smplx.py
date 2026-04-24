import os
import json
import numpy as np
import torch
import smplx
import cv2
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from mpl_toolkits.mplot3d import Axes3D

def rotmat_to_axis_angle(matrices):
    shape = matrices.shape
    matrices_flat = matrices.reshape(-1, 3, 3)
    axis_angles = np.zeros((matrices_flat.shape[0], 3), dtype=np.float32)
    for i in range(matrices_flat.shape[0]):
        aa, _ = cv2.Rodrigues(matrices_flat[i])
        axis_angles[i] = aa.reshape(3)
    return axis_angles.reshape(shape[:-2] + (3,))

def main():
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    gt_json_path = os.path.join(backend_dir, "..", "..", "s03", "smplx", "deadlift.json")
    models_dir = os.path.join(backend_dir, "..", "data", "smplx_models")
    
    if not os.path.exists(gt_json_path):
        print(f"File not found: {gt_json_path}")
        return
        
    print("Loading Ground Truth from JSON...")
    with open(gt_json_path, 'r') as f:
        data = json.load(f)
        
    transl = torch.tensor(data['transl'], dtype=torch.float32)
    global_orient_mat = np.array(data['global_orient'], dtype=np.float32)
    body_pose_mat = np.array(data['body_pose'], dtype=np.float32)
    betas = torch.tensor(data['betas'], dtype=torch.float32) if 'betas' in data else torch.zeros(1, 10)
    
    global_orient = torch.tensor(rotmat_to_axis_angle(global_orient_mat).reshape(-1, 3), dtype=torch.float32)
    body_pose = torch.tensor(rotmat_to_axis_angle(body_pose_mat).reshape(-1, 63), dtype=torch.float32)
    
    num_frames = transl.shape[0]
    
    print("Generating SMPL-X Joints...")
    body_model = smplx.create(models_dir, model_type='smplx', gender='neutral', 
                              use_pca=False, batch_size=num_frames)
    
    if betas.shape[0] == 1 and num_frames > 1:
        betas = betas.expand(num_frames, -1)
        
    with torch.no_grad():
        out = body_model(transl=transl, global_orient=global_orient, body_pose=body_pose, betas=betas)
        joints = out.joints[:, :22, :].numpy()
        
    print(f"Generated joints: {joints.shape}")
    
    # SMPL Connections
    connections = [
        (0, 1), (0, 2), (0, 3),
        (1, 4), (2, 5), (3, 6),
        (4, 7), (5, 8), (6, 9),
        (7, 10), (8, 11), (9, 12), (9, 13), (9, 14),
        (12, 15),
        (13, 16), (14, 17),
        (16, 18), (17, 19),
        (18, 20), (19, 21)
    ]
    
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    
    # Auto-scale
    min_x, max_x = np.min(joints[:, :, 0]), np.max(joints[:, :, 0])
    min_y, max_y = np.min(joints[:, :, 1]), np.max(joints[:, :, 1])
    min_z, max_z = np.min(joints[:, :, 2]), np.max(joints[:, :, 2])

    mid_x = (max_x + min_x) * 0.5
    mid_y = (max_y + min_y) * 0.5
    mid_z = (max_z + min_z) * 0.5
    max_range = max(max_x - min_x, max_y - min_y, max_z - min_z) / 2.0
    
    ax.set_xlim(mid_x - max_range, mid_x + max_range)
    ax.set_ylim(mid_z - max_range, mid_z + max_range) # Z becomes Y in matplotlib
    ax.set_zlim(-mid_y - max_range, -mid_y + max_range) # Invert Y for Z
    
    scatter = ax.scatter([], [], [], c='r', marker='o')
    lines = [ax.plot([], [], [], c='blue')[0] for _ in connections]
    
    # Text for current frame
    title = ax.set_title("GT Deadlift")
    
    def update(frame_idx):
        pts = joints[frame_idx]
        x = pts[:, 0]
        y = pts[:, 1]
        z = pts[:, 2]
        
        scatter._offsets3d = (x, z, -y)
        
        for idx, (start, end) in enumerate(connections):
            lines[idx].set_data([x[start], x[end]], [z[start], z[end]])
            lines[idx].set_3d_properties([-y[start], -y[end]])
            
        title.set_text(f'Ground Truth SMPL-X - Frame {frame_idx}/{num_frames}')
        return [scatter] + lines
        
    ax.set_xlabel('X')
    ax.set_ylabel('Z')
    ax.set_zlabel('Y (Inverted)')
    
    # Faster animation to skip some frames if wanted (step=2)
    ani = animation.FuncAnimation(fig, update, frames=range(0, num_frames, 2), interval=33, blit=False)
    plt.show()

if __name__ == "__main__":
    main()
