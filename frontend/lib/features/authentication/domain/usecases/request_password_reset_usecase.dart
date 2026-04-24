// ============================================================
// lib/features/authentication/domain/usecases/request_password_reset_usecase.dart
// ============================================================
// Action métier : envoyer un code de réinitialisation à l'email de l'utilisateur.
// Délègue à `AuthRepository.requestPasswordReset`.
// ============================================================

import '../repositories/auth_repository.dart';

/// Action métier : demander l'envoi d'un email de réinitialisation du mot de passe.
class RequestPasswordResetUseCase {
  final AuthRepository repository;

  const RequestPasswordResetUseCase(this.repository);

  /// Déclenche la réinitialisation pour [email]. Lève une exception si l'email est invalide.
  Future<void> call({required String email}) {
    return repository.requestPasswordReset(email: email);
  }
}
