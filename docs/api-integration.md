# Mobile API Integration

Authoritative endpoint list: [backend api-reference.md](../../Job-backend/docs/api-reference.md). Base URL includes `/api/v1`.

## The contract — [`api_service_base.dart`](../my_flutter_app/lib/core/services/api_service_base.dart)

Screens depend only on the abstract `ApiServiceBase`; the [`service_locator`](../my_flutter_app/lib/core/services/service_locator.dart) `api` getter resolves it to `MockApiService` (demo) or `ApiService.instance` (real). **Any new method must be added to the base class and both implementations.**

## Demo mode

[`app_config.dart`](../my_flutter_app/lib/core/config/app_config.dart): `API_URL` dart-define absent → `isDemoMode == true` → [`MockApiService`](../my_flutter_app/lib/core/services/mock_api_service.dart) serves everything from [`mock_data.dart`](../my_flutter_app/lib/core/services/mock_data.dart) with 200–500 ms latency, including fake upload progress and AI results. Demo credentials: `dev@jobscout.com` / `password123`.

## Real implementation — [`api_service.dart`](../my_flutter_app/lib/core/services/api_service.dart)

Singleton over the shared Dio from [`api_client.dart`](../my_flutter_app/lib/core/services/api_client.dart) (Bearer + silent 401 refresh via [`auth_interceptor.dart`](../my_flutter_app/lib/core/services/auth_interceptor.dart); tokens in [`token_storage.dart`](../my_flutter_app/lib/core/services/token_storage.dart)).

### Endpoint map

| Area | Calls |
|---|---|
| Auth | `POST /auth/login` ⚠️, `POST /auth/register`, `GET /users/me`, `POST /auth/refresh` (interceptor only) |
| Jobs | `GET /jobs` (query: repeated `company`, `location`, `role`, `location_type`, `days_ago`, `page`, `limit`), `GET /jobs/{id}`, `GET /jobs/{id}/skill-gap` |
| Companies | `GET /companies` |
| Alerts | `GET /alerts` (`unread_only`, `page`, `limit`), `PATCH /alerts/{id}/read`, `PATCH /alerts/{id}/saved`, `PATCH /alerts/{id}/applied` |
| Preferences | `PUT /users/me/preferences` |
| Skills | `GET /users/me/skills`, `POST /users/me/skills`, `DELETE /users/me/skills/{skill}` |
| CV | `POST /users/me/cv/presign`, `POST /users/me/cv/{id}/confirm`, `GET /users/me/cv`, `GET /users/me/cv/{id}/download-url`, `DELETE /users/me/cv/{id}` |
| AI/ATS | `POST /users/me/cv/{id}/analyze`, `POST /users/me/cv/{id}/tailor`, `GET /users/me/cv/tasks/{taskId}` |

> ⚠️ **Login contract mismatch**: `login()` sends `FormData {username, password}` as `application/x-www-form-urlencoded` (assuming FastAPI's `OAuth2PasswordRequestForm`), but the backend expects **JSON `{email, password}`** — real-backend login currently 422s. See [known issue #1](../../docs/known-issues.md). Demo mode is unaffected.

Pagination: Flutter consumes the backend's `PaginatedResponse` shape (`items,total,page,limit,pages`) directly — no field renaming (unlike the dashboard).

## CV upload

Three steps, mirroring the dashboard:

1. Compute SHA-256 with the `crypto` package (❗not `dart:convert`) → `POST /users/me/cv/presign`.
2. Upload the file to the presigned URL with a **plain `Dio()` instance** — deliberately *not* the shared client, so no JWT interceptor touches the request (a JWT header breaks the S3/MinIO signature). Policy fields go into the `FormData` **before** the file; `onSendProgress` drives the progress UI.
3. `POST /users/me/cv/{id}/confirm`.

An in-memory `_alertsCache` in `ApiService` backs the synchronous helpers `isJobSaved()` / `alertIdForJob()` used by list UIs.

## AI analyze / tailor — await-based polling

No timers: Job Detail runs a simple `await` loop (poll `GET /users/me/cv/tasks/{taskId}` every 2 s, 60 s timeout) — it cancels naturally when the widget unmounts. Flow in [`job_detail_screen.dart`](../my_flutter_app/lib/features/jobs/job_detail_screen.dart):

1. `analyzeCv(cvId, jobId)` → cached `CVAnalysisResult` rendered immediately, or a `task_id`.
2. Poll until `isTerminal`; `CVAnalysisResult.matchPercent` = backend score ×100.
3. `tailorCv(cvId, jobId)` → always a task → same loop → `CVTailorResult` (tailored summary + keywords added).
4. **429** (10/hr or 50/day caps) → show the backend's message; do not retry-loop.

## Error mapping

`ApiService._message(DioException)` converts timeouts/connection errors/status codes into user-friendly strings; screens catch and render [`error_state.dart`](../my_flutter_app/lib/core/widgets/error_state.dart) or snackbars.

## Adding a new API call (checklist)

1. Confirm the endpoint in [backend api-reference.md](../../Job-backend/docs/api-reference.md).
2. Model with `fromJson` in [`models.dart`](../my_flutter_app/lib/core/models/models.dart).
3. Method on `ApiServiceBase` → implement in `ApiService` (map errors via `_message`) → implement in `MockApiService` with plausible fake data.
4. Consume via `final _api = api;` in the screen.
