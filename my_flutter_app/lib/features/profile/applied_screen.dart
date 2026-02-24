import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

class AppliedScreen extends StatefulWidget {
  const AppliedScreen({super.key});

  @override
  State<AppliedScreen> createState() => _AppliedScreenState();
}

class _AppliedScreenState extends State<AppliedScreen> {
  final _api = api;
  List<AlertResponse> _applied = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.getAlerts(page: 1, limit: 50);
    if (mounted) {
      setState(() {
        _applied = result.items.where((a) => a.isApplied).toList()
          ..sort((a, b) => b.notifiedAt.compareTo(a.notifiedAt));
        _loading = false;
      });
    }
  }

  void _showStatusMenu(BuildContext context, AlertResponse alert) {
    final statuses = ['Applied', 'Interviewing', 'Offer', 'Rejected'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Update Status',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              ...statuses.map((status) => ListTile(
                    leading: Icon(
                      _statusIcon(status),
                      color: _statusColor(status),
                    ),
                    title: Text(status),
                    onTap: () => Navigator.pop(context),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Applications',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_applied.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.send_outlined,
                      size: 64,
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No applications yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mark jobs as Applied from the Alerts screen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.go('/alerts'),
                      icon: const Icon(Icons.notifications_outlined, size: 18),
                      label: const Text('Go to Alerts'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${_applied.length} application${_applied.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ApplicationTile(
                    alert: _applied[i],
                    index: i,
                    onTap: () => context.push('/jobs/${_applied[i].job.id}'),
                    onLongPress: () => _showStatusMenu(context, _applied[i]),
                  ),
                  childCount: _applied.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'Interviewing': return Icons.calendar_month_outlined;
      case 'Offer': return Icons.celebration_outlined;
      case 'Rejected': return Icons.cancel_outlined;
      default: return Icons.send_outlined;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Interviewing': return AppColors.primaryBlue;
      case 'Offer': return AppColors.success;
      case 'Rejected': return AppColors.destructive;
      default: return AppColors.warning;
    }
  }
}

// ─── Application Tile ──────────────────────────────────────────

class _ApplicationTile extends StatelessWidget {
  final AlertResponse alert;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ApplicationTile({
    required this.alert,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final job = alert.job;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Company avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    job.company.name[0],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.company.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 11, color: AppColors.success),
                          const SizedBox(width: 4),
                          const Text(
                            'Applied',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Applied date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(alert.notifiedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.more_vert,
                    size: 16,
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 60), duration: 350.ms)
        .slideY(
          begin: 0.08,
          delay: Duration(milliseconds: index * 60),
          duration: 350.ms,
          curve: Curves.easeOut,
        );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
