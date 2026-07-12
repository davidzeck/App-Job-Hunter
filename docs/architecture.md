# Mobile App Architecture

## Layering

```
lib/
├── core/        # shared infrastructure — config, models, services, providers, router, theme, widgets
└── features/    # one folder per screen domain — auth, onboarding, shell, home, jobs, companies, alerts, profile
```

Features depend on core; core never depends on features.

## Startup & wiring — [`main.dart`](../my_flutter_app/lib/main.dart)

```
main (async)
├── PushService.instance.init()   # Firebase + tap/foreground handlers;
│                                 # no-op in demo mode or without Firebase config
└── runApp
    └── MultiProvider
    ├── AuthProvider        # token load, login/register/logout, isAuthenticated/isInitialized
    ├── ThemeProvider       # light/dark mode
    ├── AlertsProvider      # unread badge, home stats, recent alerts (3 parallel fetches in refresh())
    └── JobsFilterProvider  # company-filter bridge: Companies screen → Jobs screen
    └── MaterialApp.router(theme: AppTheme.light(), darkTheme: AppTheme.dark(), routerConfig: appRouter)
```

State philosophy: `ChangeNotifier` providers only for **cross-screen** state (auth, theme, alert badge, filter handoff). Screen-local concerns (lists, pagination, loading flags) are plain `setState` — deliberate simplicity, don't introduce heavier state management.

## Navigation — [`core/router/app_router.dart`](../my_flutter_app/lib/core/router/app_router.dart)

go_router with:
- `initialLocation: '/splash'`, `refreshListenable: authProvider` — auth changes re-evaluate routing.
- A `redirect` guard: unauthenticated users can only reach public routes (splash/onboarding/login/register); authenticated users are kept out of auth screens.
- **`ShellRoute`** wraps the 5 bottom-nav tabs — `/home`, `/jobs`, `/companies`, `/alerts`, `/profile` — inside [`main_shell.dart`](../my_flutter_app/lib/features/shell/main_shell.dart) (NavigationBar + unread-alerts badge), with `NoTransitionPage` for instant tab switches.
- Detail/sub-routes sit **outside** the shell (full-screen push): `/jobs/:id`, `/profile/skills`, `/profile/applied`.

Launch decision (in [`splash_screen.dart`](../my_flutter_app/lib/features/auth/splash_screen.dart)): `AuthProvider.initialize()` → authenticated → `/home`; else onboarding seen (SharedPreferences flag) → `/auth/login`; else → `/onboarding`.

## API access — the service locator

```dart
// core/services/service_locator.dart — the ONLY switch point
ApiServiceBase get api =>
    AppConfig.isDemoMode ? MockApiService() : ApiService.instance;
```

- [`ApiServiceBase`](../my_flutter_app/lib/core/services/api_service_base.dart) — abstract contract every screen codes against (`final _api = api;`).
- [`ApiService`](../my_flutter_app/lib/core/services/api_service.dart) — real HTTP via the shared Dio singleton from [`api_client.dart`](../my_flutter_app/lib/core/services/api_client.dart).
- [`MockApiService`](../my_flutter_app/lib/core/services/mock_api_service.dart) — full in-memory implementation over [`mock_data.dart`](../my_flutter_app/lib/core/services/mock_data.dart) with 200–500 ms simulated latency.
- [`AppConfig`](../my_flutter_app/lib/core/config/app_config.dart): `isDemoMode == true` when no `API_URL` dart-define was provided; timeouts connect 10 s / receive 30 s.

## Auth & tokens

```
login/register → TokenResponse
     │
     ▼
TokenStorage (core/services/token_storage.dart)
  flutter_secure_storage: iOS Keychain / Android EncryptedSharedPreferences
  + in-memory cache for sync reads
     │
     ▼
AuthInterceptor (core/services/auth_interceptor.dart) on the shared Dio:
  • attaches Authorization: Bearer <access>
  • on 401: silent refresh via POST /auth/refresh using a separate,
    un-intercepted Dio → store new pair → retry the original request
  • refresh fails → tokens cleared → AuthProvider flips → router guard redirects to login
```

⚠️ The S3 upload path bypasses this interceptor on purpose — presigned uploads must carry no JWT ([api-integration.md](api-integration.md#cv-upload)).

## Push notifications — [`push_service.dart`](../my_flutter_app/lib/core/services/push_service.dart)

`PushService.instance` (singleton) owns the FCM lifecycle:
- `init()` (before `runApp`): `Firebase.initializeApp()` + message handlers. Silently disabled in demo mode or when the Firebase config files are missing.
- `registerToken()` (fire-and-forget from `AuthProvider` after login/register/authenticated start): permission → `getToken()` → `PUT /users/me/fcm-token`; `onTokenRefresh` keeps the backend current.
- `clearToken()` (on logout): `deleteToken()` locally; the backend nulls its stored copy in `/auth/logout`.
- Notification taps deep-link to `/jobs/:id` — live via the `appRouter` global; cold start via a pending id consumed in `MainShell.initState`. Foreground pushes call `onForegroundMessage` (wired in `main.dart` to `AlertsProvider.refresh()`).

## Data models — [`core/models/models.dart`](../my_flutter_app/lib/core/models/models.dart)

Single file of `fromJson` classes mirroring backend Pydantic schemas: `TokenResponse`, `UserProfileResponse` (incl. `hasCv`, `skillsCount`, `preferences`), `CompanyBrief`/`CompanyResponse`, `JobListItem` → `JobDetail` (inheritance mirrors backend `JobListItem`/`JobDetail`), skill-gap types (`SkillMatch`, `MissingSkill`, `PartialSkill`, `SkillGapResponse`), `AlertResponse` (mutable `isRead/isSaved/isApplied` for optimistic UI), generic `PaginatedResponse<T>` (`items,total,page,limit,pages` — backend shape, no renaming), and CV/AI types (`CVPresignResponse`, `CVResponse` with `isReady/isProcessing/isFailed`, `CVTaskStatusResponse` with `isSuccess/isTerminal`, `CVAnalysisResult` where `matchPercent = score×100`, `CVTailorResult`).

Two parsing extensions (`SkillGapResponseParsing`, `AlertResponseParsing`) live at the bottom of `api_service.dart` rather than `models.dart` — quirk to know when hunting for a `fromJson`.

## Error handling

`ApiService._message(DioException)` maps transport/status errors to friendly strings; screens wrap calls in try/catch and render [`error_state.dart`](../my_flutter_app/lib/core/widgets/error_state.dart) or snackbars. 429s from AI endpoints surface the backend's rate-limit message verbatim.

## Key dependencies ([pubspec.yaml](../my_flutter_app/pubspec.yaml))

`provider` 6 · `go_router` 14 · `dio` 5 · `flutter_secure_storage` 9 · `shared_preferences` (onboarding flag) · `google_fonts` (Inter) · `flutter_animate` · `cached_network_image` (logos) · `url_launcher` (apply links) · `file_picker` + `crypto` (CV SHA-256; upload UI currently web-only) · `intl`.
