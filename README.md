# 3D Human Motion Comparison System

A PySide6-based desktop application for comparing human movements in 3D using SMPL-X models.

## Features

- 📊 Load and visualize 47 different exercise types from 8 subjects
- 🎥 Multi-view video support (4 camera angles)
- 🤖 SMPL-X 3D human body model integration
- 📈 Interactive 3D visualization with Plotly
- 💾 PostgreSQL database for efficient data management
- 🔍 Compare user movements with reference exercises
- ⚡ Optimized for Apple Silicon (M4 chip)

## Prerequisites

- Python 3.9+
- PostgreSQL 17.5
- macOS (optimized for M4 chip)

**OR**

- Docker Desktop (for containerized deployment)

## Quick Start with Docker 🐳

The easiest way to run the project is using Docker:

```bash
./deploy.sh
```

This will automatically:
- Set up PostgreSQL database
- Load all training data
- Start the application

For detailed Docker instructions, see [DOCKER.md](DOCKER.md).

## Manual Installation

### 1. Clone the repository

```bash
cd /Users/HP/Desktop/ikram/M2/PFE/3D-Human-Motion-Comparison-System
```

### 2. Run setup script

```bash
python setup.py
```

This will:
- Create a virtual environment
- Install all dependencies
- Create `.env` configuration file

### 3. Configure database credentials

Edit the `.env` file and set your PostgreSQL password:

```bash
DB_PASSWORD=your_actual_password
```

### 4. Activate virtual environment

```bash
source venv/bin/activate
```

### 5. Initialize database

```bash
python scripts/init_database.py
```

### 6. Load training data

```bash
python scripts/load_training_data.py
```

This will load:
- 8 subjects (s03-s11)
- 47 exercise types
- SMPL-X parameters for each subject/exercise
- 3D joints data
- Camera parameters for 4 views

## Project Structure

```
3D-Human-Motion-Comparison-System/
├── database/           # Database models and configuration
│   ├── schema.sql     # PostgreSQL schema
│   ├── models.py      # SQLAlchemy ORM models
│   └── db_config.py   # Database connection
├── smplx_utils/       # SMPL-X model utilities
├── ui/                # PySide6 user interface
├── scripts/           # Setup and data loading scripts
├── models/            # SMPL-X model files
│   └── smplx/        # MALE, FEMALE, NEUTRAL models
├── train/             # Training data (8 subjects × 47 exercises)
├── requirements.txt   # Python dependencies
├── setup.py          # Setup automation script
└── .env              # Environment configuration
```

## Usage

### Launch the application

```bash
python main.py
```

### View exercise data

1. Navigate to the "Viewer" tab
2. Select an exercise from the dropdown
3. Select a subject
4. Click "Load Exercise"
5. Use playback controls to view the 3D animation

### Compare movements

1. Upload your multi-view videos
2. Select a reference exercise
3. View side-by-side comparison
4. Review error feedback and suggestions

## Database Schema

- **subjects**: Subject metadata (s03-s11)
- **exercises**: 47 exercise types with categories
- **exercise_data**: SMPL-X parameters and 3D joints
- **camera_views**: Multi-view camera parameters
- **comparisons**: User comparison history

## Technologies

- **UI**: PySide6 (Qt for Python)
- **3D Visualization**: Plotly
- **Database**: PostgreSQL 17.5 + SQLAlchemy
- **SMPL-X**: PyTorch with MPS (Apple Silicon)
- **Video Processing**: OpenCV
- **Pose Estimation**: MediaPipe

## Development

### Run database tests

```bash
python -c "from database.db_config import test_connection; test_connection()"
```

### Query database

```bash
psql -U postgres -d motion_compare_db
```

## License

MIT License

## Author

Ikram - M2 PFE Project
