import 'package:job_scout/core/config/app_config.dart';
import 'package:job_scout/core/services/api_service.dart';
import 'package:job_scout/core/services/api_service_base.dart';
import 'package:job_scout/core/services/mock_api_service.dart';

/// Top-level getter — returns the correct [ApiServiceBase] implementation
/// based on whether an API_URL was supplied at build time.
///
/// Usage in any screen state class:
///   final _api = api;   // replaces: final _api = MockApiService();
///
/// No Provider or BuildContext needed — it's a plain singleton getter.
ApiServiceBase get api =>
    AppConfig.isDemoMode ? MockApiService() : ApiService.instance;
