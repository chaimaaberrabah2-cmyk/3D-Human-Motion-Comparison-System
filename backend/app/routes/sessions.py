# =============================================================
# backend/app/api/endpoints/sessions.py
# =============================================================
# Endpoints :
#   GET  /sessions/{id}/status   → état du pipeline
#   GET  /sessions/{id}/smplx    → JSON Three.js
#   GET  /sessions/{id}/viewer   → page HTML Three.js + contrôles orientation
#   POST /sessions/{id}/refit    → relance le fitting avec une orientation donnée
# =============================================================

import os
import json
import math
import threading
from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

BASE_DIR  = os.getcwd()
FRAME_DIR = os.path.join(BASE_DIR, "data", "frames")

# In-memory refit status per session
_refit_status: dict = {}   # session_id → {"status": str, "msg": str}


def _session_dir(session_id: str) -> str:
    return os.path.join(FRAME_DIR, session_id)


# ──────────────────────────────────────────────────────────────────────────────
# GET /sessions/{id}/status
# ──────────────────────────────────────────────────────────────────────────────
@router.get("/{session_id}/status")
async def get_session_status(session_id: str):
    session_path = _session_dir(session_id)
    if not os.path.isdir(session_path):
        raise HTTPException(404, f"Session '{session_id}' not found.")

    phase1     = any(os.path.isdir(os.path.join(session_path, f"temp{i}")) for i in range(1, 5))
    phase2     = os.path.exists(os.path.join(session_path, "keypoints_angle1.npy"))
    phase3     = os.path.exists(os.path.join(session_path, "keypoints_3d.npy"))
    phase4     = os.path.exists(os.path.join(session_path, "smplx_result.npz"))
    has_viewer = os.path.exists(os.path.join(session_path, "smplx_threejs.json"))
    refit_info = _refit_status.get(session_id, None)

    # Read real status message and logs from status.json
    status_msg = "Processing..."
    logs = []
    progress_override = None
    comparison_results = None
    status_file = os.path.join(session_path, "status.json")
    if os.path.exists(status_file):
        try:
            with open(status_file) as f:
                sdata = json.load(f)
            status_msg = sdata.get("status_message", sdata.get("status", "Processing..."))
            logs = sdata.get("logs", [])
            progress_override = sdata.get("progress_percent")
            comparison_results = sdata.get("comparison_results")
        except Exception:
            pass

    progress = progress_override if progress_override is not None else int((sum([phase1, phase2, phase3, phase4]) / 4) * 100)

    return {
        "session_id":       session_id,
        "progress_percent": progress,
        "status_message":   status_msg,
        "logs":             logs,
        "is_complete":      phase4,
        "has_smplx_viewer": has_viewer,
        "refit":            refit_info,
        "comparison_results": comparison_results,
        "phases": {
            "phase1_frames_extracted": phase1,
            "phase2_pose_estimated":   phase2,
            "phase3_triangulated":     phase3,
            "phase4_smplx_fitted":     phase4,
        },
    }


# ──────────────────────────────────────────────────────────────────────────────
# GET /sessions/{id}/smplx
# ──────────────────────────────────────────────────────────────────────────────
@router.get("/{session_id}/smplx")
async def get_smplx_data(session_id: str):
    json_path = os.path.join(_session_dir(session_id), "smplx_threejs.json")
    if not os.path.exists(json_path):
        raise HTTPException(404, "SMPL-X data not ready yet.")
    with open(json_path, "r") as f:
        data = json.load(f)
    return JSONResponse(content=data)


# ──────────────────────────────────────────────────────────────────────────────
# POST /sessions/{id}/refit   ← NEW
# ──────────────────────────────────────────────────────────────────────────────
class RefitRequest(BaseModel):
    ax: float = 0.0    # rotation around X  (radians)
    ay: float = 0.0    # rotation around Y  (radians)
    az: float = 0.0    # rotation around Z  (radians)
    gender: str = "neutral"
    n_iter: int = 20


@router.post("/{session_id}/refit")
async def refit_session(session_id: str, body: RefitRequest):
    """
    Relance le fitting SMPL-X avec une orientation imposée.
    Appelé par le viewer quand l'utilisateur clique "Valider".
    Tourne en arrière-plan — poll /status pour suivre l'avancement.
    """
    session_path = _session_dir(session_id)
    if not os.path.isdir(session_path):
        raise HTTPException(404, f"Session '{session_id}' not found.")
    if not os.path.exists(os.path.join(session_path, "keypoints_3d.npy")):
        raise HTTPException(400, "keypoints_3d.npy not found. Phase 3 must complete first.")

    # Check if a refit is already running
    st = _refit_status.get(session_id, {})
    if st.get("status") == "running":
        return {"status": "already_running", "msg": "A refit is already processing."}

    force_orient = (body.ax, body.ay, body.az)
    _refit_status[session_id] = {
        "status": "running",
        "msg":    f"Refitting with orientation ({body.ax:.3f}, {body.ay:.3f}, {body.az:.3f})",
        "orient": {"ax": body.ax, "ay": body.ay, "az": body.az},
    }

    def _run():
        try:
            from app.pipeline.step4_smplx_fitting_service import SmplxService
            result = SmplxService.fit_and_save(
                session_output_root=session_path,
                gender=body.gender,
                n_iter=body.n_iter,
                force_orient=force_orient,
                max_export_frames=9999,
            )
            if result:
                _refit_status[session_id] = {
                    "status": "done",
                    "msg":    "Refit complete. Reload viewer.",
                    "orient": {"ax": body.ax, "ay": body.ay, "az": body.az},
                }
            else:
                _refit_status[session_id] = {
                    "status": "failed",
                    "msg":    "Refit returned None. Check server logs.",
                }
        except Exception as e:
            _refit_status[session_id] = {"status": "failed", "msg": str(e)}

    threading.Thread(target=_run, daemon=True).start()

    return {
        "status":  "started",
        "msg":     f"Refit started with orientation ax={body.ax:.3f} ay={body.ay:.3f} az={body.az:.3f}",
        "orient":  {"ax": body.ax, "ay": body.ay, "az": body.az},
    }


# ──────────────────────────────────────────────────────────────────────────────
# GET /sessions/{id}/viewer
# ──────────────────────────────────────────────────────────────────────────────
@router.get("/{session_id}/viewer", response_class=HTMLResponse)
async def get_smplx_viewer(session_id: str, embed: bool = False):
    from app.database.setup import SessionLocal
    from app.database.models import Movement

    db = SessionLocal()
    movement = db.query(Movement).filter(Movement.name == session_id).first()
    db.close()

    # Orientation par défaut si non trouvée
    orient = {"ax": -1.571, "ay": 0.0, "az": -1.658, "by": 0.90}
    if movement and movement.orientation:
        orient = movement.orientation

    json_path = os.path.join(_session_dir(session_id), "smplx_threejs.json")
    if not os.path.exists(json_path):
        return HTMLResponse(content=_loading_page(session_id), status_code=200)

    return HTMLResponse(content=_viewer_html(session_id, orient, embed=embed), status_code=200)


# ──────────────────────────────────────────────────────────────────────────────
# HTML Templates
# ──────────────────────────────────────────────────────────────────────────────

def _loading_page(session_id: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"/>
<title>3D Reconstruction Loading</title>
<style>
  body {{ margin:0; background:#0a0a1a; display:flex; flex-direction:column;
         align-items:center; justify-content:center; height:100vh;
         font-family:'Segoe UI',sans-serif; color:#fff; }}
  .spinner {{ width:64px; height:64px; border:4px solid #ffffff22;
              border-top-color:#6c63ff; border-radius:50%;
              animation:spin 1s linear infinite; margin-bottom:24px; }}
  @keyframes spin {{ to {{ transform:rotate(360deg); }} }}
</style></head><body>
  <div class="spinner"></div>
  <h2>3D Body Reconstruction in Progress</h2>
  <p>Session: {session_id[:8]}…</p>
  <script>setTimeout(() => location.reload(), 5000);</script>
</body></html>"""


def _viewer_html(session_id: str, orient: dict, equip_type: str = None, equip_orient: dict = None, embed: bool = False) -> str:
    api_url = f"/api/v1/sessions/{session_id}/smplx"
    refit_url = f"/api/v1/sessions/{session_id}/refit"

    # Valeurs par défaut
    ax = orient.get("ax", -1.571)
    ay = orient.get("ay", 0.0)
    az = orient.get("az", -1.658)
    by = orient.get("by", 0.90)

    equip_orient = equip_orient or {"ax": 0.00, "ay": 1.48, "az": 0.00, "bx": 0.02, "by": -0.07, "bz": -0.10}
    bax, bay, baz = equip_orient.get("ax", 0), equip_orient.get("ay", 0), equip_orient.get("az", 0)
    bbx, bby, bbz = equip_orient.get("bx", 0), equip_orient.get("by", 0), equip_orient.get("bz", 0)

    show_barbell_ui = 'flex' if equip_type == 'barbell' else 'none'
    panels_display = 'none' if embed else 'flex'
    frame_label_display = 'none' if embed else 'inline'
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>3D Body — SMPL-X Viewer</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#080818; overflow:hidden; font-family:'Segoe UI',sans-serif; }}
#canvas-container {{ width:100vw; height:100vh; }}

/* ── Top status bar ── */
#status {{
  position:fixed; top:12px; left:50%; transform:translateX(-50%);
  background:rgba(255,255,255,0.07); backdrop-filter:blur(10px);
  padding:5px 18px; border-radius:20px; color:#aaa; font-size:11px;
  border:1px solid rgba(255,255,255,0.07); letter-spacing:.5px;
}}

/* ── Bottom playback bar ── */
#ui {{
  position:fixed; bottom:16px; left:50%; transform:translateX(-50%);
  display:flex; gap:10px; align-items:center;
  background:rgba(255,255,255,0.07); backdrop-filter:blur(12px);
  padding:8px 18px; border-radius:50px;
  border:1px solid rgba(255,255,255,0.1); color:#fff;
}}
#ui button {{
  background:#6c63ff; color:#fff; border:none;
  padding:5px 14px; border-radius:20px; cursor:pointer;
  font-size:12px; transition:opacity .2s;
}}
#ui button:hover {{ opacity:.75; }}
#frame-label {{ font-size:11px; color:#aaa; min-width:80px; text-align:center; }}

/* ── Side panels container ── */
.side-panels {{
  position:fixed; right:16px; top:50%; transform:translateY(-50%);
  display:flex; flex-direction:column; gap:12px; z-index:100;
}}
.ctrl-panel {{
  background:rgba(10,10,30,0.85); -webkit-backdrop-filter:blur(14px); backdrop-filter:blur(14px);
  border:1px solid rgba(108,99,255,0.3); border-radius:16px;
  padding:16px; display:flex; flex-direction:column; gap:10px;
  width:210px; color:#fff;
}}
.ctrl-panel h4 {{
  font-size:12px; color:#6c63ff; letter-spacing:.8px;
  text-transform:uppercase; margin-bottom:2px; text-align:center;
}}
.ctrl-panel.bar-panel h4 {{ color:#ff9f43; }}
.axis-row {{
  display:flex; align-items:center; gap:6px;
}}
.axis-label {{
  font-size:11px; color:#aaa; width:22px; text-align:center; font-weight:bold;
}}
.axis-row button {{
  background:rgba(108,99,255,0.25); color:#fff; border:1px solid rgba(108,99,255,0.4);
  padding:4px 10px; border-radius:8px; cursor:pointer; font-size:13px;
  transition:background .15s; flex:1;
}}
.axis-row button:hover {{ background:rgba(108,99,255,0.55); }}
.bar-panel .axis-row button {{
  background:rgba(255,159,67,0.2); border-color:rgba(255,159,67,0.4);
}}
.bar-panel .axis-row button:hover {{ background:rgba(255,159,67,0.45); }}
.val-display {{
  font-size:11px; color:#6c63ff; width:42px; text-align:right;
  font-variant-numeric:tabular-nums;
}}
.bar-panel .val-display {{ color:#ff9f43; }}
#orient-values {{
  font-size:10px; color:#555; text-align:center; line-height:1.6;
  background:rgba(0,0,0,0.3); border-radius:8px; padding:6px;
}}
#btn-validate {{
  background:linear-gradient(135deg,#6c63ff,#a855f7);
  color:#fff; border:none; border-radius:10px;
  padding:8px; cursor:pointer; font-size:12px; font-weight:600;
  letter-spacing:.5px; transition:opacity .2s;
}}
#btn-validate:hover {{ opacity:.85; }}
#btn-validate:disabled {{ opacity:.4; cursor:default; }}
#refit-status {{
  font-size:10px; text-align:center; color:#aaa; min-height:14px;
}}
.spinner-sm {{
  display:inline-block; width:10px; height:10px;
  border:2px solid #ffffff22; border-top-color:#6c63ff;
  border-radius:50%; animation:spin .7s linear infinite;
  vertical-align:middle; margin-right:4px;
}}
@keyframes spin {{ to {{ transform:rotate(360deg); }} }}

#loading {{
  position:fixed; top:50%; left:50%; transform:translate(-50%,-50%);
  color:#fff; text-align:center; display:flex; flex-direction:column;
  align-items:center; gap:16px;
}}
.spinner {{
  width:48px; height:48px; border:3px solid #ffffff22;
  border-top-color:#6c63ff; border-radius:50%;
  animation:spin .8s linear infinite;
}}
</style>
</head>
<body>
<div id="canvas-container"></div>
<div id="loading">
  <div class="spinner"></div>
  <span style="color:#aaa;font-size:13px">Loading 3D Model…</span>
</div>
<div id="status" style="display:none">SMPL-X Body Reconstruction</div>

<!-- Playback bar -->
<div id="ui" style="display:none">
  <button id="btn-play">▶ Play</button>
  <button id="btn-pause">⏸ Pause</button>
  <button id="btn-reset">↺ Reset</button>
  <span id="frame-label" style="display:{frame_label_display}">Frame 0 / 0</span>
  <button id="btn-rotate">🔄 Auto Rotate</button>
</div>

<!-- Side panels -->
<div class="side-panels" style="display:none" id="panels-container">

  <!-- Panel 1: SMPL-X Orientation -->
  <div class="ctrl-panel">
    <h4>🎯 Orientation SMPL-X</h4>
    <div class="axis-row"><span class="axis-label">X</span><button onclick="rotateAxis('x',-1)">−</button><button onclick="rotateAxis('x', 1)">+</button><span class="val-display" id="val-x">0</span></div>
    <div class="axis-row"><span class="axis-label">Y</span><button onclick="rotateAxis('y',-1)">−</button><button onclick="rotateAxis('y', 1)">+</button><span class="val-display" id="val-y">0</span></div>
    <div class="axis-row"><span class="axis-label">Z</span><button onclick="rotateAxis('z',-1)">−</button><button onclick="rotateAxis('z', 1)">+</button><span class="val-display" id="val-z">0</span></div>
    <div style="border-top:1px solid rgba(108,99,255,0.2);padding-top:8px;">
      <div class="axis-row"><span class="axis-label">↕</span><button onclick="moveY(1)">↑</button><button onclick="moveY(-1)">↓</button><span class="val-display" id="val-ty">0</span></div>
    </div>
    <div id="orient-values">ax={ax:.3f}  ay={ay:.3f}  az={az:.3f}  by={by:.2f}</div>
    <button id="btn-copy" onclick="copyOrientation()" style="background:rgba(255,255,255,0.1);color:#fff;border:1px solid rgba(255,255,255,0.2);border-radius:8px;padding:6px;font-size:10px;cursor:pointer;">📋 Copier</button>
    <button id="btn-validate" onclick="validateOrientation()">✅ Valider &amp; Recalculer</button>
    <div id="refit-status"></div>
  </div>

  <!-- Panel 2: Barbell Orientation -->
  <div class="ctrl-panel bar-panel" style="display:{show_barbell_ui};">
    <h4>🏋️ Barbell Orientation</h4>
    <div class="axis-row"><span class="axis-label">ax</span><button onclick="moveBar('ax',-1)">−</button><button onclick="moveBar('ax',1)">+</button><span class="val-display" id="val-bax">0</span></div>
    <div class="axis-row"><span class="axis-label">ay</span><button onclick="moveBar('ay',-1)">−</button><button onclick="moveBar('ay',1)">+</button><span class="val-display" id="val-bay">0</span></div>
    <div class="axis-row"><span class="axis-label">az</span><button onclick="moveBar('az',-1)">−</button><button onclick="moveBar('az',1)">+</button><span class="val-display" id="val-baz">0</span></div>
    <div style="border-top:1px solid rgba(255,159,67,0.2);margin-top:4px;padding-top:8px;"></div>
    <div class="axis-row"><span class="axis-label">bx</span><button onclick="moveBar('bx',-1)">−</button><button onclick="moveBar('bx',1)">+</button><span class="val-display" id="val-bbx">0</span></div>
    <div class="axis-row"><span class="axis-label">by</span><button onclick="moveBar('by',-1)">−</button><button onclick="moveBar('by',1)">+</button><span class="val-display" id="val-bby">0</span></div>
    <div class="axis-row"><span class="axis-label">bz</span><button onclick="moveBar('bz',-1)">−</button><button onclick="moveBar('bz',1)">+</button><span class="val-display" id="val-bbz">0</span></div>
    <div id="bar-values" style="font-size:10px;color:#555;text-align:center;background:rgba(0,0,0,0.3);border-radius:8px;padding:6px;margin-top:4px;">ax=0 ay=0 az=0<br>bx=0 by=0 bz=0</div>
  </div>

</div>

<!-- Three.js -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>

<script>
// ── Orientation state (in radians, accumulates UI button presses) ──────────
const STEP   = Math.PI / 36;   // 5° per rotation click
const STEP_T = 0.05;           // 5 cm per translation click
let userOrient  = {{ x: {ax}, y: {ay}, z: {az} }};
let meshOffsetY = {by};
let meshGroup   = null;
let barbell     = null;
let barOff = {{ ax: {bax}, ay: {bay}, az: {baz}, bx: {bbx}, by: {bby}, bz: {bbz} }};
const BAR_POS_STEP = 0.01;
const BAR_ROT_STEP = Math.PI / 36;

function moveBar(axis, sign) {{
  if (axis === 'ax' || axis === 'ay' || axis === 'az') barOff[axis] += sign * BAR_ROT_STEP;
  else barOff[axis] += sign * BAR_POS_STEP;
  document.getElementById('val-bax').textContent = barOff.ax.toFixed(3);
  document.getElementById('val-bay').textContent = barOff.ay.toFixed(3);
  document.getElementById('val-baz').textContent = barOff.az.toFixed(3);
  document.getElementById('val-bbx').textContent = barOff.bx.toFixed(3);
  document.getElementById('val-bby').textContent = barOff.by.toFixed(3);
  document.getElementById('val-bbz').textContent = barOff.bz.toFixed(3);
  document.getElementById('bar-values').innerHTML =
    'ax=' + barOff.ax.toFixed(2) + ' ay=' + barOff.ay.toFixed(2) + ' az=' + barOff.az.toFixed(2) + '<br>' +
    'bx=' + barOff.bx.toFixed(2) + ' by=' + barOff.by.toFixed(2) + ' bz=' + barOff.bz.toFixed(2);
  if (window.applyBarbellOffset) window.applyBarbellOffset();
}}

function rotateAxis(axis, sign) {{
  userOrient[axis] += sign * STEP;
  if (meshGroup) {{
    meshGroup.rotation.x = userOrient.x;
    meshGroup.rotation.y = userOrient.y;
    meshGroup.rotation.z = userOrient.z;
  }}
  document.getElementById('val-x').textContent = userOrient.x.toFixed(2);
  document.getElementById('val-y').textContent = userOrient.y.toFixed(2);
  document.getElementById('val-z').textContent = userOrient.z.toFixed(2);
  updateOrientLabel();
}}

function moveY(sign) {{
  meshOffsetY += sign * STEP_T;
  if (meshGroup) meshGroup.position.y = meshOffsetY;
  document.getElementById('val-ty').textContent = meshOffsetY.toFixed(2);
  updateOrientLabel();
}}

function updateOrientLabel() {{
  document.getElementById('orient-values').textContent =
    `ax=${{userOrient.x.toFixed(3)}}  ay=${{userOrient.y.toFixed(3)}}  az=${{userOrient.z.toFixed(3)}}  by=${{meshOffsetY.toFixed(2)}}`;
}}

function copyOrientation() {{
  const text = `orientation = {{"ax": ${{userOrient.x.toFixed(3)}}, "ay": ${{userOrient.y.toFixed(3)}}, "az": ${{userOrient.z.toFixed(3)}}, "by": ${{meshOffsetY.toFixed(2)}}}}`;
  navigator.clipboard.writeText(text);
  const btn = document.getElementById('btn-copy');
  const oldText = btn.textContent;
  btn.textContent = '✅ Copié !';
  setTimeout(() => btn.textContent = oldText, 2000);
}}

async function validateOrientation() {{
  const btn = document.getElementById('btn-validate');
  const statusEl = document.getElementById('refit-status');
  btn.disabled = true;
  statusEl.innerHTML = '<span class="spinner-sm"></span>Envoi au serveur…';

  try {{
    const res = await fetch('{refit_url}', {{
      method: 'POST',
      headers: {{ 'Content-Type': 'application/json' }},
      body: JSON.stringify({{
        ax: userOrient.x,
        ay: userOrient.y,
        az: userOrient.z,
        n_iter: 20,
      }}),
    }});
    const data = await res.json();

    if (data.status === 'started') {{
      statusEl.innerHTML = '<span class="spinner-sm"></span>Recalcul en cours…';
      pollRefitStatus();
    }} else if (data.status === 'already_running') {{
      statusEl.textContent = '⏳ Déjà en cours…';
      btn.disabled = false;
    }} else {{
      statusEl.textContent = '⚠️ ' + (data.msg || 'Erreur');
      btn.disabled = false;
    }}
  }} catch(e) {{
    statusEl.textContent = '❌ Erreur réseau: ' + e.message;
    btn.disabled = false;
  }}
}}

function pollRefitStatus() {{
  const statusEl = document.getElementById('refit-status');
  const btn = document.getElementById('btn-validate');
  const interval = setInterval(async () => {{
    try {{
      const res  = await fetch('{refit_url}'.replace('/refit', '/status'));
      const data = await res.json();
      const rf   = data.refit;
      if (!rf || rf.status === 'running') return;  // still going

      clearInterval(interval);
      if (rf.status === 'done') {{
        statusEl.innerHTML = '✅ Terminé ! <a href="javascript:location.reload()" style="color:#6c63ff">Recharger</a>';
      }} else {{
        statusEl.textContent = '❌ Échec : ' + (rf.msg || 'inconnu');
      }}
      btn.disabled = false;
    }} catch(_) {{ /* keep polling */ }}
  }}, 4000);
}}

// ── Three.js scene ───────────────────────────────────────────────────────────
(async () => {{
  let meshData;
  try {{
    const res = await fetch('{api_url}');
    if (!res.ok) throw new Error('HTTP ' + res.status);
    meshData = await res.json();
  }} catch(e) {{
    document.getElementById('loading').innerHTML =
      '<p style="color:#f66">Failed to load mesh: ' + e.message + '</p>';
    return;
  }}

  const {{ faces, frames, meta }} = meshData;
  const nFrames = frames.length;

  const container = document.getElementById('canvas-container');
  const W = container.clientWidth, H = container.clientHeight;

  const renderer = new THREE.WebGLRenderer({{ antialias:true, alpha:true }});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(W, H);
  renderer.shadowMap.enabled = true;
  renderer.outputEncoding = THREE.sRGBEncoding;
  container.appendChild(renderer.domElement);

  const scene  = new THREE.Scene();
  scene.background = new THREE.Color(0x080818);
  scene.fog = new THREE.Fog(0x080818, 5, 20);

  const camera = new THREE.PerspectiveCamera(50, W/H, 0.01, 100);
  camera.position.set(0, 1, 3.5);

  const controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.target.set(0, 0.9, 0);
  controls.update();

  // Lights
  scene.add(new THREE.AmbientLight(0xffffff, 0.5));
  const sun = new THREE.DirectionalLight(0xffffff, 0.8);
  sun.position.set(3,5,3); sun.castShadow = true;
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0x8080ff, 0.3);
  fill.position.set(-3,2,-2); scene.add(fill);

  // Grid
  scene.add(new THREE.GridHelper(6, 20, 0x333344, 0x222233));

  // Body mesh geometry
  const geometry = new THREE.BufferGeometry();
  geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(faces), 1));
  const verts0 = new Float32Array(frames[0].v);
  geometry.setAttribute('position', new THREE.BufferAttribute(verts0.slice(), 3));
  geometry.computeVertexNormals();

  const material = new THREE.MeshPhongMaterial({{
    color:0x6c63ff, specular:0x222244, shininess:40,
    side:THREE.FrontSide, transparent:true, opacity:0.92,
  }});

  const mesh = new THREE.Mesh(geometry, material);
  mesh.castShadow = true;
  // ── wrap mesh in a group so UI rotation doesn't fight OrbitControls ──
  meshGroup = new THREE.Group();
  meshGroup.add(mesh);

  // Apply initial user orientation
  meshGroup.rotation.x = userOrient.x;
  meshGroup.rotation.y = userOrient.y;
  meshGroup.rotation.z = userOrient.z;
  meshGroup.position.y = meshOffsetY;

  geometry.computeBoundingBox();
  const center = new THREE.Vector3();
  geometry.boundingBox.getCenter(center);
  mesh.position.set(-center.x, -center.y + 0.2, -center.z);
  scene.add(meshGroup);

  // Joints overlay
  const jMat  = new THREE.MeshBasicMaterial({{ color:0xff4466 }});
  const jGeo  = new THREE.SphereGeometry(0.012, 8, 8);
  const jMeshes = [];
  for (let i = 0; i < meta.n_joints; i++) {{
    const jm = new THREE.Mesh(jGeo, jMat);
    meshGroup.add(jm);
    jMeshes.push(jm);
  }}

  // ── Equipment ────────────────────────────────────────────────────────────────
  if ('{equip_type}' === 'barbell') {{
    const g = new THREE.Group();
    const barGeo = new THREE.CylinderGeometry(0.014, 0.014, 2.2, 12);
    const barMat = new THREE.MeshStandardMaterial({{ color:0xbbbbbb, metalness:0.85, roughness:0.15 }});
    const bar = new THREE.Mesh(barGeo, barMat);
    bar.rotation.z = Math.PI / 2;
    g.add(bar);
    const plateGeo = new THREE.CylinderGeometry(0.20, 0.20, 0.07, 32);
    const plateMat = new THREE.MeshStandardMaterial({{ color:0x111111, metalness:0.3, roughness:0.6 }});
    const lp = new THREE.Mesh(plateGeo, plateMat); lp.position.x = -0.8; lp.rotation.z = Math.PI/2; g.add(lp);
    const rp = lp.clone(); rp.position.x = 0.8; g.add(rp);
    meshGroup.add(g);
    barbell = g;
  }}

  // Animation loop
  let currentFrame = 0, playing = true, autoRotate = false, lastTime = 0;
  const FPS = meta.fps || 30, FRAME_MS = 1000/FPS;

  function updateFrame(fi) {{
    const frame = frames[fi];
    const vArr  = new Float32Array(frame.v);
    const posAttr = geometry.attributes.position;
    for (let i = 0; i < vArr.length; i++) posAttr.array[i] = vArr[i];
    posAttr.needsUpdate = true;
    geometry.computeVertexNormals();
    const jArr = frame.j;
    for (let j = 0; j < meta.n_joints; j++) {{
      jMeshes[j].position.set(
        jArr[j*3]   + mesh.position.x,
        jArr[j*3+1] + mesh.position.y,
        jArr[j*3+2] + mesh.position.z,
      );
    }}
    if (window.applyBarbellOffset) window.applyBarbellOffset();

    document.getElementById('frame-label').textContent =
      'Frame ' + fi + ' / ' + (nFrames-1);
  }}

  window.applyBarbellOffset = function() {{
    if (barbell && meta.n_joints > 21) {{
      const pL = jMeshes[20].position, pR = jMeshes[21].position;
      // Appliquer les positions (bx, by, bz)
      barbell.position.set(
        (pL.x + pR.x) / 2 + barOff.bx,
        (pL.y + pR.y) / 2 + barOff.by,
        (pL.z + pR.z) / 2 + barOff.bz
      );
      // Aligner la barre entre les poignets
      const dir = new THREE.Vector3().subVectors(pR, pL).normalize();
      barbell.quaternion.setFromUnitVectors(new THREE.Vector3(1, 0, 0), dir);
      
      // Appliquer les rotations relatives aux axes globaux (pour que ce soit visible et intuitif)
      barbell.rotateOnWorldAxis(new THREE.Vector3(1, 0, 0), barOff.ax);
      barbell.rotateOnWorldAxis(new THREE.Vector3(0, 1, 0), barOff.ay);
      barbell.rotateOnWorldAxis(new THREE.Vector3(0, 0, 1), barOff.az);
    }}
  }};

  function animate(time) {{
    requestAnimationFrame(animate);
    if (playing && time-lastTime > FRAME_MS) {{
      currentFrame = (currentFrame+1) % nFrames;
      updateFrame(currentFrame);
      lastTime = time;
    }}
    if (autoRotate) meshGroup.rotation.y += 0.003;
    controls.update();
    renderer.render(scene, camera);
  }}

  updateFrame(0);
  document.getElementById('loading').style.display  = 'none';
  document.getElementById('status').style.display   = 'block';
  document.getElementById('ui').style.display       = 'flex';
  document.getElementById('panels-container').style.display = '{panels_display}';
  document.getElementById('val-x').textContent = userOrient.x.toFixed(2);
  document.getElementById('val-y').textContent = userOrient.y.toFixed(2);
  document.getElementById('val-z').textContent = userOrient.z.toFixed(2);
  document.getElementById('val-ty').textContent = meshOffsetY.toFixed(2);
  document.getElementById('val-bax').textContent = barOff.ax.toFixed(3);
  document.getElementById('val-bay').textContent = barOff.ay.toFixed(3);
  document.getElementById('val-baz').textContent = barOff.az.toFixed(3);
  document.getElementById('val-bbx').textContent = barOff.bx.toFixed(3);
  document.getElementById('val-bby').textContent = barOff.by.toFixed(3);
  document.getElementById('val-bbz').textContent = barOff.bz.toFixed(3);
  document.getElementById('bar-values').innerHTML =
    'ax=' + barOff.ax.toFixed(2) + ' ay=' + barOff.ay.toFixed(2) + ' az=' + barOff.az.toFixed(2) + '<br>' +
    'bx=' + barOff.bx.toFixed(2) + ' by=' + barOff.by.toFixed(2) + ' bz=' + barOff.bz.toFixed(2);
  requestAnimationFrame(animate);

  // Playback controls
  document.getElementById('btn-play').onclick   = () => {{ playing = true; }};
  document.getElementById('btn-pause').onclick  = () => {{ playing = false; }};
  document.getElementById('btn-reset').onclick  = () => {{ currentFrame=0; updateFrame(0); }};
  document.getElementById('btn-rotate').onclick = () => {{ autoRotate = !autoRotate; }};

  window.addEventListener('resize', () => {{
    const nW=container.clientWidth, nH=container.clientHeight;
    camera.aspect = nW/nH;
    camera.updateProjectionMatrix();
    renderer.setSize(nW, nH);
  }});
}})();
</script>
</body>
</html>"""