import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Mock implementation — replace with real API/Firebase calls when backend is ready.
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Replace with real authentication logic (e.g. HTTP call, Firebase)
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password must not be empty.');
    }

    return AuthUser(
      id: 'mock-user-id',
      email: email,
      displayName: email.split('@').first,
    );
  }
}
