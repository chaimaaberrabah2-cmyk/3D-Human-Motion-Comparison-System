import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from mpl_toolkits.mplot3d import Axes3D
import sys
import os

def visualize_3d_animated(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found.")
        return

    # Load 3D coordinates (num_frames, 33, 4) or (num_frames, 33, 3)
    data = np.load(file_path)
    print(f"Loaded 3D data: {data.shape}")

    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')

    # MediaPipe Pose Connections
    connections = [
        (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), # Arms
        (11, 23), (12, 24), (23, 24), (23, 25), (24, 26), # Torso/Hips
        (25, 27), (26, 28), (27, 29), (28, 30), (29, 31), (30, 32) # Legs
    ]

    # Calculate global limits to keep the camera steady
    # Assuming shape is (N, 33, 3 or 4)
    valid_data = data[~np.isnan(data[..., 0])]
    if len(valid_data) == 0:
        print("No valid data found")
        return

    # Extract global min/max for x, y, z across the entire video
    min_x, max_x = np.nanmin(data[:, :, 0]), np.nanmax(data[:, :, 0])
    min_y, max_y = np.nanmin(data[:, :, 1]), np.nanmax(data[:, :, 1])
    min_z, max_z = np.nanmin(data[:, :, 2]), np.nanmax(data[:, :, 2])

    mid_x = (max_x + min_x) * 0.5
    mid_y = (max_y + min_y) * 0.5
    mid_z = (max_z + min_z) * 0.5
    max_range = max(max_x - min_x, max_y - min_y, max_z - min_z) / 2.0

    # Initialize empty objects
    scatter = ax.scatter([], [], [], c='r', marker='o')
    lines = [ax.plot([], [], [], c='blue')[0] for _ in connections]

    def update(frame_idx):
        points = data[frame_idx]
        x = points[:, 0]
        y = points[:, 1]
        z = points[:, 2]
        
        valid = ~np.isnan(x)
        
        # In Matplotlib 3D, scatter requires separate calls or _offsets3d
        scatter._offsets3d = (x[valid], z[valid], -y[valid])
        
        for idx, (start, end) in enumerate(connections):
            if valid[start] and valid[end]:
                lines[idx].set_data([x[start], x[end]], [z[start], z[end]])
                lines[idx].set_3d_properties([-y[start], -y[end]])
            else:
                lines[idx].set_data([], [])
                lines[idx].set_3d_properties([])
                
        ax.set_title(f'3D Skeleton Animation - Frame {frame_idx}/{data.shape[0]}')
        return [scatter] + lines

    ax.set_xlabel('X')
    ax.set_ylabel('Z')
    ax.set_zlabel('Y (Inverted)')

    # Set steady limits
    ax.set_xlim(mid_x - max_range, mid_x + max_range)
    ax.set_zlim(-mid_y - max_range, -mid_y + max_range)
    ax.set_ylim(mid_z - max_range, mid_z + max_range)

    # 30 fps ≈ 33ms interval
    ani = animation.FuncAnimation(fig, update, frames=data.shape[0], interval=33, blit=False)
    plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python visualize_3d.py <path_to_npy>")
    else:
        path = sys.argv[1]
        visualize_3d_animated(path)
