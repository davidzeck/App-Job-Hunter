import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';

/// Lightweight provider that drives:
///  - The unread-alert badge on the navigation shell
///  - The stats grid on the home screen
///  - The recent-alerts horizontal scroll on the home screen
///
/// Call [refresh()] on app start and after any alert mutation.
class AlertsProvider extends ChangeNotifier {
  final _api = api;

  int _unreadCount = 0;
  List<AlertResponse> _recentAlerts = [];
  Map<String, int> _stats = const {
    'totalJobs': 0,
    'newToday': 0,
    'unreadAlerts': 0,
    'applied': 0,
  };
  bool _loaded = false;

  int get unreadCount => _unreadCount;
  List<AlertResponse> get recentAlerts => _recentAlerts;
  Map<String, int> get stats => _stats;
  bool get loaded => _loaded;

  /// Fires three parallel requests:
  ///   1. Total jobs (last 30 days)
  ///   2. New jobs today
  ///   3. Recent alerts (up to 50, used for unread count + applied count)
  Future<void> refresh() async {
    try {
      // Start all three concurrently before awaiting any
      final f1 = _api.getJobs(page: 1, limit: 1, daysAgo: 30);
      final f2 = _api.getJobs(page: 1, limit: 1, daysAgo: 1);
      final f3 = _api.getAlerts(page: 1, limit: 50);

      final jobsR = await f1;
      final newTodayR = await f2;
      final alertsR = await f3;

      final alerts = alertsR.items;
      _unreadCount = alerts.where((a) => !a.isRead).length;
      _recentAlerts = alerts.take(4).toList();
      _stats = {
        'totalJobs': jobsR.total,
        'newToday': newTodayR.total,
        'unreadAlerts': _unreadCount,
        'applied': alerts.where((a) => a.isApplied).length,
      };
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Silent failure — keeps previous values displayed
    }
  }
}
