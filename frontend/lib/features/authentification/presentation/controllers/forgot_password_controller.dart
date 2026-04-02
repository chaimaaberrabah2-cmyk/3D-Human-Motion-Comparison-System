// ============================================================
// lib/features/authentification/presentation/controllers/forgot_password_controller.dart
// ============================================================
// Le ViewModel / Contrôleur pour l'écran "Mot de passe oublié".
//
// Quand l'utilisateur saisit son email et appuie sur "Envoyer le code",
// ce contrôleur appelle `RequestPasswordResetUseCase` et suit
// l'état chargement/succès/erreur pour que l'interface puisse réagir.
//
// En cas de succès → la page sait que le code a été envoyé et affiche un retour.
// En cas d'erreur  → un message d'erreur est affiché à l'utilisateur.
// ============================================================

import 'package:flutter/material.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';

/// États possibles pour la demande de réinitialisation de mot de passe.
enum ForgotPasswordStatus { idle, loading, success, error }

/// Contrôle l'état de la ForgotPasswordPage.
class ForgotPasswordController extends ChangeNotifier {
  final RequestPasswordResetUseCase _useCase;

  ForgotPasswordController()
      : _useCase = RequestPasswordResetUseCase(
          AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(
              client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
            ),
          ),
        );

  ForgotPasswordStatus _status = ForgotPasswordStatus.idle;
  String? _errorMessage;

  ForgotPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ForgotPasswordStatus.loading;
  /// Vrai quand la demande de réinitialisation a été envoyée avec succès.
  bool get isSuccess => _status == ForgotPasswordStatus.success;

  /// Envoie un code de réinitialisation à [email].
  /// Retourne `true` en cas de succès, `false` sinon.
  Future<bool> requestReset({required String email}) async {
    _status = ForgotPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _useCase(email: email);
      _status = ForgotPasswordStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = ForgotPasswordStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
