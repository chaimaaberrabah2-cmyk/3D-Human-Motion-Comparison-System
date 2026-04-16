from fastapi import APIRouter, Depends, HTTPException
from typing import Any, Dict
import cv2
from sqlalchemy.orm import Session
from app.db.db_config import get_db
from app.models.models import Establishment

router = APIRouter()

@router.get("/list")
def list_cameras() -> Any:
    # ... (existing code stayed the same, just keeping the definition here for context)
    available = []
    for index in range(10):
        cap = cv2.VideoCapture(index)
        if cap is not None and cap.isOpened():
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            fps = cap.get(cv2.CAP_PROP_FPS)
            cap.release()
            available.append({
                "index": index,
                "name": f"Camera {index}",
                "resolution": f"{width}x{height}",
                "fps": round(fps, 1) if fps > 0 else None,
                "type": "Built-in" if index == 0 else "External",
            })
        else:
            if cap is not None:
                cap.release()
            if index > 0:
                break
    return {"cameras": available, "count": len(available)}

@router.get("/calibration/{establishment_id}")
def get_calibration(establishment_id: int, db: Session = Depends(get_db)):
    """Récupère la calibration d'un établissement."""
    est = db.query(Establishment).filter(Establishment.establishment_id == establishment_id).first()
    if not est:
        raise HTTPException(status_code=404, detail="Établissement non trouvé")
    return {"calibration": est.calibration_data or {}}

@router.put("/calibration/{establishment_id}")
def update_calibration(establishment_id: int, calibration: Dict[str, Any], db: Session = Depends(get_db)):
    """Met à jour la calibration d'un établissement."""
    est = db.query(Establishment).filter(Establishment.establishment_id == establishment_id).first()
    if not est:
        raise HTTPException(status_code=404, detail="Établissement non trouvé")
    
    est.calibration_data = calibration
    db.commit()
    return {"message": "Calibration mise à jour avec succès", "calibration": est.calibration_data}
