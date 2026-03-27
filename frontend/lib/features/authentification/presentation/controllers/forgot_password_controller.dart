import 'package:flutter/material.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum ForgotPasswordStatus { idle, loading, success, error }

class ForgotPasswordController extends ChangeNotifier {
  final RequestPasswordResetUseCase _useCase;

  ForgotPasswordController()
      : _useCase = RequestPasswordResetUseCase(AuthRepositoryImpl());

  ForgotPasswordStatus _status = ForgotPasswordStatus.idle;
  String? _errorMessage;

  ForgotPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ForgotPasswordStatus.loading;
  bool get isSuccess => _status == ForgotPasswordStatus.success;

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
