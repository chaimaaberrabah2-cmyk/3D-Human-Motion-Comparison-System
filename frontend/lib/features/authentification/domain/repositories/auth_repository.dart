// ============================================================
// lib/features/authentification/domain/repositories/auth_repository.dart
// ============================================================
// Définit le CONTRAT (interface) pour toutes les opérations d'authentification.
//
// En Architecture Propre, la couche `domaine` définit des interfaces
// abstraites qui décrivent CE QUI peut être fait, sans dire COMMENT.
// L'implémentation concrète se trouve dans la couche `data`
// (auth_repository_impl.dart).
//
// IMPORTANT : La couche domaine ne dépend d'aucun framework Flutter,
// Dio, Firebase ou bibliothèque externe — c'est du Dart pur.
//
// Méthodes :
//   signIn               → Authentifie un utilisateur existant
//   signUp               → Inscrit un nouvel utilisateur
//   requestPasswordReset → Envoie un code de réinitialisation par email
//   verifyResetCode      → Valide le code de réinitialisation reçu
// ============================================================

import '../entities/auth_user.dart';

/// Contrat abstrait pour les opérations de données de la fonctionnalité d'authentification.
/// L'implémentation concrète est dans `data/repositories/auth_repository_impl.dart`.
abstract class AuthRepository {
  /// Authentifie un utilisateur avec [email] et [password].
  /// Retourne un [AuthUser] en cas de succès ou lève une exception en cas d'échec.
  Future<AuthUser> signIn({required String email, required String password});

  /// Crée un nouveau compte utilisateur avec [name], [email], [password].
  /// Retourne un [AuthUser] en cas de succès ou lève une exception en cas d'échec.
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Envoie un code de réinitialisation de mot de passe à [email].
  Future<void> requestPasswordReset({required String email});

  /// Vérifie le [code] de réinitialisation envoyé à l'email de l'utilisateur.
  Future<void> verifyResetCode({required String code});

  /// Met à jour les informations personnelles de l'utilisateur.
  Future<AuthUser> updateUser(String oldEmail, String newEmail, String newPseudo);

  /// Met à jour le mot de passe de l'utilisateur.
  Future<void> updatePassword(String email, String oldPassword, String newPassword);

  /// Met à jour le mot de passe via le flux de réinitialisation (OTP).
  Future<void> resetPassword(String email, String newPassword);
}
