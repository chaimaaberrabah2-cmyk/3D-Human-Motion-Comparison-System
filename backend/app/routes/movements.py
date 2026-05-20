from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.setup import SessionLocal
from app.database.models import Movement
from typing import List, Optional
from pydantic import BaseModel
import os
import json
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse

router = APIRouter()

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class MovementResponse(BaseModel):
    movement_id: int
    name: str
    category: str
    description: str
    difficulty: str
    instructions: List[str]
    thumbnail_path: Optional[str] = None
    smpl_ref: Optional[str] = None
    orientation: Optional[dict] = None

    class Config:
        from_attributes = True

@router.get("/", response_model=List[MovementResponse])
async def get_movements(db: Session = Depends(get_db)):
    movements = db.query(Movement).all()
    return movements

@router.get("/{name}", response_model=MovementResponse)
async def get_movement_by_name(name: str, db: Session = Depends(get_db)):
    movement = db.query(Movement).filter(Movement.name == name).first()
    if not movement:
        raise HTTPException(status_code=404, detail="Movement not found")
    return movement

@router.get("/{name}/smplx")
async def get_movement_smplx(name: str, db: Session = Depends(get_db)):
    movement = db.query(Movement).filter(Movement.name == name).first()
    if not movement or not movement.smpl_ref:
        raise HTTPException(status_code=404, detail="SMPL-X data not found for this movement")
    
    if not os.path.exists(movement.smpl_ref):
         raise HTTPException(status_code=404, detail=f"File not found: {movement.smpl_ref}")
         
    def iter_file():
        with open(movement.smpl_ref, "rb") as f:
            while chunk := f.read(1024 * 1024):
                yield chunk

    from starlette.responses import StreamingResponse
    return StreamingResponse(iter_file(), media_type="application/json")

@router.get("/{name}/viewer")
async def get_movement_viewer(name: str, db: Session = Depends(get_db)):
    movement = db.query(Movement).filter(Movement.name == name).first()
    if not movement:
        raise HTTPException(status_code=404, detail="Movement not found")
        
    from app.routes.sessions import _viewer_html
    # On utilise l'orientation stockée dans la base si elle existe
    orient = getattr(movement, "orientation", None) or {"ax": -1.571, "ay": 0.0, "az": -1.658, "by": 0.90}
    equip_type = getattr(movement, "equipment", None)
    equip_orient = getattr(movement, "equipment_orientation", None) or {"ax": 0.00, "ay": 0.00, "az": 0.00, "bx": 0.02, "by": -0.07, "bz": -0.10}
    
    # Génération du HTML simplifié
    html = _viewer_html(name)
    
    # Injection dynamique de l'orientation et de la translation Y depuis la DB
    ax = orient.get("ax", -2.007)
    ay = orient.get("ay", -0.262)
    az = orient.get("az", -0.262)
    by = orient.get("by", 0.85)
    html = html.replace(
        "let userOrient  = { x: -2.007, y: -0.262, z: -0.262 };",
        f"let userOrient  = {{ x: {ax}, y: {ay}, z: {az} }};"
    )
    html = html.replace(
        "let meshOffsetY = 0.85;",
        f"let meshOffsetY = {by};"
    )
    
    # Redirection vers l'API des mouvements au lieu des sessions
    html = html.replace(f"http://127.0.0.1:8000/api/v1/sessions/{name}/smplx", f"http://127.0.0.1:8000/api/v1/movements/{name}/smplx")
    html = html.replace(f"http://127.0.0.1:8000/api/v1/sessions/{name}/refit", f"http://127.0.0.1:8000/api/v1/movements/{name}/refit")
    
    return HTMLResponse(content=html)
