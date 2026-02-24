import 'package:dio/dio.dart';
import 'package:job_scout/core/services/token_storage.dart';

/// Dio interceptor that:
///  1. Attaches `Authorization: Bearer <token>` to every request.
///  2. On 401 — attempts a silent token refresh, then retries the original request.
///  3. On refresh failure — clears stored tokens and rethrows so the caller
///     (AuthProvider.initialize) can redirect to login.
class AuthInterceptor extends Interceptor {
  final TokenStorage _storage;

  /// A separate unauthenticated Dio instance used exclusively for the
  /// refresh call, avoiding an infinite interceptor loop.
  late final Dio _refreshDio;

  final String _refreshPath = '/auth/refresh';

  AuthInterceptor(this._storage, String baseUrl) {
    _refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
  }

  // ─── Attach token to outbound requests ─────────────

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _storage.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ─── Handle 401 → refresh → retry ──────────────────

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clear();
      handler.next(err);
      return;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refresh_token': refreshToken},
      );

      final newAccess = response.data?['access_token'] as String?;
      if (newAccess == null) throw Exception('No access_token in refresh response');

      await _storage.updateAccessToken(newAccess);

      // Retry the original request with the new token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _refreshDio.fetch<dynamic>(opts);
      handler.resolve(retryResponse);
    } catch (_) {
      // Refresh failed — force logout
      await _storage.clear();
      handler.next(err);
    }
  }
}
