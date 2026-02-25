# Job Scout — Remaining Work

_Last updated: 2026-02-24_

---

## Functional Gaps (broken or no-op today)

| # | Item | File | Detail |
|---|------|------|--------|
| 1 | **Applied status updates** | `features/profile/applied_screen.dart` | Status menu items call `Navigator.pop` only — no API call, no local state update. Need `api.updateApplicationStatus(id, status)` + `setState`. |
| 2 | **Skill gap empty state** | `features/jobs/job_detail_screen.dart` | If all three skill lists (matched / missing / to-learn) come back empty the section renders blank. Add a "No skill data available" fallback. |
| 3 | **CV upload** | `features/profile/profile_screen.dart` | Button shows "coming soon" SnackBar. Either wire `file_picker` + upload API, or hide the button until the feature is ready. |
| 4 | **Skills case-insensitive dedup** | `features/profile/skills_screen.dart` | `"Python"` and `"python"` both get added. Normalize to lowercase before the `contains` check. |

---

## Polish / UX

| # | Item | File | Detail |
|---|------|------|--------|
| 5 | **Swipe action visual confirmation** | `features/alerts/alerts_screen.dart` | `confirmDismiss` returns `false` (item stays) but there's no flash/color cue the action was registered. A brief green/red background moment before returning false would confirm it. |
| 6 | **Applied menu: hide current status** | `features/profile/applied_screen.dart` | If a job is already "Applied", the "Applied" option still appears in the update menu. Filter it out or show a checkmark next to the active status. |
| 7 | **Jobs empty state with company filter** | `features/jobs/jobs_screen.dart` | "No jobs match your filters" doesn't mention which company is active. Change to e.g. "No jobs found for **Stripe** — try removing the company filter." |
| 8 | **Profile CV status color** | `features/profile/profile_screen.dart` | "Missing" CV uses warning amber. `AppColors.destructive` (red) would signal the gap more clearly. |
| 9 | **Time abbreviation: `w` → `wk`** | `job_card.dart`, `alerts_screen.dart`, `applied_screen.dart` | `"2w ago"` is non-standard. Use `"2wk ago"` or `"2 weeks ago"`. |
| 10 | **Demo credentials UX** | `features/auth/login_screen.dart` | Email + password are pre-filled in the form. Cleaner pattern: empty fields + a small "Use demo credentials" `TextButton` below the form. |

---

## Missing Features (scope decisions)

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| 11 | **Advanced job filters** | Medium | Salary range, job type (full-time / contract / internship), seniority level. Needs API support + filter UI expansion on Jobs screen. |
| 12 | **Search history / autocomplete** | Small | Store last N searches in `SharedPreferences`, show as suggestions below the search bar in Jobs screen. |
| 13 | **Create / manage alert rules** | Medium | Users can view alerts but can't define new ones. Needs an "Add alert" sheet + API endpoint for saved-search rules. |
| 14 | **Real-time notifications** | Large | Notification preference toggles exist in Profile but do nothing. Needs WebSocket or push-notification backend integration. |

---

## Code Quality

| # | Item | File | Detail |
|---|------|------|--------|
| 15 | **Mutable mock data bleeds between sessions** | `core/services/mock_data.dart` | `mockAlerts` is mutated in-place (mark read, toggle save, etc.). On hot-restart the state persists in memory. Deep-copy the lists before modification, or add a `reset()` method. |
| 16 | **Auth interceptor: no refresh mutex** | `core/services/auth_interceptor.dart` | Concurrent 401 responses can trigger multiple simultaneous token-refresh calls. Add a `Completer` lock so only one refresh runs at a time and others wait on it. |
| 17 | **Unsafe list cast in Profile** | `features/profile/profile_screen.dart` | `(prefs['roles'] as List?)?.cast<String>()` throws at runtime if the list contains non-strings. Use `.whereType<String>().toList()` instead. |

---

## Done ✓

- Auth flow: splash → onboarding → login → register
- Service locator: mock ↔ real API swap via `AppConfig`
- Home dashboard: stat cards, recent alerts, latest jobs, skeleton loading
- Jobs: search + debounce, location-type + days filters, company deep-link chip, pagination, skeleton loading, error state
- Job detail: Hero animation, skill gap ring + breakdown, save toggle, haptics
- Companies: grid, detail sheet, skeleton loading, → Jobs deep link
- Alerts: swipe actions, haptics, read / save / applied, All/Unread toggle, skeleton loading
- Profile: preferences, skills sub-screen, applied sub-screen
- Global: dark mode, AlertsProvider badge, JobsFilterProvider

---

_Priority order: fix items 1–4 first (functional gaps), then 5–10 (polish), then 11–14 (new features) as needed._
