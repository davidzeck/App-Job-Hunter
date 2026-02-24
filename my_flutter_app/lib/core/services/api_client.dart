import 'package:dio/dio.dart';
import 'package:job_scout/core/config/app_config.dart';
import 'package:job_scout/core/services/auth_interceptor.dart';
import 'package:job_scout/core/services/token_storage.dart';

/// Singleton Dio instance pre-configured with:
///  - Base URL from [AppConfig.apiUrl]
///  - JSON content-type headers
///  - Connect / receive timeouts
///  - [AuthInterceptor] for token injection and 401 refresh
class ApiClient {
  ApiClient._();
  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  late final Dio _dio = _build();

  Dio get dio => _dio;

  Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(TokenStorage.instance, AppConfig.apiUrl),
    );

    // Uncomment to log requests in debug builds:
    // if (kDebugMode) {
    //   dio.interceptors.add(LogInterceptor(responseBody: true));
    // }

    return dio;
  }
}
