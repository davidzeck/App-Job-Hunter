# Job Scout Flutter — Implementation Phases

## Current State (~65% complete)

### Done
- Splash → Login → Register flow with Hero animations
- Bottom navigation shell (5 tabs)
- Home screen with stat cards + recent alerts + latest jobs
- Jobs list with search, filter chips, pull-to-refresh
- Job detail with Hero animation, salary card, skill gap analysis
- Alerts list with swipe-to-read, swipe-to-save, All/Unread toggle
- Full theme system (light/dark) matching dashboard
- All data models + mock API service
- GoRouter with auth guards

### Stubs (route exists, screen is "Coming Soon")
- `/companies` → Companies screen
- `/profile`   → Profile screen

### Incomplete actions
- "Apply Now" button → shows snackbar, doesn't open URL
- "Save" bookmark on job detail → shows snackbar, not persisted
- "Mark Applied" in alerts → model supports it, no UI trigger

---

## Phase 2 — Complete the Shell (Priority: ship this week)

**Goal:** Every tab has a real screen. Every button does something real.

### 2.1 Companies Screen
**Files to create:** `lib/features/companies/companies_screen.dart`
- Grid layout (2 columns) of company cards
- Each card: company logo avatar, name, job count badge, description snippet
- Tap → company detail sheet (bottom sheet, not new screen — shows logo, description, active job count, "View Jobs" button that navigates to Jobs tab filtered by that company)
- Pull-to-refresh
- Search bar to filter companies by name

### 2.2 Profile Screen
**Files to create:** `lib/features/profile/profile_screen.dart`
- User avatar (initials circle), name, email, phone
- Stats row: skills count, CV uploaded badge
- Preferences section:
  - Roles list (chips, tappable to edit)
  - Locations preference (Kenya / Remote / Both)
  - Notification toggles (push/email, frequency: immediate/daily/weekly)
- App settings section:
  - Dark mode toggle (wired to ThemeProvider)
  - "Manage Skills" row → Skills screen
  - "Upload CV" row → file picker stub
- Account section:
  - "Sign Out" button → auth.logout() → router redirects to login

### 2.3 Skills Management Screen
**Files to create:** `lib/features/profile/skills_screen.dart`
- List of user's current skills with experience level chips
- "Add Skill" FAB → bottom sheet with text input + category picker + years slider
- Swipe to delete skill
- Skills pulled from mockUser.preferences

### 2.4 Apply Now — Open URL
**File to update:** `lib/features/jobs/job_detail_screen.dart`
**Dependency to add:** `url_launcher: ^6.3.1`
- Replace snackbar with `launchUrl(Uri.parse(job.applyUrl))`
- Fallback: show snackbar with the URL if launch fails

### 2.5 Save Job — Wire to Alerts
**Files to update:** `lib/features/jobs/job_detail_screen.dart`, `mock_api_service.dart`
- Check if job already has a saved alert, toggle bookmark icon accordingly
- On save: find matching alert → `toggleAlertSaved()` or create saved state
- Bookmark icon fills when saved (Icons.bookmark vs Icons.bookmark_border)

### 2.6 Mark Applied from Alerts
**File to update:** `lib/features/alerts/alerts_screen.dart`
- Long-press on alert card → context menu with "Mark Applied" option
- Or add a third swipe direction — use a trailing action button inside each item

---

## Phase 3 — Polish & UX (Priority: before first real user)

**Goal:** App feels complete and production-quality.

### 3.1 Onboarding Flow (3 screens, show on first launch)
**Files to create:** `lib/features/onboarding/onboarding_screen.dart`
- Screen 1: "Discover Jobs" — illustration + description
- Screen 2: "Get Alerts" — push notification permission request
- Screen 3: "Set Your Preferences" — pick roles + locations (saves to user preferences)
- "Skip" and "Next" navigation, dot page indicator
- Shown only once (check flag in local storage)

### 3.2 Pagination on Jobs and Alerts
**Files to update:** `jobs_screen.dart`, `alerts_screen.dart`
- Detect scroll near bottom → trigger `getJobs(page: currentPage + 1)`
- Append new items to list (don't replace)
- "Loading more..." indicator at bottom

### 3.3 Error States
**Files to update:** all screens using FutureBuilder/setState loading
- Retry button when API call fails
- Network error banner at top of screen
- Empty state illustrations (not just icon + text)

### 3.4 Search Improvements on Jobs Screen
**File to update:** `jobs_screen.dart`
- Debounce search input (300ms) instead of waiting for submit
- Search history (last 5 searches stored locally)
- "Suggested searches" chips below empty search bar

### 3.5 Notification Preferences (Profile → Settings)
- Wire the push/email toggles to actually call `PUT /users/me/preferences`
- Frequency selector (immediate/daily/weekly) saved to mock user preferences

### 3.6 Saved Jobs Tab
**Option A:** Add a 6th tab "Saved" — filter alerts where isSaved == true
**Option B:** Add "Saved" section to Profile screen
Recommendation: Option B (keep 5 tabs, add to profile)

### 3.7 Application Tracker
**Files to create:** `lib/features/profile/applied_screen.dart`
- List of jobs where isApplied == true (from alerts)
- Columns: company, title, applied date, status (applied/interviewing/rejected/offer)
- Status update via long-press menu

---

## Phase 4 — Real API Integration (Priority: after backend DB is running)

**Goal:** Replace all mock data with real HTTP calls.

### 4.1 HTTP Client Setup
**Files to create:**
- `lib/core/services/api_client.dart` — Dio instance with base URL, interceptors
- `lib/core/services/auth_interceptor.dart` — Attaches `Authorization: Bearer <token>` to every request; intercepts 401 → refresh token → retry

**Dependency to add:** `dio: ^5.7.0`

### 4.2 Secure Token Storage
**Files to create/update:**
- `lib/core/services/token_storage.dart` — read/write tokens via flutter_secure_storage
- Update `auth_provider.dart` → on login: save tokens; on initialize(): read tokens from storage

**Dependency to add:** `flutter_secure_storage: ^9.2.2`

### 4.3 Real API Service
**Files to create:** `lib/core/services/api_service.dart`
- Identical method signatures to `MockApiService`
- Uses `api_client.dart` to make real HTTP calls
- Maps `DioException` to user-friendly error messages

### 4.4 Environment Config
**Files to create:** `lib/core/config/app_config.dart`
- `baseUrl` — reads from compile-time Dart define (`--dart-define=API_URL=...`)
- `isDemoMode` — falls back to mock service if no URL configured

```dart
// Run with mock: flutter run
// Run with real API: flutter run --dart-define=API_URL=http://localhost:8000
```

### 4.5 Service Provider Switch
**File to update:** `lib/main.dart`
- Provide `MockApiService` or `ApiService` based on `AppConfig.isDemoMode`
- All screens read from a single `ApiServiceProvider` — zero screen code changes

---

## Phase 5 — Push Notifications (Priority: after Phase 4)

**Goal:** Real-time job alerts delivered to the device.

### 5.1 Firebase Setup
**Dependency to add:** `firebase_core`, `firebase_messaging`
- Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) — gitignored
- `lib/core/services/notification_service.dart`:
  - Request permission on first launch
  - Get FCM token → `PUT /users/me/fcm-token`
  - Handle foreground messages → show local notification
  - Handle background tap → navigate to specific alert/job

### 5.2 Local Notifications
**Dependency to add:** `flutter_local_notifications`
- Show in-app banner when FCM message arrives foreground
- Tap action navigates to `/jobs/{id}` or `/alerts`

### 5.3 Deep Links
- FCM payload includes `job_id` → tapping notification opens job detail directly
- Configure Android `intent-filter` and iOS `Associated Domains`

---

## Phase 6 — CV Upload & Processing (Priority: Phase 5 complete)

**Goal:** User can upload their CV, app extracts skills automatically.

### 6.1 File Picker
**Dependency to add:** `file_picker: ^8.1.4`
- Profile → "Upload CV" → file picker (PDF only, max 5MB)
- Upload to `POST /users/me/cv` as multipart form

### 6.2 Upload Progress UI
- LinearProgressIndicator while uploading
- Success state: "CV uploaded — skills extracted" with count
- CV preview: show extracted skills as chips

### 6.3 Skill Gap Refresh
- After CV upload → re-fetch skill gap for any viewed jobs (invalidate cache)

---

## Phase 7 — Testing (Priority: before App Store submission)

**Goal:** Confidence in app stability.

### 7.1 Unit Tests
- `test/core/models/models_test.dart` — fromJson/toJson round-trips for all models
- `test/core/services/mock_api_service_test.dart` — filtering, pagination, state mutations

### 7.2 Widget Tests
- `test/features/auth/login_screen_test.dart` — form validation, error display
- `test/features/jobs/jobs_screen_test.dart` — filter chips, empty state
- `test/features/alerts/alerts_screen_test.dart` — swipe actions

### 7.3 Integration Tests
- Full login → browse jobs → view detail → mark alert read flow
- Uses `integration_test` package with a mock HTTP server

---

## File Creation Summary

| Phase | New Files | Updated Files |
|-------|-----------|---------------|
| 2 | companies_screen.dart, profile_screen.dart, skills_screen.dart | job_detail_screen.dart, alerts_screen.dart, mock_api_service.dart, pubspec.yaml |
| 3 | onboarding_screen.dart, applied_screen.dart | jobs_screen.dart, alerts_screen.dart, all screens (error states) |
| 4 | api_client.dart, auth_interceptor.dart, api_service.dart, token_storage.dart, app_config.dart | main.dart, auth_provider.dart, pubspec.yaml |
| 5 | notification_service.dart | main.dart, pubspec.yaml, AndroidManifest.xml, Info.plist |
| 6 | (CV upload added to profile_screen.dart) | profile_screen.dart, pubspec.yaml |
| 7 | *_test.dart files (7+) | — |

---

## Dependency Additions by Phase

```yaml
# Phase 2
url_launcher: ^6.3.1

# Phase 3
shared_preferences: ^2.3.2   # onboarding "seen" flag, search history

# Phase 4
dio: ^5.7.0
flutter_secure_storage: ^9.2.2

# Phase 5
firebase_core: ^3.8.1
firebase_messaging: ^15.1.5
flutter_local_notifications: ^18.0.1

# Phase 6
file_picker: ^8.1.4
```
