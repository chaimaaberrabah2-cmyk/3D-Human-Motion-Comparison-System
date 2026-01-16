"""Initialize PostgreSQL database and create tables."""

import sys
import os
import subprocess

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database.db_config import DATABASE_URL, DB_NAME, DB_USER, DB_HOST, DB_PORT, test_connection
from dotenv import load_dotenv

load_dotenv()


def create_database():
    """Create the PostgreSQL database if it doesn't exist."""
    print(f"🔧 Creating database '{DB_NAME}'...")
    
    # Connect to default 'postgres' database to create our database
    create_db_cmd = f"""
    psql -h {DB_HOST} -p {DB_PORT} -U {DB_USER} -d postgres -c "CREATE DATABASE {DB_NAME};" 2>/dev/null || echo "Database may already exist"
    """
    
    try:
        result = subprocess.run(create_db_cmd, shell=True, capture_output=True, text=True)
        if "already exists" in result.stderr or "Database may already exist" in result.stdout:
            print(f"   ℹ️  Database '{DB_NAME}' already exists")
        else:
            print(f"   ✅ Database '{DB_NAME}' created successfully")
    except Exception as e:
        print(f"   ⚠️  Note: {e}")
        print(f"   You may need to create the database manually:")
        print(f"   psql -U {DB_USER} -c 'CREATE DATABASE {DB_NAME};'")


def create_schema():
    """Create database schema from SQL file."""
    print(f"\n📋 Creating database schema...")
    
    schema_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'database', 'schema.sql')
    
    if not os.path.exists(schema_file):
        print(f"   ❌ Schema file not found: {schema_file}")
        return False
    
    create_schema_cmd = f"psql -h {DB_HOST} -p {DB_PORT} -U {DB_USER} -d {DB_NAME} -f {schema_file}"
    
    try:
        result = subprocess.run(create_schema_cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"   ✅ Schema created successfully")
            return True
        else:
            print(f"   ❌ Error creating schema:")
            print(f"   {result.stderr}")
            return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False


def main():
    """Main initialization function."""
    print("=" * 60)
    print("  3D Human Motion Comparison System - Database Setup")
    print("=" * 60)
    
    # Test connection first
    print("\n🔌 Testing database connection...")
    if not test_connection():
        print("\n❌ Cannot connect to PostgreSQL server.")
        print("   Please ensure PostgreSQL is running and credentials are correct.")
        print(f"   Connection string: postgresql://{DB_USER}:***@{DB_HOST}:{DB_PORT}")
        sys.exit(1)
    
    # Create database
    create_database()
    
    # Create schema
    if not create_schema():
        print("\n❌ Schema creation failed.")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("  ✅ Database initialization complete!")
    print("=" * 60)
    print(f"\nDatabase: {DB_NAME}")
    print(f"Host: {DB_HOST}:{DB_PORT}")
    print(f"\nNext step: Run 'python scripts/load_training_data.py' to load exercise data")


if __name__ == "__main__":
    main()
