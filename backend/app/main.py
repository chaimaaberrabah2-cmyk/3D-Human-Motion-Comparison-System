"""
backend/app/main.py
===================
This is the ENTRY POINT of the Python FastAPI backend server.

Responsibilities:
- Creates the FastAPI application instance with a title and version.
- Configures CORS (Cross-Origin Resource Sharing) middleware so that the
  Flutter frontend (running on a different port) is allowed to make HTTP
  requests to this server without being blocked by browser security.
- Registers all API endpoint 'routers' — currently only the 'analysis' router,
  which handles video upload and processing requests.
- Provides a simple root endpoint (GET /) to confirm the server is running.

To start this server, run from the 'backend' directory:
    uvicorn app.main:app --reload
The API will be available at http://127.0.0.1:8000
Interactive documentation: http://127.0.0.1:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import analysis, auth, cameras, sessions, movements
from app.database.setup import engine, SessionLocal
from app.database.models import Movement
from sqlalchemy import text

# Auto-migrate DB (Added for barbell equipment)
try:
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE movements ADD COLUMN IF NOT EXISTS equipment VARCHAR(100);"))
        conn.execute(text("ALTER TABLE movements ADD COLUMN IF NOT EXISTS equipment_orientation JSONB;"))
    db = SessionLocal()
    deadlift = db.query(Movement).filter(Movement.name == 'deadlift').first()
    if deadlift:
        deadlift.equipment = 'barbell'
        deadlift.equipment_orientation = {
            "ax": 0.00, "ay": 0.00, "az": 0.00, 
            "bx": 0.02, "by": -0.07, "bz": -0.10
        }
        db.commit()
    db.close()
except Exception as e:
    print(f"DB Migration error: {e}")


# Create the main FastAPI application
app = FastAPI(
    title="Motion AI API",
    description="Backend API for 3D Human Motion Comparison System",
    version="1.0.0"
)

# Configure CORS — this allows the Flutter frontend to communicate with
# this server even though they run on different ports locally.
# In production, replace "*" with the actual frontend domain for security.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register the analysis router under the /api/v1/analysis path prefix.
# All endpoints defined in analysis.py will be accessible via this prefix.
app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["analysis"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(cameras.router, prefix="/api/v1/cameras", tags=["cameras"])
app.include_router(sessions.router, prefix="/api/v1/sessions", tags=["sessions"])
app.include_router(movements.router, prefix="/api/v1/movements", tags=["movements"])

@app.get("/")
async def root():
    """Health check endpoint — confirms the server is running."""
    return {"message": "Welcome to Motion AI API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
