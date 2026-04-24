// ============================================================
// lib/features/authentication/domain/entities/auth_user.dart
// ============================================================

/// Représente un utilisateur authentifié dans la couche domaine.
class AuthUser {
  /// Identifiant unique de l'utilisateur.
  final String id;

  /// Adresse email utilisée pour la connexion.
  final String email;

  /// Nom affiché dans l'interface.
  final String? displayName;

  /// Jeton de session JWT.
  final String? token;

  /// Rôle de l'utilisateur (user, admin, super_admin).
  final String? role;

  /// ID de l'établissement rattaché.
  final int? establishmentId;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.token,
    this.role,
    this.establishmentId,
  });
}
