import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/mock_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = MockApiService();

  UserProfileResponse? _user;
  TokenResponse? _tokens;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  bool get isAuthenticated => _tokens != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  UserProfileResponse? get user => _user;
  String? get error => _error;

  /// Called on app launch to check for existing session.
  /// In a real app this would read tokens from secure storage.
  Future<void> initialize() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tokens = await _api.login(email, password);
      _user = await _api.getCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tokens = await _api.register(email, password, fullName);
      _user = await _api.getCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _tokens = null;
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
