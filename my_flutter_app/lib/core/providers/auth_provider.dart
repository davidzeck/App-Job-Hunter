import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = TokenStorage.instance;

  UserProfileResponse? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  bool get isAuthenticated => _storage.hasTokens;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  UserProfileResponse? get user => _user;
  String? get error => _error;

  /// Called on app launch.
  /// Loads tokens from secure storage; if valid, fetches the user profile.
  Future<void> initialize() async {
    await _storage.load();

    if (_storage.hasTokens) {
      try {
        _user = await api.getCurrentUser();
      } catch (_) {
        // Token expired / network failure — clear and go to login
        await _storage.clear();
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await api.login(email, password);
      await _storage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _user = await api.getCurrentUser();
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
      final tokens = await api.register(email, password, fullName);
      await _storage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _user = await api.getCurrentUser();
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

  Future<void> logout() async {
    await _storage.clear();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
