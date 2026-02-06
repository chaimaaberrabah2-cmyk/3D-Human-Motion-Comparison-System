"""Setup script to create .env file and virtual environment."""

import os
import shutil
import subprocess
import sys


def create_env_file():
    """Create .env file from .env.example if it doesn't exist."""
    if os.path.exists('.env'):
        print("✅ .env file already exists")
        return
    
    if not os.path.exists('.env.example'):
        print("❌ .env.example not found")
        return
    
    shutil.copy('.env.example', '.env')
    print("✅ Created .env file from .env.example")
    print("⚠️  Please edit .env and set your PostgreSQL password!")


def create_venv():
    """Create Python virtual environment."""
    if os.path.exists('venv'):
        print("✅ Virtual environment already exists")
        return
    
    print("🔧 Creating virtual environment...")
    subprocess.run([sys.executable, '-m', 'venv', 'venv'])
    print("✅ Virtual environment created")


def install_requirements():
    """Install Python requirements."""
    print("\n📦 Installing Python packages...")
    
    # Determine pip path
    if os.name == 'nt':  # Windows
        pip_path = 'venv\\Scripts\\pip'
    else:  # Unix/Mac
        pip_path = 'venv/bin/pip'
    
    subprocess.run([pip_path, 'install', '--upgrade', 'pip'])
    subprocess.run([pip_path, 'install', '-r', 'requirements.txt'])
    print("✅ Packages installed")


def main():
    """Main setup function."""
    print("=" * 60)
    print("  3D Human Motion Comparison System - Setup")
    print("=" * 60)
    
    # Create .env file
    print("\n1️⃣  Setting up environment configuration...")
    create_env_file()
    
    # Create virtual environment
    print("\n2️⃣  Setting up Python virtual environment...")
    create_venv()
    
    # Install requirements
    print("\n3️⃣  Installing dependencies...")
    install_requirements()
    
    print("\n" + "=" * 60)
    print("  ✅ Setup complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("  1. Edit .env file and set your PostgreSQL password")
    print("  2. Activate virtual environment:")
    if os.name == 'nt':
        print("     venv\\Scripts\\activate")
    else:
        print("     source venv/bin/activate")
    print("  3. Initialize database:")
    print("     python scripts/init_database.py")
    print("  4. Load training data:")
    print("     python scripts/load_training_data.py")


if __name__ == "__main__":
    main()
