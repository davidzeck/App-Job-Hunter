import 'package:job_scout/core/models/models.dart';

/// Abstract contract for the Job Scout API.
///
/// [MockApiService] implements this for offline/demo mode.
/// [ApiService] implements this for real HTTP calls.
///
/// All screens depend only on [ApiServiceBase] — swapping
/// the implementation is a single change in service_locator.dart.
abstract class ApiServiceBase {
  // ─── Auth ──────────────────────────────────────────

  Future<TokenResponse> login(String email, String password);

  Future<TokenResponse> register(
    String email,
    String password,
    String fullName,
  );

  Future<UserProfileResponse> getCurrentUser();

  // ─── Jobs ──────────────────────────────────────────

  Future<PaginatedResponse<JobListItem>> getJobs({
    List<String>? companySlugs,
    String? location,
    String? role,
    String? locationType,
    int daysAgo = 7,
    int page = 1,
    int limit = 20,
  });

  Future<JobDetail> getJobDetail(String jobId);

  Future<SkillGapResponse> getSkillGap(String jobId);

  // ─── Companies ─────────────────────────────────────

  Future<List<CompanyResponse>> getCompanies();

  // ─── Alerts ────────────────────────────────────────

  Future<PaginatedResponse<AlertResponse>> getAlerts({
    bool unreadOnly = false,
    int page = 1,
    int limit = 20,
  });

  Future<void> markAlertRead(String alertId);

  Future<void> toggleAlertSaved(String alertId);

  Future<void> markAlertApplied(String alertId);

  // ─── Job save convenience (backed by alerts cache) ─

  /// Synchronous — reads local cache populated by [getAlerts].
  bool isJobSaved(String jobId);

  Future<bool> toggleJobSaved(String jobId);

  /// Returns the alertId for a given jobId, null if not found.
  String? alertIdForJob(String jobId);

  // ─── Preferences ───────────────────────────────────

  Future<void> updatePreferences(Map<String, dynamic> prefs);

  // ─── Skills ────────────────────────────────────────

  Future<List<String>> getUserSkills();

  Future<void> addUserSkill(String skill);

  Future<void> removeUserSkill(String skill);

  // ─── CV Management ─────────────────────────────────

  /// 3-step upload: presign → S3 → confirm.
  /// Accepts the raw file bytes + original filename.
  /// [onProgress] is called with values from 0.0 to 1.0 during the S3 upload.
  Future<CVResponse> uploadCv(
    List<int> bytes,
    String filename, {
    void Function(double progress)? onProgress,
  });

  /// List all active CVs for the current user.
  Future<List<CVResponse>> listCvs();

  /// Get a time-limited presigned download URL for a CV.
  Future<String> getCvDownloadUrl(String cvId);

  /// Soft-delete a CV and remove it from S3.
  Future<void> deleteCv(String cvId);
}
