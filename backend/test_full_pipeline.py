import os
import sys

# Add backend to path
sys.path.append(os.getcwd())

from app.pipeline.step2_2d_keypoints_service import PoseService
from app.pipeline.step3_3d_keypoints_service import TriangulationService

session_id = 'e1f86903-5fc2-4a5d-a41a-7ef351b755a0'
output_root = f'data/frames/{session_id}'

def test_full():
    print(f"Testing session: {session_id}")
    for i in range(1, 5):
        temp_dir = os.path.join(output_root, f"temp{i}")
        keypoints_file = os.path.join(output_root, f"keypoints_angle{i}.npy")
        
        if os.path.exists(temp_dir):
            print(f"Angle {i}: Found {len(os.listdir(temp_dir))} files.")
            try:
                success = PoseService.extract_keypoints(temp_dir, keypoints_file)
                print(f"Angle {i} Success: {success}")
            except Exception as e:
                print(f"Angle {i} Error: {e}")
                import traceback
                traceback.print_exc()
        else:
            print(f"Angle {i} Not Found.")

    print("\n--- Starting Triangulation ---")
    try:
        TriangulationService.triangulate(output_root, "squat")
        print("Triangulation Success!")
    except Exception as e:
        print(f"Triangulation Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_full()
