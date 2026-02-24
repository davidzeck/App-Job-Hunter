import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth tokens in the device's secure enclave.
/// iOS → Keychain, Android → EncryptedSharedPreferences.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  // ─── In-memory cache (avoids repeated disk reads) ──

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get hasTokens => _accessToken != null && _accessToken!.isNotEmpty;

  /// Load tokens from secure storage into memory.
  /// Call once at app startup from [AuthProvider.initialize].
  Future<void> load() async {
    _accessToken = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
  }

  /// Persist tokens after a successful login or refresh.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  /// Update only the access token after a token refresh.
  Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
    await _storage.write(key: _kAccessToken, value: accessToken);
  }

  /// Clear all tokens on logout or session expiry.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }
}
