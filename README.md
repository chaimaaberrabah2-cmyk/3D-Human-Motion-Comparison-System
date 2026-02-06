# 🎯 Motion AI - 3D Human Motion Comparison System

> **Advanced 3D Human Motion Analysis** using Deep Learning, SMPL-X, and Multi-platform Flutter Interface

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Latest-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-336791?logo=postgresql)](https://www.postgresql.org)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://www.python.org)

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Documentation](#-documentation)
- [Contributing](#-contributing)

---

## 🌟 Overview

**Motion AI** is a cutting-edge 3D human motion comparison system that analyzes, compares, and provides feedback on human movements using:

- **BlazePose** for 3D pose estimation from video
- **SMPL-X** for accurate 3D human body modeling
- **Deep Learning** for motion analysis and comparison
- **Flutter** for cross-platform UI (Mobile, Web, Desktop)
- **FastAPI** for high-performance backend API

### 🎯 Use Cases

- 🏋️ **Fitness & Sports**: Compare user movements with professional athletes
- 🩺 **Physical Therapy**: Track rehabilitation progress
- 🎭 **Animation**: Motion capture and analysis
- 🎓 **Education**: Learn proper exercise techniques

---

## ✨ Features

### 🎥 Video Analysis
- Multi-view video upload support
- Real-time 3D pose estimation with BlazePose
- Frame-by-frame motion tracking

### 🎭 3D Reconstruction
- SMPL-X body model fitting
- Accurate skeletal reconstruction
- 3D visualization of movements

### 📊 Comparative Analytics
- Compare user movements against reference exercises
- Similarity scoring and error detection
- Detailed feedback on posture and technique

### 📱 Multi-Platform Support
- **Mobile**: iOS & Android native apps
- **Web**: Progressive Web App (PWA)
- **Desktop**: macOS, Windows, Linux

### 🔐 User Management
- Secure authentication (JWT)
- User profiles and history
- Progress tracking

---

## 🏗️ Architecture

This project follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│         PRESENTATION (Flutter UI)           │
│  ┌───────────────────────────────────────┐  │
│  │    DOMAIN (Business Logic)            │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │   DATA (API, Database)          │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Key Architectural Decisions

- **Frontend**: Flutter with BLoC pattern for state management
- **Backend**: FastAPI for REST API with async support
- **Database**: PostgreSQL for metadata + Filesystem for video storage
- **3D Processing**: BlazePose + SMPL-X pipeline

� **Learn more**: [Clean Architecture Guide](CLEAN_ARCHITECTURE_GUIDE.md)

---

## 🛠️ Tech Stack

### Frontend (Flutter)

| Category | Technology | Purpose |
|----------|------------|---------|
| **Framework** | Flutter 3.0+ | Multi-platform UI |
| **Language** | Dart 3.0+ | Programming language |
| **State Management** | flutter_bloc | BLoC pattern |
| **HTTP Client** | dio + retrofit | API communication |
| **3D Rendering** | vector_math | 3D calculations |
| **Video Player** | video_player | Video playback |

### Backend (Python)

| Category | Technology | Purpose |
|----------|------------|---------|
| **Framework** | FastAPI | REST API |
| **Server** | Uvicorn | ASGI server |
| **ORM** | SQLAlchemy | Database ORM |
| **Database** | PostgreSQL 17 | Metadata storage |
| **Pose Estimation** | MediaPipe BlazePose | 3D keypoint extraction |
| **3D Modeling** | SMPL-X + PyTorch | Body model fitting |
| **Video Processing** | OpenCV | Video manipulation |

### Storage

- **PostgreSQL**: User data, analysis metadata, exercise references
- **Filesystem**: Videos (MP4), Keypoints (JSON), SMPL-X parameters (JSON)

📊 **Full details**: [Tech Stack Documentation](TECH_STACK.md)

---

## 📁 Project Structure

```
3D-Human-Motion-Comparison-System/
│
├── frontend/                    # Flutter Multi-platform App
│   ├── lib/
│   │   ├── features/           # Feature-based organization
│   │   │   ├── starting/       # Welcome page
│   │   │   ├── auth/           # Authentication (signin, signup)
│   │   │   ├── home/           # Dashboard
│   │   │   ├── analysis/       # Motion analysis (core feature)
│   │   │   └── settings/       # User settings
│   │   └── core/               # Shared utilities
│   ├── assets/                 # Images, icons
│   └── [platform configs]      # web/, ios/, android/, macos/, etc.
│
├── backend/                     # FastAPI Python Backend
│   ├── app/
│   │   ├── api/                # REST API routes
│   │   ├── models/             # SQLAlchemy models
│   │   ├── schemas/            # Pydantic schemas
│   │   ├── services/           # Business logic
│   │   ├── core/               # Config & security
│   │   └── db/                 # Database setup
│   ├── scripts/                # Utility scripts
│   └── smplx_utils/            # SMPL-X helpers
│
├── dataset/                     # Filesystem Storage
│   ├── videos/                 # MP4 files
│   │   ├── reference/          # Training data
│   │   └── user_uploads/       # User videos
│   ├── keypoints/              # 3D keypoints (JSON)
│   └── smpl/                   # SMPL-X data (JSON)
│
├── docs/                        # Documentation
│
├── README.md                    # This file
├── TECH_STACK.md               # Detailed tech stack
├── PROJECT_STRUCTURE.md        # Detailed folder structure
└── CLEAN_ARCHITECTURE_GUIDE.md # Clean Architecture explained
```

📁 **Detailed structure**: [Project Structure Documentation](PROJECT_STRUCTURE.md)

---

## 🚀 Getting Started

### Prerequisites

- **Python** 3.9+
- **Flutter** 3.0+
- **PostgreSQL** 17+
- **Git**



## 📚 Documentation

| Document | Description |
|----------|-------------|
| [TECH_STACK.md](TECH_STACK.md) | Complete technology stack with tables for all platforms |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | Detailed folder organization and data flow |
| [CLEAN_ARCHITECTURE_GUIDE.md](CLEAN_ARCHITECTURE_GUIDE.md) | Clean Architecture principles explained with examples |



---


## � License

This project is part of a Master's thesis (PFE) at [Your University].

---

## � Authors

- **Ikram** - *Lead Developer* - [GitHub Profile](https://github.com/ikramtlh)

---

## 🙏 Acknowledgments

- **MediaPipe** for BlazePose
- **SMPL-X** team for the body model
- **Flutter** and **FastAPI** communities
- Academic advisors and contributors

---

## 📞 Contact

For questions or collaboration:
- **Email**: talhaoui.ikram03@gmail.com
- **GitHub Issues**: [Create an issue](https://github.com/yourusername/3D-Human-Motion-Comparison-System/issues)

---

<div align="center">

**Made with ❤️ using Flutter, and Deep Learning**

[⬆ Back to Top](#-motion-ai---3d-human-motion-comparison-system)

</div>
