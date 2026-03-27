import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository repository;

  const SignUpUseCase(this.repository);

  Future<AuthUser> call({
    required String name,
    required String email,
    required String password,
  }) {
    return repository.signUp(name: name, email: email, password: password);
  }
}
