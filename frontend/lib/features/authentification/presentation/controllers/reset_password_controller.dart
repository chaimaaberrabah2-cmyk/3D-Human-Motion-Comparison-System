import 'package:flutter/material.dart';
import '../../domain/usecases/verify_reset_code_usecase.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum ResetPasswordStatus { idle, loading, success, error }

class ResetPasswordController extends ChangeNotifier {
  final VerifyResetCodeUseCase _verifyUseCase;

  ResetPasswordController()
      : _verifyUseCase = VerifyResetCodeUseCase(AuthRepositoryImpl());

  ResetPasswordStatus _status = ResetPasswordStatus.idle;
  String? _errorMessage;

  ResetPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ResetPasswordStatus.loading;

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

  void reset() {
    _status = ResetPasswordStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
