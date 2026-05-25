from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.setup import SessionLocal
from app.database.models import Movement
from typing import List, Optional
from pydantic import BaseModel
import os
import json
from fastapi.responses import JSONResponse, HTMLResponse

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
         
    with open(movement.smpl_ref, "r") as f:
        data = json.load(f)
    return JSONResponse(content=data)

@router.get("/{name}/viewer")
async def get_movement_viewer(name: str, db: Session = Depends(get_db)):
    movement = db.query(Movement).filter(Movement.name == name).first()
    if not movement:
        raise HTTPException(status_code=404, detail="Movement not found")
        
    from app.routes.sessions import _viewer_html
    # On utilise l'orientation stockée dans la base
    orient = movement.orientation or {"ax": -1.571, "ay": 0.0, "az": -1.658, "by": 0.90}
    equip_type = movement.equipment
    equip_orient = movement.equipment_orientation or {"ax": 0.00, "ay": 0.00, "az": 0.00, "bx": 0.02, "by": -0.07, "bz": -0.10}
    
    # Génération du HTML avec la nouvelle interface
    html = _viewer_html(name, orient, equip_type, equip_orient)
    
    # On s'assure que le chemin SMPL-X pointe vers le mouvement et non vers une session
    html = html.replace(f"/api/v1/sessions/{name}/smplx", f"/api/v1/movements/{name}/smplx")
    
    return HTMLResponse(content=html)
