// ============================================================
// lib/features/authentification/domain/usecases/sign_in_usecase.dart
// ============================================================
// Un Cas d'Utilisation (UseCase) représente une action métier unique.
//
// En Architecture Propre, les UseCases se trouvent dans la couche domaine
// et appellent les méthodes des repositories. Ce pattern permet de :
//   - Tester la logique métier sans dépendre de l'UI ou de la couche data
//   - Réutiliser la logique depuis plusieurs contrôleurs/pages
//   - Garder les contrôleurs simples (ils délèguent aux use cases)
//
// Ce use case gère la connexion d'un utilisateur existant.
// Il délègue à `AuthRepository.signIn`.
// ============================================================

import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Action métier : connecter un utilisateur avec son email et mot de passe.
class SignInUseCase {
  final AuthRepository repository;

  const SignInUseCase(this.repository);

  /// Exécute la connexion. Retourne l'[AuthUser] authentifié ou lève une exception.
  Future<AuthUser> call({required String email, required String password}) {
    return repository.signIn(email: email, password: password);
  }
}
