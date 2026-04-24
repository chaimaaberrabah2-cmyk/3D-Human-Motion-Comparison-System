import sys
import os

# Ensure backend directory is in the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from dotenv import load_dotenv

from app.database.setup import engine, Base
from app.database.models import User, Movement, Performance

load_dotenv()

DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'ikram')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'motion_compare_db')

def create_database():
    """Create the database if it does not exist."""
    print("Connecting to PostgreSQL to check database existence...")
    try:
        # Connect to the default 'postgres' database to create the new one
        conn = psycopg2.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT,
            dbname="postgres"
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Check if database exists
        cursor.execute(f"SELECT 1 FROM pg_catalog.pg_database WHERE datname = '{DB_NAME}'")
        exists = cursor.fetchone()
        
        if not exists:
            print(f"Creating database '{DB_NAME}'...")
            cursor.execute(f"CREATE DATABASE {DB_NAME}")
            print("Database created successfully!")
        else:
            print(f"Database '{DB_NAME}' already exists.")
            
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error checking/creating database: {e}")
        # Proceed anyway as the user might have already created it manually
        
def create_tables():
    """Create all tables defined in SQLAlchemy models."""
    print("\nDropping old tables if they exist...")
    # Drop all tables so we get a clean slate based on new schema
    Base.metadata.drop_all(bind=engine)
    
    print("Creating new tables based on models (User, Movement, Performance)...")
    Base.metadata.create_all(bind=engine)
    print("Tables created successfully!")
    print("\n✅ Initialization complete. You can now view the tables in DBeaver/PostgreSQL.")

if __name__ == "__main__":
    create_database()
    create_tables()
