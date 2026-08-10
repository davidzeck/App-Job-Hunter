import 'package:flutter_test/flutter_test.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/mock_api_service.dart';
import 'package:job_scout/core/services/mock_data.dart';

/// Demo mode has no other safety net: `flutter analyze` proves MockApiService
/// compiles, not that it behaves like the backend it stands in for. These
/// cover the behaviours the career screens actually depend on.
void main() {
  late MockApiService api;

  setUp(() {
    api = MockApiService();
    // The mock is a singleton over mutable module state, so reset the seed
    // between tests or ordering decides the assertions.
    mockEmployments = [
      Employment(
        id: 'emp-001',
        employerName: 'TechCorp Kenya',
        roleTitle: 'Software Engineer',
        startDate: DateTime(2022, 1, 10),
        isCurrent: true,
      ),
    ];
    mockAchievements = [
      Achievement(
        id: 'ach-001',
        occurredAt: DateTime.now().subtract(const Duration(days: 4)),
        rawText: 'Cut checkout latency 40%.',
        status: 'structured',
        headline: 'Cut checkout latency 40%',
        structured: const {
          'metric': '40% lower checkout latency',
          'skills': ['Python'],
          'category': 'technical',
          'cv_bullet': 'Cut checkout latency 40%.',
        },
      ),
    ];
  });

  test('logging returns 202-style start response and lands in the list',
      () async {
    final started = await api.logAchievement('Shipped the billing rewrite.');
    expect(started.achievementId, isNotEmpty);
    expect(started.taskId, isNotEmpty);

    final items = await api.listAchievements();
    expect(items.any((a) => a.id == started.achievementId), isTrue);
  });

  test('a new entry structures asynchronously, as the real backend does',
      () async {
    final started = await api.logAchievement('Shipped the billing rewrite.');

    final immediately = await api.getAchievement(started.achievementId);
    expect(immediately.isStructuring, isTrue,
        reason: 'capture must not block on the model call');

    // The mock flips to structured after 3s, mirroring the Celery task.
    await Future.delayed(const Duration(seconds: 4));
    final later = await api.getAchievement(started.achievementId);
    expect(later.isStructured, isTrue);
  });

  test('a note with no number sets needs_metric so the nudge can fire',
      () async {
    final started = await api.logAchievement(
        'Mentored a colleague through their first production feature.');
    await Future.delayed(const Duration(seconds: 4));

    final structured = await api.getAchievement(started.achievementId);
    expect(structured.needsMetric, isTrue);

    // ...and a note carrying a figure does not.
    final withNumber = await api.logAchievement('Cut build time by 64%.');
    await Future.delayed(const Duration(seconds: 4));
    expect((await api.getAchievement(withNumber.achievementId)).needsMetric,
        isFalse);
  });

  test('logging attaches to the current role', () async {
    final started = await api.logAchievement('Shipped the billing rewrite.');
    final achievement = await api.getAchievement(started.achievementId);
    expect(achievement.employmentId, 'emp-001');
  });

  test('editing the text re-structures, and raw_text stays the user\'s',
      () async {
    final updated = await api.updateAchievement(
      'ach-001',
      rawText: 'Cut checkout latency 40%. Support tickets halved too.',
    );
    expect(updated.isStructuring, isTrue);
    expect(updated.rawText, contains('Support tickets halved'));
  });

  test('at most one role is current', () async {
    await api.createEmployment(
      employerName: 'NewCo',
      roleTitle: 'Senior Engineer',
      startDate: DateTime(2024, 3, 1),
      isCurrent: true,
    );
    final roles = await api.listEmployments();
    expect(roles.where((r) => r.isCurrent).length, 1);
    expect(roles.firstWhere((r) => r.isCurrent).employerName, 'NewCo');
  });

  test('digest counts match the log', () async {
    final digest = await api.getAchievementDigest();
    expect(digest.total, 1);
    expect(digest.withMetric, 1);
    expect(digest.skills, contains('Python'));
    expect(digest.byCategory['technical'], 1);
  });

  test('career state round-trips through the profile call', () async {
    await api.updateCareerState('not_looking');
    expect((await api.getCurrentUser()).careerState, 'not_looking');
  });
}
