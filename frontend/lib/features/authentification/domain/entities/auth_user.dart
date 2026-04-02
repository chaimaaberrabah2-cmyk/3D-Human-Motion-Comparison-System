// ============================================================
// lib/features/authentification/domain/entities/auth_user.dart
// ============================================================
// Définit le modèle de données `AuthUser` pour la couche domaine.
//
// En Architecture Propre (Clean Architecture), une "entité" est une
// classe de données pure sans dépendance sur Flutter ou une bibliothèque
// externe — c'est juste une représentation d'un concept métier.
//
// Cette classe représente un utilisateur connecté et est retournée
// par le repository d'authentification après une connexion ou inscription réussie.
//
// Champs :
//   id          identifiant unique de l'utilisateur (depuis le backend/Firebase)
//   email       adresse email de l'utilisateur
//   displayName nom optionnel affiché dans l'interface (préfixe email si null)
// ============================================================

/// Représente un utilisateur authentifié dans la couche domaine.
class AuthUser {
  /// Identifiant unique de l'utilisateur — fourni par le backend ou Firebase.
  final String id;

  /// Adresse email utilisée pour la connexion.
  final String email;

  /// Nom affiché dans l'interface. Utilise le préfixe de l'email si null.
  final String? displayName;

  /// Jeton de session JWT (pas dans le stockage persistant ici, mais pratique en mémoire).
  final String? token;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.token,
  });
}
