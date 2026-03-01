# Mobile UI / UX Design

The app intentionally mirrors the dashboard's **"Urgent Clarity"** design system — [`app_theme.dart`](../my_flutter_app/lib/core/theme/app_theme.dart) opens with: *"All semantic colors matching the Next.js dashboard design system. Converted from HSL values in globals.css → Flutter Color hex."* When the dashboard tokens change, update `AppColors` to match (dashboard source of truth: [`globals.css`](../../Dashboard-Job-Hunter/src/app/globals.css), documented in [dashboard ui-ux-design.md](../../Dashboard-Job-Hunter/docs/ui-ux-design.md)).

## Color palette — `AppColors`

| Token | Hex | Dashboard equivalent |
|---|---|---|
| `primaryBlue` / `primaryLight` / `primaryDark` | `#3B82F6` / `#60A5FA` / `#2563EB` | `--primary` (blue 217 91% 60%) |
| `success` / `successLight` | `#16A34A` / `#22C55E` | `--success` |
| `warning` / `warningLight` | `#F59E0B` / `#FBBF24` | `--warning` / `--urgent` (amber) |
| `destructive` / `destructiveLight` | `#EF4444` / `#F87171` | `--destructive` |
| Light surfaces: `backgroundLight` `#FFFFFF`, `foregroundLight` `#030712`, `mutedLight` `#F1F5F9`, `mutedForegroundLight` `#64748B`, `borderLight` `#E2E8F0`, `cardLight` `#FFFFFF` | | `:root` tokens |
| Dark surfaces: `backgroundDark` `#030712`, `foregroundDark` `#F8FAFC`, `mutedDark` `#1E293B`, `mutedForegroundDark` `#94A3B8`, `borderDark` `#1E293B`, `cardDark` `#0F172A` | | `.dark` tokens |

Semantic usage matches the dashboard: match scores ≥75 success / ≥50 warning / else destructive; new-job accents in amber; source/CV statuses in green/amber/red.

## Theme construction — `AppTheme.light()` / `AppTheme.dark()`

Material 3 (`useMaterial3: true`) with `ColorScheme.fromSeed(primaryBlue)`, then overridden for exact parity:

- **Typography**: `GoogleFonts.interTextTheme` — Inter everywhere, same as the web.
- **Cards**: elevation 0, 12 px radius, 1 px border (`borderLight`/`borderDark`) — the web's "borders not shadows" surface language.
- **AppBars**: flat (elevation 0), background = surface.
- **Inputs**: filled with muted fill, borderless until focus, then 2 px `primaryBlue`; 12 px radius; comfortable padding.
- **Chips**: muted background, primary-tinted when selected, 8 px radius, no border — used for skills and keyword badges.
- **NavigationBar**: primary-tinted indicator (alpha .12 light / .20 dark), Inter labels, selected = w600 primary.

Mode switching: [`theme_provider.dart`](../my_flutter_app/lib/core/theme/theme_provider.dart) (`ThemeProvider`), toggled from the Profile screen; `MaterialApp.router` gets both themes.

## Shared widgets — [`core/widgets/`](../my_flutter_app/lib/core/widgets/)

| Widget | Purpose |
|---|---|
| `job_card.dart` | The standard job list item: title, company, location/type badges, freshness — reused on Home and Jobs |
| `stat_card.dart` | Home-screen stat tiles (total jobs, new today, unread, applied) |
| `skeleton_loader.dart` | Loading shimmer placeholders — use instead of spinners for list loads |
| `error_state.dart` | Standard error panel with retry action |

## Navigation & interaction patterns

- **Bottom NavigationBar** (5 tabs) inside a `ShellRoute` with `NoTransitionPage` — tab switches are instant; detail screens push full-screen on top.
- **Infinite scroll + pull-to-refresh** on Jobs and Alerts; page size varies by screen (jobs 5 when company-filtered, alerts 4).
- **Debounced search** on Jobs; filter chips for location type and a days-ago selector (`1/3/7/14/30`).
- **Cross-screen filter handoff**: tapping a company on the Companies screen sets `JobsFilterProvider.filterByCompany()` and jumps to Jobs — clear the filter chip to reset.
- **Optimistic toggles**: alert read/saved/applied flip locally (`AlertResponse` is mutable) then sync.
- **Progressive disclosure on Job Detail**: skill-gap and AI sections are expandable; AI results render in place with explicit analyzing/tailoring progress states.
- **External actions** via `url_launcher` (Apply opens the real posting).
- **Onboarding once**: multi-page intro, persisted `onboarding_seen` flag in SharedPreferences.
- Motion: `flutter_animate` for list/entrance animations — keep them short, mirroring the web's ≤300 ms rule.

## UX guardrails

- Show `skeleton_loader` for initial loads, inline spinners only for in-place actions (button-level progress on analyze/tailor).
- Every network failure path renders `error_state` with retry, or a snackbar for transient action failures — never silent failure.
- 429 from AI endpoints: show the friendly limit message; don't auto-retry.
- CV management is intentionally absent: Profile shows a "Manage CVs via web dashboard" tile — don't add upload UI here without a product decision.
