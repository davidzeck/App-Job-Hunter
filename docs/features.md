# Feature Catalog — Screen by Screen

All screens under [`my_flutter_app/lib/features/`](../my_flutter_app/lib/features/). Routes defined in [`app_router.dart`](../my_flutter_app/lib/core/router/app_router.dart); the five tab screens live inside the bottom-nav `ShellRoute`.

## Boot & auth

| Screen | Route | What it does |
|---|---|---|
| Splash — [`auth/splash_screen.dart`](../my_flutter_app/lib/features/auth/splash_screen.dart) | `/splash` | Runs `AuthProvider.initialize()` (token load), then routes: authenticated → `/home` · onboarding seen → `/auth/login` · else → `/onboarding` |
| Onboarding — [`onboarding/onboarding_screen.dart`](../my_flutter_app/lib/features/onboarding/onboarding_screen.dart) | `/onboarding` | Multi-page value-prop intro; persists `onboarding_seen` (SharedPreferences) so it shows once |
| Login — [`auth/login_screen.dart`](../my_flutter_app/lib/features/auth/login_screen.dart) | `/auth/login` | Email/password → `AuthProvider.login()`; snackbar on failure. Demo creds: `dev@jobscout.com`/`password123` ⚠️ real-backend login blocked by [known issue #1](../../docs/known-issues.md) |
| Register — [`auth/register_screen.dart`](../my_flutter_app/lib/features/auth/register_screen.dart) | `/auth/register` | Name/email/password/confirm → `AuthProvider.register()` |

## Shell — [`shell/main_shell.dart`](../my_flutter_app/lib/features/shell/main_shell.dart)

Bottom `NavigationBar` hosting the 5 tabs, unread-alerts badge from `AlertsProvider`, first `refresh()` triggered post-frame.

## Tabs

| Screen | Route | What it does |
|---|---|---|
| Home — [`home/home_screen.dart`](../my_flutter_app/lib/features/home/home_screen.dart) | `/home` | Parallel load: recent jobs (`getJobs(limit:5, daysAgo:30)`) + `getRecommendedJobs` + `AlertsProvider.refresh()`. Stats grid, recent alerts, **"Recommended for you" carousel** (match-% pill + matched skills; hidden when empty or errored — no CV yet), recent job cards |
| Jobs — [`jobs/jobs_screen.dart`](../my_flutter_app/lib/features/jobs/jobs_screen.dart) | `/jobs` | Infinite-scroll paginated list (`job_card`), debounced search, location-type filter, days-ago selector (1/3/7/14/30). Reacts to `JobsFilterProvider` when arriving from Companies (page size 5, filter chip shown) |
| Companies — [`companies/companies_screen.dart`](../my_flutter_app/lib/features/companies/companies_screen.dart) | `/companies` | `getCompanies()` list with client-side search; tap → `JobsFilterProvider.filterByCompany()` → navigate to Jobs |
| Alerts — [`alerts/alerts_screen.dart`](../my_flutter_app/lib/features/alerts/alerts_screen.dart) | `/alerts` | Paginated alert feed (page size 4), unread-only toggle, mark-read, save toggle, mark-applied — optimistic updates on the mutable `AlertResponse` |
| Profile — [`profile/profile_screen.dart`](../my_flutter_app/lib/features/profile/profile_screen.dart) | `/profile` | User info, saved/applied counts, theme toggle (`ThemeProvider`), links to Skills, Applied, and **Manage CVs** (`/profile/cvs` — full client-side CV flow since 2026-07-15), logout |

## Pushed screens (outside the shell)

| Screen | Route | What it does |
|---|---|---|
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
