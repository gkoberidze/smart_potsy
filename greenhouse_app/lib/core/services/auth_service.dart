import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../models/user.dart';
import 'api_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthState _state = AuthState.initial;
  User? _user;
  String? _error;

  AuthService(this._apiService);

  AuthState get state => _state;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;

  Future<void> init() async {
    _state = AuthState.loading;
    notifyListeners();

    final token = await _storage.read(key: 'token');
    if (token != null) {
      _apiService.setToken(token);
      final success = await _fetchCurrentUser();
      if (!success) {
        await _storage.delete(key: 'token');
        _apiService.setToken(null);
      }
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> _fetchCurrentUser() async {
    final response = await _apiService.get(ApiConstants.me);
    if (response.success && response.data != null) {
      _user = User.fromJson(response.data);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    }
    _state = AuthState.unauthenticated;
    notifyListeners();
    return false;
  }

  Future<bool> register(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiConstants.register, {
        'email': email,
        'password': password,
      });

      if (response.success && response.data != null) {
        final token = response.data['token'];
        final userData = response.data['user'];

        if (token != null && userData != null) {
          await _storage.write(key: 'token', value: token.toString());
          _apiService.setToken(token.toString());
          _user = User.fromJson(Map<String, dynamic>.from(userData as Map));
          _state = AuthState.authenticated;
          notifyListeners();
          return true;
        } else {
          _error = 'Invalid response from server';
          _state = AuthState.error;
          notifyListeners();
          return false;
        }
      }

      _error = response.error ?? 'რეგისტრაცია ვერ მოხერხდა';
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Exception: ${e.toString()}';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiConstants.login, {
        'email': email,
        'password': password,
      });

      if (response.success && response.data != null) {
        final token = response.data['token'];
        final userData = response.data['user'];

        if (token != null && userData != null) {
          await _storage.write(key: 'token', value: token.toString());
          _apiService.setToken(token.toString());
          _user = User.fromJson(Map<String, dynamic>.from(userData as Map));
          _state = AuthState.authenticated;
          notifyListeners();
          return true;
        } else {
          _error = 'Invalid response from server';
          _state = AuthState.error;
          notifyListeners();
          return false;
        }
      }

      _error = response.error ?? 'შესვლა ვერ მოხერხდა';
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Exception: ${e.toString()}';
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOAuth(String provider, String accessToken) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    final response = await _apiService.post(ApiConstants.oauth, {
      'provider': provider,
      'accessToken': accessToken,
    });

    if (response.success && response.data != null) {
      final token = response.data['token'];
      await _storage.write(key: 'token', value: token);
      _apiService.setToken(token);
      _user = User.fromJson(response.data['user']);
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    }

    _error = response.error ?? 'OAuth შესვლა ვერ მოხერხდა';
    _state = AuthState.error;
    notifyListeners();
    return false;
  }

  Future<bool> forgotPassword(String email) async {
    final response = await _apiService.post(ApiConstants.forgotPassword, {
      'email': email,
    });

    return response.success;
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    final response = await _apiService.post(ApiConstants.resetPassword, {
      'token': token,
      'newPassword': newPassword,
    });

    return response.success;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    _apiService.setToken(null);
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }
}
