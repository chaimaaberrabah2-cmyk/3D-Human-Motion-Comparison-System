import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database.setup import engine
from sqlalchemy import text

def migrate():
    with engine.connect() as conn:
        print("🔍 Checking and migrating 'establishments' table...")
        
        # Add 'calibration_data' column
        try:
            conn.execute(text("ALTER TABLE establishments ADD COLUMN calibration_data JSONB"))
            conn.commit()
            print("✅ Added 'calibration_data' column to 'establishments'")
        except Exception as e:
            conn.rollback()
            if "already exists" in str(e):
                print("ℹ️ 'calibration_data' column already exists.")
            else:
                print(f"❌ Error adding 'calibration_data': {e}")
            
        print("🚀 Migration complete.")

if __name__ == "__main__":
    migrate()
