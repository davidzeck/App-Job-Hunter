# Feature Catalog — Screen by Screen

All screens under [`my_flutter_app/lib/features/`](../my_flutter_app/lib/features/). Routes defined in [`app_router.dart`](../my_flutter_app/lib/core/router/app_router.dart); the five tab screens live inside the bottom-nav `ShellRoute`.

## Boot & auth

| Screen | Route | What it does |
|---|---|---|
| Splash — [`auth/splash_screen.dart`](../my_flutter_app/lib/features/auth/splash_screen.dart) | `/splash` | Runs `AuthProvider.initialize()` (token load), then routes: authenticated → `/home` · onboarding seen → `/auth/login` · else → `/onboarding` |
| Onboarding — [`onboarding/onboarding_screen.dart`](../my_flutter_app/lib/features/onboarding/onboarding_screen.dart) | `/onboarding` | Multi-page value-prop intro; persists `onboarding_seen` (SharedPreferences) so it shows once |
| Login — [`auth/login_screen.dart`](../my_flutter_app/lib/features/auth/login_screen.dart) | `/auth/login` | Email/password → `AuthProvider.login()`; snackbar on failure. Demo creds: `dev@jobscout.com`/`password123`. Sends the OAuth2 form the backend expects |
| Register — [`auth/register_screen.dart`](../my_flutter_app/lib/features/auth/register_screen.dart) | `/auth/register` | Name/email/password/confirm → `AuthProvider.register()` |

## Shell — [`shell/main_shell.dart`](../my_flutter_app/lib/features/shell/main_shell.dart)

Bottom `NavigationBar` hosting the 5 tabs — `Home · Jobs · Practice · My Career · Profile` — with the unread-alerts badge on **Home** (Alerts lost its tab to Practice on 2026-08-11 and its feed lives on Home), and the first `AlertsProvider.refresh()` triggered post-frame.

## Tabs

| Screen | Route | What it does |
|---|---|---|
| Home — [`home/home_screen.dart`](../my_flutter_app/lib/features/home/home_screen.dart) | `/home` | Parallel load: recent jobs (`getJobs(limit:5, daysAgo:30)`) + `getRecommendedJobs` + `AlertsProvider.refresh()`. Stats grid, recent alerts, **"Recommended for you" carousel** (match-% pill + matched skills; hidden when empty or errored — no CV yet), recent job cards |
| Jobs — [`jobs/jobs_screen.dart`](../my_flutter_app/lib/features/jobs/jobs_screen.dart) | `/jobs` | Infinite-scroll paginated list (`job_card`), debounced search, location-type filter, days-ago selector (1/3/7/14/30). Reacts to `JobsFilterProvider` when arriving from Companies (page size 5, filter chip shown). App-bar action → Companies, which lost its tab to My Career in 2026-08-10 |
| **Practice** — [`practice/practice_screen.dart`](../my_flutter_app/lib/features/practice/practice_screen.dart) | `/practice` | The wedge (since 2026-08-11). Question bank with a category filter (all / behavioural / technical / situational / intro) over a list of recent scored answers showing overall score + assigned drill. Tap a question → record |
| **My Career** — [`career/career_screen.dart`](../my_flutter_app/lib/features/career/career_screen.dart) | `/career` | The retention loop (since 2026-08-10). Digest card (wins, with-numbers, skills, active weeks + category chips) over the achievement log grouped by calendar month. FAB → capture sheet; polls the new entry and fires the **"add a number"** nudge only once structuring reports `needs_metric`. Tap an entry for the detail sheet (your words, the metric, skills, and the copyable CV bullet). `?log=1` opens capture straight away — that is where the weekly nudge notification lands |
| Profile — [`profile/profile_screen.dart`](../my_flutter_app/lib/features/profile/profile_screen.dart) | `/profile` | User info, saved/applied counts, **career state** chips (`actively_looking`/`open`/`not_looking` → `PATCH /users/me`), theme toggle (`ThemeProvider`), links to Skills, Applied, and **Manage CVs** (`/profile/cvs` — full client-side CV flow since 2026-07-15), logout |

Home also carries a **"What did you ship this week?"** prompt when nothing was logged in the last 7 days — the same window the backend's Friday nudge uses. It exists because push delivery is still gated on the Firebase ops step ([#2b](../../docs/known-issues.md)), which makes this currently the *only* place the weekly nudge appears.

## Pushed screens (outside the shell)

| Screen | Route | What it does |
|---|---|---|
| **Record an answer** — [`practice/record_answer_screen.dart`](../my_flutter_app/lib/features/practice/record_answer_screen.dart) | `/practice/record/:id` | Mic permission → AAC/m4a mono @64 kbps (5-min cap, 5-sec floor) → presign → S3 → confirm → poll → debrief. **A pulsing red dot and a running clock are on screen for the entire recording**; `PopScope` stops the mic if you leave, `dispose()` releases it, and the local temp file is deleted after upload or discard. On behavioural questions it shows *"you have N real examples for this"* from your achievement log |
| **Debrief** — [`practice/debrief_screen.dart`](../my_flutter_app/lib/features/practice/debrief_screen.dart) | `/practice/debrief/:id` | **The assigned drill renders first, above the scores** — a number says where you stand, the drill says what to do next. Then rubric axes (structure/evidence/relevance/conciseness, 1–5), delivery metrics (wpm + pace flag, filler count + breakdown, pauses), strengths, improvements, and the verbatim transcript in an expander. Closes with a reminder that the recording was deleted |
| **Roles** — [`career/employments_screen.dart`](../my_flutter_app/lib/features/career/employments_screen.dart) | `/career/roles` | Employment history: add/edit via bottom sheet, soft delete. Marking a role current demotes the previous one server-side, so new wins attach to the right role automatically |
| Alerts — [`alerts/alerts_screen.dart`](../my_flutter_app/lib/features/alerts/alerts_screen.dart) | `/alerts` | Paginated alert feed (page size 4), unread-only toggle, mark-read, save toggle, mark-applied — optimistic updates on the mutable `AlertResponse`. Pushed from Home since it stopped being a tab; the unread badge now sits on the Home tab icon |
| Companies — [`companies/companies_screen.dart`](../my_flutter_app/lib/features/companies/companies_screen.dart) | `/companies` | `getCompanies()` list with client-side search; tap → `JobsFilterProvider.filterByCompany()` → navigate to Jobs. Pushed from the Jobs app bar since it stopped being a tab |
| **Job Detail** — [`jobs/job_detail_screen.dart`](../my_flutter_app/lib/features/jobs/job_detail_screen.dart) | `/jobs/:id` | The richest screen (~1200 lines). Loads job detail + skill-gap + user CVs in parallel. Sections: header/description, **expandable skill gap** (matched/partial/missing vs the user's skills), save/unsave (alert toggle), Apply (`url_launcher` → `apply_url`), and the **AI section**: CV picker (ready CVs only) → Analyze (match % + present/missing keyword chips, cached results instant, else 2 s polling ≤60 s) → Tailor (tailored summary display). Explicit analyzing/tailoring progress and error states, 429-friendly messages |
| Skills — [`profile/skills_screen.dart`](../my_flutter_app/lib/features/profile/skills_screen.dart) | `/profile/skills` | Lists user skills; add via bottom sheet (`addUserSkill`), swipe/delete (`removeUserSkill`) |
| Applied — [`profile/applied_screen.dart`](../my_flutter_app/lib/features/profile/applied_screen.dart) | `/profile/applied` | Applied-jobs list with per-job status labels (Applied/Interviewing/Offer/Rejected + icon/color helpers) — ⚠️ labels are **local UI state only**, not persisted to the backend ([known issue #19](../../docs/known-issues.md)) |
| **Manage CVs** — [`profile/cv_management_screen.dart`](../my_flutter_app/lib/features/profile/cv_management_screen.dart) | `/profile/cvs` | The CV hub: upload PDF (`file_picker`, ≤5 MB, ≤10 CVs, progress bar, post-upload processing poll), CV list (status icon, download via presigned URL + `url_launcher`, delete with confirm), link to Skills, **Tailored CVs** drafts list with status chips → draft screen |
| **CV Draft** — [`profile/cv_draft_screen.dart`](../my_flutter_app/lib/features/profile/cv_draft_screen.dart) | `/profile/cvs/drafts/:id` | Status-driven curation review: `generating`/`approved` poll (2 s ≤60×); `review` = full editor (per-section cards, muted ORIGINAL block above editable tailored fields, injected-keyword chips, Save / **Approve & generate** bar); `rendered` = Download PDF/DOCX (presigned → `url_launcher`); `failed`/`superseded` notices |

## Screen-to-API mapping

| Screen | ApiServiceBase calls |
|---|---|
| Splash/Login/Register | `login`, `register`, `getMe` (via AuthProvider) |
| Home | `getJobs(limit:5, daysAgo:30)`, `getRecommendedJobs(limit:10)`; alerts via AlertsProvider (`getAlerts` ×3 parallel) |
| Jobs | `getJobs(page, limit, role, location, locationType, daysAgo, company)` |
| Job Detail | `getJob`, `getSkillGap`, `getCvs`, `analyzeCv`, `tailorCv`, `curateCv`, `getCvTaskStatus`, alert save/apply toggles |
| Manage CVs | `uploadCv`, `listCvs`, `getCvDownloadUrl`, `deleteCv`, `listDrafts` |
| CV Draft | `getDraft`, `updateDraft`, `approveDraft`, `getDraftDownloadUrl` |
| Companies | `getCompanies` |
| Alerts | `getAlerts(unreadOnly, page, limit)`, `markAlertRead`, `toggleAlertSaved`, `markAlertApplied` |
| Profile/Skills | `getMe`, `getUserSkills`, `addUserSkill`, `removeUserSkill` |
