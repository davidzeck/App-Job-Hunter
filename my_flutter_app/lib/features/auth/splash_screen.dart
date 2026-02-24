import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/features/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();

    if (!mounted) return;

    // Router redirect handles the authenticated case → /home
    if (auth.isAuthenticated) return;

    // Not authenticated: check if onboarding has been shown before
    final seen = await hasSeenOnboarding();
    if (!mounted) return;

    if (seen) {
      context.go('/auth/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Hero(
              tag: 'app-logo',
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.work_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),

            const SizedBox(height: 24),

            // App name
            Text(
              'Job Scout',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms),

            const SizedBox(height: 8),

            // Tagline
            Text(
              'Never miss a job opportunity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 500.ms),

            const SizedBox(height: 48),

            // Loading indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            )
                .animate()
                .fadeIn(delay: 900.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
