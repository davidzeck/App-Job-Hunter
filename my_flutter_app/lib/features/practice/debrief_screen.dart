import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// What that answer was actually like.
///
/// Ordered on purpose: **the drill comes before the scores.** A number tells
/// you where you stand; the drill tells you what to do on Tuesday, and only
/// one of those changes anything. Scores are supporting evidence.
class DebriefScreen extends StatefulWidget {
  final String answerId;

  const DebriefScreen({super.key, required this.answerId});

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  final _api = api;
  PracticeAnswer? _answer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final answer = await _api.getPracticeAnswer(widget.answerId);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;
    final a = _answer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your answer',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : a == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'Not found',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(
                      a.questionText,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),

                    // ─── The drill: the one thing to do next ───
                    if (a.drill != null)
                      _DrillCard(drill: a.drill!, isDark: isDark)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.08, duration: 400.ms),

                    // ─── Rubric ───────────────────────────────
                    if (a.scores.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader('How it scored', muted: muted),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (a.overallScore != null) ...[
                                Row(
                                  children: [
                                    Text(
                                      a.overallScore!.toStringAsFixed(1),
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _scoreColor(a.overallScore!),
                                      ),
                                    ),
                                    Text(' / 5',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: muted)),
                                    const Spacer(),
                                    if (a.durationSeconds != null)
                                      Text(
                                        '${a.durationSeconds!.round()}s answer',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(color: muted),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],
                              ..._axisOrder
                                  .where((k) => a.scores.containsKey(k))
                                  .map((k) => _AxisBar(
                                        label: _axisLabels[k]!,
                                        score: a.scores[k]!,
                                        muted: muted,
                                      )),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ─── Delivery ─────────────────────────────
                    if (a.metrics != null) ...[
                      const SizedBox(height: 20),
                      _SectionHeader('How you delivered it', muted: muted),
                      const SizedBox(height: 4),
                      Text(
                        'Measured from the recording, not judged by a model — '
                        'so these are comparable session to session.',
                        style:
                            theme.textTheme.labelSmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 8),
                      _MetricsCard(metrics: a.metrics!, isDark: isDark),
                    ],

                    // ─── Takeaways ────────────────────────────
                    if (a.strengths.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHeader('What worked', muted: muted),
                      const SizedBox(height: 8),
                      ...a.strengths.map((s) => _Bullet(
                            text: s,
                            icon: Icons.check_circle_outline,
                            color: AppColors.success,
                          )),
                    ],
                    if (a.improvements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader('What to sharpen', muted: muted),
                      const SizedBox(height: 8),
                      ...a.improvements.map((s) => _Bullet(
                            text: s,
                            icon: Icons.arrow_circle_up_outlined,
                            color: AppColors.warning,
                          )),
                    ],

                    // ─── Transcript ───────────────────────────
                    if (a.transcriptText != null &&
                        a.transcriptText!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            'What you actually said',
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Verbatim, fillers included',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: muted),
                          ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(a.transcriptText!,
                                  style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      'The recording itself has been deleted.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/practice'),
                      icon: const Icon(Icons.mic, size: 18),
                      label: const Text('Practise another'),
                    ),
                  ],
                ),
    );
  }
}

const _axisOrder = ['structure', 'evidence', 'relevance', 'conciseness'];
const _axisLabels = {
  'structure': 'Structure (STAR)',
  'evidence': 'Evidence',
  'relevance': 'Relevance',
  'conciseness': 'Conciseness',
};

Color _scoreColor(double score) {
  if (score >= 4) return AppColors.success;
  if (score >= 3) return AppColors.warning;
  return AppColors.destructive;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color muted;

  const _SectionHeader(this.title, {required this.muted});

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: muted,
        ),
      );
}

/// Deliberately the loudest thing on the page.
class _DrillCard extends StatelessWidget {
  final AnswerDrill drill;
  final bool isDark;

  const _DrillCard({required this.drill, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.14 : 0.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center,
                    size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'PRACTISE THIS NEXT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              drill.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(drill.why, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(drill.how, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  final String label;
  final int score;
  final Color muted;

  const _AxisBar({
    required this.label,
    required this.score,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _scoreColor(score.toDouble());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: score / 5,
                minHeight: 8,
                backgroundColor: muted.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$score',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final AnswerMetrics metrics;
  final bool isDark;

  const _MetricsCard({required this.metrics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    final paceLabel = switch (metrics.paceFlag) {
      'fast' => 'Fast',
      'slow' => 'Slow',
      'no_speech' => 'No speech',
      _ => 'Comfortable',
    };
    final paceColor = metrics.paceFlag == 'comfortable'
        ? AppColors.success
        : AppColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _Metric(
                  value: metrics.wordsPerMinute.round().toString(),
                  label: 'words/min',
                  note: paceLabel,
                  noteColor: paceColor,
                  muted: muted,
                ),
                _Metric(
                  value: metrics.fillerCount.toString(),
                  label: 'filler words',
                  note: '${metrics.fillerPerMinute.toStringAsFixed(1)}/min',
                  noteColor: metrics.fillerPerMinute >= 6
                      ? AppColors.warning
                      : AppColors.success,
                  muted: muted,
                ),
                _Metric(
                  value: metrics.pauseCount.toString(),
                  label: 'pauses',
                  note: '${metrics.longestPauseSeconds.toStringAsFixed(1)}s max',
                  noteColor: muted,
                  muted: muted,
                ),
              ],
            ),
            if (metrics.fillerBreakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (metrics.fillerBreakdown.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '"${e.key}" ×${e.value}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final String note;
  final Color noteColor;
  final Color muted;

  const _Metric({
    required this.value,
    required this.label,
    required this.note,
    required this.noteColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          Text(
            note,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: noteColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _Bullet({required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
