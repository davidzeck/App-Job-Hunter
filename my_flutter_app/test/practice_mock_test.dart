import 'package:flutter_test/flutter_test.dart';
import 'package:job_scout/core/services/mock_api_service.dart';
import 'package:job_scout/core/services/mock_data.dart';

/// Covers the practice flow's contract with the client screens: the upload
/// returns a 202-shaped response, analysis is genuinely asynchronous, and a
/// finished answer carries the one thing the debrief is built around — a
/// drill.
void main() {
  late MockApiService api;

  setUp(() {
    api = MockApiService();
    mockSessions = [];
    mockAnswers = [];
  });

  test('questions can be filtered by category', () async {
    final all = await api.getPracticeQuestions();
    expect(all, isNotEmpty);

    final behavioral = await api.getPracticeQuestions(category: 'behavioral');
    expect(behavioral, isNotEmpty);
    expect(behavioral.every((q) => q.isBehavioral), isTrue);
  });

  test('recording an answer starts analysis rather than blocking', () async {
    final session = await api.startPracticeSession();
    final started = await api.uploadAnswer(
      sessionId: session.id,
      bytes: List.filled(1024, 0),
      filename: 'answer.m4a',
      contentType: 'audio/mp4',
      questionId: 'q-002',
    );
    expect(started.answerId, isNotEmpty);
    expect(started.taskId, isNotEmpty);

    final immediately = await api.getPracticeAnswer(started.answerId);
    expect(immediately.isAnalyzing, isTrue);
    expect(immediately.questionText, isNotEmpty,
        reason: 'the question is resolved from the id, as the backend does');
  });

  test('upload reports progress so the UI can show it', () async {
    final session = await api.startPracticeSession();
    final seen = <double>[];
    await api.uploadAnswer(
      sessionId: session.id,
      bytes: List.filled(1024, 0),
      filename: 'answer.m4a',
      contentType: 'audio/mp4',
      questionId: 'q-002',
      onProgress: seen.add,
    );
    expect(seen, isNotEmpty);
    expect(seen.last, 1.0);
  });

  test('a finished answer carries scores, metrics and exactly one drill',
      () async {
    final session = await api.startPracticeSession();
    final started = await api.uploadAnswer(
      sessionId: session.id,
      bytes: List.filled(1024, 0),
      filename: 'answer.m4a',
      contentType: 'audio/mp4',
      questionId: 'q-002',
    );

    await Future.delayed(const Duration(seconds: 6));
    final answer = await api.getPracticeAnswer(started.answerId);

    expect(answer.isScored, isTrue);
    expect(answer.drill, isNotNull, reason: 'the debrief is built around it');
    expect(answer.drill!.title, isNotEmpty);
    expect(answer.drill!.how, isNotEmpty);
    expect(answer.overallScore, isNotNull);
    expect(answer.scores.keys,
        containsAll(['structure', 'evidence', 'relevance', 'conciseness']));
    expect(answer.metrics, isNotNull);
    expect(answer.metrics!.wordsPerMinute, greaterThan(0));
    expect(answer.transcriptText, isNotEmpty);
  });

  test('the task poll goes terminal once the answer is scored', () async {
    final session = await api.startPracticeSession();
    final started = await api.uploadAnswer(
      sessionId: session.id,
      bytes: List.filled(1024, 0),
      filename: 'answer.m4a',
      contentType: 'audio/mp4',
      questionId: 'q-002',
    );

    expect((await api.getCoachTaskStatus(started.taskId)).status, 'PENDING');
    await Future.delayed(const Duration(seconds: 6));
    expect((await api.getCoachTaskStatus(started.taskId)).status, 'SUCCESS');
  });

  test('the session collects its answers and can be ended', () async {
    final session = await api.startPracticeSession();
    await api.uploadAnswer(
      sessionId: session.id,
      bytes: List.filled(1024, 0),
      filename: 'answer.m4a',
      contentType: 'audio/mp4',
      questionId: 'q-002',
    );

    final loaded = await api.getPracticeSession(session.id);
    expect(loaded.answers.length, 1);

    final ended = await api.updatePracticeSession(session.id, ended: true);
    expect(ended.endedAt, isNotNull);
  });

  test('drills vary between answers rather than always being the same', () async {
    final session = await api.startPracticeSession();
    for (var i = 0; i < 3; i++) {
      await api.uploadAnswer(
        sessionId: session.id,
        bytes: List.filled(1024, 0),
        filename: 'answer$i.m4a',
        contentType: 'audio/mp4',
        questionId: 'q-002',
      );
    }
    await Future.delayed(const Duration(seconds: 6));

    final answers = (await api.getPracticeSession(session.id)).answers;
    final drills = answers.map((a) => a.drill?.title).toSet();
    expect(drills.length, greaterThan(1),
        reason: 'a demo where every answer scores the same teaches nothing');
  });
}
