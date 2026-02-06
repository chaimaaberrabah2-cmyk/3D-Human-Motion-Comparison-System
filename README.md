# 3D Human Motion Comparison System

A multi-platform application for comparing human motion in 3D using SMPL-X models, built with **Flutter** (frontend) and **FastAPI** (backend).

## 🏗️ Architecture

This project follows **Clean Architecture** principles with clear separation between frontend and backend:

- **Frontend**: Flutter (Mobile, Web, Desktop)
- **Backend**: Python FastAPI
- **Database**: PostgreSQL + JSONB
- **Storage**: Organized dataset for videos, keypoints, and SMPL data

## 📁 Project Structure

See [STRUCTURE.md](STRUCTURE.md) for the complete folder organization.

```
├── backend/          # Python FastAPI backend
│   ├── app/         # Main application
│   │   ├── api/     # REST endpoints
│   │   ├── models/  # Database models
│   │   ├── services/# Business logic
│   │   └── ...
│   └── ...
│
├── frontend/        # Flutter multi-platform app
│   └── lib/
│       ├── features/# Feature-based modules
│       │   ├── starting/
│       │   ├── auth/ (signin, signup, forget_password)
│       │   ├── home/
│       │   ├── analysis/
│       │   └── settings/
│       └── core/    # Shared utilities
│
└── dataset/         # Data storage
    ├── videos/      # MP4 files
    ├── keypoints/   # 3D pose data
    └── smpl/        # SMPL-X parameters
```

## ✨ Features

### Authentication
- ✅ User signup and login
- ✅ Password recovery
- ✅ JWT token-based auth

### Motion Analysis
- 📹 Multi-view video upload
- 🤖 BlazePose 3D pose estimation
- 🎭 SMPL-X model fitting
- 📊 Motion comparison with reference exercises
- 📈 Similarity scoring

### Multi-Platform Support
- 📱 iOS & Android (Mobile)
- 🌐 Web (Progressive Web App)
- 💻 Windows, macOS, Linux (Desktop)

## 🗄️ Database: PostgreSQL + JSONB

**Why PostgreSQL?**
- ✅ Relational structure for users and relationships
- ✅ JSONB for flexible SMPL-X and keypoint storage
- ✅ High performance with GIN indexes
- ✅ ACID compliance

**Main Tables:**
- `users` - Authentication and profiles
- `analyses` - User motion analysis results
- `exercises` - Reference exercise library
- `exercise_data` - SMPL-X parameters and keypoints

## 🚀 Getting Started

### Prerequisites
- Python 3.9+
- Flutter 3.0+
- PostgreSQL 17+

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Initialize database
python scripts/init_database.py

# Run server
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run  # For mobile/desktop
flutter run -d chrome  # For web
```

## 📚 Documentation

- [Complete Structure](STRUCTURE.md) - Detailed folder organization
- [Technical Justifications](backend/docs/justifications_techniques.md) - Architecture decisions
- [API Documentation](http://localhost:8000/docs) - Swagger UI (when running)

## 🛠️ Technology Stack

### Backend
- **FastAPI** - Modern Python web framework
- **SQLAlchemy** - ORM for PostgreSQL
- **Pydantic** - Data validation
- **BlazePose** - 3D pose estimation
- **PyTorch** - SMPL-X model fitting

### Frontend
- **Flutter** - Cross-platform UI framework
- **flutter_bloc** - State management
- **dio** - HTTP client
- **flutter_gl** - 3D visualization
- **go_router** - Navigation

### Database
- **PostgreSQL 17** - Main database
- **JSONB** - Flexible JSON storage

## 📖 Development Guide

### Adding a New Feature (Frontend)

1. Create feature folder: `frontend/lib/features/my_feature/`
2. Add layers: `presentation/`, `domain/`, `data/`
3. Implement pages in `presentation/pages/`
4. Add widgets in `presentation/widgets/`

### Adding a New API Endpoint (Backend)

1. Create route in `backend/app/api/`
2. Add schema in `backend/app/schemas/`
3. Implement service in `backend/app/services/`
4. Update model if needed in `backend/app/models/`

## 📝 License

This project is part of a Master's thesis (M2 PFE).

## 👤 Author

**Ikram** - M2 PFE Project  
January 2026
