import json
import numpy as np

with open("s03/joints3d_25/squat.json", "r") as f:
    gt = np.array(json.load(f)["joints3d_25"])

print("--- VERIFICATION DU SQUELETTE FIT3D ---")
frame = gt[0]

for i in range(25):
    print(f"  Joint {i:2d} : X={frame[i,0]:7.3f}  Y={frame[i,1]:7.3f}  Z={frame[i,2]:7.3f}")

# Test : si Joint0-Joint15 = 50-60cm, c'est SMPL (Pelvis-Tete)
d = np.linalg.norm(frame[0] - frame[15]) * 100
print(f"\nDistance Joint0-Joint15 = {d:.1f} cm")
if 40 < d < 70:
    print("FORMAT SMPL (notre mapping actuel est FAUX)")
else:
    print("FORMAT BODY25 (notre mapping est bon)")
