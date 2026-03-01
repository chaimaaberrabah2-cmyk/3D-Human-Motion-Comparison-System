# 📚 Stack Technologique - Motion AI

## 🎯 Vue d'Ensemble

| Composant | Technologie | Plateforme | Rôle |
|-----------|-------------|------------|------|
| **Frontend** | Flutter | Mobile, Web, Desktop | Interface utilisateur multi-plateforme |
| **Backend** | FastAPI (Python) | Serveur | API REST + Traitement IA |
| **Base de Données** | PostgreSQL 17 + JSONB | Serveur | Métadonnées + Données structurées |
| **Stockage Fichiers** | Filesystem | Serveur | Vidéos, Keypoints, SMPL-X |

---

## 📱 Frontend - Flutter (Multi-plateforme)

### Plateformes Supportées

| Plateforme | Status | Framework | Build Command |
|------------|--------|-----------|---------------|
| **📱 Mobile iOS** | ✅ Supporté | Flutter | `flutter build ios` |
| **📱 Mobile Android** | ✅ Supporté | Flutter | `flutter build apk` |
| **🌐 Web** | ✅ Supporté | Flutter Web | `flutter build web` |
| **💻 Desktop macOS** | ✅ Supporté | Flutter Desktop | `flutter build macos` |
| **💻 Desktop Windows** | ✅ Supporté | Flutter Desktop | `flutter build windows` |
| **💻 Desktop Linux** | ✅ Supporté | Flutter Desktop | `flutter build linux` |

### Technologies Frontend

| Catégorie | Package | Version | Utilisation |
|-----------|---------|---------|-------------|
| **Framework** | Flutter SDK | 3.0+ | Framework principal |
| **Langage** | Dart | 3.0+ | Langage de programmation |
| **State Management** | flutter_bloc | ^8.1.3 | Gestion d'état (BLoC pattern) |
| **State Management** | equatable | ^2.0.5 | Comparaison d'états |
| **Navigation** | go_router | ^13.0.0 | Routing multi-plateforme |
| **HTTP Client** | dio | ^5.4.0 | Requêtes API REST |
| **API Generation** | retrofit | ^4.0.3 | Client API type-safe |
| **Serialization** | json_annotation | ^4.8.1 | Sérialisation JSON |
| **Local Storage** | shared_preferences | ^2.2.2 | Préférences utilisateur |
| **Secure Storage** | flutter_secure_storage | ^9.0.0 | Stockage sécurisé (tokens) |
| **3D Rendering** | vector_math | ^2.1.4 | Calculs 3D |
| **Video Player** | video_player | ^2.8.2 | Lecture vidéo |
| **File Picker** | image_picker | ^1.0.7 | Sélection images |
| **File Picker** | file_picker | ^6.1.1 | Sélection fichiers |
| **Internationalization** | intl | ^0.18.1 | i18n |
| **Logging** | logger | ^2.0.2 | Logs debug |

---

## 🔧 Backend - FastAPI (Python)

### Technologies Backend

| Catégorie | Package | Version | Utilisation |
|-----------|---------|---------|-------------|
| **Framework** | FastAPI | Latest | Framework web API |
| **ASGI Server** | Uvicorn | Latest | Serveur ASGI |
| **Validation** | Pydantic | Latest | Validation données |
| **ORM** | SQLAlchemy | Latest | ORM PostgreSQL |
| **Database Driver** | psycopg2-binary | Latest | Driver PostgreSQL |
| **Migration** | Alembic | Latest | Migrations DB |
| **Auth - JWT** | python-jose | Latest | Tokens JWT |
| **Auth - Password** | passlib[bcrypt] | Latest | Hash mots de passe |
| **CORS** | fastapi.middleware.cors | Built-in | CORS pour Flutter Web |
| **File Upload** | python-multipart | Latest | Upload fichiers |
| **Video Processing** | opencv-python | Latest | Traitement vidéo |
| **Pose Estimation** | mediapipe | Latest | BlazePose 3D |
| **ML Framework** | torch | Latest | PyTorch (SMPL-X) |
| **3D Body Model** | smplx | Latest | Modèle SMPL-X |
| **Numerical** | numpy | Latest | Calculs numériques |
| **Environment** | python-dotenv | Latest | Variables d'environnement |

---

## 💾 Base de Données - PostgreSQL

### Configuration

| Composant | Technologie | Utilisation |
|-----------|-------------|-------------|
| **SGBD** | PostgreSQL 17 | Base de données principale |
| **Extension** | JSONB | Stockage flexible (SMPL-X, keypoints) |
| **Index** | GIN Index | Index sur colonnes JSONB |
| **ORM** | SQLAlchemy | Mapping objet-relationnel |
| **Pool** | SQLAlchemy Pool | Gestion connexions |

### Tables Principales

| Table | Type de Données | Stockage |
|-------|----------------|----------|
| **users** | Relationnel | PostgreSQL |
| **analyses** | Relationnel + JSONB | PostgreSQL (metadata) + Filesystem (vidéos) |
| **exercises** | Relationnel + JSONB | PostgreSQL |
| **exercise_data** | JSONB | PostgreSQL (SMPL-X params, keypoints) |
| **camera_views** | Relationnel | PostgreSQL |

---

## 📁 Stockage Fichiers - Filesystem

### Organisation

| Type de Fichier | Emplacement | Format | Taille Moyenne |
|----------------|-------------|--------|----------------|
| **Vidéos Référence** | `dataset/videos/reference/` | MP4 | 50-200 MB |
| **Vidéos Utilisateur** | `dataset/videos/user_uploads/` | MP4 | 10-100 MB |
| **Keypoints Référence** | `dataset/keypoints/reference/` | JSON | 1-5 MB |
| **Keypoints Utilisateur** | `dataset/keypoints/user_uploads/` | JSON | 500 KB - 2 MB |
| **SMPL-X Modèles** | `dataset/smpl/models/` | PKL, NPZ | 100-500 MB |
| **SMPL-X Référence** | `dataset/smpl/reference/` | JSON | 500 KB - 2 MB |
| **SMPL-X Utilisateur** | `dataset/smpl/user_uploads/` | JSON | 500 KB - 2 MB |

### Stratégie de Stockage

```
PostgreSQL (Métadonnées)          Filesystem (Fichiers)
├── video_id                      ├── video_file.mp4
├── file_path (référence)   ←────→├── /dataset/videos/user_123/video_456.mp4
├── file_size                     
├── duration                      
├── resolution                    
└── uploaded_at                   
```

---

## 🐳 Déploiement - Docker

### Containers

| Service | Image | Port | Utilisation |
|---------|-------|------|-------------|
| **PostgreSQL** | postgres:17 | 5432 | Base de données |
| **Backend API** | Custom (Python) | 8000 | API FastAPI |
| **Frontend Web** | Custom (Flutter) | 80 | Application Web |

### Docker Compose

```yaml
services:
  postgres:
    image: postgres:17
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./dataset:/dataset  # Montage filesystem
  
  backend:
    build: ./backend
    volumes:
      - ./dataset:/app/dataset  # Accès fichiers
    depends_on:
      - postgres
  
  frontend:
    build: ./frontend
    ports:
      - "80:80"
```

---

## 🎨 Architecture par Plateforme

### Mobile (iOS/Android)

| Composant | Technologie |
|-----------|-------------|
| **UI Framework** | Flutter |
| **State** | flutter_bloc |
| **HTTP** | dio + retrofit |
| **Storage** | flutter_secure_storage |
| **Video** | video_player |
| **Camera** | image_picker |
| **3D Rendering** | vector_math |

### Web

| Composant | Technologie |
|-----------|-------------|
| **UI Framework** | Flutter Web |
| **Rendering** | CanvasKit / HTML |
| **State** | flutter_bloc |
| **HTTP** | dio (web-compatible) |
| **Storage** | shared_preferences (web) |
| **Video** | video_player (web) |

### Desktop (macOS/Windows/Linux)

| Composant | Technologie |
|-----------|-------------|
| **UI Framework** | Flutter Desktop |
| **State** | flutter_bloc |
| **HTTP** | dio |
| **Storage** | flutter_secure_storage |
| **Video** | video_player |
| **File System** | file_picker |

---

## 🔄 Flux de Données Complet

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER (Multi-plateforme)               │
│  📱 iOS  |  🤖 Android  |  🌐 Web  |  💻 Desktop          │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP/REST (dio + retrofit)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND (Python)                 │
│  ├── API Routes (auth, analysis, exercises)                │
│  ├── Services (BlazePose, SMPL-X)                          │
│  └── Models (SQLAlchemy)                                   │
└────────┬────────────────────────────┬───────────────────────┘
         │                            │
         ↓                            ↓
┌────────────────────┐    ┌──────────────────────────────────┐
│   POSTGRESQL 17    │    │       FILESYSTEM                 │
│                    │    │                                  │
│  ├── users         │    │  ├── videos/                    │
│  ├── analyses ─────┼────┼──├── keypoints/                 │
│  ├── exercises     │    │  └── smpl/                      │
│  └── JSONB data    │    │                                  │
└────────────────────┘    └──────────────────────────────────┘
```

---

## 📊 Récapitulatif par Couche

### Couche Présentation (Frontend)
- **Framework** : Flutter 3.0+
- **Langage** : Dart 3.0+
- **Plateformes** : iOS, Android, Web, macOS, Windows, Linux

### Couche Application (Backend)
- **Framework** : FastAPI
- **Langage** : Python 3.9+
- **Serveur** : Uvicorn (ASGI)

### Couche Données
- **Base de Données** : PostgreSQL 17 + JSONB
- **Stockage Fichiers** : Filesystem (dataset/)
- **ORM** : SQLAlchemy

### Couche IA/ML
- **Pose Estimation** : MediaPipe BlazePose
- **3D Modeling** : SMPL-X + PyTorch
- **Video Processing** : OpenCV

### Couche Déploiement
- **PostgreSQL** : Installation locale ou serveur
- **Backend** : Uvicorn server
- **Frontend** : Build natif par plateforme

---

## 🚀 Commandes de Lancement

### Backend
```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend
```bash
cd frontend

# Mobile
flutter run  # iOS/Android

# Web
flutter run -d chrome

# Desktop
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```

---

## 📝 Notes Importantes

1. **PostgreSQL** stocke uniquement les **métadonnées** des vidéos (chemin, taille, durée)
2. **Filesystem** stocke les **fichiers réels** (vidéos, keypoints, SMPL-X)
3. **Flutter** compile en **natif** pour chaque plateforme (pas de WebView)
4. **FastAPI** génère automatiquement la **documentation Swagger** à `/docs`
5. **JSONB** permet de stocker des données **flexibles** sans schéma fixe
