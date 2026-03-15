import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Signs in a user with [email] and [password].
  /// Returns an [AuthUser] on success or throws on failure.
  Future<AuthUser> signIn({required String email, required String password});
}
