import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:job_scout/core/theme/app_theme.dart';

const _kOnboardingSeenKey = 'onboarding_seen';

/// Call this once at app startup to check if onboarding should be shown.
Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingSeenKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingSeenKey, true);
}

// ─── Page Data ─────────────────────────────────────────────────

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

const _pages = [
  _OnboardingPage(
    icon: Icons.radar,
    color: AppColors.primaryBlue,
    title: 'Discover Jobs',
    subtitle:
        'Job Scout monitors your favourite companies 24/7 and surfaces every new opening the moment it\'s posted — no more missed opportunities.',
  ),
  _OnboardingPage(
    icon: Icons.notifications_active_outlined,
    color: AppColors.success,
    title: 'Get Instant Alerts',
    subtitle:
        'Receive push and email alerts the second a matching role goes live. Filter by remote, hybrid or on-site and never miss a deadline.',
  ),
  _OnboardingPage(
    icon: Icons.psychology_outlined,
    color: AppColors.warning,
    title: 'Know Your Fit',
    subtitle:
        'Upload your CV and Job Scout analyses every role against your skills, showing your match percentage and exactly what to learn next.',
  ),
];

// ─── Screen ────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Skip ──────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ),
              ),
            ),

            // ─── Pages ─────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(page: _pages[index]);
                },
              ),
            ),

            // ─── Dots ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: active
                        ? _pages[_currentPage].color
                        : (isDark
                            ? AppColors.mutedDark
                            : AppColors.mutedLight),
                  ),
                );
              }),
            ),

            // ─── CTA Button ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: _pages[_currentPage].color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isLast ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single Onboarding Page ────────────────────────────────────

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                duration: 500.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: 40),

          Text(
            page.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.2, delay: 150.ms, duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(height: 16),

          Text(
            page.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 250.ms, duration: 400.ms)
              .slideY(begin: 0.2, delay: 250.ms, duration: 400.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
