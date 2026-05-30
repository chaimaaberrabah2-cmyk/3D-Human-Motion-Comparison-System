#!/usr/bin/env python3
"""
compare_viewer.py — 3D Skeleton Comparator
Shows GT (green) · Pipeline OP25 (blue) · SMPL-X joints (orange)
Usage:  python compare_viewer.py deadlift
        python compare_viewer.py dumbbell_biceps_curls
"""

import os, sys, json, argparse, webbrowser
import numpy as np

_PYENV_PY = "/Users/HP/.pyenv/versions/3.11.7/bin/python3"
if os.path.exists(_PYENV_PY) and sys.executable != _PYENV_PY:
    os.execv(_PYENV_PY, [_PYENV_PY] + sys.argv)

import plotly.graph_objects as go

ROOT = os.path.dirname(os.path.abspath(__file__))

# ── Skeleton definitions ───────────────────────────────────────────────────────

# FIT3D joints3d_25
# 0=Pelvis 1=L_Hip 2=L_Knee 3=L_Ankle
# 4=R_Hip  5=R_Knee 6=R_Ankle
# 7=Spine1 8=Spine2 9=Chest 10=Head
# 11=L_Shoulder 12=L_Elbow 13=L_Wrist
# 14=R_Shoulder 15=R_Elbow 16=R_Wrist
GT_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3),
    (0, 4), (4, 5), (5, 6),
    (0, 7), (7, 8), (8, 9), (9, 10),
    (9, 11), (11, 12), (12, 13),
    (9, 14), (14, 15), (15, 16),
    (11, 14), (1, 4),
]

# OpenPose-25
# 0=Nose 1=Neck 2=RSho 3=RElb 4=RWri 5=LSho 6=LElb 7=LWri
# 8=MidHip 9=RHip 10=RKnee 11=RAnkle 12=LHip 13=LKnee 14=LAnkle
# 19=LBigToe 21=LHeel 22=RBigToe 24=RHeel
OP25_CONNECTIONS = [
    (0, 1),
    (1, 2), (2, 3), (3, 4),
    (1, 5), (5, 6), (6, 7),
    (1, 8),
    (8, 9),  (9, 10),  (10, 11),
    (8, 12), (12, 13), (13, 14),
    (11, 24), (14, 21),
    (11, 22), (14, 19),
    (9, 12), (2, 5),
]

# SMPL-X 22 body joints
# 0=Pelvis 1=L_Hip 2=R_Hip 3=Spine1 4=L_Knee 5=R_Knee
# 6=Spine2 7=L_Ankle 8=R_Ankle 9=Spine3 10=L_Foot 11=R_Foot
# 12=Neck 13=L_Collar 14=R_Collar 15=Head 16=L_Shoulder
# 17=R_Shoulder 18=L_Elbow 19=R_Elbow 20=L_Wrist 21=R_Wrist
SMPL_CONNECTIONS = [
    (0, 1), (1, 4), (4, 7), (7, 10),    # L leg
    (0, 2), (2, 5), (5, 8), (8, 11),    # R leg
    (0, 3), (3, 6), (6, 9), (9, 12), (12, 15),  # Spine → Head
    (9, 13), (13, 16), (16, 18), (18, 20),       # L arm
    (9, 14), (14, 17), (17, 19), (19, 21),       # R arm
    (1, 2), (16, 17),
]

# OP25 → GT mapping for MPJPE
OP25_TO_GT = {
    8:  0,  12: 1,  13: 2,  14: 3,
    9:  4,  10: 5,  11: 6,
    1:  9,
    5:  11,  6: 12,  7: 13,
    2:  14,  3: 15,  4: 16,
}
OP25_JOINT_NAMES = {
    8: "MidHip", 12: "L_Hip", 13: "L_Knee", 14: "L_Ankle",
    9: "R_Hip",  10: "R_Knee", 11: "R_Ankle",
    1: "Neck",
    5: "L_Shoulder", 6: "L_Elbow", 7: "L_Wrist",
    2: "R_Shoulder", 3: "R_Elbow", 4: "R_Wrist",
}

# ── Data loading ───────────────────────────────────────────────────────────────

def load_gt(exercise: str) -> np.ndarray:
    import re
    gt_dir = os.path.join(ROOT, "s03", "joints3d_25")
    # Strip test_ prefix and trailing digit suffix (e.g. test_dumbbell_biceps_curls1 → dumbbell_biceps_curls)
    name = re.sub(r"^test_", "", exercise)
    name = re.sub(r"\d+$", "", name).rstrip("_")
    candidates = [exercise, name]
    for c in candidates:
        path = os.path.join(gt_dir, f"{c}.json")
        if os.path.exists(path):
            with open(path) as f:
                data = json.load(f)
            return np.array(data["joints3d_25"], dtype=np.float32)
    raise FileNotFoundError(f"No GT found for '{exercise}' (tried: {candidates})")

def load_pred(exercise: str) -> np.ndarray:
    path = os.path.join(ROOT, "backend", "data", "frames", exercise, "keypoints_3d.npy")
    return np.load(path)[:, :, :3].astype(np.float32)  # (T, 25, 3) OP25

def load_smpl(exercise: str) -> np.ndarray | None:
    path = os.path.join(ROOT, "backend", "data", "frames", exercise, "smplx_result.npz")
    if not os.path.exists(path):
        return None
    d = np.load(path)
    return d["joints"].astype(np.float32)  # (T, 22, 3)

def root_align(gt: np.ndarray, pred: np.ndarray) -> tuple:
    """Align pred MidHip (OP25 j8) to GT Pelvis (GT j0) per frame."""
    T = min(len(gt), len(pred))
    pred_out = pred.copy()
    for t in range(T):
        pred_out[t] += gt[t, 0] - pred[t, 8]
    return gt, pred_out

def smpl_align(gt: np.ndarray, smpl: np.ndarray) -> np.ndarray:
    """Align SMPL Pelvis (j0) to GT Pelvis (GT j0) per frame."""
    T = min(len(gt), len(smpl))
    smpl_out = smpl.copy()
    for t in range(T):
        smpl_out[t] += gt[t, 0] - smpl[t, 0]
    return smpl_out

# ── MPJPE ─────────────────────────────────────────────────────────────────────

def compute_mpjpe(gt: np.ndarray, pred: np.ndarray) -> dict:
    T = min(len(gt), len(pred))
    op_idxs = sorted(OP25_TO_GT.keys())
    gt_idxs = [OP25_TO_GT[i] for i in op_idxs]
    frame_errors, joint_buckets = [], {i: [] for i in op_idxs}
    for t in range(T):
        gt_root, pred_root = gt[t, 0], pred[t, 8]
        fe = []
        for pi, gi in zip(op_idxs, gt_idxs):
            g = gt[t, gi] - gt_root
            p = pred[t, pi] - pred_root
            if not (np.any(np.isnan(g)) or np.any(np.isnan(p))):
                e = float(np.linalg.norm(g - p))
                fe.append(e); joint_buckets[pi].append(e)
        frame_errors.append(float(np.mean(fe)) if fe else float("nan"))
    valid = [e for e in frame_errors if not np.isnan(e)]
    return {
        "mpjpe_mm":        float(np.mean(valid)) * 1000,
        "mpjpe_per_frame": [e * 1000 for e in frame_errors],
        "mpjpe_per_joint": {OP25_JOINT_NAMES[i]: np.mean(v) * 1000
                            for i, v in joint_buckets.items() if v},
        "num_frames": T,
    }

# ── Plotly helpers ─────────────────────────────────────────────────────────────

def _bone_lines(pts: np.ndarray, connections: list):
    bx, by, bz = [], [], []
    valid = ~np.isnan(pts[:, 0])
    for a, b in connections:
        if a < len(pts) and b < len(pts) and valid[a] and valid[b]:
            bx += [pts[a, 0], pts[b, 0], None]
            by += [pts[a, 1], pts[b, 1], None]
            bz += [pts[a, 2], pts[b, 2], None]
    return bx, by, bz

def _skeleton_traces(pts, conns, color, name, scene):
    x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
    valid = ~np.isnan(x)
    bx, by, bz = _bone_lines(pts, conns)
    return [
        go.Scatter3d(x=x[valid], y=y[valid], z=z[valid],
                     mode="markers", marker=dict(size=5, color=color),
                     name=name, scene=scene, legendgroup=name),
        go.Scatter3d(x=bx, y=by, z=bz,
                     mode="lines", line=dict(color=color, width=5),
                     name=name, scene=scene, legendgroup=name,
                     showlegend=False, hoverinfo="skip"),
    ]

def build_frames(gt, pred, smpl, mpjpe_per_frame, step):
    T = min(len(gt), len(pred))
    if smpl is not None:
        T = min(T, len(smpl))
    max_err = max((e for e in mpjpe_per_frame if not np.isnan(e)), default=200) * 1.1
    frames = []
    n_smpl_traces = 2 if smpl is not None else 0

    for t in range(0, T, step):
        gp, pp = gt[t], pred[t]
        gv = ~np.isnan(gp[:, 0]); pv = ~np.isnan(pp[:, 0])
        gbx, gby, gbz = _bone_lines(gp, GT_CONNECTIONS)
        pbx, pby, pbz = _bone_lines(pp, OP25_CONNECTIONS)
        cur_err = mpjpe_per_frame[t] if t < len(mpjpe_per_frame) else float("nan")
        err_label = f"{cur_err:.0f} mm" if not np.isnan(cur_err) else "—"

        frame_data = [
            go.Scatter3d(x=gp[gv, 0], y=gp[gv, 1], z=gp[gv, 2]),
            go.Scatter3d(x=gbx, y=gby, z=gbz),
            go.Scatter3d(x=pp[pv, 0], y=pp[pv, 1], z=pp[pv, 2]),
            go.Scatter3d(x=pbx, y=pby, z=pbz),
        ]
        trace_indices = [0, 1, 2, 3]

        if smpl is not None:
            sp = smpl[t]; sv = ~np.isnan(sp[:, 0])
            sbx, sby, sbz = _bone_lines(sp, SMPL_CONNECTIONS)
            frame_data += [
                go.Scatter3d(x=sp[sv, 0], y=sp[sv, 1], z=sp[sv, 2]),
                go.Scatter3d(x=sbx, y=sby, z=sbz),
            ]
            trace_indices += [4, 5]

        # Animated chart marker
        chart_base = 4 + n_smpl_traces
        frame_data += [
            go.Scatter(x=[t, t], y=[0, max_err], mode="lines",
                       line=dict(color="#dc2626", width=2, dash="dash")),
            go.Scatter(x=[t], y=[cur_err], mode="markers+text",
                       marker=dict(color="#dc2626", size=9),
                       text=[err_label], textposition="top center",
                       textfont=dict(size=11, color="#dc2626")),
        ]
        trace_indices += [chart_base, chart_base + 1]

        frames.append(go.Frame(name=str(t), data=frame_data, traces=trace_indices))
    return frames

# ── Main ───────────────────────────────────────────────────────────────────────

def build_frames_triple(gt, pred, pred2, smpl, smpl2, mpjpe1, mpjpe2, step):
    """3 separate scenes: GT+s03+test overlay | s03+SMPL-X | test+SMPL-X.
    Trace layout (fixed indices):
      0-1   GT joints/bones          (scene,  green)
      2-3   s03 joints/bones         (scene,  blue)   ← also in GT panel
      4-5   test joints/bones        (scene,  red)    ← also in GT panel
      6-7   s03 joints/bones         (scene2, blue)
      8-9   s03 SMPL-X joints/bones  (scene2, orange)
      10-11 test joints/bones        (scene3, red)
      12-13 test SMPL-X joints/bones (scene3, purple)
      14    MPJPE s03 line  (static)
      15    MPJPE test line (static)
      16    cursor line     (animated)
      17    cursor dot s03  (animated)
      18    cursor dot test (animated)
    """
    T = min(len(gt), len(pred), len(pred2))
    if smpl  is not None: T = min(T, len(smpl))
    if smpl2 is not None: T = min(T, len(smpl2))
    all_errs = [e for e in mpjpe1 + mpjpe2 if not np.isnan(e)]
    max_err  = max(all_errs, default=200) * 1.1
    frames   = []

    for t in range(0, T, step):
        gp, pp, p2 = gt[t], pred[t], pred2[t]
        gv  = ~np.isnan(gp[:, 0])
        pv  = ~np.isnan(pp[:, 0])
        p2v = ~np.isnan(p2[:, 0])
        gbx,  gby,  gbz  = _bone_lines(gp,  GT_CONNECTIONS)
        pbx,  pby,  pbz  = _bone_lines(pp,  OP25_CONNECTIONS)
        p2bx, p2by, p2bz = _bone_lines(p2,  OP25_CONNECTIONS)
        e1  = mpjpe1[t] if t < len(mpjpe1) else float("nan")
        e2  = mpjpe2[t] if t < len(mpjpe2) else float("nan")
        lbl1 = f"{e1:.0f}" if not np.isnan(e1) else "—"
        lbl2 = f"{e2:.0f}" if not np.isnan(e2) else "—"

        # 0,1 – GT (scene)
        fd = [
            go.Scatter3d(x=gp[gv,0], y=gp[gv,1], z=gp[gv,2]),
            go.Scatter3d(x=gbx, y=gby, z=gbz),
        ]
        # 2,3 – s03 in GT scene (scene)
        fd += [
            go.Scatter3d(x=pp[pv,0], y=pp[pv,1], z=pp[pv,2]),
            go.Scatter3d(x=pbx, y=pby, z=pbz),
        ]
        # 4,5 – test in GT scene (scene)
        fd += [
            go.Scatter3d(x=p2[p2v,0], y=p2[p2v,1], z=p2[p2v,2]),
            go.Scatter3d(x=p2bx, y=p2by, z=p2bz),
        ]
        # 6,7 – s03 keypoints (scene2)
        fd += [
            go.Scatter3d(x=pp[pv,0], y=pp[pv,1], z=pp[pv,2]),
            go.Scatter3d(x=pbx, y=pby, z=pbz),
        ]
        # 8,9 – s03 SMPL-X (scene2)
        if smpl is not None:
            sp = smpl[t]; sv = ~np.isnan(sp[:, 0])
            sbx, sby, sbz = _bone_lines(sp, SMPL_CONNECTIONS)
            fd += [go.Scatter3d(x=sp[sv,0], y=sp[sv,1], z=sp[sv,2]),
                   go.Scatter3d(x=sbx, y=sby, z=sbz)]
        else:
            fd += [go.Scatter3d(x=[], y=[], z=[]), go.Scatter3d(x=[], y=[], z=[])]
        # 10,11 – test keypoints (scene3)
        fd += [
            go.Scatter3d(x=p2[p2v,0], y=p2[p2v,1], z=p2[p2v,2]),
            go.Scatter3d(x=p2bx, y=p2by, z=p2bz),
        ]
        # 12,13 – test SMPL-X (scene3)
        if smpl2 is not None:
            sp2 = smpl2[t]; sv2 = ~np.isnan(sp2[:, 0])
            sb2x, sb2y, sb2z = _bone_lines(sp2, SMPL_CONNECTIONS)
            fd += [go.Scatter3d(x=sp2[sv2,0], y=sp2[sv2,1], z=sp2[sv2,2]),
                   go.Scatter3d(x=sb2x, y=sb2y, z=sb2z)]
        else:
            fd += [go.Scatter3d(x=[], y=[], z=[]), go.Scatter3d(x=[], y=[], z=[])]
        # 16,17,18 – cursor (traces 14,15 are static MPJPE lines, not in frames)
        fd += [
            go.Scatter(x=[t, t], y=[0, max_err]),
            go.Scatter(x=[t], y=[e1 if not np.isnan(e1) else 0],
                       text=[lbl1], mode="markers+text"),
            go.Scatter(x=[t], y=[e2 if not np.isnan(e2) else 0],
                       text=[lbl2], mode="markers+text"),
        ]
        frames.append(go.Frame(
            name=str(t), data=fd,
            traces=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18],
        ))
    return frames


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("exercise", nargs="?", default="deadlift")
    parser.add_argument("--test",  default=None,
                        help="second session to compare (e.g. test_dumbbell_biceps_curls1)")
    parser.add_argument("--step",  type=int, default=3)
    args = parser.parse_args()
    ex   = args.exercise
    ex2  = args.test  # may be None

    print(f"📂  Loading  {ex}")
    gt   = load_gt(ex)
    pred = load_pred(ex)
    smpl = load_smpl(ex)
    print(f"    GT   {gt.shape}   Pred {pred.shape}   SMPL {smpl.shape if smpl is not None else 'N/A'}")

    gt, pred = root_align(gt, pred)
    if smpl is not None:
        smpl = smpl_align(gt, smpl)

    print("📐  Computing MPJPE (s03)…")
    m1 = compute_mpjpe(gt, pred)
    print(f"    Global MPJPE : {m1['mpjpe_mm']:.1f} mm")

    # ── Dual-session mode ──────────────────────────────────────────────────────
    pred2 = None
    smpl2 = None
    m2    = None
    if ex2:
        print(f"📂  Loading test session: {ex2}")
        pred2 = load_pred(ex2)
        _, pred2 = root_align(gt, pred2)
        smpl2 = load_smpl(ex2)
        if smpl2 is not None:
            smpl2 = smpl_align(gt, smpl2)
        print(f"    Pred2 {pred2.shape}   SMPL2 {smpl2.shape if smpl2 is not None else 'N/A'}")
        print("📐  Computing MPJPE (test)…")
        m2 = compute_mpjpe(gt, pred2)
        print(f"    Global MPJPE : {m2['mpjpe_mm']:.1f} mm")

        # Print side-by-side per-joint table
        print(f"\n{'Joint':<16} {'s03':>8} {'test':>8}  [mm]")
        print("-" * 36)
        for joint in m1["mpjpe_per_joint"]:
            v1 = m1["mpjpe_per_joint"].get(joint, float("nan"))
            v2 = m2["mpjpe_per_joint"].get(joint, float("nan"))
            better = "✓" if v1 <= v2 else " "
            print(f"  {joint:<14} {v1:>7.1f}  {v2:>7.1f}  {better}")
        print(f"  {'TOTAL':<14} {m1['mpjpe_mm']:>7.1f}  {m2['mpjpe_mm']:>7.1f}")
    else:
        for joint, err in sorted(m1["mpjpe_per_joint"].items(), key=lambda x: x[1]):
            print(f"    {joint:15s}: {err:6.1f} mm")

    from plotly.subplots import make_subplots
    T = min(len(gt), len(pred))
    if pred2  is not None: T = min(T, len(pred2))
    if smpl   is not None: T = min(T, len(smpl))
    if smpl2  is not None: T = min(T, len(smpl2))

    per_frame1 = m1["mpjpe_per_frame"]
    per_frame2 = m2["mpjpe_per_frame"] if m2 else []
    all_errs   = [e for e in per_frame1 + per_frame2 if not np.isnan(e)]
    max_err    = max(all_errs, default=200) * 1.1
    e1_0 = per_frame1[0] if per_frame1 and not np.isnan(per_frame1[0]) else 0
    e2_0 = per_frame2[0] if per_frame2 and not np.isnan(per_frame2[0]) else 0

    chart_title = (
        f"MPJPE — s03 <b>{m1['mpjpe_mm']:.0f} mm</b>"
        + (f"  |  test <b>{m2['mpjpe_mm']:.0f} mm</b>" if m2 else "")
    )

    # ── Compute axis ranges (shared across all scenes) ─────────────────────────
    all_pts = [gt[:T, :, :3].reshape(-1, 3), pred[:T, :, :3].reshape(-1, 3)]
    if pred2  is not None: all_pts.append(pred2[:T, :, :3].reshape(-1, 3))
    if smpl   is not None: all_pts.append(smpl[:T, :, :3].reshape(-1, 3))
    if smpl2  is not None: all_pts.append(smpl2[:T, :, :3].reshape(-1, 3))
    pts = np.concatenate(all_pts)
    pts = pts[~np.isnan(pts).any(axis=1)]
    xr = [float(pts[:, 0].min()) - 0.05, float(pts[:, 0].max()) + 0.05]
    yr = [float(pts[:, 1].min()) - 0.05, float(pts[:, 1].max()) + 0.05]
    zr = [float(pts[:, 2].min()) - 0.05, float(pts[:, 2].max()) + 0.05]

    # ── Build figure ───────────────────────────────────────────────────────────
    if ex2:
        # ── DUAL MODE: 3 separate 3D scenes + MPJPE chart below ───────────────
        fig = make_subplots(
            rows=2, cols=3,
            specs=[
                [{"type": "scene"}, {"type": "scene"}, {"type": "scene"}],
                [{"type": "xy", "colspan": 3}, None, None],
            ],
            subplot_titles=[
                "GT (FIT3D)",
                f"s03 — {ex}",
                f"test — {ex2}",
                chart_title,
            ],
            row_heights=[0.65, 0.35],
            vertical_spacing=0.06,
            horizontal_spacing=0.02,
        )

        # Traces 0,1 – GT (scene, green)
        for tr in _skeleton_traces(gt[0],    GT_CONNECTIONS,   "#16a34a", "GT",        "scene"):
            fig.add_trace(tr)
        # Traces 2,3 – s03 in GT scene (scene, blue)
        for tr in _skeleton_traces(pred[0],  OP25_CONNECTIONS, "#2563eb", "s03",       "scene"):
            fig.add_trace(tr)
        # Traces 4,5 – test in GT scene (scene, red)
        for tr in _skeleton_traces(pred2[0], OP25_CONNECTIONS, "#dc2626", "test",      "scene"):
            fig.add_trace(tr)
        # Traces 6,7 – s03 keypoints (scene2, blue)
        for tr in _skeleton_traces(pred[0],  OP25_CONNECTIONS, "#2563eb", "s03",       "scene2"):
            fig.add_trace(tr)
        # Traces 8,9 – s03 SMPL-X (scene2, orange)
        if smpl is not None:
            for tr in _skeleton_traces(smpl[0], SMPL_CONNECTIONS, "#ea580c", "SMPL-X s03", "scene2"):
                fig.add_trace(tr)
        else:
            fig.add_trace(go.Scatter3d(x=[], y=[], z=[], showlegend=False, scene="scene2"))
            fig.add_trace(go.Scatter3d(x=[], y=[], z=[], showlegend=False, scene="scene2"))
        # Traces 10,11 – test keypoints (scene3, red)
        for tr in _skeleton_traces(pred2[0], OP25_CONNECTIONS, "#dc2626", "test",      "scene3"):
            fig.add_trace(tr)
        # Traces 12,13 – test SMPL-X (scene3, purple)
        if smpl2 is not None:
            for tr in _skeleton_traces(smpl2[0], SMPL_CONNECTIONS, "#9333ea", "SMPL-X test", "scene3"):
                fig.add_trace(tr)
        else:
            fig.add_trace(go.Scatter3d(x=[], y=[], z=[], showlegend=False, scene="scene3"))
            fig.add_trace(go.Scatter3d(x=[], y=[], z=[], showlegend=False, scene="scene3"))
        # Trace 14 – MPJPE s03 line (static)
        fig.add_trace(go.Scatter(x=list(range(len(per_frame1))), y=per_frame1,
                                 mode="lines", name="MPJPE s03",
                                 line=dict(color="#2563eb", width=1.5)), row=2, col=1)
        # Trace 15 – MPJPE test line (static)
        fig.add_trace(go.Scatter(x=list(range(len(per_frame2))), y=per_frame2,
                                 mode="lines", name="MPJPE test",
                                 line=dict(color="#dc2626", width=1.5)), row=2, col=1)
        # Trace 16 – cursor line (animated)
        fig.add_trace(go.Scatter(x=[0, 0], y=[0, max_err], mode="lines", showlegend=False,
                                 line=dict(color="#6b7280", width=1.5, dash="dash")), row=2, col=1)
        # Trace 17 – cursor dot s03 (animated)
        fig.add_trace(go.Scatter(x=[0], y=[e1_0], mode="markers+text", showlegend=False,
                                 marker=dict(color="#2563eb", size=9),
                                 text=[f"{e1_0:.0f}"], textposition="top right",
                                 textfont=dict(size=10, color="#2563eb")), row=2, col=1)
        # Trace 18 – cursor dot test (animated)
        fig.add_trace(go.Scatter(x=[0], y=[e2_0], mode="markers+text", showlegend=False,
                                 marker=dict(color="#dc2626", size=9),
                                 text=[f"{e2_0:.0f}"], textposition="top left",
                                 textfont=dict(size=10, color="#dc2626")), row=2, col=1)

        print("🎞   Building animation…")
        frames = build_frames_triple(gt, pred, pred2, smpl, smpl2,
                                     per_frame1, per_frame2, args.step)
        fig.frames = frames

        slider_steps = [
            dict(args=[[f.name], {"frame": {"duration": 0, "redraw": True}, "mode": "immediate"}],
                 label=f.name, method="animate")
            for f in frames
        ]

        scene_cfg = dict(
            uirevision="constant", dragmode="orbit",
            xaxis=dict(range=xr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1", showticklabels=False),
            yaxis=dict(range=yr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1", showticklabels=False),
            zaxis=dict(title="Z", range=zr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1"),
            camera=dict(eye=dict(x=1.6, y=1.6, z=0.8), up=dict(x=0, y=0, z=1)),
            aspectmode="cube", bgcolor="#ffffff",
        )
        fig.update_layout(
            title=dict(text=f"3D Skeleton Comparator — <b>{ex}</b>  vs  <b>{ex2}</b>",
                       x=0.5, font=dict(size=16, color="#1e293b")),
            scene=scene_cfg, scene2=scene_cfg, scene3=scene_cfg,
            xaxis=dict(title="Frame", range=[0, T], gridcolor="#e2e8f0"),
            yaxis=dict(title="MPJPE (mm)", range=[0, max_err], gridcolor="#e2e8f0"),
            paper_bgcolor="#f8fafc", plot_bgcolor="#f8fafc",
            font=dict(color="#0f172a"),
            margin=dict(l=10, r=10, t=60, b=110),
            legend=dict(x=0.01, y=0.99, bgcolor="rgba(255,255,255,0.85)",
                        bordercolor="#cbd5e1", borderwidth=1),
            updatemenus=[dict(
                type="buttons", showactive=False, x=0.08, y=-0.02,
                buttons=[
                    dict(label="▶ Play", method="animate",
                         args=[None, {"frame": {"duration": 33, "redraw": True},
                                      "fromcurrent": True, "mode": "immediate"}]),
                    dict(label="⏸ Pause", method="animate",
                         args=[[None], {"frame": {"duration": 0}, "mode": "immediate"}]),
                ],
            )],
            sliders=[dict(
                active=0, steps=slider_steps, x=0.1, len=0.82,
                currentvalue=dict(prefix="Frame: ", font=dict(size=12)),
                bgcolor="#f1f5f9", bordercolor="#cbd5e1",
            )],
        )

    else:
        # ── SINGLE MODE: 1 3D scene + MPJPE chart (original layout) ───────────
        fig = make_subplots(
            rows=1, cols=2,
            column_widths=[0.60, 0.40],
            specs=[[{"type": "scene"}, {"type": "xy"}]],
            subplot_titles=[f"3D Skeleton — <b>{ex}</b>", chart_title],
        )

        for tr in _skeleton_traces(gt[0],   GT_CONNECTIONS,   "#16a34a", "GT (FIT3D)", "scene"):
            fig.add_trace(tr)
        for tr in _skeleton_traces(pred[0], OP25_CONNECTIONS, "#2563eb", f"s03 ({ex})", "scene"):
            fig.add_trace(tr)
        if smpl is not None:
            for tr in _skeleton_traces(smpl[0], SMPL_CONNECTIONS, "#ea580c", "SMPL-X", "scene"):
                fig.add_trace(tr)

        fig.add_trace(go.Scatter(x=list(range(len(per_frame1))), y=per_frame1,
                                 mode="lines", name="MPJPE s03",
                                 line=dict(color="#2563eb", width=1.5)), row=1, col=2)
        fig.add_trace(go.Scatter(x=[], y=[], showlegend=False), row=1, col=2)

        cb = 4 + (2 if smpl is not None else 0)
        fig.add_trace(go.Scatter(x=[0, 0], y=[0, max_err], mode="lines", showlegend=False,
                                 line=dict(color="#6b7280", width=1.5, dash="dash")), row=1, col=2)
        fig.add_trace(go.Scatter(x=[0], y=[e1_0], mode="markers+text", showlegend=False,
                                 marker=dict(color="#2563eb", size=9),
                                 text=[f"{e1_0:.0f} mm"], textposition="top right",
                                 textfont=dict(size=10, color="#2563eb")), row=1, col=2)
        fig.add_trace(go.Scatter(x=[0], y=[e2_0], mode="markers+text", showlegend=False,
                                 marker=dict(color="#dc2626", size=9),
                                 text=[f"{e2_0:.0f} mm"], textposition="top left",
                                 textfont=dict(size=10, color="#dc2626")), row=1, col=2)

        print("🎞   Building animation…")
        frames = build_frames(gt, pred, smpl, per_frame1, args.step)
        fig.frames = frames

        slider_steps = [
            dict(args=[[f.name], {"frame": {"duration": 0, "redraw": True}, "mode": "immediate"}],
                 label=f.name, method="animate")
            for f in frames
        ]

        fig.update_layout(
            title=dict(text=f"3D Skeleton Comparator — <b>{ex}</b>",
                       x=0.5, font=dict(size=17, color="#1e293b")),
            scene=dict(
                uirevision="constant", dragmode="orbit",
                xaxis=dict(title="X", range=xr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1"),
                yaxis=dict(title="Y", range=yr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1"),
                zaxis=dict(title="Z (height)", range=zr, backgroundcolor="#f1f5f9", gridcolor="#cbd5e1"),
                camera=dict(eye=dict(x=1.6, y=1.6, z=0.8), up=dict(x=0, y=0, z=1)),
                aspectmode="cube", bgcolor="#ffffff",
                domain=dict(x=[0, 0.58], y=[0.05, 1.0]),
            ),
            xaxis=dict(title="Frame", range=[0, T], gridcolor="#e2e8f0"),
            yaxis=dict(title="MPJPE (mm)", range=[0, max_err], gridcolor="#e2e8f0"),
            paper_bgcolor="#f8fafc", plot_bgcolor="#f8fafc",
            font=dict(color="#0f172a"),
            margin=dict(l=10, r=20, t=70, b=110),
            legend=dict(x=0.01, y=0.99, bgcolor="rgba(255,255,255,0.85)",
                        bordercolor="#cbd5e1", borderwidth=1),
            updatemenus=[dict(
                type="buttons", showactive=False, x=0.08, y=-0.02,
                buttons=[
                    dict(label="▶ Play", method="animate",
                         args=[None, {"frame": {"duration": 33, "redraw": True},
                                      "fromcurrent": True, "mode": "immediate"}]),
                    dict(label="⏸ Pause", method="animate",
                         args=[[None], {"frame": {"duration": 0}, "mode": "immediate"}]),
                ],
            )],
            sliders=[dict(
                active=0, steps=slider_steps, x=0.1, len=0.82,
                currentvalue=dict(prefix="Frame: ", font=dict(size=12)),
                bgcolor="#f1f5f9", bordercolor="#cbd5e1",
            )],
        )

    out = os.path.join(ROOT, "backend", "compare.html")
    fig.write_html(out, include_plotlyjs="cdn", full_html=True)
    print(f"\n✅  Saved → {out}")
    webbrowser.open(f"file://{out}")


if __name__ == "__main__":
    main()
