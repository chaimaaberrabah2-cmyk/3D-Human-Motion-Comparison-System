import os
import sys

# Set working directory to backend so imports work
os.chdir('/Volumes/SSD_Ikram/3D-Human-Motion-Comparison-System/backend')
sys.path.append('/Volumes/SSD_Ikram/3D-Human-Motion-Comparison-System/backend')

from app.database.setup import engine, SessionLocal
from app.database.models import Movement
from sqlalchemy import text

# Alter table to add columns
with engine.begin() as conn:
    try:
        conn.execute(text("ALTER TABLE movements ADD COLUMN IF NOT EXISTS equipment VARCHAR(100);"))
        conn.execute(text("ALTER TABLE movements ADD COLUMN IF NOT EXISTS equipment_orientation JSONB;"))
    except Exception as e:
        print("Alter table error:", e)

# Update the deadlift entry
db = SessionLocal()
try:
    deadlift = db.query(Movement).filter(Movement.name == 'deadlift').first()
    if deadlift:
        deadlift.equipment = 'barbell'
        deadlift.equipment_orientation = {
            "ax": 0.00, "ay": 1.48, "az": 0.00, 
            "bx": 0.02, "by": -0.07, "bz": -0.10
        }
        db.commit()
        print("Deadlift record successfully updated in PostgreSQL!")
    else:
        print("Deadlift movement not found in DB.")
finally:
    db.close()
