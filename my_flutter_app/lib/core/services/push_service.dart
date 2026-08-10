import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:job_scout/core/config/app_config.dart';
import 'package:job_scout/core/router/app_router.dart';
import 'package:job_scout/core/services/service_locator.dart';

/// Push-notification lifecycle: Firebase init, permission + token
/// registration with the backend, token-rotation handling, and
/// notification-tap deep links.
///
/// Degrades to a silent no-op when:
///   - the app runs in demo mode (no API_URL dart-define), or
///   - Firebase isn't configured for this build (no google-services.json /
///     GoogleService-Info.plist) — `Firebase.initializeApp` throws and push
///     stays disabled without affecting the rest of the app.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _available = false;
  bool _tokenRegistered = false;
  StreamSubscription<String>? _refreshSub;

  /// Route from a notification tapped while the app was terminated.
  /// Consumed by MainShell once the authenticated UI is up.
  String? _pendingRoute;

  /// Set by main.dart — invoked for pushes received while the app is open
  /// (no system banner in that state; we refresh the in-app alerts badge).
  void Function(RemoteMessage message)? onForegroundMessage;

  /// Initialize Firebase and message handlers. Safe to call unconditionally
  /// before runApp; never throws.
  Future<void> init() async {
    if (AppConfig.isDemoMode) return;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('PushService: Firebase not configured, push disabled ($e)');
      return;
    }

    // Cold start caused by a notification tap (app was terminated):
    // the router doesn't exist yet, so stash the target for MainShell.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    _pendingRoute = initial == null ? null : _routeFor(initial.data);

    // Backgrounded app brought forward by a tap: router is alive, go direct.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _routeFor(message.data);
      if (route != null) appRouter?.go(route);
    });

    FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage?.call(message);
    });
  }

  /// Ask permission, fetch the device token, and register it with the
  /// backend. Fire-and-forget after login/register and on authenticated
  /// app start — must never block or fail the auth flow.
  Future<void> registerToken() async {
    if (!_available || _tokenRegistered) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await api.updateFcmToken(token);
      _tokenRegistered = true;

      // FCM rotates tokens (reinstall, restore-from-backup, ...) — keep the
      // backend current or delivery silently decays.
      _refreshSub ??=
          FirebaseMessaging.instance.onTokenRefresh.listen((fresh) async {
        try {
          await api.updateFcmToken(fresh);
        } catch (_) {
          // Next login re-registers.
        }
      });
    } catch (e) {
      debugPrint('PushService: token registration failed ($e)');
    }
  }

  /// Invalidate this device's token on logout. The backend clears its stored
  /// copy server-side as part of /auth/logout; this kills the token itself so
  /// nothing can be delivered to a logged-out (possibly shared) device.
  Future<void> clearToken() async {
    _tokenRegistered = false;
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Map a notification payload to an in-app route.
  ///
  /// `job_id` is the alert payload (no `type` field, so it stays first for
  /// backward compatibility); `type` carries everything added since.
  static String? _routeFor(Map<String, dynamic> data) {
    final jobId = data['job_id'];
    if (jobId is String && jobId.isNotEmpty) return '/jobs/$jobId';

    return switch (data['type']) {
      // The Friday "what did you ship this week?" nudge opens capture directly
      // — a habit prompt that lands you on a list is a prompt people ignore.
      'achievement_nudge' => '/career?log=1',
      _ => null,
    };
  }

  /// One-shot read of a cold-start deep-link target.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }
}
