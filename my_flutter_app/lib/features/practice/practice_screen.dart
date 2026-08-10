import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// The wedge: rehearse an interview answer and find out how you came across.
///
/// Zero-stakes by design — nobody is watching, the recording is destroyed,
/// and every sitting ends with one thing to practise rather than a verdict.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _api = api;
  List<PracticeQuestion> _questions = [];
  List<PracticeAnswer> _recent = [];
  String? _category;
  bool _loading = true;
  String? _error;

  static const _categories = {
    null: 'All',
    'behavioral': 'Behavioural',
    'technical': 'Technical',
    'situational': 'Situational',
    'intro': 'Intro',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questions = await _api.getPracticeQuestions(
        category: _category,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
    // History is secondary — a failure here must not hide the questions.
    try {
      final sessions = await _api.listPracticeSessions(limit: 10);
      final answers = <PracticeAnswer>[];
      for (final s in sessions.take(5)) {
        try {
          answers.addAll((await _api.getPracticeSession(s.id))
              .answers
              .where((a) => a.isScored));
        } catch (_) {}
      }
      answers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _recent = answers.take(5).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Practice',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Nobody is listening but you',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.error_outline,
                                color: AppColors.destructive),
                            title: Text(_error!,
                                style: theme.textTheme.bodySmall),
                            trailing: TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ─── Recent debriefs ──────────────────────
                  if (_recent.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECENT ANSWERS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._recent.map((a) => _RecentAnswerTile(
                                  answer: a,
                                  muted: muted,
                                  onTap: () => context
                                      .push('/practice/debrief/${a.id}'),
                                )),
                          ],
                        ),
                      ),
                    ),

                  // ─── Category filter ──────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.entries
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(e.value),
                                      selected: _category == e.key,
                                      onSelected: (_) {
                                        setState(() {
                                          _category = e.key;
                                          _loading = true;
                                        });
                                        _load();
                                      },
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),

                  // ─── Questions ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: _questions
                            .map((q) => _QuestionTile(
                                  question: q,
                                  muted: muted,
                                  onTap: () => context
                                      .push('/practice/record/${q.id}',
                                          extra: q)
                                      .then((_) => _load()),
                                ))
                            .toList(),
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ),

                  if (_questions.isEmpty && _error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No questions in this category yet.',
                          textAlign: TextAlign.center,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final PracticeQuestion question;
  final Color muted;
  final VoidCallback onTap;

  const _QuestionTile({
    required this.question,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        title: Text(
          question.question,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: question.skillTags.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  question.skillTags.join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
        trailing: const Icon(Icons.mic, size: 20, color: AppColors.primaryBlue),
        onTap: onTap,
      ),
    );
  }
}

class _RecentAnswerTile extends StatelessWidget {
  final PracticeAnswer answer;
  final Color muted;
  final VoidCallback onTap;

  const _RecentAnswerTile({
    required this.answer,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = answer.overallScore;
    final color = score == null
        ? muted
        : score >= 4
            ? AppColors.success
            : score >= 3
                ? AppColors.warning
                : AppColors.destructive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text(
            score?.toStringAsFixed(1) ?? '–',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          answer.questionText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          answer.drill?.title != null
              ? '${DateFormat('d MMM').format(answer.createdAt)} · '
                  '${answer.drill!.title}'
              : DateFormat('d MMM').format(answer.createdAt),
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}
