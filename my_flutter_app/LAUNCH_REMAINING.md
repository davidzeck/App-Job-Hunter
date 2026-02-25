# Job Scout Mobile App — Launch Remaining

_Stack: Flutter 3 · Dart 3 · Provider · GoRouter · Dio · FlutterSecureStorage_
_Last updated: 2026-02-25_

---

## Current State

The app has a complete UI shell with all major screens built and connected to a real HTTP service layer:

- Auth flow: splash → onboarding → login → register
- Home: stat cards, recent alerts, latest jobs, skeleton loading
- Jobs: search + debounce, location/days filters, company deep-link chip, pagination, error/empty states
- Job detail: Hero animation, skill gap ring + breakdown, save toggle, haptics
- Companies: grid, detail sheet, skeleton loading, → Jobs deep link
- Alerts: swipe actions, read / save / applied, All/Unread toggle, skeleton loading
- Profile: preferences, skills sub-screen, applied sub-screen, dark mode toggle
- Service layer: `ApiService` (real Dio HTTP) + `MockApiService` (offline demo) swapped via `AppConfig.isDemoMode`
- Auth: `TokenStorage` (FlutterSecureStorage), `AuthInterceptor` (Bearer inject + 401 refresh), `AuthProvider`

**The app runs in demo mode by default** (`--dart-define=API_URL=...` is required to switch to real API). Most enterprise-launch blockers are platform configuration and missing features, not missing UI screens.

---

## P0 — Blockers (not shippable without these)

### 1. Firebase / FCM not configured
The backend sends push notifications via `firebase-admin`. The app has no Firebase setup at all.

**Required:**
- Add `firebase_core`, `firebase_messaging` to `pubspec.yaml`
- Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`
- Call `await Firebase.initializeApp()` in `main()` (requires `WidgetsFlutterBinding.ensureInitialized()` first — see item 2)
- Request notification permission via `FirebaseMessaging.instance.requestPermission()`
- After login, call `POST /users/me/fcm-token` with the device FCM token — `ApiServiceBase` needs a `registerFcmToken(String token)` method
- Handle foreground messages with `FirebaseMessaging.onMessage` and show a local notification
- Handle background/terminated taps with `FirebaseMessaging.onMessageOpenedApp` → navigate to the relevant job

Without this, the app's primary value proposition — instant job alerts — does not work on device.

---

### 2. `main()` missing `WidgetsFlutterBinding.ensureInitialized()`
`main.dart` calls `runApp(...)` directly. Any async operation before `runApp` (Firebase init, SharedPreferences, SecureStorage warmup) will crash.

**Required:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  runApp(MultiProvider(...));
}
```

---

### 3. `AuthInterceptor` has no refresh mutex
`auth_interceptor.dart:39` — if two requests fail with 401 simultaneously, two concurrent refresh calls fire. The second will fail (the first already consumed the refresh token), log the user out unnecessarily, and lose their session.

**Required:** Add a `Completer<void>?` lock:
```dart
Completer<void>? _refreshCompleter;

// In onError:
if (_refreshCompleter != null) {
  await _refreshCompleter!.future;
  // retry original with the already-refreshed token
  handler.resolve(await _refreshDio.fetch(err.requestOptions));
  return;
}
_refreshCompleter = Completer();
// ... do refresh ...
_refreshCompleter!.complete();
_refreshCompleter = null;
```

---

### 4. Logout does not revoke the refresh token
`auth_provider.dart:84` — `logout()` clears local tokens only. The backend `POST /auth/logout` endpoint revokes the server-side refresh token. Without calling it, the token lives in the database until it naturally expires, making stolen tokens valid indefinitely.

**Required:**
- Add `Future<void> logout()` to `ApiServiceBase` and both implementations
- `AuthProvider.logout()` should call `api.logout()` before clearing storage (fire-and-forget is acceptable)

---

### 5. No forgot-password / reset-password screens
The login screen has no "Forgot password?" link. The backend has `POST /auth/forgot-password` and `POST /auth/reset-password`.

**Required UI:**
- `features/auth/forgot_password_screen.dart` — email input → `POST /auth/forgot-password`
- `features/auth/reset_password_screen.dart` — token + new password form → `POST /auth/reset-password`
- GoRouter route: `/auth/forgot-password` and `/auth/reset-password?token=...`
- Deep link handling so the email reset link opens this screen (see item 14)
- Add "Forgot password?" TextButton to the login screen

---

### 6. No post-registration email verification screen
After `POST /auth/register`, the backend sends a verification email. If email verification is enforced before login, the app shows a generic error with no recovery path.

**Required:**
- A "Check your email" screen after successful registration explaining next steps
- A "Resend verification email" button that calls `POST /auth/resend-verification`
- Handle the case where an unverified user tries to log in (403/422 response) by showing actionable guidance

---

### 7. App icons and splash screen are Flutter defaults
The app ships with the default Flutter bird icon and white splash. Unacceptable for store submission.

**Required:**
- Replace `android/app/src/main/res/mipmap-*/` with branded icons
- Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset/` with branded icons
- Configure `flutter_native_splash` or native splash XML/storyboard
- Add a small notification icon (white-on-transparent 96×96 PNG) to `android/app/src/main/res/drawable/` and reference it in FCM payload

---

### 8. Android and iOS platform configuration incomplete

**Android (`android/app/`):**
- `build.gradle` — confirm `applicationId` matches Play Console entry, set `minSdkVersion` to ≥21 (required by FlutterSecureStorage), configure signing for release builds
- `AndroidManifest.xml` — add `INTERNET` permission, `RECEIVE_BOOT_COMPLETED` for background notifications, and `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` (Android 13+)
- ProGuard rules for Dio / Gson if using R8/minification

**iOS (`ios/Runner/`):**
- `Info.plist` — add `NSFaceIDUsageDescription` (FlutterSecureStorage uses biometrics on iOS), `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` (CV upload, item 16), background fetch and remote notification capabilities
- Xcode: enable Push Notifications capability, enable Background Modes → Remote notifications
- Upload `AuthKey_XXXXXXXX.p8` APNs key to Firebase Console

---

### 9. `ApiService.getUserSkills` uses unsafe `.cast<String>()`
`api_service.dart:282` — `res.data!.cast<String>()` throws `CastError` at runtime if the response contains non-string elements (nulls, maps). Already identified in `REMAINING.md` item 17.

**Fix:**
```dart
return res.data!.whereType<String>().toList();
```

---

## P1 — Required for production quality

### 10. Forgot-password + profile: change password form
The profile screen has no way for an authenticated user to change their password. The backend has `POST /users/me/change-password`.

**Required:**
- Add a "Change Password" list tile in the profile screen under account settings
- Navigate to a dedicated `ChangePasswordScreen` with current-password + new-password + confirm fields
- Call `POST /users/me/change-password` on submit

---

### 11. No account deletion flow
GDPR Article 17 ("right to erasure") and Apple App Store Review Guidelines §5.1.1 require in-app account deletion. The backend has `DELETE /users/me`.

**Required:**
- Add a "Delete Account" option in the profile screen (destructive red, behind a confirmation dialog)
- Call `DELETE /users/me`, then `storage.clear()` + redirect to splash/login
- Show a clear warning: "This will permanently delete all your data"

---

### 12. No create / manage alert rules (saved searches)
Users can receive alerts that the backend triggers, but they cannot define _which_ searches to be alerted about from within the app. This is the core user-facing feature for a job alert app.

**Required UI + API:**
- `features/alerts/alert_rules_screen.dart` — list existing saved-search rules (keywords, location, job type)
- Create rule sheet: keyword(s), location, job type, minimum salary — `POST /users/me/alert-rules`
- Edit / delete rule — `PATCH /users/me/alert-rules/{id}`, `DELETE /users/me/alert-rules/{id}`
- Backend needs corresponding endpoints if not already present
- Add "Manage Alerts" entry point from the Alerts screen app bar or Profile screen

---

### 13. No search history / autocomplete on Jobs screen
`SharedPreferences` is already installed. The Jobs search bar has no history, recent searches, or autocomplete.

**Required:**
- On search submit: write the query to `SharedPreferences` (cap at 10 entries, FIFO eviction)
- When the search field receives focus and is empty: show a "Recent searches" list of tappable chips
- Clear history: X button per item + "Clear all" action
- Optional: debounced `GET /jobs?role={query}&limit=5` for live autocomplete suggestions

---

### 14. No deep link / universal link handling
Email alerts contain links like `https://app.jobscout.com/jobs/abc123`. Tapping on mobile should open the app directly to that job. GoRouter supports deep linking, but the native layer is not configured.

**Android:**
- `AndroidManifest.xml` — add `<intent-filter>` with `ACTION_VIEW`, `CATEGORY_BROWSABLE`, and the app domain for App Links
- Verify domain via `/.well-known/assetlinks.json` on the backend domain

**iOS:**
- Enable Associated Domains capability in Xcode (`applinks:app.jobscout.com`)
- Backend must serve `/.well-known/apple-app-site-association` with the app's Team ID / Bundle ID
- GoRouter `initialLocation` / `redirect` already handles auth gating, so deep links will work once native is wired

---

### 15. `AlertsProvider` badge can go stale after profile actions
`profile_screen.dart` calls `_api.getAlerts` but never notifies `AlertsProvider` after marking items as applied or toggling preferences. The unread badge in the bottom nav stays stale.

**Fix:**
```dart
// In profile_screen.dart after preference changes:
context.read<AlertsProvider>().refresh();
```

---

### 16. CV upload feature not implemented
The upload tile in `profile_screen.dart` is `enabled: false` with a "Soon" badge. The backend has `POST /users/me/cv`.

**Required:**
- Add `file_picker: ^8.x` to `pubspec.yaml`
- Upload tile: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'])`
- `POST /users/me/cv` as `multipart/form-data`
- Show upload progress indicator
- Update `UserProfileResponse.hasCv` after success

---

### 17. No offline / network status banner
When the device loses connectivity, the generic `ErrorStateWidget` appears on every screen reload. There is no persistent offline banner and no cached API responses.

**Required (minimum):**
- Use `connectivity_plus` package to detect connectivity changes
- Show a dismissable `MaterialBanner` ("No internet connection") at the top of screens when offline
- Pull-to-refresh should detect offline state and show a snackbar rather than wiping the existing list

---

### 18. `MockApiService` data mutated in-place between hot restarts
`mock_data.dart` lists (alerts, jobs, etc.) are mutated directly during the session. On hot restart the original constants have been modified, causing inconsistent test/demo state.

**Fix:**
- Return deep copies from `MockApiService` methods:
  ```dart
  return MockData.alerts.map((a) => a.copyWith()).toList();
  ```
- Or add a `MockData.reset()` method called in `MockApiService` constructor

---

### 19. Zero tests written
The project has `flutter_test` in dev dependencies but no test files exist. For an enterprise app, the minimum test surface before launch is:

| Test type | What to cover |
|-----------|--------------|
| Unit | `TokenStorage` save/load/clear, `AuthInterceptor` refresh logic, all `fromJson` model parsers |
| Widget | `LoginScreen` form validation, `JobCard` renders hero tag, `AlertsScreen` swipe actions |
| Integration | Full login → jobs list → job detail flow using `MockApiService` |

**Structure:**
```
test/
├── unit/
│   ├── token_storage_test.dart
│   ├── auth_interceptor_test.dart
│   └── models_test.dart
└── widget/
    ├── login_screen_test.dart
    └── job_card_test.dart
integration_test/
└── app_test.dart
```

---

## P2 — Enterprise polish

### 20. No analytics or crash reporting
Without telemetry, production issues are invisible until user complaints arrive.

**Required:**
- `firebase_analytics` — screen views, login events, job saves, applied events
- `firebase_crashlytics` — automatic crash capture; call `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`
- Tag users after login: `FirebaseCrashlytics.instance.setUserIdentifier(user.id)`

---

### 21. No app flavor / multi-environment setup
Currently only `--dart-define=API_URL` distinguishes environments. For a team workflow:

**Recommended flavor setup:**
```
flutter build apk --flavor dev    --dart-define=API_URL=https://dev-api.jobscout.app
flutter build apk --flavor prod   --dart-define=API_URL=https://api.jobscout.app
```

- Separate `google-services.json` per flavor in `android/app/src/{flavor}/`
- Different bundle IDs per flavor (`com.jobscout.app.dev`, `com.jobscout.app`)
- `AppConfig` extended with `AppFlavor` enum

---

### 22. No accessibility audit
Custom widgets (`JobCard`, `StatCard`, skeleton loaders, swipe `Dismissible` items) lack semantic labels. VoiceOver/TalkBack users cannot navigate the app.

**Required:**
- Add `Semantics` wrappers to `job_card.dart` (`label: '${job.title} at ${job.company.name}'`)
- Add `semanticLabel` to all `IconButton` and `FloatingActionButton` widgets
- Test with TalkBack (Android) and VoiceOver (iOS) before launch
- Ensure minimum touch target size of 48×48dp on all interactive elements

---

### 23. `LogInterceptor` should be enabled in debug mode
`api_client.dart:37-40` has the logger commented out unconditionally.

**Fix:**
```dart
if (kDebugMode) {
  dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
}
```

---

### 24. Advanced job filters
The Jobs filter row supports `locationType` and `daysAgo` only. Candidates need:
- **Job type**: Full-time / Part-time / Contract / Internship (API param: `job_type`)
- **Seniority**: Junior / Mid / Senior / Lead (API param: `seniority`)
- **Salary range**: min/max slider (API param: `min_salary`, `max_salary`)
- Expandable "More filters" bottom sheet to keep the UI clean

---

### 25. Companies screen has no pagination or search
`getCompanies()` returns all companies in one unbounded call. As the dataset grows this will slow the home screen.

**Required:**
- Add `search` and `page`/`limit` params to `ApiServiceBase.getCompanies()`
- Add a search bar to `companies_screen.dart`
- Paginate with infinite scroll (same pattern as Jobs and Alerts)

---

### 26. No in-app update check
If the backend API introduces a breaking change, older app versions will silently fail.

**Required:**
- Use `in_app_update` (Android) and `app_store_connect` API check (iOS) to prompt updates
- Or: backend returns `X-Min-App-Version` header; `AuthInterceptor` compares it to `packageInfo.buildNumber` and redirects to an "Update Required" screen

---

### 27. Profile screen: edit name / phone number
`profile_screen.dart` displays the user's full name and email as read-only text. There is no edit form. The backend accepts `PATCH /users/me` with `{ full_name, phone }`.

**Required:**
- Add an edit icon / "Edit Profile" button
- Modal bottom sheet or inline edit with text fields for full name and phone
- Call `PATCH /users/me` on save; update `AuthProvider._user`

---

## Screen / Feature Status

| Screen | UI Built | Real API Wired | Production Ready |
|--------|----------|----------------|-----------------|
| Splash | ✓ | — | ✓ |
| Onboarding | ✓ | — | ✓ |
| Login | ✓ | ✓ | ✗ (no forgot-pw link) |
| Register | ✓ | ✓ | ✗ (no verification screen) |
| Forgot Password | ✗ | ✗ | ✗ |
| Reset Password | ✗ | ✗ | ✗ |
| Home Dashboard | ✓ | ✓ | ✓ |
| Jobs List | ✓ | ✓ | ✓ |
| Job Detail | ✓ | ✓ | ✓ |
| Companies | ✓ | ✓ | ✗ (unbounded fetch) |
| Alerts | ✓ | ✓ | ✓ |
| Alert Rules (Create/Edit) | ✗ | ✗ | ✗ |
| Profile | ✓ | ✓ | ✗ (no edit, no delete account) |
| Skills | ✓ | ✓ | ✓ |
| Applied | ✓ | ✓ partial | ✓ |
| Change Password | ✗ | ✗ | ✗ |
| CV Upload | ✗ (stub) | ✗ | ✗ |

---

## Infrastructure Checklist

| Item | Status |
|------|--------|
| `google-services.json` added | ✗ |
| `GoogleService-Info.plist` added | ✗ |
| APNs key uploaded to Firebase | ✗ |
| Firebase.initializeApp() in main() | ✗ |
| FCM token registered after login | ✗ |
| Android release signing config | ✗ |
| iOS Push Notifications capability | ✗ |
| iOS Associated Domains capability | ✗ |
| Android `minSdkVersion` ≥ 21 | needs verification |
| App icons (all densities) | ✗ |
| Splash screen assets | ✗ |
| `flutter analyze` clean | ✓ |
| Unit + widget tests passing | ✗ |

---

## Recommended Implementation Order

1. `WidgetsFlutterBinding.ensureInitialized()` + Firebase init in `main()` — unblocks FCM
2. FCM setup: `google-services.json`, `GoogleService-Info.plist`, push permission, token registration
3. Refresh mutex in `AuthInterceptor` — prevents production session-loss bug
4. Logout revokes server token
5. Forgot-password + reset-password screens
6. Post-registration email verification screen
7. Android / iOS platform config (permissions, capabilities, signing)
8. App icons + splash screen
9. Account deletion flow (legal requirement for store submission)
10. Change password form in Profile
11. Create / manage alert rules
12. CV upload (unblock `file_picker` + multipart)
13. Deep link config (Android App Links + iOS Universal Links)
14. Analytics + Crashlytics
15. Tests (unit models → widget login → integration flow)
16. Advanced filters, companies pagination, edit profile, search history
