# Job Scout Mobile (Flutter) — Documentation

Flutter app (package `job_scout`) — the job-seeker client. Deliberately a **thin client**: browse jobs, receive alerts, view skill gaps, run AI CV analysis/tailoring. CV *management* (upload/delete) is web-only; the app points users to the dashboard.

Code lives in [`my_flutter_app/`](../my_flutter_app/). System-level context: [`../../docs/`](../../docs/README.md) · API contract: [`../../Job-backend/docs/api-reference.md`](../../Job-backend/docs/api-reference.md)

## Docs in this folder

| Doc | What it covers |
|---|---|
| [architecture.md](architecture.md) | core/features split, providers, router + auth guard, service locator, token flow |
| [folder-structure.md](folder-structure.md) | Annotated tree of `lib/` |
| [ui-ux-design.md](ui-ux-design.md) | Theme (mirrors the dashboard design system), widgets, UX patterns |
| [api-integration.md](api-integration.md) | `ApiServiceBase` contract, endpoints, mock service, CV/AI flows |
| [features.md](features.md) | Screen-by-screen catalog |

## Quick start

```bash
cd App-Job-Hunter/my_flutter_app
flutter pub get

# DEMO MODE (default — no backend needed, in-memory mock data)
flutter run
#   demo login: dev@jobscout.com / password123

# REAL BACKEND (start Job-backend first)
flutter run --dart-define=API_URL=http://localhost:8000/api/v1
#   Android emulator needs the host alias:
#   flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1

flutter test        # runs widget/unit tests
flutter analyze     # lints (flutter_lints)
```

The **only** switch between demo and real is the `API_URL` dart-define — see [api-integration.md](api-integration.md#demo-mode).

## Orientation in 60 seconds

- Entry: [`lib/main.dart`](../my_flutter_app/lib/main.dart) — `MultiProvider` (Auth, Theme, Alerts, JobsFilter) + `MaterialApp.router` (go_router).
- Screens live under [`lib/features/`](../my_flutter_app/lib/features/); shared infra under [`lib/core/`](../my_flutter_app/lib/core/).
- Every screen talks to the API through the `api` getter from [`service_locator.dart`](../my_flutter_app/lib/core/services/service_locator.dart) — never instantiate Dio or a service directly.
- Tokens sit in secure storage; a Dio interceptor injects Bearer and silently refreshes on 401 ([architecture.md](architecture.md#auth--tokens)).
- ⚠️ Known gaps (no push handling yet, applied-status labels are local-only, login contract mismatch vs the real backend): [`../../docs/known-issues.md`](../../docs/known-issues.md) #1, #18, #19.

## Conventions

- State: `provider` + `ChangeNotifier` for app-wide state; plain `setState` for screen-local lists/pagination. No bloc/riverpod — keep it consistent.
- New screen → `lib/features/<domain>/<name>_screen.dart` + route in [`app_router.dart`](../my_flutter_app/lib/core/router/app_router.dart) (inside the `ShellRoute` if it's a tab).
- New API call → add to `ApiServiceBase` **and both** implementations (`ApiService`, `MockApiService`) — the abstract class is the contract; a missing mock breaks demo mode.
- Models: `fromJson` data classes in [`models.dart`](../my_flutter_app/lib/core/models/models.dart), mirroring backend Pydantic schemas.
- S3 uploads use a **plain `Dio()`** without the auth interceptor (JWT breaks the presigned signature).
