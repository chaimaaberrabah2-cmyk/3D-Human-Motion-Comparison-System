import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/auth_user.dart';

abstract class AuthRemoteDataSource {
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> signUp(String pseudo, String email, String password);
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> updateUser(String oldEmail, String newEmail, String newPseudo);
  Future<void> updatePassword(String email, String oldPassword, String newPassword);
  Future<void> resetPassword(String email, String newPassword);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio client;
  final GoogleSignIn googleSignIn;

  AuthRemoteDataSourceImpl({required this.client, GoogleSignIn? googleSignIn})
      : googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final response = await client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthUser(
          id: data['user']['user_id'].toString(),
          displayName: data['user']['pseudo'],
          email: data['user']['email'],
          token: data['access_token'],
        );
      } else {
        throw Exception('Failed to sign in');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Connection error');
    }
  }

  @override
  Future<AuthUser> signUp(String pseudo, String email, String password) async {
    try {
      final response = await client.post('/auth/register', data: {
        'pseudo': pseudo,
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthUser(
          id: data['user']['user_id'].toString(),
          displayName: data['user']['pseudo'],
          email: data['user']['email'],
          token: data['access_token'],
        );
      } else {
        throw Exception('Failed to sign up');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Connection error');
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      // Trigger the Google authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        throw Exception('Sign in aborted by user');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      // Send the ID token to our backend
      final response = await client.post('/auth/google', data: {
        'id_token': idToken,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthUser(
          id: data['user']['user_id'].toString(),
          displayName: data['user']['pseudo'],
          email: data['user']['email'],
          token: data['access_token'],
        );
      } else {
        throw Exception('Failed to authenticate with backend via Google');
      }
    } catch (e) {
      // Ensure we sign out if something goes wrong so the user can try again
      await googleSignIn.signOut();
      throw Exception('Google Sign In Error: $e');
    }
  }

  @override
  Future<AuthUser> updateUser(String oldEmail, String newEmail, String newPseudo) async {
    try {
      final response = await client.put('/auth/update', data: {
        'old_email': oldEmail,
        'new_email': newEmail,
        'pseudo': newPseudo,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AuthUser(
          id: data['user_id'].toString(),
          displayName: data['pseudo'],
          email: data['email'],
        );
      } else {
        throw Exception('Failed to update user');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Connection error');
    }
  }

  @override
  Future<void> updatePassword(String email, String oldPassword, String newPassword) async {
    try {
      final response = await client.put('/auth/update_password', data: {
        'email': email,
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to update password');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Connection error');
    }
  }

  @override
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      final response = await client.post('/auth/reset-password', data: {
        'email': email,
        'new_password': newPassword,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to reset password');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['detail'] ?? 'Connection error');
    }
  }
}
