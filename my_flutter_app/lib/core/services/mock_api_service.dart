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
}
