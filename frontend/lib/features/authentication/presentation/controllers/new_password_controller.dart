import 'package:flutter/material.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'package:dio/dio.dart';

enum NewPasswordStatus { idle, loading, success, error }

class NewPasswordController extends ChangeNotifier {
  final AuthRepository _repository;

  NewPasswordController()
      : _repository = AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSourceImpl(
            client: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1')),
          ),
        );

  NewPasswordStatus _status = NewPasswordStatus.idle;
  String? _errorMessage;

  NewPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == NewPasswordStatus.loading;
  bool get isSuccess => _status == NewPasswordStatus.success;

  Future<bool> resetPassword(String email, String newPassword) async {
    _status = NewPasswordStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.resetPassword(email, newPassword);
      _status = NewPasswordStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _status = NewPasswordStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
