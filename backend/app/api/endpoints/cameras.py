from fastapi import APIRouter
from typing import Any
import cv2

router = APIRouter()

@router.get("/list")
def list_cameras() -> Any:
    """
    Probe connected cameras using OpenCV VideoCapture.
    Returns a list of available camera devices.
    """
    available = []
    # Probe indices 0 to 9
    for index in range(10):
        cap = cv2.VideoCapture(index)
        if cap is not None and cap.isOpened():
            # Try to read camera properties
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
            # Stop probing after first gap (no camera found)
            if index > 0:
                break

    return {"cameras": available, "count": len(available)}
