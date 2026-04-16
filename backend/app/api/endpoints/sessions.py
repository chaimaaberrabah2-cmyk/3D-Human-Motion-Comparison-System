# =============================================================
# backend/app/api/endpoints/sessions.py
# =============================================================
# Gestion des sessions d'analyse et des résultats SMPL-X.
#
# Endpoints :
#   GET /sessions/{session_id}/status    → état du pipeline (phases complètes)
#   GET /sessions/{session_id}/smplx     → JSON Three.js (vertices + faces)
#   GET /sessions/{session_id}/viewer    → page HTML Three.js autonome
# =============================================================

import os
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse

router = APIRouter()

BASE_DIR = os.getcwd()
FRAME_DIR = os.path.join(BASE_DIR, "data", "frames")


def _session_dir(session_id: str) -> str:
    return os.path.join(FRAME_DIR, session_id)


# -----------------------------------------------------------------------
# GET /sessions/{session_id}/status
# -----------------------------------------------------------------------
@router.get("/{session_id}/status")
async def get_session_status(session_id: str):
    """
    Returns which pipeline phases have completed for a given session.
    The Flutter app polls this to show real-time progress.
    """
    session_path = _session_dir(session_id)
    if not os.path.isdir(session_path):
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")

    phase1 = any(
        os.path.isdir(os.path.join(session_path, f"temp{i}")) for i in range(1, 5)
    )
    phase2 = os.path.exists(os.path.join(session_path, "keypoints_angle1.npy"))
    phase3 = os.path.exists(os.path.join(session_path, "keypoints_3d.npy"))
    phase4 = os.path.exists(os.path.join(session_path, "smplx_result.npz"))
    has_viewer = os.path.exists(os.path.join(session_path, "smplx_threejs.json"))

    completed_phases = sum([phase1, phase2, phase3, phase4])
    total_phases = 4
    progress_pct = int((completed_phases / total_phases) * 100)

    return {
        "session_id": session_id,
        "progress_percent": progress_pct,
        "is_complete": phase4,
        "has_smplx_viewer": has_viewer,
        "phases": {
            "phase1_frames_extracted": phase1,
            "phase2_pose_estimated": phase2,
            "phase3_triangulated": phase3,
            "phase4_smplx_fitted": phase4,
        },
    }


# -----------------------------------------------------------------------
# GET /sessions/{session_id}/smplx
# -----------------------------------------------------------------------
@router.get("/{session_id}/smplx")
async def get_smplx_data(session_id: str):
    """
    Returns the compact Three.js-ready JSON (vertices + faces per frame).
    Used directly by the embedded Three.js viewer.
    """
    json_path = os.path.join(_session_dir(session_id), "smplx_threejs.json")
    if not os.path.exists(json_path):
        raise HTTPException(
            status_code=404,
            detail="SMPL-X data not ready yet. Check /status — Phase 4 must complete first.",
        )

    with open(json_path, "r") as f:
        data = json.load(f)

    return JSONResponse(content=data)


# -----------------------------------------------------------------------
# GET /sessions/{session_id}/viewer
# -----------------------------------------------------------------------
@router.get("/{session_id}/viewer", response_class=HTMLResponse)
async def get_smplx_viewer(session_id: str):
    """
    Returns a self-contained HTML page with Three.js that renders the
    animated SMPL-X mesh for the given session.
    Flutter opens this URL in a WebView.
    """
    # Check that SMPL-X data exists
    json_path = os.path.join(_session_dir(session_id), "smplx_threejs.json")
    if not os.path.exists(json_path):
        return HTMLResponse(
            content=_loading_page(session_id),
            status_code=200,
        )

    return HTMLResponse(content=_viewer_html(session_id), status_code=200)


# -----------------------------------------------------------------------
# HTML Templates
# -----------------------------------------------------------------------

def _loading_page(session_id: str) -> str:
    """Shown while SMPL-X fitting is still running."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>3D Reconstruction Loading</title>
<style>
  body {{
    margin: 0; background: #0a0a1a;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    height: 100vh; font-family: 'Segoe UI', sans-serif; color: #fff;
  }}
  .spinner {{
    width: 64px; height: 64px;
    border: 4px solid #ffffff22;
    border-top-color: #6c63ff;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 24px;
  }}
  @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
  h2 {{ font-size: 1.2rem; color: #aaa; margin-bottom: 8px; }}
  p  {{ font-size: 0.85rem; color: #555; }}
</style>
</head>
<body>
  <div class="spinner"></div>
  <h2>3D Body Reconstruction in Progress</h2>
  <p>Session: {session_id[:8]}…</p>
  <p style="margin-top:16px;font-size:0.75rem;color:#333;">
    SMPL-X Phase 4 is running in the background.<br/>
    This page will refresh when ready.
  </p>
  <script>
    // Auto-reload every 5s until data is ready
    setTimeout(() => location.reload(), 5000);
  </script>
</body>
</html>"""


def _viewer_html(session_id: str) -> str:
    """Full Three.js SMPL-X mesh viewer."""
    api_url = f"http://127.0.0.1:8000/api/v1/sessions/{session_id}/smplx"
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>3D Body Reconstruction</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ background: #080818; overflow: hidden; font-family: 'Segoe UI', sans-serif; }}
  #canvas-container {{ width: 100vw; height: 100vh; }}
  #ui {{
    position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
    display: flex; gap: 12px; align-items: center;
    background: rgba(255,255,255,0.08);
    backdrop-filter: blur(10px);
    padding: 10px 20px; border-radius: 50px;
    border: 1px solid rgba(255,255,255,0.1);
    color: #fff;
  }}
  button {{
    background: #6c63ff; color: #fff; border: none;
    padding: 6px 16px; border-radius: 20px;
    cursor: pointer; font-size: 13px; transition: opacity 0.2s;
  }}
  button:hover {{ opacity: 0.8; }}
  #frame-label {{ font-size: 12px; color: #aaa; min-width: 80px; text-align:center; }}
  #status {{
    position: fixed; top: 16px; left: 50%; transform: translateX(-50%);
    background: rgba(255,255,255,0.08); backdrop-filter: blur(8px);
    padding: 6px 20px; border-radius: 20px; color: #aaa; font-size: 12px;
    border: 1px solid rgba(255,255,255,0.07);
  }}
  #loading {{
    position: fixed; top: 50%; left: 50%; transform: translate(-50%,-50%);
    color: #fff; text-align: center; display: flex; flex-direction: column;
    align-items: center; gap: 16px;
  }}
  .spinner {{
    width: 48px; height: 48px; border: 3px solid #ffffff22;
    border-top-color: #6c63ff; border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }}
  @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
</style>
</head>
<body>
<div id="canvas-container"></div>
<div id="loading">
  <div class="spinner"></div>
  <span style="color:#aaa;font-size:13px">Loading 3D Model…</span>
</div>
<div id="status" style="display:none">SMPL-X Body Reconstruction</div>
<div id="ui" style="display:none">
  <button id="btn-play">▶ Play</button>
  <button id="btn-pause">⏸ Pause</button>
  <button id="btn-reset">↺ Reset</button>
  <span id="frame-label">Frame 0 / 0</span>
  <button id="btn-rotate">🔄 Auto Rotate</button>
</div>

<!-- Three.js CDN -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>

<script>
(async () => {{
  // ---- Fetch SMPL-X data ----
  let meshData;
  try {{
    const res = await fetch("{api_url}");
    if (!res.ok) throw new Error("HTTP " + res.status);
    meshData = await res.json();
  }} catch(e) {{
    document.getElementById("loading").innerHTML =
      '<p style="color:#f66">Failed to load mesh: ' + e.message + '</p>';
    return;
  }}

  const {{ faces, frames, meta }} = meshData;
  const nVerts = meta.n_vertices;
  const nFrames = frames.length;

  // ---- Three.js Setup ----
  const container = document.getElementById("canvas-container");
  const W = container.clientWidth, H = container.clientHeight;

  const renderer = new THREE.WebGLRenderer({{ antialias: true, alpha: true }});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(W, H);
  renderer.shadowMap.enabled = true;
  renderer.outputEncoding = THREE.sRGBEncoding;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x080818);
  scene.fog = new THREE.Fog(0x080818, 5, 20);

  const camera = new THREE.PerspectiveCamera(50, W / H, 0.01, 100);
  camera.position.set(0, 1, 3.5);

  const controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.target.set(0, 0.9, 0);
  controls.update();

  // ---- Lighting ----
  scene.add(new THREE.AmbientLight(0xffffff, 0.5));
  const sun = new THREE.DirectionalLight(0xffffff, 0.8);
  sun.position.set(3, 5, 3);
  sun.castShadow = true;
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0x8080ff, 0.3);
  fill.position.set(-3, 2, -2);
  scene.add(fill);

  // ---- Grid Floor ----
  const grid = new THREE.GridHelper(6, 20, 0x333344, 0x222233);
  scene.add(grid);

  // ---- Build SMPL-X mesh geometry ----
  const geometry = new THREE.BufferGeometry();
  const faceIndex = new Uint32Array(faces);
  geometry.setIndex(new THREE.BufferAttribute(faceIndex, 1));

  // Initial vertex positions from frame 0
  const verts0 = new Float32Array(frames[0].v);
  geometry.setAttribute("position", new THREE.BufferAttribute(verts0.slice(), 3));
  geometry.computeVertexNormals();

  // Gradient body material
  const material = new THREE.MeshPhongMaterial({{
    color: 0x6c63ff,
    specular: 0x222244,
    shininess: 40,
    side: THREE.FrontSide,
    transparent: true,
    opacity: 0.92,
  }});

  const mesh = new THREE.Mesh(geometry, material);

  // Center mesh: find centroid of pelvis area
  geometry.computeBoundingBox();
  const center = new THREE.Vector3();
  geometry.boundingBox.getCenter(center);
  mesh.position.set(-center.x, -center.y + 0.2, -center.z);
  mesh.castShadow = true;
  scene.add(mesh);

  // ---- Skeleton joints overlay ----
  const jointMaterial = new THREE.MeshBasicMaterial({{ color: 0xff4466 }});
  const jointGeo = new THREE.SphereGeometry(0.012, 8, 8);
  const jointMeshes = [];
  for (let i = 0; i < meta.n_joints; i++) {{
    const jm = new THREE.Mesh(jointGeo, jointMaterial);
    scene.add(jm);
    jointMeshes.push(jm);
  }}

  // ---- Animation ----
  let currentFrame = 0;
  let playing = true;
  let autoRotate = false;
  let lastTime = 0;
  const FPS = meta.fps || 30;
  const FRAME_MS = 1000 / FPS;

  function updateFrame(fi) {{
    const frame = frames[fi];
    const vArr = new Float32Array(frame.v);
    const posAttr = geometry.attributes.position;
    for (let i = 0; i < vArr.length; i++) posAttr.array[i] = vArr[i];
    posAttr.needsUpdate = true;
    geometry.computeVertexNormals();

    // Update joints
    const jArr = frame.j;
    for (let j = 0; j < meta.n_joints; j++) {{
      jointMeshes[j].position.set(
        jArr[j*3]   + mesh.position.x,
        jArr[j*3+1] + mesh.position.y,
        jArr[j*3+2] + mesh.position.z
      );
    }}
    document.getElementById("frame-label").textContent =
      "Frame " + fi + " / " + (nFrames - 1);
  }}

  function animate(time) {{
    requestAnimationFrame(animate);
    if (playing && time - lastTime > FRAME_MS) {{
      currentFrame = (currentFrame + 1) % nFrames;
      updateFrame(currentFrame);
      lastTime = time;
    }}
    if (autoRotate) scene.rotation.y += 0.003;
    controls.update();
    renderer.render(scene, camera);
  }}

  // Init
  updateFrame(0);
  document.getElementById("loading").style.display = "none";
  document.getElementById("status").style.display = "block";
  document.getElementById("ui").style.display = "flex";
  requestAnimationFrame(animate);

  // ---- UI Controls ----
  document.getElementById("btn-play").onclick   = () => {{ playing = true; }};
  document.getElementById("btn-pause").onclick  = () => {{ playing = false; }};
  document.getElementById("btn-reset").onclick  = () => {{ currentFrame = 0; updateFrame(0); }};
  document.getElementById("btn-rotate").onclick = () => {{ autoRotate = !autoRotate; }};

  // ---- Resize ----
  window.addEventListener("resize", () => {{
    const nW = container.clientWidth, nH = container.clientHeight;
    camera.aspect = nW / nH;
    camera.updateProjectionMatrix();
    renderer.setSize(nW, nH);
  }});
}})();
</script>
</body>
</html>"""
