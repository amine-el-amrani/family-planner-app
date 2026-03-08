import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiClient();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null) {
      try {
        final response = await _api.dio.get('/users/me');
        _user = response.data;
        _isAuthenticated = true;
      } catch (_) {
        await prefs.remove('jwt_token');
      }
    }
    _isLoading = false;
    notifyListeners();
    // Re-subscribe to push on app start (token may have rotated)
    if (_isAuthenticated) {
      PushService.initialize().then((_) => PushService.subscribeAndRegister());
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _api.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final token = response.data['access_token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    final me = await _api.dio.get('/users/me');
    _user = me.data;
    _isAuthenticated = true;
    notifyListeners();
    // Subscribe to push notifications after login
    PushService.initialize().then((_) => PushService.subscribeAndRegister());
  }

  Future<void> register(String fullName, String email, String password) async {
    await _api.dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'password': password,
    });
    await login(email, password);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final response = await _api.dio.get('/users/me');
      _user = response.data;
      notifyListeners();
    } catch (_) {}
  }
}
