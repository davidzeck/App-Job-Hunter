# Mobile Folder Structure

Flutter project root: [`my_flutter_app/`](../my_flutter_app/). App code under `lib/`, split `core/` (infrastructure) vs `features/` (screens).

```
my_flutter_app/
├── lib/
│   ├── main.dart                          # runApp: MultiProvider + MaterialApp.router
│   │
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart            # API_URL dart-define → isDemoMode, apiUrl, timeouts
│   │   ├── models/
│   │   │   └── models.dart                # ALL data classes (mirror backend schemas)
│   │   ├── providers/
│   │   │   ├── auth_provider.dart         # login/register/logout, isAuthenticated/isInitialized
│   │   │   ├── alerts_provider.dart       # unread badge + home stats + recent alerts
│   │   │   └── jobs_filter_provider.dart  # company filter handoff Companies → Jobs
│   │   ├── router/
│   │   │   └── app_router.dart            # go_router: guard redirect + ShellRoute bottom nav
│   │   ├── services/
│   │   │   ├── api_service_base.dart      # ABSTRACT contract — screens depend only on this
│   │   │   ├── api_service.dart           # real impl (Dio) + SkillGap/Alert parsing extensions
│   │   │   ├── mock_api_service.dart      # demo impl (in-memory, simulated latency)
│   │   │   ├── mock_data.dart             # demo dataset
│   │   │   ├── service_locator.dart       # `api` getter: demo ⇄ real switch (ONLY switch point)
│   │   │   ├── api_client.dart            # shared Dio singleton + interceptor wiring
│   │   │   ├── auth_interceptor.dart      # Bearer inject + silent 401 refresh/retry
│   │   │   └── token_storage.dart         # flutter_secure_storage + in-memory cache
│   │   ├── theme/
│   │   │   ├── app_theme.dart             # AppColors + Material 3 light/dark ThemeData (Inter)
│   │   │   └── theme_provider.dart        # theme mode toggle
│   │   └── widgets/                       # shared: job_card, stat_card, skeleton_loader, error_state
│   │
│   └── features/
│       ├── auth/
│       │   ├── splash_screen.dart         # boot routing decision
│       │   ├── login_screen.dart
│       │   └── register_screen.dart
│       ├── onboarding/onboarding_screen.dart   # multi-page intro, SharedPreferences flag
│       ├── shell/main_shell.dart          # bottom NavigationBar (5 tabs) + alerts badge
│       ├── home/home_screen.dart          # stats grid + recent alerts + recent jobs
│       ├── jobs/
│       │   ├── jobs_screen.dart           # infinite scroll + debounced search + filters
│       │   └── job_detail_screen.dart     # richest screen: skill gap + AI analyze/tailor
│       ├── companies/companies_screen.dart
│       ├── alerts/alerts_screen.dart      # paginated feed, unread filter, read/save/applied
│       └── profile/
│           ├── profile_screen.dart        # user info, theme toggle, links, logout
│           ├── skills_screen.dart         # list/add/delete skills
│           └── applied_screen.dart        # applied jobs + local status labels
│
├── pubspec.yaml
├── test/                                  # flutter_test
├── android/ ios/ web/ …                   # platform shells
└── analysis_options.yaml                  # flutter_lints
```

## Where to make common changes

| Change | Touch these |
|---|---|
| New screen | `lib/features/<domain>/<name>_screen.dart` + route in `core/router/app_router.dart` (ShellRoute if it's a tab; also add the nav item in `main_shell.dart`) |
| New API call | `api_service_base.dart` (contract) + `api_service.dart` (real) + `mock_api_service.dart` (demo) — all three, always |
| New model | `core/models/models.dart` with `fromJson`, mirroring the backend schema |
| Cross-screen state | new `ChangeNotifier` in `core/providers/` + register in `main.dart` MultiProvider |
| Colors/typography | `core/theme/app_theme.dart` (keep parity with the dashboard tokens — see [ui-ux-design.md](ui-ux-design.md)) |
| Shared widget | `core/widgets/` |
