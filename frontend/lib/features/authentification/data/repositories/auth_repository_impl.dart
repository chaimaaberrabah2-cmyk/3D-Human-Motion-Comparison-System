// ============================================================
// lib/features/authentification/data/repositories/auth_repository_impl.dart
// ============================================================
// Implementation of AuthRepository communicating with FastAPI backend.
// ============================================================

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  
  AuthUser? _currentUser;
  
  AuthRepositoryImpl({
    required this.remoteDataSource,
  });

  Future<void> _saveSession(AuthUser user) async {
    if (user.token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', user.token!);
      await prefs.setString('user_name', user.displayName ?? 'Utilisateur');
      await prefs.setString('user_email', user.email);
    }
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    final user = await remoteDataSource.signIn(email, password);
    _currentUser = user;
    await _saveSession(user);
    return user;
  }

  @override
  Future<AuthUser> signUp({required String name, required String email, required String password}) async {
    final user = await remoteDataSource.signUp(name, email, password);
    _currentUser = user;
    await _saveSession(user);
    return user;
  }

  Future<AuthUser> signInWithGoogle() async {
    final user = await remoteDataSource.signInWithGoogle();
    _currentUser = user;
    await _saveSession(user);
    return user;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    // TODO: Connect to backend password reset endpoint (for now mocked)
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<bool> verifyResetCode({required String code}) async {
    // TODO: Connect to backend verify code endpoint
    await Future.delayed(const Duration(seconds: 1));
    return code == '1234';
  }

  @override
  Future<void> resetPassword(String email, String newPassword) async {
    await remoteDataSource.resetPassword(email, newPassword);
  }

  @override
  AuthUser? getCurrentUser() {
    return _currentUser;
  }

  @override
  Future<AuthUser> updateUser(String oldEmail, String newEmail, String newPseudo) async {
    final user = await remoteDataSource.updateUser(oldEmail, newEmail, newPseudo);
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.displayName ?? 'Utilisateur');
    await prefs.setString('user_email', user.email);
    return user;
  }

  @override
  Future<void> updatePassword(String email, String oldPassword, String newPassword) async {
    await remoteDataSource.updatePassword(email, oldPassword, newPassword);
  }
}
