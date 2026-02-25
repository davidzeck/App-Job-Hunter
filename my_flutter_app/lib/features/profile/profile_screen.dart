import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = api;
  UserProfileResponse? _user;
  List<AlertResponse> _savedAlerts = [];
  List<AlertResponse> _appliedAlerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.getCurrentUser(),
      _api.getAlerts(page: 1, limit: 50),
    ]);
    final user = results[0] as UserProfileResponse;
    final allAlerts = (results[1] as PaginatedResponse<AlertResponse>).items;
    if (mounted) {
      setState(() {
        _user = user;
        _savedAlerts = allAlerts.where((a) => a.isSaved).toList();
        _appliedAlerts = allAlerts.where((a) => a.isApplied).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ─── App Bar ───────────────────────────────
                SliverAppBar(
                  floating: true,
                  title: Text(
                    'Profile',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Avatar + Identity ─────────────
                        _AvatarSection(user: _user!)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),

                        const SizedBox(height: 20),

                        // ─── Stats Row ─────────────────────
                        _StatsRow(user: _user!)
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 400.ms),

                        const SizedBox(height: 24),

                        // ─── Appearance ────────────────────
                        _SectionHeader('Appearance'),
                        const SizedBox(height: 8),
                        _DarkModeCard()
                            .animate()
                            .fadeIn(delay: 150.ms, duration: 400.ms),

                        const SizedBox(height: 24),

                        // ─── Preferences ───────────────────
                        _SectionHeader('Job Preferences'),
                        const SizedBox(height: 8),
                        _PreferencesCard(user: _user!, isDark: isDark)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms),

                        const SizedBox(height: 24),

                        // ─── Notifications ─────────────────
                        _SectionHeader('Notifications'),
                        const SizedBox(height: 8),
                        _NotificationsCard(user: _user!, onChanged: _onPrefsChanged, isDark: isDark)
                            .animate()
                            .fadeIn(delay: 250.ms, duration: 400.ms),

                        const SizedBox(height: 24),

                        // ─── Saved Jobs ────────────────────
                        if (_savedAlerts.isNotEmpty) ...[
                          _SectionHeader('Saved Jobs'),
                          const SizedBox(height: 8),
                          _JobAlertRow(
                            alerts: _savedAlerts,
                            emptyIcon: Icons.bookmark_border,
                            emptyLabel: 'No saved jobs yet',
                          ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],

                        // ─── Applied Jobs ──────────────────
                        if (_appliedAlerts.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(child: _SectionHeader('Applied Jobs')),
                              TextButton(
                                onPressed: () =>
                                    context.push('/profile/applied'),
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _JobAlertRow(
                            alerts: _appliedAlerts,
                            emptyIcon: Icons.check_circle_outline,
                            emptyLabel: 'No applications yet',
                          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],

                        // ─── Account Actions ───────────────
                        _SectionHeader('Account'),
                        const SizedBox(height: 8),
                        _AccountCard(isDark: isDark)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms),

                        const SizedBox(height: 32),

                        // ─── Sign Out ──────────────────────
                        _SignOutButton()
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 400.ms),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _onPrefsChanged(String key, dynamic value) async {
    final notifs = Map<String, dynamic>.from(
      (_user!.preferences['notifications'] as Map? ?? {}),
    );
    notifs[key] = value;
    await _api.updatePreferences({'notifications': notifs});
    // Force local refresh for toggle
    setState(() {});
  }
}

// ─── Section Header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight,
      ),
    );
  }
}

// ─── Avatar Section ────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final UserProfileResponse user;
  const _AvatarSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(user.fullName ?? user.email);

    return Row(
      children: [
        // Avatar circle
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName ?? 'User',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.mutedForegroundDark
                      : AppColors.mutedForegroundLight,
                ),
              ),
              if (user.phone != null) ...[
                const SizedBox(height: 2),
                Text(
                  user.phone!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Verified badge
        if (user.emailVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 12, color: AppColors.success),
                SizedBox(width: 3),
                Text(
                  'Verified',
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
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ─── Stats Row ─────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserProfileResponse user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          label: 'Skills',
          value: '${user.skillsCount}',
          icon: Icons.psychology_outlined,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: 12),
        _StatItem(
          label: 'CV',
          value: user.hasCv ? 'Uploaded' : 'Missing',
          icon: Icons.description_outlined,
          color: user.hasCv ? AppColors.success : AppColors.destructive,
        ),
        const SizedBox(width: 12),
        _StatItem(
          label: 'Member',
          value: _memberSince(user.createdAt),
          icon: Icons.calendar_today_outlined,
          color: AppColors.mutedForegroundLight,
        ),
      ],
    );
  }

  static String _memberSince(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y';
    }
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo';
    }
    return '${diff.inDays}d';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.mutedForegroundDark
                    : AppColors.mutedForegroundLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dark Mode Card ────────────────────────────────────────────

class _DarkModeCard extends StatelessWidget {
  const _DarkModeCard();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight,
        ),
        title: Text(
          'Dark Mode',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(isDarkMode ? 'Currently dark' : 'Currently light'),
        value: isDarkMode,
        activeColor: AppColors.primaryBlue,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }
}

// ─── Preferences Card ──────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final UserProfileResponse user;
  final bool isDark;

  const _PreferencesCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final prefs = user.preferences;
    final roles =
        (prefs['roles'] as List?)?.whereType<String>().toList() ?? [];
    final locations =
        (prefs['locations'] as List?)?.whereType<String>().toList() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrefRow(
              label: 'Target Roles',
              icon: Icons.work_outline,
              tags: roles,
              isDark: isDark,
            ),
            if (roles.isNotEmpty && locations.isNotEmpty)
              const Divider(height: 24),
            _PrefRow(
              label: 'Locations',
              icon: Icons.location_on_outlined,
              tags: locations,
              isDark: isDark,
            ),
            const Divider(height: 24),
            // Manage skills
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/profile/skills'),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 18,
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage Skills',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${user.skillsCount} skills',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> tags;
  final bool isDark;

  const _PrefRow({
    required this.label,
    required this.icon,
    required this.tags,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.mutedForegroundDark
                    : AppColors.mutedForegroundLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text(
            'Not set',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ─── Notifications Card ────────────────────────────────────────

class _NotificationsCard extends StatelessWidget {
  final UserProfileResponse user;
  final Future<void> Function(String key, dynamic value) onChanged;
  final bool isDark;

  const _NotificationsCard({
    required this.user,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final notifs = (user.preferences['notifications'] as Map?)
            ?.cast<String, dynamic>() ??
        {};
    final pushEnabled = notifs['push'] as bool? ?? true;
    final emailEnabled = notifs['email'] as bool? ?? true;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            secondary: Icon(
              Icons.notifications_outlined,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
            title: Text(
              'Push Notifications',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            value: pushEnabled,
            activeColor: AppColors.primaryBlue,
            onChanged: (v) => onChanged('push', v),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            secondary: Icon(
              Icons.email_outlined,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
            title: Text(
              'Email Alerts',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            value: emailEnabled,
            activeColor: AppColors.primaryBlue,
            onChanged: (v) => onChanged('email', v),
          ),
        ],
      ),
    );
  }
}

// ─── Account Card ──────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final bool isDark;
  const _AccountCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            enabled: false,
            leading: Icon(
              Icons.upload_file_outlined,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
            title: Text(
              'Upload CV',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mutedLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForegroundLight,
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
            title: Text(
              'About Job Scout',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Job Scout',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Job Scout',
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sign Out Button ───────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sign out?'),
            content:
                const Text('You will need to log in again to access Job Scout.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.destructive),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          context.read<AuthProvider>().logout();
        }
      },
      icon: const Icon(Icons.logout, color: AppColors.destructive),
      label: const Text(
        'Sign Out',
        style: TextStyle(color: AppColors.destructive),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: AppColors.destructive),
      ),
    );
  }
}

// ─── Job Alert Row ─────────────────────────────────────────────

class _JobAlertRow extends StatelessWidget {
  final List<AlertResponse> alerts;
  final IconData emptyIcon;
  final String emptyLabel;

  const _JobAlertRow({
    required this.alerts,
    required this.emptyIcon,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (alerts.isEmpty) {
      return Row(
        children: [
          Icon(emptyIcon,
              size: 16,
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight),
          const SizedBox(width: 8),
          Text(
            emptyLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final job = alerts[i].job;
          return InkWell(
            onTap: () => context.push('/jobs/${job.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Company letter avatar + name
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            job.company.name[0],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          job.company.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.mutedForegroundDark
                                : AppColors.mutedForegroundLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Job title
                  Text(
                    job.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
