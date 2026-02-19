import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/features/auth/splash_screen.dart';
import 'package:job_scout/features/auth/login_screen.dart';
import 'package:job_scout/features/auth/register_screen.dart';
import 'package:job_scout/features/shell/main_shell.dart';
import 'package:job_scout/features/home/home_screen.dart';
import 'package:job_scout/features/jobs/jobs_screen.dart';
import 'package:job_scout/features/jobs/job_detail_screen.dart';
import 'package:job_scout/features/alerts/alerts_screen.dart';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuth = authProvider.isAuthenticated;
        final initialized = authProvider.isInitialized;
        final path = state.matchedLocation;

        // Always allow splash
        if (path == '/splash') {
          // Once initialized, redirect based on auth state
          if (initialized && isAuth) return '/home';
          if (initialized && !isAuth) return '/auth/login';
          return null;
        }

        // Not initialized yet? Go to splash
        if (!initialized) return '/splash';

        // Auth routes: redirect to home if already logged in
        if (path.startsWith('/auth') && isAuth) return '/home';

        // Protected routes: redirect to login if not authenticated
        if (!path.startsWith('/auth') && !isAuth) return '/auth/login';

        return null;
      },
      routes: [
        // ─── Splash ────────────────────────────────
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),

        // ─── Auth ──────────────────────────────────
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen(),
        ),

        // ─── Main App (Bottom Nav Shell) ───────────
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, __) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/jobs',
              pageBuilder: (_, __) => const NoTransitionPage(
                child: JobsScreen(),
              ),
            ),
            GoRoute(
              path: '/companies',
              pageBuilder: (_, __) => NoTransitionPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Companies')),
                  body: const Center(child: Text('Companies - Coming Soon')),
                ),
              ),
            ),
            GoRoute(
              path: '/alerts',
              pageBuilder: (_, __) => const NoTransitionPage(
                child: AlertsScreen(),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => NoTransitionPage(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Profile')),
                  body: const Center(child: Text('Profile - Coming Soon')),
                ),
              ),
            ),
          ],
        ),

        // ─── Job Detail (outside shell for Hero) ───
        GoRoute(
          path: '/jobs/:id',
          builder: (_, state) => JobDetailScreen(
            jobId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
