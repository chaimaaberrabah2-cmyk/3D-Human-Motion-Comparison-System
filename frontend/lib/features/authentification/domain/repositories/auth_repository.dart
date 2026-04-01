import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Sends a password reset link to [email].
  Future<void> requestPasswordReset({required String email});

  /// Verifies the [code] sent to the user.
  Future<void> verifyResetCode({required String code});
}
