/// Reads compile-time configuration injected via --dart-define.
///
/// Demo mode (no real API):
///   flutter run
///
/// Real API (local):
///   flutter run --dart-define=API_URL=http://localhost:8000/api/v1
///
/// Real API (Android emulator — 10.0.2.2 maps to host machine):
///   flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
///
/// Production:
///   flutter build apk --dart-define=API_URL=https://api.jobscout.app/api/v1
class AppConfig {
  AppConfig._();

  static const _apiUrl = String.fromEnvironment('API_URL');

  /// True when no API_URL was provided at build time.
  /// The app runs entirely on mock data in this mode.
  static bool get isDemoMode => _apiUrl.isEmpty;

  /// Base URL for the backend API (must include /api/v1 prefix).
  static String get apiUrl =>
      _apiUrl.isEmpty ? 'http://localhost:8000/api/v1' : _apiUrl;

  /// Request timeout.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
