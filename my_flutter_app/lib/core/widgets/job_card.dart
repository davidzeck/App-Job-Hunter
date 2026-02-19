import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/theme/app_theme.dart';

class JobCard extends StatelessWidget {
  final JobListItem job;
  final int animationIndex;
  final Widget? trailing;

  const JobCard({
    super.key,
    required this.job,
    this.animationIndex = 0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Hero(
      tag: 'job-${job.id}',
      child: Material(
        color: Colors.transparent,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/jobs/${job.id}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company logo
                  _CompanyAvatar(company: job.company, isDark: isDark),
                  const SizedBox(width: 12),

                  // Job info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.company.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.mutedForegroundDark
                                : AppColors.mutedForegroundLight,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Location + chips
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isDark
                                  ? AppColors.mutedForegroundDark
                                  : AppColors.mutedForegroundLight,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                job.location ?? 'Unknown',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.mutedForegroundDark
                                      : AppColors.mutedForegroundLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Chips row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (job.locationType != null)
                              _TypeChip(
                                label: _formatLocationType(job.locationType!),
                                color: job.locationType == 'remote'
                                    ? AppColors.success
                                    : AppColors.primaryBlue,
                              ),
                            if (job.jobType != null)
                              _TypeChip(
                                label: _formatJobType(job.jobType!),
                                color: AppColors.mutedForegroundLight,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing widget or time ago
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _timeAgo(job.discoveredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.mutedForegroundDark
                              : AppColors.mutedForegroundLight,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(height: 8),
                        trailing!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: animationIndex * 80),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.08,
          delay: Duration(milliseconds: animationIndex * 80),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  static String _formatLocationType(String type) {
    switch (type) {
      case 'remote':
        return 'Remote';
      case 'hybrid':
        return 'Hybrid';
      case 'onsite':
        return 'On-site';
      default:
        return type;
    }
  }

  static String _formatJobType(String type) {
    switch (type) {
      case 'full_time':
        return 'Full-time';
      case 'part_time':
        return 'Part-time';
      case 'contract':
        return 'Contract';
      case 'internship':
        return 'Internship';
      default:
        return type;
    }
  }

  static String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _CompanyAvatar extends StatelessWidget {
  final CompanyBrief company;
  final bool isDark;

  const _CompanyAvatar({required this.company, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          company.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
