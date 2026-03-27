import '../repositories/auth_repository.dart';

class RequestPasswordResetUseCase {
  final AuthRepository repository;

  const RequestPasswordResetUseCase(this.repository);

  Future<void> call({required String email}) {
    return repository.requestPasswordReset(email: email);
  }
}
