// ============================================================
// lib/features/authentification/domain/usecases/sign_up_usecase.dart
// ============================================================
// Action métier : inscrire un nouvel utilisateur.
// Délègue à `AuthRepository.signUp`.
//
// Voir sign_in_usecase.dart pour une explication générale
// du fonctionnement des UseCases dans ce projet.
// ============================================================

import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Action métier : créer un nouveau compte utilisateur.
class SignUpUseCase {
  final AuthRepository repository;

  const SignUpUseCase(this.repository);

  /// Exécute l'inscription. Retourne [AuthUser] en cas de succès ou lève une exception.
  Future<AuthUser> call({
    required String name,
    required String email,
    required String password,
  }) {
    return repository.signUp(name: name, email: email, password: password);
  }
}
