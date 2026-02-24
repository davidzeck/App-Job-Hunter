import 'package:go_router/go_router.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/features/auth/splash_screen.dart';
import 'package:job_scout/features/auth/login_screen.dart';
import 'package:job_scout/features/auth/register_screen.dart';
import 'package:job_scout/features/onboarding/onboarding_screen.dart';
import 'package:job_scout/features/shell/main_shell.dart';
import 'package:job_scout/features/home/home_screen.dart';
import 'package:job_scout/features/jobs/jobs_screen.dart';
import 'package:job_scout/features/jobs/job_detail_screen.dart';
import 'package:job_scout/features/companies/companies_screen.dart';
import 'package:job_scout/features/alerts/alerts_screen.dart';
import 'package:job_scout/features/profile/profile_screen.dart';
import 'package:job_scout/features/profile/skills_screen.dart';
import 'package:job_scout/features/profile/applied_screen.dart';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuth = authProvider.isAuthenticated;
        final initialized = authProvider.isInitialized;
        final path = state.matchedLocation;

        // Always allow splash (it handles its own navigation after init)
        if (path == '/splash') {
          if (initialized && isAuth) return '/home';
          return null; // Splash handles !isAuth case (onboarding vs login)
        }

        // Not initialized yet? Go to splash
        if (!initialized) return '/splash';

        // Onboarding is public — let it through
        if (path == '/onboarding') return null;

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

        // ─── Onboarding ────────────────────────────
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
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
              pageBuilder: (_, __) => const NoTransitionPage(
                child: CompaniesScreen(),
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
              pageBuilder: (_, __) => const NoTransitionPage(
                child: ProfileScreen(),
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

        // ─── Profile sub-screens (outside shell) ───
        GoRoute(
          path: '/profile/skills',
          builder: (_, __) => const SkillsScreen(),
        ),
        GoRoute(
          path: '/profile/applied',
          builder: (_, __) => const AppliedScreen(),
        ),
      ],
    );
