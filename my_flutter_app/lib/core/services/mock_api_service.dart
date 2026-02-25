import 'dart:math';

import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/api_service_base.dart';
import 'package:job_scout/core/services/mock_data.dart';

/// Offline mock service with simulated network delays.
/// Implements [ApiServiceBase] so it is drop-in replaceable by [ApiService].
class MockApiService extends ApiServiceBase {
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  final _random = Random();

  Future<T> _withDelay<T>(T data) async {
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));
    return data;
  }

  // ─── Auth ──────────────────────────────────────────

  @override
  Future<TokenResponse> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email == 'dev@jobscout.com' && password == 'password123') {
      return const TokenResponse(
        accessToken: 'mock-access-token-xyz',
        refreshToken: 'mock-refresh-token-xyz',
        expiresIn: 1800,
      );
    }
    throw Exception('Invalid email or password');
  }

  @override
  Future<TokenResponse> register(
    String email,
    String password,
    String fullName,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return const TokenResponse(
      accessToken: 'mock-access-token-new',
      refreshToken: 'mock-refresh-token-new',
      expiresIn: 1800,
    );
  }

  @override
  Future<UserProfileResponse> getCurrentUser() {
    return _withDelay(mockUser);
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
    var filtered = List<JobListItem>.from(mockJobs);

    if (companySlugs != null && companySlugs.isNotEmpty) {
      filtered = filtered
          .where((j) => companySlugs.contains(j.company.slug))
          .toList();
    }
    if (locationType != null && locationType.isNotEmpty) {
      filtered =
          filtered.where((j) => j.locationType == locationType).toList();
    }
    if (role != null && role.isNotEmpty) {
      final query = role.toLowerCase();
      filtered = filtered
          .where((j) => j.title.toLowerCase().contains(query))
          .toList();
    }

    final cutoff = DateTime.now().subtract(Duration(days: daysAgo));
    filtered = filtered.where((j) => j.discoveredAt.isAfter(cutoff)).toList();

    final total = filtered.length;
    final start = (page - 1) * limit;
    final end = start + limit > total ? total : start + limit;
    final items = start < total ? filtered.sublist(start, end) : <JobListItem>[];

    return _withDelay(PaginatedResponse(
      items: items,
      total: total,
      page: page,
      limit: limit,
      pages: (total / limit).ceil().clamp(1, 999),
    ));
  }

  @override
  Future<JobDetail> getJobDetail(String jobId) async {
    final detail = mockJobDetails[jobId];
    if (detail != null) return _withDelay(detail);

    final listItem = mockJobs.firstWhere(
      (j) => j.id == jobId,
      orElse: () => throw Exception('Job not found'),
    );
    return _withDelay(JobDetail(
      id: listItem.id,
      title: listItem.title,
      location: listItem.location,
      locationType: listItem.locationType,
      jobType: listItem.jobType,
      applyUrl: listItem.applyUrl,
      company: listItem.company,
      postedAt: listItem.postedAt,
      discoveredAt: listItem.discoveredAt,
      description: 'Full job description for ${listItem.title} at ${listItem.company.name}.',
      skills: const [],
      createdAt: listItem.discoveredAt,
      updatedAt: listItem.discoveredAt,
    ));
  }

  @override
  Future<SkillGapResponse> getSkillGap(String jobId) async {
    final gap = mockSkillGaps[jobId];
    if (gap != null) return _withDelay(gap);
    return _withDelay(SkillGapResponse(
      jobId: jobId,
      jobTitle: 'Unknown',
      matchPercentage: 50.0,
      recommendation: 'No detailed skill analysis available for this job.',
    ));
  }

  // ─── Companies ─────────────────────────────────────

  @override
  Future<List<CompanyResponse>> getCompanies() {
    return _withDelay(List<CompanyResponse>.from(mockCompanies));
  }

  // ─── Alerts ────────────────────────────────────────

  @override
  Future<PaginatedResponse<AlertResponse>> getAlerts({
    bool unreadOnly = false,
    int page = 1,
    int limit = 20,
  }) async {
    var filtered = List<AlertResponse>.from(mockAlerts);
    if (unreadOnly) {
      filtered = filtered.where((a) => !a.isRead).toList();
    }
    final total = filtered.length;
    final start = (page - 1) * limit;
    final end = start + limit > total ? total : start + limit;
    final items =
        start < total ? filtered.sublist(start, end) : <AlertResponse>[];
    return _withDelay(PaginatedResponse(
      items: items,
      total: total,
      page: page,
      limit: limit,
      pages: (total / limit).ceil().clamp(1, 999),
    ));
  }

  @override
  Future<void> markAlertRead(String alertId) async {
    await _withDelay(null);
    mockAlerts.firstWhere((a) => a.id == alertId).isRead = true;
  }

  @override
  Future<void> toggleAlertSaved(String alertId) async {
    await _withDelay(null);
    final alert = mockAlerts.firstWhere((a) => a.id == alertId);
    alert.isSaved = !alert.isSaved;
  }

  @override
  Future<void> markAlertApplied(String alertId) async {
    await _withDelay(null);
    mockAlerts.firstWhere((a) => a.id == alertId).isApplied = true;
  }

  @override
  bool isJobSaved(String jobId) {
    return mockAlerts.any((a) => a.job.id == jobId && a.isSaved);
  }

  @override
  Future<bool> toggleJobSaved(String jobId) async {
    await _withDelay(null);
    final idx = mockAlerts.indexWhere((a) => a.job.id == jobId);
    if (idx == -1) return false;
    mockAlerts[idx].isSaved = !mockAlerts[idx].isSaved;
    return mockAlerts[idx].isSaved;
  }

  @override
  String? alertIdForJob(String jobId) {
    try {
      return mockAlerts.firstWhere((a) => a.job.id == jobId).id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    await _withDelay(null);
    mockUser.preferences.addAll(prefs);
  }

  // ─── Skills ────────────────────────────────────────

  @override
  Future<List<String>> getUserSkills() {
    return _withDelay(List<String>.from(mockUserSkills));
  }

  @override
  Future<void> addUserSkill(String skill) async {
    await _withDelay(null);
    if (!mockUserSkills.contains(skill)) mockUserSkills.add(skill);
  }

  @override
  Future<void> removeUserSkill(String skill) async {
    await _withDelay(null);
    mockUserSkills.remove(skill);
  }

  // ─── CV Management ─────────────────────────────────

  // In-memory list of mock CVs
  final List<CVResponse> _mockCvs = [];

  @override
  Future<CVResponse> uploadCv(
    List<int> bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) async {
    // Simulate upload progress
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      onProgress?.call(i / 5);
    }
    final cv = CVResponse(
      id: 'mock-cv-${_mockCvs.length + 1}',
      filename: filename,
      fileSizeBytes: bytes.length,
      fileHash: 'mock-sha256-hash',
      uploadStatus: 'ready',
      skillsExtracted: 12,
      isActive: true,
      createdAt: DateTime.now(),
      processedAt: DateTime.now(),
    );
    _mockCvs.add(cv);
    // Flip hasCv on the mock user
    mockUser.preferences['has_cv'] = true;
    return cv;
  }

  @override
  Future<List<CVResponse>> listCvs() => _withDelay(List.from(_mockCvs));

  @override
  Future<String> getCvDownloadUrl(String cvId) =>
      _withDelay('https://mock-s3.example.com/cv/$cvId/resume.pdf');

  @override
  Future<void> deleteCv(String cvId) async {
    await _withDelay(null);
    _mockCvs.removeWhere((cv) => cv.id == cvId);
  }
}
