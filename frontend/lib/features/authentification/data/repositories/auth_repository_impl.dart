import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Mock implementation — replace with real API/Firebase calls when backend is ready.
class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password must not be empty.');
    }
    return AuthUser(
      id: 'mock-user-id',
      email: email,
      displayName: email.split('@').first,
    );
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('All fields are required.');
    }
    if (!email.contains('@')) {
      throw Exception('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    // TODO: Replace with real registration logic (e.g. HTTP call, Firebase)
    return AuthUser(
      id: 'mock-new-user-id',
      email: email,
      displayName: name,
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Enter a valid email address.');
    }
    // TODO: Replace with real password reset call (e.g. HTTP call, Firebase)
  }

  @override
  Future<void> verifyResetCode({required String code}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (code.isEmpty) {
      throw Exception('Verification code is required.');
    }
    if (code.length < 4) {
      throw Exception('Enter a valid verification code.');
    }
    // TODO: Replace with real verification logic
  }
}

