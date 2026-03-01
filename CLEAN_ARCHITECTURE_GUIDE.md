# 🏗️ Clean Architecture - Guide Complet

## 🎯 C'est Quoi Clean Architecture ?

**Clean Architecture** est une façon d'organiser ton code pour qu'il soit :
- ✅ **Testable** : Facile à tester
- ✅ **Maintenable** : Facile à modifier
- ✅ **Indépendant** : Pas dépendant d'un framework ou DB spécifique
- ✅ **Scalable** : Facile à agrandir

### 🔄 Principe de Base : Les Cercles

```
┌─────────────────────────────────────────────┐
│         PRESENTATION (UI)                   │  ← Ce que l'utilisateur voit
│  ┌───────────────────────────────────────┐  │
│  │         DOMAIN (Business Logic)       │  │  ← Règles métier
│  │  ┌─────────────────────────────────┐  │  │
│  │  │      DATA (Sources)             │  │  │  ← Accès aux données
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘

Règle d'Or : Les dépendances vont TOUJOURS vers l'intérieur
```

---

## 📦 Les 3 Couches Principales

### 1️⃣ **PRESENTATION** (Interface Utilisateur)

**C'est quoi ?** Tout ce que l'utilisateur voit et touche.

**Contient :**
- `pages/` : Les écrans de l'app
- `widgets/` : Les composants UI réutilisables
- `bloc/` ou `cubit/` : Gestion d'état (BLoC pattern)

**Exemple concret :**
```dart
// signin_page.dart (PRESENTATION)
class SigninPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(), // Email input
          TextField(), // Password input
          ElevatedButton(
            onPressed: () {
              // Appelle le BLoC
              context.read<AuthBloc>().add(LoginEvent());
            },
            child: Text('Login'),
          ),
        ],
      ),
    );
  }
}
```

**Responsabilité :** Afficher les données et capturer les actions utilisateur.

---

### 2️⃣ **DOMAIN** (Logique Métier)

**C'est quoi ?** Le cœur de ton application. Les règles métier pures.

**Contient :**
- `entities/` : Les objets métier (modèles purs)
- `usecases/` : Les actions métier (ce que l'app peut faire)
- `repositories/` : Les contrats (interfaces) pour accéder aux données

#### 📋 **Entities** (Entités)

**C'est quoi ?** Les objets métier de ton app. Pas de dépendances externes.

**Exemple :**
```dart
// user.dart (ENTITY)
class User {
  final int id;
  final String email;
  final String username;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
  });
}
```

**Pourquoi ?** C'est la représentation pure de ton objet métier. Pas de JSON, pas de DB, juste les données.

---

#### 🎬 **Use Cases** (Cas d'Utilisation)

**C'est quoi ?** Une action métier spécifique. **1 use case = 1 action**.

**Exemple :**
```dart
// login_user.dart (USE CASE)
class LoginUser {
  final AuthRepository repository;

  LoginUser(this.repository);

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
  }) async {
    // Validation métier
    if (email.isEmpty || password.isEmpty) {
      return Left(ValidationFailure('Email et password requis'));
    }

    // Appelle le repository
    return await repository.login(email, password);
  }
}
```

**Pourquoi ?** Sépare chaque action métier. Facile à tester, facile à réutiliser.

**Exemples d'autres use cases :**
- `SignupUser` : Créer un compte
- `UploadVideo` : Uploader une vidéo
- `GetAnalysisResult` : Récupérer un résultat d'analyse
- `CompareMovements` : Comparer deux mouvements

---

#### 🔌 **Repositories** (Contrats)

**C'est quoi ?** Une **interface** (contrat) qui dit "comment" accéder aux données, sans dire "où".

**Exemple :**
```dart
// auth_repository.dart (REPOSITORY - Interface)
abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, User>> signup(String email, String password);
  Future<Either<Failure, void>> logout();
}
```

**Pourquoi ?** Le DOMAIN ne sait pas si les données viennent d'une API, d'une DB locale, ou d'un fichier. Il s'en fiche !

---

### 3️⃣ **DATA** (Sources de Données)

**C'est quoi ?** L'implémentation concrète pour accéder aux données.

**Contient :**
- `models/` : Les modèles de données (avec JSON, DB, etc.)
- `repositories/` : L'implémentation du contrat (interface)
- `datasources/` : Les sources de données (API, DB locale, cache)

#### 🗂️ **Models** (Modèles de Données)

**C'est quoi ?** La version "technique" de l'entité. Sait comment se convertir depuis/vers JSON, DB, etc.

**Exemple :**
```dart
// user_model.dart (MODEL)
class UserModel extends User {
  UserModel({
    required int id,
    required String email,
    required String username,
    required DateTime createdAt,
  }) : super(
          id: id,
          email: email,
          username: username,
          createdAt: createdAt,
        );

  // Depuis JSON (API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Vers JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

**Pourquoi ?** Sépare la logique métier (Entity) de la logique technique (Model).

---

#### 🔌 **Repository Implementation** (Implémentation)

**C'est quoi ?** L'implémentation concrète du contrat défini dans DOMAIN.

**Exemple :**
```dart
// auth_repository_impl.dart (REPOSITORY IMPLEMENTATION)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      // 1. Appelle l'API
      final userModel = await remoteDataSource.login(email, password);
      
      // 2. Sauvegarde en local
      await localDataSource.cacheUser(userModel);
      
      // 3. Retourne l'entité
      return Right(userModel);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
```

**Pourquoi ?** Gère la logique d'accès aux données (API + cache local).

---

#### 📡 **DataSources** (Sources de Données)

**C'est quoi ?** Les sources concrètes de données.

**Types :**
- **Remote** : API, serveur
- **Local** : DB locale, cache, fichiers

**Exemple :**
```dart
// auth_remote_datasource.dart (REMOTE DATASOURCE)
abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<UserModel> login(String email, String password) async {
    final response = await dio.post(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(response.data);
    } else {
      throw ServerException();
    }
  }
}
```

---

## 🔄 Flux de Données Complet

### Exemple : Connexion Utilisateur

```
1. USER clique sur "Login" (PRESENTATION)
   ↓
2. SigninPage appelle AuthBloc.add(LoginEvent)
   ↓
3. AuthBloc appelle LoginUser use case (DOMAIN)
   ↓
4. LoginUser use case appelle AuthRepository.login() (DOMAIN - Interface)
   ↓
5. AuthRepositoryImpl.login() est appelé (DATA)
   ↓
6. AuthRemoteDataSource.login() appelle l'API (DATA)
   ↓
7. API retourne JSON → UserModel (DATA)
   ↓
8. UserModel est converti en User entity (DOMAIN)
   ↓
9. User est retourné au BLoC (PRESENTATION)
   ↓
10. BLoC émet un état "Logged In"
   ↓
11. UI se met à jour → Navigation vers HomePage
```

---

## 📁 Structure Concrète pour Motion AI

### Feature : Auth (Signin)

```
frontend/lib/features/auth/signin/
│
├── presentation/              # COUCHE 1 : UI
│   ├── pages/
│   │   └── signin_page.dart           # Écran de connexion
│   ├── widgets/
│   │   ├── email_input.dart           # Champ email
│   │   └── password_input.dart        # Champ password
│   └── bloc/
│       ├── auth_bloc.dart             # Gestion d'état
│       ├── auth_event.dart            # Événements (LoginEvent, etc.)
│       └── auth_state.dart            # États (Loading, Success, Error)
│
├── domain/                    # COUCHE 2 : Logique Métier
│   ├── entities/
│   │   └── user.dart                  # Entité User (pure)
│   ├── repositories/
│   │   └── auth_repository.dart       # Interface (contrat)
│   └── usecases/
│       ├── login_user.dart            # Use case : Se connecter
│       ├── signup_user.dart           # Use case : S'inscrire
│       └── logout_user.dart           # Use case : Se déconnecter
│
└── data/                      # COUCHE 3 : Accès Données
    ├── models/
    │   └── user_model.dart            # Model avec fromJson/toJson
    ├── repositories/
    │   └── auth_repository_impl.dart  # Implémentation du contrat
    └── datasources/
        ├── auth_remote_datasource.dart    # API calls
        └── auth_local_datasource.dart     # Cache local
```

---

## 🎯 Résumé Visuel

| Couche | Dossier | Contient | Responsabilité | Exemple |
|--------|---------|----------|----------------|---------|
| **PRESENTATION** | `presentation/` | Pages, Widgets, BLoC | Affichage UI | `signin_page.dart` |
| **DOMAIN** | `domain/` | Entities, UseCases, Repositories (interface) | Logique métier | `login_user.dart` |
| **DATA** | `data/` | Models, Repositories (impl), DataSources | Accès données | `auth_remote_datasource.dart` |

---

## 🤔 Pourquoi Séparer Tout Ça ?

### ❌ Sans Clean Architecture
```dart
// signin_page.dart (TOUT MÉLANGÉ)
class SigninPage extends StatelessWidget {
  void login() async {
    // Validation UI
    if (emailController.text.isEmpty) {
      showError('Email requis');
      return;
    }

    // Appel API direct
    final response = await http.post(
      'https://api.motionai.com/auth/login',
      body: {'email': emailController.text},
    );

    // Parsing JSON
    final user = User.fromJson(json.decode(response.body));

    // Navigation
    Navigator.push(context, HomePage());
  }
}
```

**Problèmes :**
- ❌ Impossible à tester sans UI
- ❌ Si l'API change, il faut modifier la page
- ❌ Pas de réutilisation du code
- ❌ Difficile à maintenir

---

### ✅ Avec Clean Architecture
```dart
// signin_page.dart (PRESENTATION)
class SigninPage extends StatelessWidget {
  void login() {
    context.read<AuthBloc>().add(LoginEvent(
      email: emailController.text,
      password: passwordController.text,
    ));
  }
}

// login_user.dart (DOMAIN - USE CASE)
class LoginUser {
  final AuthRepository repository;
  
  Future<User> call(String email, String password) {
    return repository.login(email, password);
  }
}

// auth_remote_datasource.dart (DATA)
class AuthRemoteDataSourceImpl {
  Future<UserModel> login(String email, String password) async {
    final response = await dio.post('/api/auth/login', ...);
    return UserModel.fromJson(response.data);
  }
}
```

**Avantages :**
- ✅ Chaque partie est testable indépendamment
- ✅ Si l'API change, seul le DataSource change
- ✅ Le use case est réutilisable partout
- ✅ Facile à maintenir et à comprendre

---

## 🧪 Testabilité

### Test du Use Case (DOMAIN)
```dart
test('LoginUser should return User when credentials are valid', () async {
  // Arrange
  final mockRepository = MockAuthRepository();
  final loginUser = LoginUser(mockRepository);
  
  when(mockRepository.login('test@test.com', 'password'))
      .thenAnswer((_) async => Right(User(...)));

  // Act
  final result = await loginUser(email: 'test@test.com', password: 'password');

  // Assert
  expect(result.isRight(), true);
});
```

**Pas besoin d'UI, pas besoin d'API réelle !** ✅

---

## 📊 Comparaison : Entity vs Model

| Aspect | **Entity** (DOMAIN) | **Model** (DATA) |
|--------|---------------------|------------------|
| **Localisation** | `domain/entities/` | `data/models/` |
| **Dépendances** | Aucune | JSON, DB, etc. |
| **Responsabilité** | Représenter l'objet métier | Convertir depuis/vers JSON/DB |
| **Exemple** | `User(id, email, username)` | `UserModel.fromJson(json)` |
| **Testable** | Oui, facilement | Oui, mais dépend de JSON |

---

## 🎓 Règles d'Or

1. **DOMAIN ne dépend de RIEN** ✅
   - Pas de `import 'package:dio'`
   - Pas de `import 'package:sqflite'`
   - Juste du Dart pur

2. **DATA dépend de DOMAIN** ✅
   - `UserModel extends User`
   - `AuthRepositoryImpl implements AuthRepository`

3. **PRESENTATION dépend de DOMAIN** ✅
   - BLoC appelle les UseCases
   - UI affiche les Entities

4. **1 Use Case = 1 Action** ✅
   - `LoginUser`, `SignupUser`, `LogoutUser`
   - Pas de `AuthUseCase` qui fait tout

5. **Repository = Interface dans DOMAIN, Implémentation dans DATA** ✅

---

## 🚀 Pour Motion AI

### Features à Implémenter

1. **Auth** : `signin/`, `signup/`, `forget_password/`
2. **Home** : Dashboard
3. **Analysis** : Upload vidéo, voir résultats, comparaison 3D
4. **Settings** : Paramètres utilisateur

Chaque feature suit la même structure :
```
feature/
├── presentation/
├── domain/
└── data/
```

---

## 💡 En Résumé

- **PRESENTATION** = Ce que l'utilisateur voit (UI, BLoC)
- **DOMAIN** = Les règles métier (Entities, UseCases, Repository interfaces)
- **DATA** = Comment accéder aux données (Models, Repository impl, DataSources)

**Flux :** UI → BLoC → UseCase → Repository → DataSource → API/DB

**Avantage :** Code testable, maintenable, et indépendant ! 🎯
