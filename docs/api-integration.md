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
| Auth | `POST /auth/login` (OAuth2 form, not JSON), `POST /auth/register`, `GET /users/me`, `POST /auth/refresh` (interceptor only) |
| Jobs | `GET /jobs` (query: repeated `company`, `location`, `role`, `location_type`, `days_ago`, `page`, `limit`), `GET /jobs/recommended` (skill-matched feed), `GET /jobs/{id}`, `GET /jobs/{id}/skill-gap` |
| Companies | `GET /companies` |
| Alerts | `GET /alerts` (`unread_only`, `page`, `limit`), `PATCH /alerts/{id}/read`, `PATCH /alerts/{id}/saved`, `PATCH /alerts/{id}/applied` |
| Preferences | `PUT /users/me/preferences` |
| Push | `PUT /users/me/fcm-token` (via [`push_service.dart`](../my_flutter_app/lib/core/services/push_service.dart) after login + on token rotation) |
| Skills | `GET /users/me/skills`, `POST /users/me/skills`, `DELETE /users/me/skills/{skill}` |
| CV | `POST /users/me/cv/presign`, `POST /users/me/cv/{id}/confirm`, `GET /users/me/cv`, `GET /users/me/cv/{id}/download-url`, `DELETE /users/me/cv/{id}` |
| AI/ATS | `POST /users/me/cv/{id}/analyze`, `POST /users/me/cv/{id}/tailor`, `GET /users/me/cv/tasks/{taskId}` |
| CV drafts | `POST /users/me/cv/{id}/curate`, `GET /users/me/cv/drafts`, `GET/PATCH /users/me/cv/drafts/{id}`, `POST /users/me/cv/drafts/{id}/approve`, `GET /users/me/cv/drafts/{id}/download?format=pdf\|docx` |
| Career state | `PATCH /users/me` (`career_state`) |
| Employments | `GET/POST /employments`, `PATCH/DELETE /employments/{id}` |
| Achievements | `POST /achievements` (202), `GET /achievements` (`from`, `to`, `employment_id`, `category`, `limit`), `GET/PATCH/DELETE /achievements/{id}`, `GET /achievements/digest?months=` |
| Interview evidence | `GET /coach/questions/{id}/evidence` — the "you have N real examples" prompt on behavioural questions |
| Practice | `GET /coach/questions` (`category`, `limit`), `POST /coach/sessions`, `GET /coach/sessions`, `GET/PATCH /coach/sessions/{id}` |
| Practice answers | `POST /coach/sessions/{id}/answers/presign`, `POST /coach/answers/{id}/confirm` (202), `GET /coach/answers/{id}`, `GET /coach/tasks/{taskId}` |

**Recording upload** mirrors the CV flow: presign -> direct-to-S3 -> confirm. Two audio-specific rules:
- The presign request declares `content_type`, and the S3 policy **pins that exact value** — so the `Content-Type` policy field and the file part's own content type must match what was asked for (`audio/mp4` for the AAC/m4a the recorder produces).
- Rejections the client handles explicitly: **415** unsupported type, **413** over 60 MB, **422** no question supplied, **424** confirm before the upload landed.

**Dates**: employment and achievement dates are Postgres `date` columns, so `ApiService._ymd()` sends bare `YYYY-MM-DD`. Sending a full ISO datetime is a 422.

**Achievement capture is asynchronous.** `POST /achievements` returns **202** with a `task_id` and a `status` of `captured`/`structuring`; the client polls `GET /achievements/{id}` every 2 s (≤10 tries) and only then knows whether `needs_metric` is set. Nothing waits on the model call, because a habit feature that stalls is a habit feature people abandon.

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
