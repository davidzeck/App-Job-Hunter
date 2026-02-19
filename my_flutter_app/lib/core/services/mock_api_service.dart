import 'dart:math';

import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/mock_data.dart';

/// Async mock service with simulated network delays.
/// Method signatures match the real API contract exactly,
/// so swapping to a real Dio-based service later is a one-line change.
class MockApiService {
  static final MockApiService _instance = MockApiService._internal();
  factory MockApiService() => _instance;
  MockApiService._internal();

  final _random = Random();

  Future<T> _withDelay<T>(T data) async {
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));
    return data;
  }

  // ─── Auth ──────────────────────────────────────────

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

  Future<UserProfileResponse> getCurrentUser() {
    return _withDelay(mockUser);
  }

  // ─── Jobs ──────────────────────────────────────────

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

    // Filter by company
    if (companySlugs != null && companySlugs.isNotEmpty) {
      filtered = filtered
          .where((j) => companySlugs.contains(j.company.slug))
          .toList();
    }

    // Filter by location type
    if (locationType != null && locationType.isNotEmpty) {
      filtered =
          filtered.where((j) => j.locationType == locationType).toList();
    }

    // Filter by role keyword
    if (role != null && role.isNotEmpty) {
      final query = role.toLowerCase();
      filtered = filtered
          .where((j) => j.title.toLowerCase().contains(query))
          .toList();
    }

    // Filter by recency
    final cutoff = DateTime.now().subtract(Duration(days: daysAgo));
    filtered =
        filtered.where((j) => j.discoveredAt.isAfter(cutoff)).toList();

    // Paginate
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

  Future<JobDetail> getJobDetail(String jobId) async {
    final detail = mockJobDetails[jobId];
    if (detail != null) return _withDelay(detail);

    // Fallback: create a basic detail from the list item
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

  Future<List<CompanyResponse>> getCompanies() {
    return _withDelay(List<CompanyResponse>.from(mockCompanies));
  }

  // ─── Alerts ────────────────────────────────────────

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

  Future<void> markAlertRead(String alertId) async {
    await _withDelay(null);
    final alert = mockAlerts.firstWhere((a) => a.id == alertId);
    alert.isRead = true;
  }

  Future<void> toggleAlertSaved(String alertId) async {
    await _withDelay(null);
    final alert = mockAlerts.firstWhere((a) => a.id == alertId);
    alert.isSaved = !alert.isSaved;
  }

  Future<void> markAlertApplied(String alertId) async {
    await _withDelay(null);
    final alert = mockAlerts.firstWhere((a) => a.id == alertId);
    alert.isApplied = true;
  }
}
