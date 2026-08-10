import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
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
import 'package:job_scout/features/career/career_screen.dart';
import 'package:job_scout/features/career/employments_screen.dart';
import 'package:job_scout/features/practice/practice_screen.dart';
import 'package:job_scout/features/practice/record_answer_screen.dart';
import 'package:job_scout/features/practice/debrief_screen.dart';
import 'package:job_scout/features/profile/profile_screen.dart';
import 'package:job_scout/features/profile/skills_screen.dart';
import 'package:job_scout/features/profile/applied_screen.dart';
import 'package:job_scout/features/profile/cv_management_screen.dart';
import 'package:job_scout/features/profile/cv_draft_screen.dart';

/// Global router handle for navigation from outside the widget tree
/// (notification taps in PushService). Set by [createRouter].
GoRouter? appRouter;

GoRouter createRouter(AuthProvider authProvider) => appRouter = GoRouter(
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
              path: '/career',
              pageBuilder: (_, state) => NoTransitionPage(
                // ?log=1 comes from the weekly nudge notification — the
                // prompt opens capture, not a list.
                child: CareerScreen(
                  openCapture: state.uri.queryParameters['log'] == '1',
                ),
              ),
            ),
            GoRoute(
              path: '/practice',
              pageBuilder: (_, __) => const NoTransitionPage(
                child: PracticeScreen(),
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

        // ─── Companies (pushed from Jobs, no longer a tab) ───
        GoRoute(
          path: '/companies',
          builder: (_, __) => const CompaniesScreen(),
        ),

        // ─── Career sub-screens (outside shell) ────
        GoRoute(
          path: '/career/roles',
          builder: (_, __) => const EmploymentsScreen(),
        ),

        // ─── Alerts (pushed from Home, no longer a tab) ───
        GoRoute(
          path: '/alerts',
          builder: (_, __) => const AlertsScreen(),
        ),

        // ─── Interview practice sub-screens ────────
        GoRoute(
          path: '/practice/record/:id',
          builder: (_, state) => RecordAnswerScreen(
            questionId: state.pathParameters['id']!,
            // The list hands the question over so the screen needn't refetch.
            question: state.extra as PracticeQuestion?,
          ),
        ),
        GoRoute(
          path: '/practice/debrief/:id',
          builder: (_, state) => DebriefScreen(
            answerId: state.pathParameters['id']!,
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
        GoRoute(
          path: '/profile/cvs',
          builder: (_, __) => const CvManagementScreen(),
        ),
        GoRoute(
          path: '/profile/cvs/drafts/:id',
          builder: (_, state) => CvDraftScreen(
            draftId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
