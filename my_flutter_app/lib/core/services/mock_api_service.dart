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
  Future<void> logout(String? refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 200));
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
  Future<PaginatedResponse<RecommendedJob>> getRecommendedJobs({
    int page = 1,
    int limit = 10,
  }) async {
    // Deterministic fake scores over the mock jobs (descending by score).
    const fakeSkills = [
      ['Python', 'FastAPI', 'PostgreSQL'],
      ['Flutter', 'Dart', 'Firebase'],
      ['React', 'TypeScript'],
      ['Docker', 'Kubernetes'],
    ];
    final recommended = <RecommendedJob>[];
    for (var i = 0; i < mockJobs.length && i < limit; i++) {
      final job = mockJobs[i];
      recommended.add(RecommendedJob(
        id: job.id,
        title: job.title,
        location: job.location,
        locationType: job.locationType,
        jobType: job.jobType,
        applyUrl: job.applyUrl,
        company: job.company,
        postedAt: job.postedAt,
        discoveredAt: job.discoveredAt,
        isActive: job.isActive,
        matchScore: (90 - i * 12).clamp(35, 100).toDouble(),
        matchedSkills: fakeSkills[i % fakeSkills.length],
      ));
    }
    return _withDelay(PaginatedResponse(
      items: recommended,
      total: recommended.length,
      page: page,
      limit: limit,
      pages: 1,
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

  @override
  Future<void> updateFcmToken(String fcmToken) async {
    await _withDelay(null); // demo mode: nowhere to push to
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

  // ─── AI / ATS ───────────────────────────────────────────

  @override
  Future<CVTaskStatusResponse> analyzeCv(String cvId, String jobId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return CVTaskStatusResponse(
      taskId: 'mock-cached',
      status: 'success',
      result: {
        'cv_id': cvId,
        'job_id': jobId,
        'match_score': 0.74,
        'present_keywords': ['Python', 'FastAPI', 'PostgreSQL', 'Docker', 'REST APIs'],
        'missing_keywords': ['Kubernetes', 'Terraform', 'GraphQL'],
        'suggested_additions': [
          'Add Kubernetes experience from personal projects',
          'Mention CI/CD pipeline work with GitHub Actions',
        ],
        'cached': true,
        'analyzed_at': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<CVTaskStatusResponse> tailorCv(String cvId, String jobId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return CVTaskStatusResponse(
      taskId: 'mock-tailor',
      status: 'success',
      result: {
        'cv_id': cvId,
        'job_id': jobId,
        'tailored_summary':
            'Senior software engineer with 5+ years building scalable backend '
            'systems using Python, FastAPI, and PostgreSQL. Experienced in '
            'containerized deployments with Docker and Kubernetes.',
        'tailored_skills': [
          'Python', 'FastAPI', 'PostgreSQL', 'Docker',
          'Kubernetes', 'REST APIs', 'CI/CD',
        ],
        'keywords_added': ['Kubernetes', 'CI/CD'],
        'original_summary':
            'Software engineer with experience in Python and web development.',
      },
    );
  }

  @override
  Future<CVTaskStatusResponse> getCvTaskStatus(String taskId) async {
    return _withDelay(CVTaskStatusResponse(
      taskId: taskId,
      status: 'success',
      result: {},
    ));
  }

  // ─── CV Drafts (full-CV curation) ──────────────────

  // In-memory drafts with time-based status progression so the
  // client's polling code paths run unchanged in demo mode:
  // generating → review after ~3s, approved → rendered after ~3s.
  final List<CVDraft> _mockDrafts = [];

  static const _mockOriginalStructure = CVStructure(
    contact: CVContact(
      name: 'Demo User',
      email: 'dev@jobscout.com',
      phone: '+254 700 000000',
      location: 'Nairobi, Kenya',
      links: ['github.com/demo-user'],
    ),
    summary:
        'Software engineer with experience in Python and web development.',
    skills: [
      CVSkillGroup(category: 'Languages', items: ['Python', 'JavaScript']),
      CVSkillGroup(category: 'Frameworks', items: ['FastAPI', 'React']),
    ],
    experience: [
      CVExperience(
        title: 'Software Engineer',
        company: 'TechCo Nairobi',
        location: 'Nairobi',
        start: 'Jan 2022',
        end: 'Present',
        bullets: [
          'Built REST APIs with FastAPI and PostgreSQL',
          'Maintained CI pipelines',
        ],
      ),
      CVExperience(
        title: 'Junior Developer',
        company: 'StartupHub',
        location: 'Nairobi',
        start: 'Jun 2020',
        end: 'Dec 2021',
        bullets: ['Developed internal tools in Python'],
      ),
    ],
    education: [
      CVEducation(
        degree: 'BSc Computer Science',
        institution: 'University of Nairobi',
        year: '2020',
      ),
    ],
    certifications: ['AWS Cloud Practitioner'],
  );

  static const _mockTailoredStructure = CVStructure(
    contact: CVContact(
      name: 'Demo User',
      email: 'dev@jobscout.com',
      phone: '+254 700 000000',
      location: 'Nairobi, Kenya',
      links: ['github.com/demo-user'],
    ),
    summary:
        'Backend engineer with 4+ years building scalable Python services '
        '(FastAPI, PostgreSQL) with containerized Kubernetes deployments '
        'and automated CI/CD.',
    skills: [
      CVSkillGroup(
        category: 'Languages',
        items: ['Python', 'JavaScript', 'SQL'],
      ),
      CVSkillGroup(
        category: 'Frameworks & Tools',
        items: ['FastAPI', 'React', 'Docker', 'Kubernetes', 'CI/CD'],
      ),
    ],
    experience: [
      CVExperience(
        title: 'Software Engineer',
        company: 'TechCo Nairobi',
        location: 'Nairobi',
        start: 'Jan 2022',
        end: 'Present',
        bullets: [
          'Designed and shipped REST APIs with FastAPI and PostgreSQL serving 10k+ daily requests',
          'Automated CI/CD pipelines, cutting release time by 60%',
        ],
      ),
      CVExperience(
        title: 'Junior Developer',
        company: 'StartupHub',
        location: 'Nairobi',
        start: 'Jun 2020',
        end: 'Dec 2021',
        bullets: ['Developed internal Python tooling adopted by 3 teams'],
      ),
    ],
    education: [
      CVEducation(
        degree: 'BSc Computer Science',
        institution: 'University of Nairobi',
        year: '2020',
      ),
    ],
    certifications: ['AWS Cloud Practitioner'],
  );

  /// Advance time-based mock status transitions in place.
  void _progressDrafts() {
    final now = DateTime.now();
    for (var i = 0; i < _mockDrafts.length; i++) {
      final d = _mockDrafts[i];
      if (d.isGenerating && now.difference(d.createdAt).inSeconds >= 3) {
        _mockDrafts[i] = CVDraft(
          id: d.id,
          cvId: d.cvId,
          jobId: d.jobId,
          status: 'review',
          content: const CVDraftContent(
            original: _mockOriginalStructure,
            tailored: _mockTailoredStructure,
            keywordsInjected: ['Kubernetes', 'CI/CD'],
          ),
          createdAt: d.createdAt,
          updatedAt: now,
        );
      } else if (d.isApproved &&
          d.approvedAt != null &&
          now.difference(d.approvedAt!).inSeconds >= 3) {
        _mockDrafts[i] = CVDraft(
          id: d.id,
          cvId: d.cvId,
          jobId: d.jobId,
          status: 'rendered',
          content: d.content,
          docxReady: true,
          pdfReady: true,
          approvedAt: d.approvedAt,
          createdAt: d.createdAt,
          updatedAt: now,
        );
      }
    }
  }

  @override
  Future<CurateStartResponse> curateCv(String cvId, String jobId) async {
    await _withDelay(null);
    // A new curation supersedes any prior non-terminal draft for (cv, job).
    for (var i = 0; i < _mockDrafts.length; i++) {
      final d = _mockDrafts[i];
      if (d.cvId == cvId && d.jobId == jobId && !d.isFailed && !d.isSuperseded) {
        _mockDrafts[i] = CVDraft(
          id: d.id,
          cvId: d.cvId,
          jobId: d.jobId,
          status: 'superseded',
          content: d.content,
          docxReady: d.docxReady,
          pdfReady: d.pdfReady,
          approvedAt: d.approvedAt,
          createdAt: d.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    final draft = CVDraft(
      id: 'mock-draft-${_mockDrafts.length + 1}',
      cvId: cvId,
      jobId: jobId,
      status: 'generating',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockDrafts.add(draft);
    return CurateStartResponse(
      taskId: 'mock-curate-${_mockDrafts.length}',
      draftId: draft.id,
    );
  }

  @override
  Future<List<CVDraft>> listDrafts() async {
    _progressDrafts();
    return _withDelay(
      _mockDrafts.where((d) => !d.isSuperseded).toList().reversed.toList(),
    );
  }

  @override
  Future<CVDraft> getDraft(String draftId) async {
    _progressDrafts();
    return _withDelay(
      _mockDrafts.firstWhere(
        (d) => d.id == draftId,
        orElse: () => throw Exception('Draft not found'),
      ),
    );
  }

  @override
  Future<CVDraft> updateDraft(String draftId, CVStructure tailored) async {
    await _withDelay(null);
    final i = _mockDrafts.indexWhere((d) => d.id == draftId);
    if (i < 0) throw Exception('Draft not found');
    final d = _mockDrafts[i];
    _mockDrafts[i] = CVDraft(
      id: d.id,
      cvId: d.cvId,
      jobId: d.jobId,
      status: d.status,
      content: CVDraftContent(
        original: d.content?.original ?? _mockOriginalStructure,
        tailored: tailored,
        keywordsInjected: d.content?.keywordsInjected ?? const [],
      ),
      createdAt: d.createdAt,
      updatedAt: DateTime.now(),
    );
    return _mockDrafts[i];
  }

  @override
  Future<CurateStartResponse> approveDraft(String draftId) async {
    await _withDelay(null);
    final i = _mockDrafts.indexWhere((d) => d.id == draftId);
    if (i < 0) throw Exception('Draft not found');
    final d = _mockDrafts[i];
    _mockDrafts[i] = CVDraft(
      id: d.id,
      cvId: d.cvId,
      jobId: d.jobId,
      status: 'approved',
      content: d.content,
      approvedAt: DateTime.now(),
      createdAt: d.createdAt,
      updatedAt: DateTime.now(),
    );
    return CurateStartResponse(taskId: 'mock-render-$draftId', draftId: draftId);
  }

  @override
  Future<String> getDraftDownloadUrl(String draftId, String format) =>
      _withDelay('https://mock-s3.example.com/drafts/$draftId/cv.$format');

  // ─── Career state ──────────────────────────────────

  @override
  Future<void> updateCareerState(String careerState) async {
    await _withDelay(null);
    mockUser = UserProfileResponse(
      id: mockUser.id,
      email: mockUser.email,
      fullName: mockUser.fullName,
      phone: mockUser.phone,
      emailVerified: mockUser.emailVerified,
      isActive: mockUser.isActive,
      preferences: mockUser.preferences,
      lastSeenAt: mockUser.lastSeenAt,
      createdAt: mockUser.createdAt,
      updatedAt: DateTime.now(),
      skillsCount: mockUser.skillsCount,
      hasCv: mockUser.hasCv,
      careerState: careerState,
    );
  }

  // ─── Employments ───────────────────────────────────

  @override
  Future<List<Employment>> listEmployments() => _withDelay(
        [...mockEmployments]
          ..sort((a, b) => b.startDate.compareTo(a.startDate)),
      );

  @override
  Future<Employment> createEmployment({
    required String employerName,
    required String roleTitle,
    required DateTime startDate,
    DateTime? endDate,
    bool isCurrent = false,
  }) async {
    await _withDelay(null);
    // At most one current role — the backend demotes rather than failing.
    if (isCurrent) _demoteCurrent();
    final employment = Employment(
      id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
      employerName: employerName,
      roleTitle: roleTitle,
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
    );
    mockEmployments.add(employment);
    return employment;
  }

  @override
  Future<Employment> updateEmployment(
    String employmentId, {
    String? employerName,
    String? roleTitle,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
  }) async {
    await _withDelay(null);
    final i = mockEmployments.indexWhere((e) => e.id == employmentId);
    if (i < 0) throw Exception('Employment not found');
    if (isCurrent == true) _demoteCurrent();
    final e = mockEmployments[i];
    final updated = Employment(
      id: e.id,
      employerName: employerName ?? e.employerName,
      roleTitle: roleTitle ?? e.roleTitle,
      companyId: e.companyId,
      startDate: startDate ?? e.startDate,
      endDate: endDate ?? e.endDate,
      isCurrent: isCurrent ?? e.isCurrent,
      seniority: e.seniority,
    );
    mockEmployments[i] = updated;
    return updated;
  }

  void _demoteCurrent() {
    for (var i = 0; i < mockEmployments.length; i++) {
      final e = mockEmployments[i];
      if (!e.isCurrent) continue;
      mockEmployments[i] = Employment(
        id: e.id,
        employerName: e.employerName,
        roleTitle: e.roleTitle,
        companyId: e.companyId,
        startDate: e.startDate,
        endDate: e.endDate,
        isCurrent: false,
        seniority: e.seniority,
      );
    }
  }

  @override
  Future<void> deleteEmployment(String employmentId) async {
    await _withDelay(null);
    mockEmployments.removeWhere((e) => e.id == employmentId);
  }

  // ─── Achievement log ───────────────────────────────

  /// Mock structuring: entries flip from `structuring` to `structured` a few
  /// seconds after capture, exactly as the Celery task does.
  final Map<String, DateTime> _structuringSince = {};

  void _progressAchievements() {
    final now = DateTime.now();
    for (var i = 0; i < mockAchievements.length; i++) {
      final a = mockAchievements[i];
      final since = _structuringSince[a.id];
      if (since == null || now.difference(since).inSeconds < 3) continue;
      _structuringSince.remove(a.id);
      final metric = _guessMetric(a.rawText);
      mockAchievements[i] = Achievement(
        id: a.id,
        employmentId: a.employmentId,
        occurredAt: a.occurredAt,
        rawText: a.rawText,
        captureMode: a.captureMode,
        status: 'structured',
        headline: _firstSentence(a.rawText),
        structured: {
          'action': _firstSentence(a.rawText),
          'impact': '',
          'metric': metric ?? '',
          'skills': const ['Communication'],
          'category': 'delivery',
          'cv_bullet': _firstSentence(a.rawText),
        },
        needsMetric: metric == null,
      );
    }
  }

  /// Stands in for the model's metric extraction: any digit in the text
  /// counts, so the demo can reach both the nudge and the no-nudge path.
  static String? _guessMetric(String text) {
    final match = RegExp(r'\d+\s*%|\d[\d,.]*\s*\w*').firstMatch(text);
    return match?.group(0)?.trim();
  }

  static String _firstSentence(String text) {
    final trimmed = text.trim();
    final stop = trimmed.indexOf(RegExp(r'[.!?]'));
    final head = stop > 0 ? trimmed.substring(0, stop) : trimmed;
    return head.length > 120 ? '${head.substring(0, 117)}…' : head;
  }

  @override
  Future<AchievementStartResponse> logAchievement(
    String rawText, {
    DateTime? occurredAt,
    String? employmentId,
  }) async {
    await _withDelay(null);
    final current = mockEmployments.where((e) => e.isCurrent);
    final id = 'ach-${DateTime.now().millisecondsSinceEpoch}';
    mockAchievements.add(Achievement(
      id: id,
      employmentId:
          employmentId ?? (current.isEmpty ? null : current.first.id),
      occurredAt: occurredAt ?? DateTime.now(),
      rawText: rawText,
      status: 'structuring',
    ));
    _structuringSince[id] = DateTime.now();
    return AchievementStartResponse(achievementId: id, taskId: 'mock-task-$id');
  }

  @override
  Future<List<Achievement>> listAchievements({
    DateTime? from,
    DateTime? to,
    String? employmentId,
    String? category,
    int limit = 50,
  }) async {
    _progressAchievements();
    final items = mockAchievements.where((a) {
      if (from != null && a.occurredAt.isBefore(from)) return false;
      if (to != null && a.occurredAt.isAfter(to)) return false;
      if (employmentId != null && a.employmentId != employmentId) return false;
      if (category != null && a.category != category) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return _withDelay(items.take(limit).toList());
  }

  @override
  Future<Achievement> getAchievement(String achievementId) async {
    _progressAchievements();
    return _withDelay(
      mockAchievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => throw Exception('Achievement not found'),
      ),
    );
  }

  @override
  Future<Achievement> updateAchievement(
    String achievementId, {
    String? rawText,
    DateTime? occurredAt,
    String? employmentId,
  }) async {
    await _withDelay(null);
    final i = mockAchievements.indexWhere((a) => a.id == achievementId);
    if (i < 0) throw Exception('Achievement not found');
    final a = mockAchievements[i];
    // Editing your own words re-runs structuring, as on the backend.
    final reStructure = rawText != null && rawText != a.rawText;
    mockAchievements[i] = Achievement(
      id: a.id,
      employmentId: employmentId ?? a.employmentId,
      occurredAt: occurredAt ?? a.occurredAt,
      rawText: rawText ?? a.rawText,
      captureMode: a.captureMode,
      status: reStructure ? 'structuring' : a.status,
      headline: reStructure ? null : a.headline,
      structured: reStructure ? const {} : a.structured,
      needsMetric: reStructure ? false : a.needsMetric,
    );
    if (reStructure) _structuringSince[a.id] = DateTime.now();
    return mockAchievements[i];
  }

  @override
  Future<void> deleteAchievement(String achievementId) async {
    await _withDelay(null);
    mockAchievements.removeWhere((a) => a.id == achievementId);
  }

  @override
  Future<AchievementDigest> getAchievementDigest({int months = 6}) async {
    _progressAchievements();
    final cutoff = DateTime.now().subtract(Duration(days: months * 31));
    final inRange =
        mockAchievements.where((a) => a.occurredAt.isAfter(cutoff)).toList();

    final byCategory = <String, int>{};
    final skills = <String>{};
    final byMonth = <String, int>{};
    final weeks = <String>{};
    var withMetric = 0;

    for (final a in inRange) {
      byCategory.update(a.category ?? 'uncategorised', (v) => v + 1,
          ifAbsent: () => 1);
      skills.addAll(a.skills);
      if (a.metric != null) withMetric++;
      final month =
          '${a.occurredAt.year}-${a.occurredAt.month.toString().padLeft(2, '0')}';
      byMonth.update(month, (v) => v + 1, ifAbsent: () => 1);
      weeks.add('${a.occurredAt.year}-W'
          '${((a.occurredAt.difference(DateTime(a.occurredAt.year)).inDays) / 7).floor()}');
    }

    final sortedMonths = byMonth.keys.toList()..sort();
    return _withDelay(AchievementDigest(
      months: months,
      total: inRange.length,
      byCategory: byCategory,
      skills: skills.toList()..sort(),
      skillsCount: skills.length,
      withMetric: withMetric,
      byMonth: sortedMonths
          .map((m) => MonthCount(month: m, count: byMonth[m]!))
          .toList(),
      activeWeeks: weeks.length,
    ));
  }

  // ─── Interview practice ────────────────────────────────

  @override
  Future<List<PracticeQuestion>> getPracticeQuestions({
    String? category,
    int limit = 20,
  }) async {
    final items = mockQuestions
        .where((q) => category == null || q.category == category)
        .take(limit)
        .toList();
    return _withDelay(items);
  }

  @override
  Future<PracticeSession> startPracticeSession({
    String? jobId,
    int? confidenceBefore,
  }) async {
    await _withDelay(null);
    final session = PracticeSession(
      id: 'sess-${DateTime.now().millisecondsSinceEpoch}',
      sessionType: 'standalone_practice',
      jobId: jobId,
      startedAt: DateTime.now(),
      confidenceBefore: confidenceBefore,
    );
    mockSessions.add(session);
    return session;
  }

  @override
  Future<List<PracticeSession>> listPracticeSessions({int limit = 20}) =>
      _withDelay(mockSessions.reversed.take(limit).toList());

  @override
  Future<PracticeSession> getPracticeSession(String sessionId) async {
    _progressAnswers();
    final i = mockSessions.indexWhere((s) => s.id == sessionId);
    if (i < 0) throw Exception('Session not found');
    return _withDelay(PracticeSession(
      id: mockSessions[i].id,
      sessionType: mockSessions[i].sessionType,
      jobId: mockSessions[i].jobId,
      startedAt: mockSessions[i].startedAt,
      endedAt: mockSessions[i].endedAt,
      confidenceBefore: mockSessions[i].confidenceBefore,
      confidenceAfter: mockSessions[i].confidenceAfter,
      answers:
          mockAnswers.where((a) => a.sessionId == sessionId).toList(),
    ));
  }

  @override
  Future<PracticeSession> updatePracticeSession(
    String sessionId, {
    bool? ended,
    int? confidenceAfter,
  }) async {
    await _withDelay(null);
    final i = mockSessions.indexWhere((s) => s.id == sessionId);
    if (i < 0) throw Exception('Session not found');
    final s = mockSessions[i];
    mockSessions[i] = PracticeSession(
      id: s.id,
      sessionType: s.sessionType,
      jobId: s.jobId,
      startedAt: s.startedAt,
      endedAt: ended == true ? DateTime.now() : s.endedAt,
      confidenceBefore: s.confidenceBefore,
      confidenceAfter: confidenceAfter ?? s.confidenceAfter,
    );
    return mockSessions[i];
  }

  /// A plausible debrief. Scores are varied deliberately so the drill
  /// assignment differs between answers — a mock that always returns 5s
  /// would hide the whole point of the feature.
  PracticeAnswer _mockDebrief(PracticeAnswer a) {
    final variant = mockAnswers.indexWhere((x) => x.id == a.id) % 3;
    final (scores, drill, metrics) = switch (variant) {
      0 => (
          const {'structure': 2, 'evidence': 4, 'relevance': 4, 'conciseness': 3},
          const AnswerDrill(
            title: 'STAR scaffold',
            why: 'Your answer was hard to follow as a story.',
            how: 'Answer the same question four times, one sentence each: the '
                'Situation, your Task, the Action you took, the Result. Then '
                'deliver all four as one answer.',
          ),
          const AnswerMetrics(
            wordCount: 210, durationSeconds: 96, speakingSeconds: 88,
            wordsPerMinute: 143, fillerCount: 6, fillerPerMinute: 4.1,
            fillerBreakdown: {'um': 4, 'like': 2}, pauseCount: 5,
            longestPauseSeconds: 1.8, timeToFirstWordSeconds: 1.2,
            paceFlag: 'comfortable',
          ),
        ),
      1 => (
          const {'structure': 4, 'evidence': 2, 'relevance': 4, 'conciseness': 4},
          const AnswerDrill(
            title: 'Add one number',
            why: 'Your answer was credible but unverifiable.',
            how: 'Re-answer including at least one concrete figure — team '
                'size, percentage, timeline, user count, money saved.',
          ),
          const AnswerMetrics(
            wordCount: 168, durationSeconds: 72, speakingSeconds: 68,
            wordsPerMinute: 148, fillerCount: 2, fillerPerMinute: 1.7,
            fillerBreakdown: {'uh': 2}, pauseCount: 3,
            longestPauseSeconds: 1.1, timeToFirstWordSeconds: 0.8,
            paceFlag: 'comfortable',
          ),
        ),
      _ => (
          const {'structure': 4, 'evidence': 4, 'relevance': 5, 'conciseness': 4},
          const AnswerDrill(
            title: 'Pause instead of filler',
            why: 'Filler words were carrying your thinking time.',
            how: 'Re-answer and when you feel a filler coming, close your '
                'mouth and pause instead. Silence reads as composure; '
                '"um" does not.',
          ),
          const AnswerMetrics(
            wordCount: 240, durationSeconds: 104, speakingSeconds: 99,
            wordsPerMinute: 152, fillerCount: 13, fillerPerMinute: 7.5,
            fillerBreakdown: {'um': 7, 'you know': 4, 'like': 2},
            pauseCount: 4, longestPauseSeconds: 1.4,
            timeToFirstWordSeconds: 0.6, paceFlag: 'comfortable',
          ),
        ),
    };

    final mean = scores.values.reduce((x, y) => x + y) / scores.length;
    return PracticeAnswer(
      id: a.id,
      sessionId: a.sessionId,
      questionId: a.questionId,
      questionText: a.questionText,
      status: 'scored',
      durationSeconds: metrics.durationSeconds,
      transcriptText:
          'So, um, in my last role we had a situation where the payments '
          'service was falling over during peak hours. I looked at the logs, '
          'found the connection pool was exhausted, and rewrote the retry '
          'logic. After that it stopped happening.',
      metrics: metrics,
      scores: scores,
      overallScore: double.parse(mean.toStringAsFixed(2)),
      strengths: const [
        'You gave a concrete situation rather than speaking in generalities.',
        'The outcome was clearly stated.',
      ],
      improvements: const [
        'The Task and Action ran together — separate what you were asked to '
            'do from what you actually did.',
        'No numbers: "stopped happening" is weaker than "incidents went from '
            '12 a month to 2".',
      ],
      nextFocus: 'Give the result a number next time.',
      drill: drill,
      createdAt: a.createdAt,
    );
  }

  /// Analysis takes real seconds on the backend (upload → STT → score), so
  /// the mock does too — otherwise the polling UI is never exercised.
  final Map<String, DateTime> _analyzingSince = {};

  void _progressAnswers() {
    final now = DateTime.now();
    for (var i = 0; i < mockAnswers.length; i++) {
      final a = mockAnswers[i];
      final since = _analyzingSince[a.id];
      if (since == null || now.difference(since).inSeconds < 5) continue;
      _analyzingSince.remove(a.id);
      mockAnswers[i] = _mockDebrief(a);
    }
  }

  @override
  Future<AnalyzeStartResponse> uploadAnswer({
    required String sessionId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? questionId,
    String? questionText,
    void Function(double progress)? onProgress,
  }) async {
    // Walk the progress bar so the upload UI behaves as it will for real.
    for (var p = 0; p <= 10; p++) {
      await Future.delayed(const Duration(milliseconds: 60));
      onProgress?.call(p / 10);
    }
    final id = 'ans-${DateTime.now().millisecondsSinceEpoch}';
    String text = questionText ?? '';
    if (questionId != null) {
      final match = mockQuestions.where((q) => q.id == questionId);
      if (match.isNotEmpty) text = match.first.question;
    }
    mockAnswers.add(PracticeAnswer(
      id: id,
      sessionId: sessionId,
      questionId: questionId,
      questionText: text,
      status: 'analyzing',
      createdAt: DateTime.now(),
    ));
    _analyzingSince[id] = DateTime.now();
    return AnalyzeStartResponse(taskId: 'mock-analyze-$id', answerId: id);
  }

  @override
  Future<PracticeAnswer> getPracticeAnswer(String answerId) async {
    _progressAnswers();
    return _withDelay(
      mockAnswers.firstWhere(
        (a) => a.id == answerId,
        orElse: () => throw Exception('Answer not found'),
      ),
    );
  }

  @override
  Future<CVTaskStatusResponse> getCoachTaskStatus(String taskId) async {
    _progressAnswers();
    final id = taskId.replaceFirst('mock-analyze-', '');
    final match = mockAnswers.where((a) => a.id == id);
    final done = match.isNotEmpty && match.first.isScored;
    return _withDelay(CVTaskStatusResponse(
      taskId: taskId,
      status: done ? 'SUCCESS' : 'PENDING',
    ));
  }

  @override
  Future<List<AchievementEvidence>> getQuestionEvidence(
    String questionId, {
    int limit = 3,
  }) async {
    _progressAchievements();
    // Deterministic stand-in: the most recent structured entries carrying a
    // hard number, which is roughly what the backend's ranking prefers.
    final ranked = mockAchievements
        .where((a) => a.isStructured)
        .toList()
      ..sort((a, b) {
        final metricDiff = (b.metric != null ? 1 : 0) - (a.metric != null ? 1 : 0);
        if (metricDiff != 0) return metricDiff;
        return b.occurredAt.compareTo(a.occurredAt);
      });
    return _withDelay(ranked
        .take(limit)
        .map((a) => AchievementEvidence(
              id: a.id,
              occurredAt: a.occurredAt,
              headline: a.headline,
              cvBullet: a.cvBullet,
              metric: a.metric,
              matchedSkills: a.skills.take(2).toList(),
              relevance: a.metric != null ? 0.9 : 0.6,
            ))
        .toList());
  }
}
