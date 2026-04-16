import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.db_config import engine
from sqlalchemy import text

def migrate():
    with engine.connect() as conn:
        print("🔍 Checking and migrating 'users' table...")
        
        # Add 'role' column
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'user'"))
            conn.commit()
            print("✅ Added 'role' column to 'users'")
        except Exception as e:
            conn.rollback()
            if "already exists" in str(e):
                print("ℹ️ 'role' column already exists.")
            else:
                print(f"❌ Error adding 'role': {e}")
            
        # Add 'establishment_id' column
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN establishment_id INTEGER REFERENCES establishments(establishment_id) ON DELETE SET NULL"))
            conn.commit()
            print("✅ Added 'establishment_id' column to 'users'")
        except Exception as e:
            conn.rollback()
            if "already exists" in str(e):
                print("ℹ️ 'establishment_id' column already exists.")
            else:
                print(f"❌ Error adding 'establishment_id': {e}")
            
        print("🚀 Migration complete.")

if __name__ == "__main__":
    migrate()
