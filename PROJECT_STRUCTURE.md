# 📁 Structure du Projet - Motion AI

## 🏗️ Architecture Globale

```
3D-Human-Motion-Comparison-System/
│
├── 📱 frontend/                    # Flutter Multi-plateforme
├── 🔧 backend/                     # FastAPI Python
├── 💾 dataset/                     # Stockage Filesystem
├──  docs/                        # Documentation
├── 📝 README.md
├── 📊 TECH_STACK.md
└── 📁 PROJECT_STRUCTURE.md (ce fichier)
```

---

## 📱 Frontend (Flutter) - Multi-plateforme

```
frontend/
│
├── lib/
│   ├── main.dart                   # Point d'entrée
│   │
│   ├── features/                   # Organisation par fonctionnalités
│   │   │
│   │   ├── starting/               # 🚪 Page de démarrage
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── starting_page.dart
│   │   │   │   └── widgets/
│   │   │   ├── domain/
│   │   │   └── data/
│   │   │
│   │   ├── auth/                   # 🔐 Authentification
│   │   │   ├── signin/
│   │   │   │   ├── presentation/
│   │   │   │   │   ├── pages/signin_page.dart
│   │   │   │   │   ├── widgets/
│   │   │   │   │   └── bloc/
│   │   │   │   ├── domain/
│   │   │   │   │   ├── entities/user.dart
│   │   │   │   │   ├── repositories/auth_repository.dart
│   │   │   │   │   └── usecases/login_user.dart
│   │   │   │   └── data/
│   │   │   │       ├── models/user_model.dart
│   │   │   │       ├── repositories/auth_repository_impl.dart
│   │   │   │       └── datasources/auth_remote_datasource.dart
│   │   │   │
│   │   │   ├── signup/
│   │   │   │   └── [même structure que signin]
│   │   │   │
│   │   │   └── forget_password/
│   │   │       └── [même structure]
│   │   │
│   │   ├── home/                   # 🏠 Dashboard
│   │   │   ├── presentation/
│   │   │   │   ├── pages/home_page.dart
│   │   │   │   ├── widgets/
│   │   │   │   │   ├── analysis_card.dart
│   │   │   │   │   └── exercise_list.dart
│   │   │   │   └── bloc/
│   │   │   ├── domain/
│   │   │   └── data/
│   │   │
│   │   ├── analysis/               # 🎯 Analyse de mouvement (CORE)
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── new_analysis_page.dart
│   │   │   │   │   └── analysis_result_page.dart
│   │   │   │   ├── widgets/
│   │   │   │   │   ├── video_upload_widget.dart
│   │   │   │   │   ├── model_3d_viewer.dart
│   │   │   │   │   └── comparison_chart.dart
│   │   │   │   └── bloc/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── analysis.dart
│   │   │   │   │   └── comparison_result.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── analysis_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── upload_video.dart
│   │   │   │       ├── get_analysis_result.dart
│   │   │   │       └── compare_movements.dart
│   │   │   └── data/
│   │   │       ├── models/
│   │   │       ├── repositories/
│   │   │       └── datasources/
│   │   │
│   │   └── settings/               # ⚙️ Paramètres
│   │       ├── presentation/
│   │       ├── domain/
│   │       └── data/
│   │
│   └── core/                       # 🔧 Utilitaires partagés
│       ├── theme/
│       │   ├── app_theme.dart
│       │   └── app_colors.dart
│       ├── network/
│       │   ├── api_client.dart      # Configuration Dio
│       │   └── endpoints.dart       # URLs API
│       ├── utils/
│       │   ├── validators.dart
│       │   └── constants.dart
│       └── widgets/
│           ├── custom_button.dart
│           └── loading_indicator.dart
│
├── assets/                         # Ressources
│   ├── images/
│   │   └── network_bg.png
│   └── icons/
│
├── web/                            # 🌐 Configuration Web
│   ├── index.html
│   └── manifest.json
│
├── ios/                            # 📱 Configuration iOS
│   └── Runner/
│
├── android/                        # 🤖 Configuration Android
│   └── app/
│
├── macos/                          # 💻 Configuration macOS
│   └── Runner/
│
├── windows/                        # 💻 Configuration Windows
│   └── runner/
│
├── linux/                          # 💻 Configuration Linux
│   └── runner/
│
├── test/                           # Tests
│   └── widget_test.dart
│
├── pubspec.yaml                    # Dépendances Flutter
├── analysis_options.yaml
└── README.md
```

---

## 🔧 Backend (FastAPI Python)

```
backend/
│
├── app/
│   ├── __init__.py
│   ├── main.py                     # Point d'entrée FastAPI
│   │
│   ├── api/                        # 📡 Routes API REST
│   │   ├── __init__.py
│   │   ├── auth.py                 # POST /api/auth/signup, /login, /forgot-password
│   │   ├── analysis.py             # POST /api/analysis/upload, GET /api/analysis/{id}
│   │   └── exercises.py            # GET /api/exercises/, GET /api/exercises/{id}
│   │
│   ├── models/                     # 🗄️ Modèles SQLAlchemy
│   │   ├── __init__.py
│   │   ├── user.py                 # Table users
│   │   ├── analysis.py             # Table analyses (avec file_path vers filesystem)
│   │   ├── exercise.py             # Table exercises
│   │   └── models.py               # Autres modèles (Subject, ExerciseData, etc.)
│   │
│   ├── schemas/                    # ✅ Schémas Pydantic
│   │   ├── __init__.py
│   │   ├── auth.py                 # UserCreate, UserLogin, Token, UserResponse
│   │   ├── analysis.py             # AnalysisCreate, AnalysisResponse, VideoUpload
│   │   └── exercise.py             # ExerciseResponse
│   │
│   ├── services/                   # ⚙️ Logique métier
│   │   ├── __init__.py
│   │   ├── auth_service.py         # Hash password, JWT tokens
│   │   ├── video_service.py        # Sauvegarde vidéos sur filesystem
│   │   ├── video_processor.py      # BlazePose extraction
│   │   └── smplx_service.py        # SMPL-X fitting
│   │
│   ├── core/                       # 🔐 Configuration
│   │   ├── __init__.py
│   │   ├── config.py               # Variables d'environnement
│   │   └── security.py             # JWT, password hashing
│   │
│   └── db/                         # 🔌 Base de données
│       ├── __init__.py
│       ├── db_config.py            # SQLAlchemy engine, session
│       └── schema.sql              # Schéma SQL (backup)
│
├── scripts/                        # 🛠️ Scripts utilitaires
│   ├── __init__.py
│   ├── init_database.py            # Créer la DB
│   └── load_training_data.py       # Charger données de référence
│
├── smplx_utils/                    # 🎭 Utilitaires SMPL-X
│   ├── __init__.py
│   └── smpl_adapter.py
│
│
├── docs/                           # 📚 Documentation technique
│   ├── justifications_techniques.md
│   ├── resume_executif.md
│   └── tableaux_comparatifs.md
│
├── requirements.txt                # Dépendances Python
├── requirements-minimal.txt
├── .env                            # Variables d'environnement
└── README.md
```

---

## 💾 Dataset (Filesystem) - Stockage Fichiers

```
dataset/
│
├── videos/                         # 🎥 Vidéos MP4
│   ├── reference/                  # Vidéos d'entraînement
│   │   ├── s03/
│   │   │   ├── squat.mp4
│   │   │   ├── pushup.mp4
│   │   │   └── ... (47 exercices)
│   │   ├── s04/
│   │   ├── s05/
│   │   ├── s07/
│   │   ├── s08/
│   │   ├── s09/
│   │   ├── s10/
│   │   └── s11/
│   │
│   └── user_uploads/               # Vidéos utilisateurs
│       ├── user_1/
│       │   ├── analysis_123/
│       │   │   ├── camera_1.mp4
│       │   │   ├── camera_2.mp4
│       │   │   ├── camera_3.mp4
│       │   │   └── camera_4.mp4
│       │   └── analysis_124/
│       └── user_2/
│
├── keypoints/                      # 📍 Keypoints 3D (BlazePose)
│   ├── reference/                  # Keypoints de référence
│   │   ├── s03_squat.json
│   │   ├── s03_pushup.json
│   │   └── ...
│   │
│   └── user_uploads/               # Keypoints utilisateurs
│       ├── analysis_123.json
│       └── analysis_124.json
│
└── smpl/                           # 🎭 SMPL-X
    ├── models/                     # Modèles SMPL-X
    │   ├── SMPLX_MALE.pkl
    │   ├── SMPLX_FEMALE.pkl
    │   └── SMPLX_NEUTRAL.pkl
    │
    ├── reference/                  # Paramètres SMPL-X de référence
    │   ├── s03_squat_smplx.json
    │   ├── s03_pushup_smplx.json
    │   └── ...
    │
    └── user_uploads/               # Paramètres SMPL-X utilisateurs
        ├── analysis_123_smplx.json
        └── analysis_124_smplx.json
```

---

## 🗄️ Structure PostgreSQL

### Tables Principales

```sql
-- Utilisateurs
users (
    id, email, username, password_hash, 
    created_at, last_login
)

-- Analyses (métadonnées seulement)
analyses (
    id, user_id, exercise_id,
    video_path,              -- Chemin vers dataset/videos/user_uploads/
    keypoints_path,          -- Chemin vers dataset/keypoints/user_uploads/
    smplx_path,              -- Chemin vers dataset/smpl/user_uploads/
    file_size, duration, resolution, fps,
    similarity_score, comparison_results (JSONB),
    status, created_at, completed_at
)

-- Exercices de référence
exercises (
    id, name, category, description,
    reference_video_path,    -- Chemin vers dataset/videos/reference/
    reference_keypoints_path,
    reference_smplx_path
)

-- Données d'exercices (JSONB pour flexibilité)
exercise_data (
    id, subject_id, exercise_id,
    smplx_params (JSONB),    -- Paramètres SMPL-X complets
    joints_3d (JSONB),       -- Keypoints 3D
    camera_views (JSONB)
)
```

---

## 🔄 Flux de Données - Upload Vidéo

```
1. Frontend (Flutter)
   └── user_uploads_video.mp4
       │
       ↓ POST /api/analysis/upload (multipart/form-data)
       │
2. Backend (FastAPI)
   ├── api/analysis.py
   │   └── Reçoit le fichier
   │
   ├── services/video_service.py
   │   ├── Sauvegarde → dataset/videos/user_uploads/user_123/video_456.mp4
   │   └── Retourne file_path
   │
   ├── services/video_processor.py
   │   ├── BlazePose extraction
   │   └── Sauvegarde → dataset/keypoints/user_uploads/analysis_456.json
   │
   ├── services/smplx_service.py
   │   ├── SMPL-X fitting
   │   └── Sauvegarde → dataset/smpl/user_uploads/analysis_456_smplx.json
   │
   └── models/analysis.py
       └── INSERT INTO analyses (
           user_id, 
           video_path = 'user_uploads/user_123/video_456.mp4',
           keypoints_path = 'user_uploads/analysis_456.json',
           smplx_path = 'user_uploads/analysis_456_smplx.json',
           file_size, duration, ...
       )
       │
       ↓ Retourne analysis_id
       │
3. Frontend (Flutter)
   └── GET /api/analysis/456
       ├── Récupère métadonnées (PostgreSQL)
       ├── Charge SMPL-X params (filesystem)
       └── Affiche modèle 3D
```

---

##  Résumé des Responsabilités

| Composant | Stocke | Ne Stocke Pas |
|-----------|--------|---------------|
| **PostgreSQL** | Métadonnées (id, paths, sizes, dates) | Fichiers vidéo/JSON |
| **Filesystem** | Fichiers réels (MP4, JSON) | Métadonnées structurées |
| **Flutter** | Cache local temporaire | Données persistantes |
| **FastAPI** | Rien (stateless) | Tout est en DB ou filesystem |

---

## 🚀 Avantages de cette Architecture

1. ✅ **Séparation des préoccupations** : Métadonnées vs Fichiers
2. ✅ **Performance** : PostgreSQL rapide pour queries, filesystem pour streaming
3. ✅ **Scalabilité** : Facile de migrer vers cloud storage plus tard
4. ✅ **Backup** : DB et fichiers séparés
5. ✅ **Multi-plateforme** : Flutter compile natif pour toutes les plateformes
6. ✅ **Type-safe** : Pydantic (backend) + Dart (frontend)
7. ✅ **Simple** : Pas de containerisation complexe, installation directe
