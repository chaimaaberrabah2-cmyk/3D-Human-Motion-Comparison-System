import 'package:flutter/material.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum SignUpStatus { idle, loading, success, error }

class SignUpController extends ChangeNotifier {
  final SignUpUseCase _signUpUseCase;

  SignUpController() : _signUpUseCase = SignUpUseCase(AuthRepositoryImpl());

  SignUpStatus _status = SignUpStatus.idle;
  String? _errorMessage;

  SignUpStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SignUpStatus.loading;

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _status = SignUpStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signUpUseCase(name: name, email: email, password: password);
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

  void reset() {
    _status = SignUpStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
