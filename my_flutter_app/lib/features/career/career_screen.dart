import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/features/career/log_achievement_sheet.dart';

/// The retention half of the product: what you have actually done, kept.
///
/// This is the reason an employed person opens the app on a Tuesday. The
/// interview wedge is the painkiller; this is the vitamin.
class CareerScreen extends StatefulWidget {
  /// True when arriving from the weekly nudge notification — open capture
  /// straight away rather than dropping the user on a list.
  final bool openCapture;

  const CareerScreen({super.key, this.openCapture = false});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  final _api = api;
  AchievementDigest _digest = const AchievementDigest();
  List<Achievement> _achievements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _logWin();
      });
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getAchievementDigest(),
        _api.listAchievements(),
      ]);
      if (!mounted) return;
      setState(() {
        _digest = results[0] as AchievementDigest;
        _achievements = results[1] as List<Achievement>;
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
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Open capture, then wait for structuring so the metric nudge can fire.
  Future<void> _logWin() async {
    final id = await showLogAchievementSheet(context);
    if (id == null || !mounted) return;
    await _load();
    _snack('Logged. Pulling out the details…');
    await _awaitStructuring(id);
  }

  /// Poll the one entry we just created. The backend returns 202 and
  /// structures in the background, so the nudge can only be decided here.
  Future<void> _awaitStructuring(String achievementId) async {
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final achievement = await _api.getAchievement(achievementId);
        if (achievement.isStructuring) continue;
        if (!mounted) return;
        await _load();
        if (achievement.needsMetric && mounted) {
          final added = await showAddMetricSheet(context, achievement);
          if (added && mounted) await _load();
        }
        return;
      } catch (_) {
        return; // Structuring is background work; a poll failure isn't fatal.
      }
    }
  }

  Future<void> _delete(Achievement achievement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: const Text(
          'It disappears from your log and your digest. Your other entries '
          'are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteAchievement(achievement.id);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openDetail(Achievement achievement) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AchievementDetailSheet(achievement: achievement),
    );
    if (changed == true && mounted) await _load();
  }

  /// Group by calendar month so the log reads as a timeline, not a feed.
  Map<String, List<Achievement>> get _byMonth {
    final grouped = <String, List<Achievement>>{};
    for (final a in _achievements) {
      final key = DateFormat('MMMM yyyy').format(a.occurredAt);
      grouped.putIfAbsent(key, () => []).add(a);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logWin,
        icon: const Icon(Icons.add),
        label: const Text('Log a win'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    title: Text(
                      'My Career',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Roles',
                        icon: const Icon(Icons.badge_outlined),
                        onPressed: () =>
                            context.push('/career/roles').then((_) => _load()),
                      ),
                    ],
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

                  // ─── The digest — the always-on payoff ────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _DigestCard(digest: _digest, isDark: isDark)
                          .animate()
                          .fadeIn(duration: 400.ms),
                    ),
                  ),

                  if (_achievements.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _EmptyLog(isDark: isDark, onLog: _logWin),
                      ),
                    )
                  else
                    ..._byMonth.entries.map(
                      (entry) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.mutedForegroundDark
                                      : AppColors.mutedForegroundLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...entry.value.map(
                                (a) => _AchievementTile(
                                  achievement: a,
                                  isDark: isDark,
                                  onTap: () => _openDetail(a),
                                  onDelete: () => _delete(a),
                                  onAddMetric: () async {
                                    final added =
                                        await showAddMetricSheet(context, a);
                                    if (added && mounted) await _load();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Clear the FAB.
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
    );
  }
}

// ─── Digest ────────────────────────────────────────────────────

class _DigestCard extends StatelessWidget {
  final AchievementDigest digest;
  final bool isDark;

  const _DigestCard({required this.digest, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last ${digest.months} months',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  value: '${digest.total}',
                  label: digest.total == 1 ? 'win' : 'wins',
                  isDark: isDark,
                ),
                _Stat(
                  value: '${digest.withMetric}',
                  label: 'with numbers',
                  isDark: isDark,
                ),
                _Stat(
                  value: '${digest.skillsCount}',
                  label: 'skills shown',
                  isDark: isDark,
                ),
                _Stat(
                  value: '${digest.activeWeeks}',
                  label: 'active weeks',
                  isDark: isDark,
                ),
              ],
            ),
            if (digest.narrative != null) ...[
              const SizedBox(height: 12),
              Text(digest.narrative!, style: theme.textTheme.bodySmall),
            ],
            if (digest.byCategory.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: digest.byCategory.entries
                    .map((e) => _CategoryChip(
                          label: '${_categoryLabel(e.key)} · ${e.value}',
                          category: e.key,
                        ))
                    .toList(),
              ),
            ],
            if (digest.total > 0 && digest.withMetric < digest.total) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${digest.total - digest.withMetric} of these have no '
                      'number in them. Numbers are what make them land.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _Stat({
    required this.value,
    required this.label,
    required this.isDark,
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
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(String category) => switch (category) {
      'delivery' => 'Delivery',
      'technical' => 'Technical',
      'leadership' => 'Leadership',
      'process' => 'Process',
      'growth' => 'Growth',
      _ => 'Other',
    };

Color _categoryColor(String? category) => switch (category) {
      'delivery' => AppColors.primaryBlue,
      'technical' => AppColors.successLight,
      'leadership' => AppColors.warning,
      'process' => AppColors.primaryLight,
      'growth' => AppColors.success,
      _ => AppColors.mutedForegroundLight,
    };

class _CategoryChip extends StatelessWidget {
  final String label;
  final String? category;

  const _CategoryChip({required this.label, this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Log ───────────────────────────────────────────────────────

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAddMetric;

  const _AchievementTile({
    required this.achievement,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    required this.onAddMetric,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: achievement.isStructuring ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          DateFormat('d MMM').format(achievement.occurredAt),
                          style:
                              theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                        if (achievement.category != null) ...[
                          const SizedBox(width: 8),
                          _CategoryChip(
                            label: _categoryLabel(achievement.category!),
                            category: achievement.category,
                          ),
                        ],
                      ],
                    ),
                    if (achievement.metric != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.trending_up,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              achievement.metric!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (achievement.isStructuring) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pulling out the details…',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ],
                    if (achievement.needsMetric)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onAddMetric,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.warning,
                          ),
                          icon: const Icon(Icons.add_chart, size: 16),
                          label: const Text('Add a number'),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                  if (v == 'metric') onAddMetric();
                },
                itemBuilder: (_) => [
                  if (achievement.metric == null && !achievement.isStructuring)
                    const PopupMenuItem(
                      value: 'metric',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add_chart),
                        title: Text('Add a number'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline,
                          color: AppColors.destructive),
                      title: Text('Remove',
                          style: TextStyle(color: AppColors.destructive)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  final bool isDark;
  final VoidCallback onLog;

  const _EmptyLog({required this.isDark, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, size: 48, color: muted),
            const SizedBox(height: 12),
            Text('Nothing logged yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Every few months your CV needs rewriting and an interviewer '
              'asks "tell me about a time you…". Both are easy if you wrote '
              'it down when it happened, and hard if you did not.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log your first win'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail ────────────────────────────────────────────────────

class _AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;

  const _AchievementDetailSheet({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            achievement.displayTitle,
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                DateFormat('d MMMM yyyy').format(achievement.occurredAt),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              if (achievement.category != null) ...[
                const SizedBox(width: 8),
                _CategoryChip(
                  label: _categoryLabel(achievement.category!),
                  category: achievement.category,
                ),
              ],
            ],
          ),

          // Your words — the permanent record. The AI never rewrites this.
          const SizedBox(height: 20),
          Text(
            'In your words',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: muted),
          ),
          const SizedBox(height: 6),
          Text(achievement.rawText, style: theme.textTheme.bodyMedium),

          if (achievement.metric != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    achievement.metric!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (achievement.skills.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Skills this shows',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: achievement.skills
                  .map((s) => Chip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],

          if (achievement.cvBullet != null) ...[
            const SizedBox(height: 20),
            Text(
              'Ready for your CV',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(achievement.cvBullet!,
                  style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: achievement.cvBullet!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],

          if (achievement.isFailed) ...[
            const SizedBox(height: 20),
            Text(
              'We could not pull the details out of this one, but your words '
              'are safe above.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
