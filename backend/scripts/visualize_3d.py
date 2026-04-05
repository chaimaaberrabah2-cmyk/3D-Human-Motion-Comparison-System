import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import sys
import os

def visualize_3d_file(file_path, frame_idx=0):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found.")
        return

    # Load 3D coordinates (num_frames, 33, 4)
    data = np.load(file_path)
    print(f"Loaded 3D data: {data.shape}")

    if frame_idx >= data.shape[0]:
        print(f"Frame index {frame_idx} out of range (max {data.shape[0]-1})")
        return

    points = data[frame_idx] # (33, 4)

    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')

    # MediaPipe Pose Connections
    connections = [
        (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), # Arms
        (11, 23), (12, 24), (23, 24), (23, 25), (24, 26), # Torso/Hips
        (25, 27), (26, 28), (27, 29), (28, 30), (29, 31), (30, 32) # Legs
    ]

    # Plot points
    x = points[:, 0]
    y = points[:, 1]
    z = points[:, 2]
    
    # Filter out NaNs
    valid = ~np.isnan(x)
    ax.scatter(x[valid], z[valid], -y[valid], c='r', marker='o') # Swap Y/Z for natural orientation

    # Plot connections
    for start, end in connections:
        if valid[start] and valid[end]:
            ax.plot([x[start], x[end]], [z[start], z[end]], [-y[start], -y[end]], c='blue')

    ax.set_xlabel('X')
    ax.set_ylabel('Z')
    ax.set_zlabel('Y (Inverted)')
    ax.set_title(f'3D Skeleton - Frame {frame_idx}')
    
    # Equal aspect ratio
    max_range = np.array([x[valid].max()-x[valid].min(), y[valid].max()-y[valid].min(), z[valid].max()-z[valid].min()]).max() / 2.0
    mid_x = (x[valid].max()+x[valid].min()) * 0.5
    mid_y = (y[valid].max()+y[valid].min()) * 0.5
    mid_z = (z[valid].max()+z[valid].min()) * 0.5
    ax.set_xlim(mid_x - max_range, mid_x + max_range)
    ax.set_zlim(-mid_y - max_range, -mid_y + max_range)
    ax.set_ylim(mid_z - max_range, mid_z + max_range)

    plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python visualize_3d.py <path_to_npy> [frame_index]")
    else:
        path = sys.argv[1]
        idx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        visualize_3d_file(path, idx)
