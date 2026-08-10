import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/providers/alerts_provider.dart';
import 'package:job_scout/core/services/push_service.dart';
import 'package:job_scout/core/theme/app_theme.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Practice and My Career hold top-level slots because feature placement is
  // positioning: if nothing in the nav says career, the app reads as a job
  // board no matter what the copy claims. The two displaced tabs kept their
  // screens and moved to where they are actually used from — Companies is a
  // way into Jobs, and Alerts is a feed Home already surfaces.
  static const _tabs = [
    '/home',
    '/jobs',
    '/practice',
    '/career',
    '/profile',
  ];

  @override
  void initState() {
    super.initState();
    // Kick off the first refresh after the first frame so the provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AlertsProvider>().refresh();
      // App launched from a notification tap while terminated: the router
      // didn't exist yet, so PushService stashed the target route.
      final route = PushService.instance.consumePendingRoute();
      if (route != null) context.push(route);
    });
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final unreadCount = context.watch<AlertsProvider>().unreadCount;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          // Alerts lost its tab to Practice, so the unread badge lives here —
          // Home is where the alerts feed now surfaces.
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              backgroundColor: AppColors.destructive,
              child: const Icon(Icons.home_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              backgroundColor: AppColors.destructive,
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Practice',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'My Career',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
