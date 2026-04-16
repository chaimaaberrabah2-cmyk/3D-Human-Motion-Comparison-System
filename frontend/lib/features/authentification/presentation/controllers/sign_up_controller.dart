// ============================================================
// lib/features/authentification/presentation/controllers/sign_up_controller.dart
// ============================================================
// Le ViewModel / Contrôleur pour l'écran d'inscription.
//
// Suit le même pattern ChangeNotifier que SignInController.
// Voir sign_in_controller.dart pour une explication détaillée
// du fonctionnement des contrôleurs dans ce projet.
//
// Machine d'état (SignUpStatus) :
//   idle     → formulaire pas encore soumis
//   loading  → requête d'inscription en cours
//   success  → compte créé (la page navigue vers l'écran de succès)
//   error    → inscription échouée (erreur affichée à l'utilisateur)
// ============================================================

import 'package:flutter/material.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';

/// États possibles pendant le processus d'inscription.
enum SignUpStatus { idle, loading, success, error }

/// Contrôle l'état du formulaire SignUpPage.
class SignUpController extends ChangeNotifier {
  final SignUpUseCase _signUpUseCase;

  final AuthRepositoryImpl _repository;

  SignUpController() 
      : _repository = AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSourceImpl(
            client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
          ),
        ),
        _signUpUseCase = SignUpUseCase(
          AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(
              client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
            ),
          )
        );

  /// Tente de connecter l'utilisateur via Google. 
  Future<bool> signInWithGoogle() async {
    _status = SignUpStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.signInWithGoogle();
      _status = SignUpStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SignUpStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  SignUpStatus _status = SignUpStatus.idle;
  String? _errorMessage;

  SignUpStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SignUpStatus.loading;

  /// Tente de créer un compte avec [name], [email], [password].
  /// Retourne `true` en cas de succès, `false` sinon.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String establishmentCode,
  }) async {
    _status = SignUpStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signUpUseCase(name: name, email: email, password: password, establishmentCode: establishmentCode);
      _status = SignUpStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SignUpStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Réinitialise l'état du contrôleur.
  void reset() {
    _status = SignUpStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
