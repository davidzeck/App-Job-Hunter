import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/theme/theme_provider.dart';
import 'package:job_scout/core/router/app_router.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
