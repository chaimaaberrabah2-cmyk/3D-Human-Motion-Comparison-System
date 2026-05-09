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

    return {
        "session_id":      session_id,
        "progress_percent": int((sum([phase1, phase2, phase3, phase4]) / 4) * 100),
        "is_complete":     phase4,
        "has_smplx_viewer": has_viewer,
        "refit":           refit_info,
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
async def get_smplx_viewer(session_id: str):
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
        
    return HTMLResponse(content=_viewer_html(session_id, orient), status_code=200)


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


def _viewer_html(session_id: str, orient: dict) -> str:
    api_url = f"/api/v1/sessions/{session_id}/smplx"
    
    # Valeurs par défaut
    ax = orient.get("ax", -1.571)
    ay = orient.get("ay", 0.0)
    az = orient.get("az", -1.658)
    by = orient.get("by", 0.90)
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>3D Body — SMPL-X Viewer</title>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />
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
#version-tag {{
  position:fixed; top:12px; right:12px; font-size:10px; color:rgba(255,255,255,0.2);
}}

/* ── Bottom playback bar (Glassmorphism) ── */
#ui {{
  position:fixed; bottom:20px; left:50%; transform:translateX(-50%);
  display:flex; gap:12px; align-items:center;
  background:rgba(255,255,255,0.08); backdrop-filter:blur(16px);
  padding:10px 24px; border-radius:50px;
  border:1px solid rgba(255,255,255,0.1); color:#fff;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}}
#ui button {{
  background:rgba(108,99,255,0.8); color:#fff; border:none;
  padding:6px 16px; border-radius:20px; cursor:pointer;
  font-size:12px; font-weight:600; transition:all .2s;
  display:flex; align-items:center; gap:6px;
}}
#ui button:hover {{ background:#6c63ff; transform:translateY(-2px); }}
#ui button:active {{ transform:translateY(0); }}
#ui button.secondary {{ background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.1); }}
#ui button.secondary:hover {{ background:rgba(255,255,255,0.2); }}

#frame-label {{ font-size:11px; color:#aaa; min-width:90px; text-align:center; font-family:monospace; }}

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
@keyframes spin {{ to {{ transform:rotate(360deg); }} }}
</style>
</head>
<body>
<div id="canvas-container"></div>
<div id="version-tag">UI v1.1 Premium</div>
<div id="loading">
  <div class="spinner"></div>
  <span style="color:#aaa;font-size:13px">Loading 3D Motion…</span>
</div>
<div id="status" style="display:none">SMPL-X Motion Analysis</div>

<!-- Clean UI Bar -->
<div id="ui" style="display:none">
  <button id="btn-play">▶ Play</button>
  <button id="btn-pause" style="display:none">⏸ Pause</button>
  <button id="btn-reset" class="secondary">↺ Restart</button>
  <div style="width:1px; height:20px; background:rgba(255,255,255,0.1); margin:0 5px;"></div>
  <span id="frame-label">Frame 0 / 0</span>
  <div style="width:1px; height:20px; background:rgba(255,255,255,0.1); margin:0 5px;"></div>
  <button id="btn-rotate" class="secondary">🔄 360° View</button>
  <button id="btn-reset-view" class="secondary">🎯 Reset View</button>
</div>

<!-- Three.js -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>

<script>
// ── Fixed Default Orientation ───────────────────────────────────────────────
const defaultOrient = {{ x: {ax}, y: {ay}, z: {az}, by: {by} }};
let meshGroup = null;
let controls = null;
let camera = null;

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

  camera = new THREE.PerspectiveCamera(50, W/H, 0.01, 100);
  camera.position.set(0, 1, 3.5);

  controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.target.set(0, 0.9, 0);
  controls.update();

  // Lights
  scene.add(new THREE.AmbientLight(0xffffff, 0.6));
  const sun = new THREE.DirectionalLight(0xffffff, 0.8);
  sun.position.set(3,5,3); sun.castShadow = true;
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0x8080ff, 0.4);
  fill.position.set(-3,2,-2); scene.add(fill);

  // Elegant Grid
  const grid = new THREE.GridHelper(10, 20, 0x6c63ff, 0x222233);
  grid.material.opacity = 0.2;
  grid.material.transparent = true;
  scene.add(grid);

  // Body mesh geometry
  const geometry = new THREE.BufferGeometry();
  geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(faces), 1));
  const verts0 = new Float32Array(frames[0].v);
  geometry.setAttribute('position', new THREE.BufferAttribute(verts0.slice(), 3));
  geometry.computeVertexNormals();

  const material = new THREE.MeshPhongMaterial({{
    color:0x6c63ff, specular:0x222244, shininess:40,
    side:THREE.FrontSide, transparent:true, opacity:0.95,
  }});

  const mesh = new THREE.Mesh(geometry, material);
  mesh.castShadow = true;
  
  meshGroup = new THREE.Group();
  meshGroup.add(mesh);

  // Apply default orientation
  meshGroup.rotation.set(defaultOrient.x, defaultOrient.y, defaultOrient.z);
  meshGroup.position.y = defaultOrient.by;

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

  // ── Equipment: Barbell ───────────────────────────────────────────────────
  let barbell = null;
  function createBarbell() {{
    const group = new THREE.Group();
    // The Bar
    const barGeo = new THREE.CylinderGeometry(0.015, 0.015, 2.2, 8);
    const barMat = new THREE.MeshStandardMaterial({{ color: 0xaaaaaa, metalness: 0.8, roughness: 0.2 }});
    const bar = new THREE.Mesh(barGeo, barMat);
    bar.rotation.z = Math.PI / 2;
    group.add(bar);

    // The Plates (Disks)
    const plateGeo = new THREE.CylinderGeometry(0.22, 0.22, 0.08, 32);
    const plateMat = new THREE.MeshStandardMaterial({{ color: 0x111111 }});
    const leftPlate = new THREE.Mesh(plateGeo, plateMat);
    leftPlate.position.x = -0.8;
    leftPlate.rotation.z = Math.PI / 2;
    group.add(leftPlate);

    const rightPlate = leftPlate.clone();
    rightPlate.position.x = 0.8;
    group.add(rightPlate);

    meshGroup.add(group);
    return group;
  }}
  barbell = createBarbell();

  // Animation loop
  let currentFrame = 0, playing = true, lastTime = 0;
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

    // Update Barbell position (attached to wrists 20 and 21)
    if (meta.n_joints > 21) {{
      const pL = jMeshes[20].position;
      const pR = jMeshes[21].position;
      
      // Position at midpoint + offsets for palms
      // offsetDown moves it towards fingers, offsetForward moves it to the front of wrist
      const offsetDown = -0.07; 
      const offsetForward = 0.03; 

      barbell.position.set(
        (pL.x + pR.x)/2, 
        (pL.y + pR.y)/2 + offsetDown, 
        (pL.z + pR.z)/2 + offsetForward
      );
      
      // Orientation: Vector between wrists
      const dir = new THREE.Vector3().subVectors(pR, pL).normalize();
      barbell.quaternion.setFromUnitVectors(new THREE.Vector3(1, 0, 0), dir);
    }}

    document.getElementById('frame-label').textContent =
      fi + ' / ' + (nFrames-1);
  }}

  function animate(time) {{
    requestAnimationFrame(animate);
    if (playing && time-lastTime > FRAME_MS) {{
      currentFrame = (currentFrame+1) % nFrames;
      updateFrame(currentFrame);
      lastTime = time;
    }}
    controls.update();
    renderer.render(scene, camera);
  }}

  updateFrame(0);
  document.getElementById('loading').style.display  = 'none';
  document.getElementById('ui').style.display       = 'flex';
  requestAnimationFrame(animate);

  // Controls Logic
  document.getElementById('btn-play').onclick = () => {{
    playing = true;
    document.getElementById('btn-play').style.display = 'none';
    document.getElementById('btn-pause').style.display = 'block';
  }};
  document.getElementById('btn-pause').onclick = () => {{
    playing = false;
    document.getElementById('btn-pause').style.display = 'none';
    document.getElementById('btn-play').style.display = 'block';
  }};
  document.getElementById('btn-reset').onclick = () => {{ 
    currentFrame=0; 
    updateFrame(0); 
  }};
  
  // 360° Rotate around human
  document.getElementById('btn-rotate').onclick = () => {{
    controls.autoRotate = !controls.autoRotate;
    document.getElementById('btn-rotate').style.background = controls.autoRotate ? '#6c63ff' : 'rgba(255,255,255,0.1)';
  }};

  // Reset View & Orientation to Default
  document.getElementById('btn-reset-view').onclick = () => {{
    camera.position.set(0, 1, 3.5);
    controls.target.set(0, 0.9, 0);
    controls.autoRotate = false;
    document.getElementById('btn-rotate').style.background = 'rgba(255,255,255,0.1)';
    meshGroup.rotation.set(defaultOrient.x, defaultOrient.y, defaultOrient.z);
    meshGroup.position.y = defaultOrient.by;
    controls.update();
  }};

  window.addEventListener('resize', () => {{
    const nW=container.clientWidth, nH=container.clientHeight;
    camera.aspect = nW/nH;
    camera.updateProjectionMatrix();
    renderer.setSize(nW, nH);
  }});
  
  // Set default button state
  document.getElementById('btn-play').style.display = 'none';
  document.getElementById('btn-pause').style.display = 'block';

}})();
</script>
</body>
</html>"""
