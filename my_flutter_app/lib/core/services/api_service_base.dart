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

  /// Best-effort server-side logout: revokes the refresh-token session and
  /// denylists the current access token. Must never throw.
  Future<void> logout(String? refreshToken);

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

  /// Jobs ranked by skill overlap with the user's CV skills.
  /// Empty when the user has no extracted skills — callers hide the section.
  Future<PaginatedResponse<RecommendedJob>> getRecommendedJobs({
    int page = 1,
    int limit = 10,
  });

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

  /// Register this device's FCM token so the backend can push job alerts.
  /// Called after login and whenever Firebase rotates the token.
  Future<void> updateFcmToken(String fcmToken);

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

  // ─── AI / ATS ───────────────────────────────────────────

  /// Analyze a CV against a job. Returns cached result or task_id for polling.
  Future<CVTaskStatusResponse> analyzeCv(String cvId, String jobId);

  /// Tailor a CV for a specific job. Always async — returns task_id for polling.
  Future<CVTaskStatusResponse> tailorCv(String cvId, String jobId);

  /// Poll a Celery task by ID.
  Future<CVTaskStatusResponse> getCvTaskStatus(String taskId);

  // ─── CV Drafts (full-CV curation) ──────────────────

  /// Start curating a full CV against a job. Supersedes any prior
  /// non-terminal draft for the same (cv, job). Rate-limited (429).
  Future<CurateStartResponse> curateCv(String cvId, String jobId);

  /// The caller's curation drafts, newest first (superseded excluded).
  Future<List<CVDraft>> listDrafts();

  Future<CVDraft> getDraft(String draftId);

  /// Persist user edits to the tailored structure (review stage only).
  Future<CVDraft> updateDraft(String draftId, CVStructure tailored);

  /// Approve a reviewed draft — enqueues DOCX/PDF rendering.
  Future<CurateStartResponse> approveDraft(String draftId);

  /// Presigned download URL for a rendered document. 409 until rendered.
  /// [format] is 'pdf' or 'docx'.
  Future<String> getDraftDownloadUrl(String draftId, String format);

  // ─── Career state ──────────────────────────────────

  /// Set career state: actively_looking | open | not_looking.
  /// A real column on the user, not a preferences key — it reconfigures
  /// which mode the product presents.
  Future<void> updateCareerState(String careerState);

  // ─── Employments ───────────────────────────────────

  /// The caller's roles, most recent first.
  Future<List<Employment>> listEmployments();

  /// Add a role. Marking it current demotes any previous current role.
  Future<Employment> createEmployment({
    required String employerName,
    required String roleTitle,
    required DateTime startDate,
    DateTime? endDate,
    bool isCurrent = false,
  });

  Future<Employment> updateEmployment(
    String employmentId, {
    String? employerName,
    String? roleTitle,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
  });

  /// Soft delete — correcting a mistake must not erase career history.
  Future<void> deleteEmployment(String employmentId);

  // ─── Achievement log ───────────────────────────────

  /// Log a win in your own words. Returns 202 immediately; structuring runs
  /// in the background, because a habit feature that waits on a model call
  /// is a habit feature people abandon.
  Future<AchievementStartResponse> logAchievement(
    String rawText, {
    DateTime? occurredAt,
    String? employmentId,
  });

  /// The caller's logged wins, most recent first.
  Future<List<Achievement>> listAchievements({
    DateTime? from,
    DateTime? to,
    String? employmentId,
    String? category,
    int limit = 50,
  });

  Future<Achievement> getAchievement(String achievementId);

  /// Correct your own words (re-runs structuring) or re-file the entry.
  Future<Achievement> updateAchievement(
    String achievementId, {
    String? rawText,
    DateTime? occurredAt,
    String? employmentId,
  });

  Future<void> deleteAchievement(String achievementId);

  /// How you've grown — the payoff for someone who is *not* job hunting.
  Future<AchievementDigest> getAchievementDigest({int months = 6});

  /// Your real achievements that answer a given interview question.
  /// Deterministic server-side ranking, no AI call.
  Future<List<AchievementEvidence>> getQuestionEvidence(
    String questionId, {
    int limit = 3,
  });

  // ─── Interview practice ────────────────────────────────

  /// Questions from the practice bank, optionally by category.
  Future<List<PracticeQuestion>> getPracticeQuestions({
    String? category,
    int limit = 20,
  });

  /// Start a practice sitting.
  Future<PracticeSession> startPracticeSession({
    String? jobId,
    int? confidenceBefore,
  });

  /// The caller's sittings, newest first (answers omitted).
  Future<List<PracticeSession>> listPracticeSessions({int limit = 20});

  /// One sitting with all its answers and debriefs.
  Future<PracticeSession> getPracticeSession(String sessionId);

  /// End a sitting and/or record how the user feels afterwards.
  Future<PracticeSession> updatePracticeSession(
    String sessionId, {
    bool? ended,
    int? confidenceAfter,
  });

  /// Upload a recorded answer: presign → S3 → confirm.
  ///
  /// Returns the 202 that starts analysis. The recording is transcribed,
  /// measured, scored, and then **deleted server-side** — only the transcript
  /// and scores survive.
  Future<AnalyzeStartResponse> uploadAnswer({
    required String sessionId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? questionId,
    String? questionText,
    void Function(double progress)? onProgress,
  });

  /// One answer with its metrics, scores, takeaways and assigned drill.
  Future<PracticeAnswer> getPracticeAnswer(String answerId);

  /// Poll an analysis task.
  Future<CVTaskStatusResponse> getCoachTaskStatus(String taskId);
}
