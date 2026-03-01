import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/api_client.dart';
import 'package:job_scout/core/services/api_service_base.dart';

/// Real HTTP implementation of [ApiServiceBase].
/// All calls go to the FastAPI backend via [ApiClient] (Dio).
///
/// Alert-based convenience methods (isJobSaved, alertIdForJob) use an
/// in-memory cache populated whenever [getAlerts] is called — so they
/// remain synchronous from the caller's perspective.
class ApiService extends ApiServiceBase {
  ApiService._();
  static final ApiService instance = ApiService._();
  factory ApiService() => instance;

  final Dio _dio = ApiClient.instance.dio;

  // ─── Local alerts cache for sync helpers ───────────
  List<AlertResponse> _alertsCache = [];

  // ─── Error mapping ─────────────────────────────────

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Check your network.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }

  // ─── Auth ──────────────────────────────────────────

  @override
  Future<TokenResponse> login(String email, String password) async {
    try {
      // FastAPI OAuth2PasswordRequestForm uses form-encoded body
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: FormData.fromMap({'username': email, 'password': password}),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      return TokenResponse.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<TokenResponse> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'password': password, 'full_name': fullName},
      );
      return TokenResponse.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<UserProfileResponse> getCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/me');
      return UserProfileResponse.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── Jobs ──────────────────────────────────────────

  @override
  Future<PaginatedResponse<JobListItem>> getJobs({
    List<String>? companySlugs,
    String? location,
    String? role,
    String? locationType,
    int daysAgo = 7,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/jobs',
        queryParameters: {
          // Backend expects repeated ?company= params (FastAPI List[str]).
          // Dio serializes a List value as repeated query params automatically.
          if (companySlugs != null && companySlugs.isNotEmpty)
            'company': companySlugs,
          if (location != null) 'location': location,
          if (role != null && role.isNotEmpty) 'role': role,
          if (locationType != null && locationType.isNotEmpty)
            'location_type': locationType,
          'days_ago': daysAgo,
          'page': page,
          'limit': limit,
        },
      );
      final data = res.data!;
      return PaginatedResponse<JobListItem>(
        items: (data['items'] as List)
            .map((j) => JobListItem.fromJson(j as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int,
        page: data['page'] as int,
        limit: data['limit'] as int,
        pages: data['pages'] as int,
      );
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<JobDetail> getJobDetail(String jobId) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/jobs/$jobId');
      return JobDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<SkillGapResponse> getSkillGap(String jobId) async {
    try {
      final res = await _dio
          .get<Map<String, dynamic>>('/jobs/$jobId/skill-gap');
      return SkillGapResponseParsing.fromJson(res.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── Companies ─────────────────────────────────────

  @override
  Future<List<CompanyResponse>> getCompanies() async {
    try {
      final res = await _dio.get<List<dynamic>>('/companies');
      return (res.data!)
          .map((c) => CompanyResponse.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── Alerts ────────────────────────────────────────

  @override
  Future<PaginatedResponse<AlertResponse>> getAlerts({
    bool unreadOnly = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/alerts',
        queryParameters: {
          'unread_only': unreadOnly,
          'page': page,
          'limit': limit,
        },
      );
      final data = res.data!;
      final alerts = (data['items'] as List)
          .map((a) => AlertResponseParsing.fromJson(a as Map<String, dynamic>))
          .toList();

      // Update cache whenever we fetch alerts
      if (page == 1) {
        _alertsCache = alerts;
      } else {
        _alertsCache = [..._alertsCache, ...alerts];
      }

      return PaginatedResponse<AlertResponse>(
        items: alerts,
        total: data['total'] as int,
        page: data['page'] as int,
        limit: data['limit'] as int,
        pages: data['pages'] as int,
      );
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> markAlertRead(String alertId) async {
    try {
      await _dio.patch<void>('/alerts/$alertId/read');
      // Update cache
      final idx = _alertsCache.indexWhere((a) => a.id == alertId);
      if (idx != -1) _alertsCache[idx].isRead = true;
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> toggleAlertSaved(String alertId) async {
    try {
      await _dio.patch<void>('/alerts/$alertId/saved');
      final idx = _alertsCache.indexWhere((a) => a.id == alertId);
      if (idx != -1) {
        _alertsCache[idx].isSaved = !_alertsCache[idx].isSaved;
      }
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> markAlertApplied(String alertId) async {
    try {
      await _dio.patch<void>('/alerts/$alertId/applied');
      final idx = _alertsCache.indexWhere((a) => a.id == alertId);
      if (idx != -1) _alertsCache[idx].isApplied = true;
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── Job save convenience (cache-backed) ───────────

  @override
  bool isJobSaved(String jobId) {
    return _alertsCache.any((a) => a.job.id == jobId && a.isSaved);
  }

  @override
  Future<bool> toggleJobSaved(String jobId) async {
    final alertId = alertIdForJob(jobId);
    if (alertId == null) return false;
    await toggleAlertSaved(alertId);
    return isJobSaved(jobId);
  }

  @override
  String? alertIdForJob(String jobId) {
    try {
      return _alertsCache.firstWhere((a) => a.job.id == jobId).id;
    } catch (_) {
      return null;
    }
  }

  // ─── Preferences ───────────────────────────────────

  @override
  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    try {
      await _dio.put<void>('/users/me/preferences', data: prefs);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── Skills ────────────────────────────────────────

  @override
  Future<List<String>> getUserSkills() async {
    try {
      final res = await _dio.get<List<dynamic>>('/users/me/skills');
      return res.data!.cast<String>();
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> addUserSkill(String skill) async {
    try {
      await _dio.post<void>('/users/me/skills', data: {'skill': skill});
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> removeUserSkill(String skill) async {
    try {
      await _dio.delete<void>('/users/me/skills/$skill');
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  // ─── CV Management ─────────────────────────────────

  @override
  Future<CVResponse> uploadCv(
    List<int> bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Compute SHA-256 hash of the file bytes (used for deduplication)
      final digest = sha256.convert(bytes);
      final fileHash = digest.toString();

      // ── Step 1: Request presigned POST URL from our API ──────────────────
      final presignRes = await _dio.post<Map<String, dynamic>>(
        '/users/me/cv/presign',
        data: {
          'filename': filename,
          'file_size_bytes': bytes.length,
          'file_hash': fileHash,
        },
      );
      final presign = CVPresignResponse.fromJson(presignRes.data!);

      // ── Step 2: Upload directly to S3 (not through our API) ─────────────
      // S3 presigned POST requires all policy fields BEFORE the file field.
      final s3Form = FormData();
      presign.fields.forEach((key, value) {
        s3Form.fields.add(MapEntry(key, value.toString()));
      });
      s3Form.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType('application', 'pdf'),
        ),
      ));

      // Use a plain Dio instance — S3 does not accept our JWT Authorization header.
      final s3Dio = Dio();
      await s3Dio.post<void>(
        presign.uploadUrl,
        data: s3Form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
        options: Options(
          // S3 presigned POST returns 204 on success — treat as success.
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      // ── Step 3: Confirm with our API to trigger Celery processing ────────
      final confirmRes = await _dio.post<Map<String, dynamic>>(
        '/users/me/cv/${presign.cvId}/confirm',
        data: {'file_hash': fileHash},
      );
      return CVResponse.fromJson(confirmRes.data!);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<List<CVResponse>> listCvs() async {
    try {
      final res = await _dio.get<List<dynamic>>('/users/me/cv');
      return (res.data!)
          .map((c) => CVResponse.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<String> getCvDownloadUrl(String cvId) async {
    try {
      final res = await _dio
          .get<Map<String, dynamic>>('/users/me/cv/$cvId/download-url');
      return res.data!['download_url'] as String;
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  @override
  Future<void> deleteCv(String cvId) async {
    try {
      await _dio.delete<void>('/users/me/cv/$cvId');
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }
}

// ─── fromJson for SkillGapResponse ─────────────────────────────
// (placed here to avoid modifying models.dart)
extension SkillGapResponseParsing on SkillGapResponse {
  static SkillGapResponse fromJson(Map<String, dynamic> json) {
    return SkillGapResponse(
      jobId: json['job_id'] as String,
      jobTitle: json['job_title'] as String,
      matchPercentage: (json['match_percentage'] as num).toDouble(),
      recommendation: json['recommendation'] as String,
      matchingSkills: (json['matching_skills'] as List? ?? [])
          .map((s) => SkillMatch(
                skillName: s['skill_name'] as String,
                userLevel: s['user_level'] as String?,
                requiredLevel: s['required_level'] as String?,
              ))
          .toList(),
      missingSkills: (json['missing_skills'] as List? ?? [])
          .map((s) => MissingSkill(
                skillName: s['skill_name'] as String,
                isRequired: s['is_required'] as bool? ?? true,
                category: s['category'] as String?,
              ))
          .toList(),
      partialSkills: (json['partial_skills'] as List? ?? [])
          .map((s) => PartialSkill(
                skillName: s['skill_name'] as String,
                userYears: (s['user_years'] as num?)?.toDouble(),
                requiredYears: s['required_years'] as int?,
                gap: s['gap'] as String? ?? 'Need more experience',
              ))
          .toList(),
    );
  }
}

// ─── fromJson for AlertResponse ────────────────────────────────
extension AlertResponseParsing on AlertResponse {
  static AlertResponse fromJson(Map<String, dynamic> json) {
    return AlertResponse(
      id: json['id'] as String,
      isRead: json['is_read'] as bool? ?? false,
      isSaved: json['is_saved'] as bool? ?? false,
      isApplied: json['is_applied'] as bool? ?? false,
      job: JobListItem.fromJson(json['job'] as Map<String, dynamic>),
      notifiedAt: DateTime.parse(json['notified_at'] as String),
      notificationChannel: json['notification_channel'] as String?,
      isDelivered: json['is_delivered'] as bool? ?? true,
      appliedAt: json['applied_at'] != null
          ? DateTime.parse(json['applied_at'] as String)
          : null,
    );
  }
}
