import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/providers/alerts_provider.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/widgets/job_card.dart';
import 'package:job_scout/core/widgets/skeleton_loader.dart';
import 'package:job_scout/core/widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = api;
  List<JobListItem> _recentJobs = [];
  List<RecommendedJob> _recommended = [];
  bool _loading = true;

  /// null until known — the prompt stays hidden rather than flashing on
  /// for users who did log something.
  bool? _loggedThisWeek;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Refreshes the jobs list, skill-matched recommendations, and the alerts
  /// provider (stats + recent alerts) in parallel.
  Future<void> _loadData() async {
    setState(() => _loading = true);
    final jobsFuture = _api.getJobs(limit: 5, daysAgo: 30);
    // Recommendations are optional garnish — a failure (e.g. no CV yet)
    // must never break the home screen.
    final recommendedFuture = _api
        .getRecommendedJobs(limit: 10)
        .then<List<RecommendedJob>>((r) => r.items)
        .catchError((_) => <RecommendedJob>[]);
    final alertsFuture = context.read<AlertsProvider>().refresh();
    // Same 7-day window the backend's weekly nudge uses.
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final weekFuture = _api
        .listAchievements(from: weekStart, limit: 1)
        .then<bool?>((items) => items.isNotEmpty)
        .catchError((_) => null);
    final result = await jobsFuture;
    final recommended = await recommendedFuture;
    final loggedThisWeek = await weekFuture;
    await alertsFuture;
    if (mounted) {
      setState(() {
        _recentJobs = result.items;
        _recommended = recommended;
        _loggedThisWeek = loggedThisWeek;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final alertsProvider = context.watch<AlertsProvider>();
    final stats = alertsProvider.stats;
    final recentAlerts = alertsProvider.recentAlerts;
    final greeting = _greeting();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ─────────────────────────────
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${user?.fullName?.split(' ').first ?? 'there'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    // Not "your job market overview" any more — the product
                    // walks a career, and the first line users read should
                    // say so.
                    'Your career, at a glance',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.go('/jobs'),
                ),
              ],
            ),

            // ─── Stats Grid ──────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: alertsProvider.loaded
                    ? [
                        StatCard(
                          icon: Icons.work_outline,
                          label: 'Total Jobs',
                          value: '${stats['totalJobs']}',
                          color: AppColors.primaryBlue,
                          animationIndex: 0,
                        ),
                        StatCard(
                          icon: Icons.fiber_new,
                          label: 'New Today',
                          value: '${stats['newToday']}',
                          color: AppColors.success,
                          animationIndex: 1,
                        ),
                        StatCard(
                          icon: Icons.notifications_active_outlined,
                          label: 'Unread Alerts',
                          value: '${stats['unreadAlerts']}',
                          color: AppColors.warning,
                          animationIndex: 2,
                        ),
                        StatCard(
                          icon: Icons.check_circle_outline,
                          label: 'Applied',
                          value: '${stats['applied']}',
                          color: AppColors.success,
                          animationIndex: 3,
                        ),
                      ]
                    : const [
                        SkeletonStatCard(),
                        SkeletonStatCard(),
                        SkeletonStatCard(),
                        SkeletonStatCard(),
                      ],
              ),
            ),

            // ─── This week's win ─────────────────────
            // The weekly nudge is a push, and push is still gated on the
            // Firebase ops step (#2b) — so in-app is currently the only
            // place the habit prompt exists at all.
            if (!_loading && _loggedThisWeek == false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _LogWinPrompt(isDark: isDark),
                ),
              ),

            // ─── Recent Alerts ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: _SectionHeader(
                  title: 'Recent Alerts',
                  onViewAll: () => context.push('/alerts'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: !alertsProvider.loaded
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: 4,
                        itemBuilder: (_, __) => const SkeletonMiniAlert(),
                      )
                    : recentAlerts.isEmpty
                        ? Center(
                            child: Text(
                              'No alerts yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.mutedForegroundDark
                                    : AppColors.mutedForegroundLight,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: recentAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = recentAlerts[index];
                              return _MiniAlertCard(alert: alert, index: index)
                                  .animate()
                                  .fadeIn(
                                    delay:
                                        Duration(milliseconds: index * 100),
                                    duration: 400.ms,
                                  )
                                  .slideX(
                                    begin: 0.1,
                                    delay:
                                        Duration(milliseconds: index * 100),
                                    duration: 400.ms,
                                    curve: Curves.easeOut,
                                  );
                            },
                          ),
              ),
            ),

            // ─── Recommended for you (skill-matched; hidden when empty) ──
            if (!_loading && _recommended.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: _SectionHeader(title: 'Recommended for you'),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _recommended.length,
                    itemBuilder: (context, index) => _RecommendedJobCard(
                      job: _recommended[index],
                      animationIndex: index,
                    ),
                  ),
                ),
              ),
            ],

            // ─── Latest Jobs ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: _SectionHeader(
                  title: 'Latest Jobs',
                  onViewAll: () => context.go('/jobs'),
                ),
              ),
            ),

            if (_loading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => JobCard(
                    job: _recentJobs[index],
                    animationIndex: index,
                  ),
                  childCount: _recentJobs.length,
                ),
              ),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ─── Log-a-win prompt ──────────────────────────────────────────

class _LogWinPrompt extends StatelessWidget {
  final bool isDark;

  const _LogWinPrompt({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Card(
      child: InkWell(
        onTap: () => context.go('/career?log=1'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_outlined,
                    color: AppColors.warning),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What did you ship this week?',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Takes a minute. Future you — writing a CV or sitting an '
                      'interview — will thank you.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }
}

class _MiniAlertCard extends StatelessWidget {
  final AlertResponse alert;
  final int index;

  const _MiniAlertCard({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/jobs/${alert.job.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (!alert.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        alert.job.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.job.company.name} · ${alert.job.location ?? ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    if (alert.isSaved)
                      const Icon(Icons.bookmark,
                          size: 14, color: AppColors.warning),
                    if (alert.isApplied) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal card for the "Recommended for you" carousel.
class _RecommendedJobCard extends StatelessWidget {
  final RecommendedJob job;
  final int animationIndex;

  const _RecommendedJobCard({required this.job, this.animationIndex = 0});

  Color get _scoreColor {
    if (job.matchScore >= 75) return AppColors.success;
    if (job.matchScore >= 50) return AppColors.warning;
    return AppColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 240,
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/jobs/${job.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${job.matchScore.round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _scoreColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${job.company.name} · ${job.location ?? 'Remote'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    job.matchedSkills.take(3).join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(
            delay: Duration(milliseconds: 50 * animationIndex),
            duration: 200.ms,
          ),
    );
  }
}
