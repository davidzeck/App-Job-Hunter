import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _api = api;
  JobDetail? _job;
  SkillGapResponse? _skillGap;
  bool _loading = true;
  bool _skillGapExpanded = false;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final job = await _api.getJobDetail(widget.jobId);
    final gap = await _api.getSkillGap(widget.jobId);
    final saved = _api.isJobSaved(widget.jobId);
    setState(() {
      _job = job;
      _skillGap = gap;
      _isSaved = saved;
      _loading = false;
    });
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final nowSaved = await _api.toggleJobSaved(widget.jobId);
    if (mounted) {
      setState(() {
        _isSaved = nowSaved;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nowSaved ? 'Job saved' : 'Removed from saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _applyNow(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open application link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Hero Header ─────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'job-${job.id}',
                child: Material(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Company logo + name
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.mutedDark
                                    : AppColors.mutedLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  job.company.name[0],
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    job.company.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? AppColors.mutedForegroundDark
                                          : AppColors.mutedForegroundLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (job.location != null)
                              _InfoChip(Icons.location_on_outlined, job.location!),
                            if (job.locationType != null)
                              _InfoChip(Icons.public, _formatType(job.locationType!)),
                            if (job.seniorityLevel != null)
                              _InfoChip(Icons.trending_up, _capitalize(job.seniorityLevel!)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Salary ──────────────────────────────
          if (job.salaryMin != null)
            SliverToBoxAdapter(
              child: _SalaryCard(job: job)
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
            ),

          // ─── Description ─────────────────────────
          if (job.description != null && job.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: isDark
                            ? AppColors.foregroundDark.withValues(alpha: 0.85)
                            : AppColors.foregroundLight.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),
            ),

          // ─── Skills Required ─────────────────────
          if (job.skills.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skills Required',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.skills.map((skill) {
                        return Chip(
                          label: Text(
                            skill.isRequired
                                ? '${skill.skillName} *'
                                : skill.skillName,
                          ),
                          backgroundColor: skill.isRequired
                              ? AppColors.primaryBlue.withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: skill.isRequired
                                ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                : (isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),
            ),

          // ─── Skill Gap Analysis ──────────────────
          if (_skillGap != null)
            SliverToBoxAdapter(
              child: _SkillGapSection(
                gap: _skillGap!,
                expanded: _skillGapExpanded,
                onToggle: () {
                  setState(() => _skillGapExpanded = !_skillGapExpanded);
                },
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms),
            ),

          // Bottom padding for the action bar
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),

      // ─── Sticky Bottom Bar ─────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton.outlined(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: _isSaved ? AppColors.primaryBlue : null,
                    ),
              onPressed: _toggleSave,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _applyNow(job.applyUrl),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Apply Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatType(String type) {
    switch (type) {
      case 'remote': return 'Remote';
      case 'hybrid': return 'Hybrid';
      case 'onsite': return 'On-site';
      default: return type;
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Sub-widgets ─────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final JobDetail job;

  const _SalaryCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = job.salaryCurrency ?? 'USD';
    final min = _formatNumber(job.salaryMin!);
    final max = job.salaryMax != null ? _formatNumber(job.salaryMax!) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        color: AppColors.success.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.success),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    max != null
                        ? '$currency $min - $max'
                        : '$currency $min',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'per month',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success.withValues(alpha: 0.7),
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

  static String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }
}

class _SkillGapSection extends StatelessWidget {
  final SkillGapResponse gap;
  final bool expanded;
  final VoidCallback onToggle;

  const _SkillGapSection({
    required this.gap,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pct = gap.matchPercentage;
    final color = pct >= 75 ? AppColors.success : (pct >= 50 ? AppColors.warning : AppColors.destructive);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Card(
        child: Column(
          children: [
            // Header — always visible
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: pct / 100,
                            strokeWidth: 5,
                            backgroundColor: color.withValues(alpha: 0.15),
                            color: color,
                          ),
                          Text(
                            '${pct.round()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skill Match',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gap.recommendation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.mutedForegroundDark
                                  : AppColors.mutedForegroundLight,
                            ),
                            maxLines: expanded ? 10 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded details
            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gap.matchingSkills.isNotEmpty) ...[
                      _SkillGroupHeader('Matching Skills', Icons.check_circle, AppColors.success),
                      const SizedBox(height: 8),
                      ...gap.matchingSkills.map((s) => _SkillRow(
                            icon: Icons.check_circle,
                            color: AppColors.success,
                            name: s.skillName,
                            detail: s.userLevel != null ? 'You: ${s.userLevel}' : null,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (gap.partialSkills.isNotEmpty) ...[
                      _SkillGroupHeader('Partial Match', Icons.warning_amber, AppColors.warning),
                      const SizedBox(height: 8),
                      ...gap.partialSkills.map((s) => _SkillRow(
                            icon: Icons.warning_amber,
                            color: AppColors.warning,
                            name: s.skillName,
                            detail: 'You: ${s.userYears?.toStringAsFixed(0) ?? "?"}yr / Need: ${s.requiredYears ?? "?"}yr',
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (gap.missingSkills.isNotEmpty) ...[
                      _SkillGroupHeader('Missing Skills', Icons.cancel, AppColors.destructive),
                      const SizedBox(height: 8),
                      ...gap.missingSkills.map((s) => _SkillRow(
                            icon: Icons.cancel,
                            color: AppColors.destructive,
                            name: s.skillName,
                            detail: s.isRequired ? 'Required' : 'Nice to have',
                          )),
                    ],
                    if (gap.matchingSkills.isEmpty &&
                        gap.partialSkills.isEmpty &&
                        gap.missingSkills.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No detailed skill breakdown available for this role.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.mutedForegroundDark
                                  : AppColors.mutedForegroundLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillGroupHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SkillGroupHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String? detail;

  const _SkillRow({
    required this.icon,
    required this.color,
    required this.name,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 22),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: theme.textTheme.bodyMedium),
          ),
          if (detail != null)
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
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
