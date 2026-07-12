import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/providers/alerts_provider.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/providers/jobs_filter_provider.dart';
import 'package:job_scout/core/services/push_service.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/theme/theme_provider.dart';
import 'package:job_scout/core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op in demo mode or when Firebase isn't configured for this build.
  await PushService.instance.init();

  final alertsProvider = AlertsProvider();
  // A push while the app is open shows no system banner — refresh the badge.
  PushService.instance.onForegroundMessage = (_) => alertsProvider.refresh();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: alertsProvider),
        ChangeNotifierProvider(create: (_) => JobsFilterProvider()),
      ],
      child: const JobScoutApp(),
    ),
  );
}

class JobScoutApp extends StatelessWidget {
  const JobScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();

    return MaterialApp.router(
      title: 'Job Scout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,
      routerConfig: createRouter(authProvider),
    );
  }
}
