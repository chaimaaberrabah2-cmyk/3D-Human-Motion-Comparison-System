// ============================================================
// lib/features/authentication/domain/usecases/verify_reset_code_usecase.dart
// ============================================================
// Action métier : valider le code de réinitialisation saisi par l'utilisateur.
// Appelé sur la page de réinitialisation après que l'utilisateur
// entre le code reçu par email.
// Délègue à `AuthRepository.verifyResetCode`.
// ============================================================

import '../repositories/auth_repository.dart';

/// Action métier : vérifier le code OTP reçu par l'utilisateur pour réinitialiser son mot de passe.
class VerifyResetCodeUseCase {
  final AuthRepository repository;

  const VerifyResetCodeUseCase(this.repository);

  /// Vérifie [code]. Lève une exception si le code est vide ou invalide.
  Future<void> call({required String code}) {
    return repository.verifyResetCode(code: code);
  }
}
