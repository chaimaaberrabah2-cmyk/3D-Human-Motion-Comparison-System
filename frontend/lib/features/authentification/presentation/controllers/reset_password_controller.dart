// ============================================================
// lib/features/authentification/presentation/controllers/reset_password_controller.dart
// ============================================================
// Le ViewModel / Contrôleur pour l'écran de saisie du code de vérification.
//
// Quand l'utilisateur entre le code reçu par email et appuie sur "Vérifier",
// ce contrôleur appelle `VerifyResetCodeUseCase` et suit l'état
// chargement/succès/erreur pour que l'interface puisse réagir.
//
// En cas de succès → la page navigue vers l'écran de nouveau mot de passe.
// En cas d'erreur  → un message d'erreur est affiché à l'utilisateur.
// ============================================================

import 'package:flutter/material.dart';
import '../../domain/usecases/verify_reset_code_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';

/// États possibles pendant la vérification du code de réinitialisation.
enum ResetPasswordStatus { idle, loading, success, error }

/// Contrôle l'état de la ResetPasswordPage (vérification du code OTP).
class ResetPasswordController extends ChangeNotifier {
  final VerifyResetCodeUseCase _verifyUseCase;

  ResetPasswordController()
      : _verifyUseCase = VerifyResetCodeUseCase(
          AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(
              client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
            ),
          ),
        );

  ResetPasswordStatus _status = ResetPasswordStatus.idle;
  String? _errorMessage;

  ResetPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ResetPasswordStatus.loading;

  /// Vérifie le [code] OTP saisi par l'utilisateur.
  /// Retourne `true` en cas de succès, `false` sinon.
  Future<bool> verifyCode({required String code}) async {
    _status = ResetPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _verifyUseCase(code: code);
      _status = ResetPasswordStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = ResetPasswordStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Réinitialise l'état du contrôleur.
  void reset() {
    _status = ResetPasswordStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
