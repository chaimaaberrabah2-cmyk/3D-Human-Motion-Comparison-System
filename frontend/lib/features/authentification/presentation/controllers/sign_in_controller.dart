import 'package:flutter/material.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum SignInStatus { idle, loading, success, error }

class SignInController extends ChangeNotifier {
  final SignInUseCase _signInUseCase;

  SignInController() : _signInUseCase = SignInUseCase(AuthRepositoryImpl());

  SignInStatus _status = SignInStatus.idle;
  String? _errorMessage;

  SignInStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SignInStatus.loading;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = SignInStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signInUseCase(email: email, password: password);
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

  void reset() {
    _status = SignInStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
