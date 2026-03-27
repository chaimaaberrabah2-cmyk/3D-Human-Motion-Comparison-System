import '../repositories/auth_repository.dart';

class VerifyResetCodeUseCase {
  final AuthRepository repository;

  const VerifyResetCodeUseCase(this.repository);

  Future<void> call({required String code}) {
    return repository.verifyResetCode(code: code);
  }
}
