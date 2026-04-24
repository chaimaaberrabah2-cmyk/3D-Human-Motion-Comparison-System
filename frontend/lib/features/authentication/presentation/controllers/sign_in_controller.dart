// ============================================================
// lib/features/authentication/presentation/controllers/sign_in_controller.dart
// ============================================================
// Le ViewModel / Contrôleur pour l'écran de connexion.
//
// Les contrôleurs dans ce projet utilisent le pattern ChangeNotifier de Flutter
// (similaire à un ViewModel en MVVM). L'interface écoute le contrôleur
// via `Consumer<SignInController>` et se reconstruit quand l'état change.
//
// Responsabilités :
//   - Maintient l'ÉTAT actuel (chargement/succès/erreur) de la connexion
//   - Appelle `SignInUseCase` quand l'utilisateur soumet le formulaire
//   - Expose `isLoading` pour désactiver le bouton pendant la requête
//   - Expose `errorMessage` pour afficher les erreurs à l'utilisateur
//
// Machine d'état (SignInStatus) :
//   idle     → formulaire pas encore soumis
//   loading  → requête en cours (affiche un spinner sur le bouton)
//   success  → connexion réussie (la page navigue ailleurs)
//   error    → connexion échouée (message d'erreur affiché)
// ============================================================

import 'package:flutter/material.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';

/// États possibles pendant le processus de connexion.
enum SignInStatus { idle, loading, success, error }

/// Contrôle l'état du formulaire SignInPage.
class SignInController extends ChangeNotifier {
  final SignInUseCase _signInUseCase;

  final AuthRepositoryImpl _repository;
  
  // Connecte le use case avec l'implémentation concrète du repository
  // On crée l'instance Dio ici avec l'URL de base de notre backend FastAPI
  SignInController() 
      : _repository = AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSourceImpl(
            client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
          ),
        ),
        _signInUseCase = SignInUseCase(
          AuthRepositoryImpl(
            remoteDataSource: AuthRemoteDataSourceImpl(
              client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
            ),
          )
        );

  SignInStatus _status = SignInStatus.idle;
  String? _errorMessage;

  SignInStatus get status => _status;
  String? get errorMessage => _errorMessage;
  /// Vrai pendant que la requête HTTP de connexion est en cours.
  bool get isLoading => _status == SignInStatus.loading;

  /// Tente de connecter l'utilisateur. Retourne `true` en cas de succès, `false` sinon.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = SignInStatus.loading;
    _errorMessage = null;
    notifyListeners(); // Déclenche le spinner sur le bouton

    try {
      await _signInUseCase(email: email, password: password);
      _status = SignInStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SignInStatus.error;
      // Supprime le préfixe "Exception: " pour des messages plus clairs
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Tente de connecter l'utilisateur via Google. 
  Future<bool> signInWithGoogle() async {
    _status = SignInStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.signInWithGoogle();
      _status = SignInStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = SignInStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Réinitialise l'état du contrôleur — utile à la rentrée sur l'écran.
  void reset() {
    _status = SignInStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
