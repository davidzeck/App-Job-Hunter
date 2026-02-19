import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/mock_api_service.dart';
import 'package:job_scout/core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _api = MockApiService();
  List<AlertResponse> _alerts = [];
  bool _loading = true;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    final result = await _api.getAlerts(unreadOnly: _unreadOnly);
    setState(() {
      _alerts = result.items;
      _loading = false;
    });
  }

  Future<void> _markRead(String alertId) async {
    await _api.markAlertRead(alertId);
    _loadAlerts();
  }

  Future<void> _toggleSaved(String alertId) async {
    await _api.toggleAlertSaved(alertId);
    _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ─────────────────────────────
            SliverAppBar(
              floating: true,
              title: Text(
                'Alerts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // ─── Toggle ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('All')),
                        ButtonSegment(value: true, label: Text('Unread')),
                      ],
                      selected: {_unreadOnly},
                      onSelectionChanged: (val) {
                        setState(() => _unreadOnly = val.first);
                        _loadAlerts();
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_alerts.length} alerts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Alert List ──────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_alerts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _unreadOnly ? 'No unread alerts' : 'No alerts yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? AppColors.mutedForegroundDark
                              : AppColors.mutedForegroundLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll notify you when new jobs match your preferences',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.mutedForegroundDark
                              : AppColors.mutedForegroundLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final alert = _alerts[index];
                    return _AlertItem(
                      alert: alert,
                      index: index,
                      onTap: () {
                        if (!alert.isRead) _markRead(alert.id);
                        context.push('/jobs/${alert.job.id}');
                      },
                      onSwipeRight: () => _markRead(alert.id),
                      onSwipeLeft: () => _toggleSaved(alert.id),
                    );
                  },
                  childCount: _alerts.length,
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final AlertResponse alert;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;

  const _AlertItem({
    required this.alert,
    required this.index,
    required this.onTap,
    required this.onSwipeRight,
    required this.onSwipeLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(alert.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: AppColors.primaryBlue.withValues(alpha: 0.15),
        child: const Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Mark Read', style: TextStyle(color: AppColors.primaryBlue)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.warning.withValues(alpha: 0.15),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Save', style: TextStyle(color: AppColors.warning)),
            SizedBox(width: 8),
            Icon(Icons.bookmark, color: AppColors.warning),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSwipeRight();
        } else {
          onSwipeLeft();
        }
        return false; // Don't remove the item
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: alert.isRead
                        ? Colors.transparent
                        : AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.job.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            alert.isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _timeAgo(alert.notifiedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.mutedForegroundDark
                                : AppColors.mutedForegroundLight,
                          ),
                        ),
                        if (alert.isSaved) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.bookmark,
                              size: 14, color: AppColors.warning),
                        ],
                        if (alert.isApplied) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Applied',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark
                    ? AppColors.mutedForegroundDark
                    : AppColors.mutedForegroundLight,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: index * 80),
          duration: 400.ms,
        )
        .slideX(
          begin: 0.05,
          delay: Duration(milliseconds: index * 80),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  static String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
