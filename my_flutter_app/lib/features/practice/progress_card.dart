import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// How you've changed across sittings — the point at which practice compounds.
///
/// Two things this deliberately does not do:
///   • **Invent encouragement.** When nothing improved there is no headline.
///     A tracker that always finds something nice to say is one nobody
///     believes the day it matters.
///   • **Judge every number.** Pauses and answer length are shown without a
///     verdict, because one of our own drills asks for *more* pauses. An
///     arrow pointing the wrong way would contradict the coaching.
class ProgressCard extends StatelessWidget {
  final PracticeProgress progress;
  final bool isDark;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.isDark,
  });

  static const _order = [
    'filler_per_minute',
    'words_per_minute',
    'pause_count',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    // One answer is a measurement, not a trend. Say so plainly instead of
    // rendering an empty chart.
    if (!progress.hasTrend) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timeline, size: 18, color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress.answersCompared == 0
                      ? 'Record two answers and this becomes a progress chart.'
                      : 'One more answer and we can show you a trend.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final overall = progress.overall;
    final retired = progress.drills.retired;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Your progress',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${progress.answersCompared} answers',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),

            if (progress.headline != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_up,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.headline!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (overall != null) ...[
              const SizedBox(height: 14),
              _TrendRow(
                label: 'Overall score',
                trend: overall,
                muted: muted,
                suffix: '/5',
              ),
            ],
            ..._order
                .where(progress.delivery.containsKey)
                .map((k) => _TrendRow(
                      label: progress.delivery[k]!.label ?? k,
                      trend: progress.delivery[k]!,
                      muted: muted,
                    )),

            // The most meaningful thing on this card: weaknesses that stopped
            // coming up at all.
            if (retired.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'NO LONGER COMING UP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: retired
                    .map((d) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check,
                                  size: 12, color: AppColors.success),
                              const SizedBox(width: 5),
                              Text(
                                d.title,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],

            // Honesty about what is *not* in the numbers above.
            if (progress.answersExcludedOldRubric > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${progress.answersExcludedOldRubric} earlier '
                '${progress.answersExcludedOldRubric == 1 ? "answer is" : "answers are"} '
                'not included — they were scored on an older scale, so '
                'comparing them here would be misleading.',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label;
  final MetricTrend trend;
  final Color muted;
  final String? suffix;

  const _TrendRow({
    required this.label,
    required this.trend,
    required this.muted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only judged metrics get a colour and an arrow. Informational ones show
    // the movement without implying it was good or bad.
    final (icon, color) = switch (trend.verdict) {
      'improved' => (Icons.arrow_upward, AppColors.success),
      'regressed' => (Icons.arrow_downward, AppColors.warning),
      'steady' => (Icons.remove, muted),
      _ => (Icons.circle_outlined, muted),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label[0].toUpperCase() + label.substring(1),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text(
            '${_fmt(trend.first)} → ${_fmt(trend.latest)}${suffix ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: trend.isJudged ? color : null,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
