# LifeVerse Feature Audit and Roadmap

This file distinguishes source implementation from runtime verification. “Source-connected” means code paths exist in this checkout; it does not mean a live database, external provider, or every target device was exercised.

## Screen-by-screen audit

| Screen / flow | Source status | Verification status | Notes |
|---|---|---|---|
| Registration and login | Implemented | Not verified in this environment | MySQL session records and rate limits are present; no live account was used. |
| Session restoration | Implemented | Not verified in this environment | Secure token storage exists by platform; Flutter runtime checks remain incomplete. |
| Home | Implemented in source | Flutter runtime not verified | Focuses on one next step, a short factual week summary, recent records, and feature shortcuts. First-use guidance can be skipped and its dismissal is saved through the existing account app-state record. |
| Progress and Weekly Review | Implemented in source | Flutter runtime and live MySQL not verified | 7/30/90-day selection, visit/activity separation, calendar, dimension levels, goals, and recent records. Optional analytics sections report availability separately so a missing visit/goals/levels table does not erase available task history. Historical visits are not backfilled. Optional weekly prompts are not written there. |
| Evolution Matrix | Implemented in source | Existing behavior not re-run end to end | Keeps the existing feature name and four dimensions. A short choose → task → record guide replaces the duplicate progress overview; task load failures now include an inline retry. |
| Growth Goals | Implemented in source | Existing flows not re-run end to end | Existing SQL-backed task/active-day goals and local reminder controls remain available. |
| Reflect hub | Implemented in source | Flutter runtime not verified | Keeps existing feature names, groups them by user intent, and explains each in plain language. Butterfly Effect opens its analysis directly from the hub. |
| Twin Mind | Implemented in source | Backend unit tests pass; Flutter runtime/Gemini not verified | Chat continuity remains saved. Additional saved facts/action/choice context is opt-in and off by default; daily review answers are never queried for Twin context. Failed sends retain a retryable draft. |
| Vision Engine | Implemented in source | Backend unit tests pass; Flutter runtime/Gemini not verified | Existing scenarios, feedback, and quest conversion retained; availability refresh preserves the decision text and loaded scenario. Scenario copy identifies these as possibilities, not predictions. |
| Life Atlas | Implemented in source | Backend syntax and unit checks pass; Dart formatter parsed changed Flutter files; Flutter semantic analysis blocked by sandbox access to the external package cache and read-only SDK lock path | Uses milestones and saved Twin Mind memories; biography drafts can also use recent daily-review answers with a visible include option and source counts. Drafts remain editable and unsaved until Save. |
| Butterfly Effect | Implemented in source | Backend tests do not exercise live Gemini | Existing micro-decision/analysis actions remain in Twin Mind. UI calls results possible patterns and states they do not prove causation. |
| Time Capsules | Implemented in source | Device, media, and live storage not verified | Existing schedules/recipients/location remain. Tutorial and composer no longer request broad permissions; the system picker handles attachments and geo-lock requests location only when enabled. Attachment limits and errors are shown, failed friend/capsule loads can retry, unavailable images retain a message. Local media durability remains a deployment limit. |
| Profile and friend profiles | Implemented in source | Flutter runtime and live MySQL not verified | Profile totals refresh on tab selection; accepted connections open a compact XP/progress/dimension view and recipient-only capsule summaries. Email and photo editing are not implemented. |
| Capsule creation/opening | Implemented in source | Not re-verified | Existing idempotent create/open flows remain in place. |
| Account deletion | Implemented in source | Not re-run against real data | Current-password confirmation and SQL cleanup exist; filesystem cleanup can be partial and is reported. |

## Changes implemented in this workspace

- Added a shared dark-indigo/violet Material theme and reusable page header, section header, surface, metric, and message components.
- Replaced `/home` with a persistent five-destination mobile navigation bar and responsive desktop navigation rail: Home, Progress, Evolution, Reflect, Profile.
- Replaced the home orb/carousel with data-backed summaries, goal progress, quick actions, and recent event labels.
- Added a Progress API and screen with 7/30/90-day periods, separate visit/growth day totals, activity calendar, task/review/XP/streak metrics, dimension activity and levels, goals, and metadata-free recent activity.
- Added authenticated visit recording to the additive `user_app_visits` table. The unique account/date key deduplicates visits; date boundaries use UTC.
- Added authenticated display-name and username editing using existing `users` fields; no new profile columns were introduced.
- Reorganized Profile into overview, connections, and privacy/account sections. Existing connection QR, request, and account deletion flows remain available.
- Added authenticated friend profile summaries gated by an accepted connection, recipient-only capsule summaries/opening, explicit sharing visibility copy, and Profile refresh when returning from saved quest XP.
- Added a Reflect hub without replacing the existing feature screens.
- Added a saved-record weekly review with 7-day visit, task, review, XP, dimension, and goal summaries; reflection prompts link to the existing daily review and are clearly not saved by this screen.
- Reworked Home around an optional, skippable first-use guide, one suggested next step, a compact recorded-week summary, recent activity, and quick links. Guide dismissal uses the existing `user_app_state` storage; no new table or migration was added.
- Simplified the Evolution Matrix entry flow while preserving its visible name, dimensions, task-generation path, and dark theme. Progress metrics remain on the separate Progress destination.
- Grouped Reflect features under clear intentions without renaming them. The Butterfly Effect hub card now opens its analysis directly. AI data details are collapsed under a short, visible privacy summary.
- Made Home, Progress, and growth-task loading failures compact and retryable. Home/Progress remain navigable when analytics fail; absent visit/goal/level records are marked unavailable instead of being shown as zero.
- Hardened the Progress API against optional visit-history, lifetime-XP, HDE-stat, or growth-goal query failures. Core task/review activity remains required; optional failures are logged server-side and surfaced through per-section availability flags.
- Reworked Life Atlas around saved milestones, real chapter counts, milestone creation, and a review/edit/save biography draft flow backed by the existing `legacy_profiles` table. The additive protected `PUT /api/legacy/biography` endpoint validates and bounds reviewed text; no schema change was needed.
- Connected `survey_answers` to Life Atlas biography drafts. Recent review answers can be included through an explicit visible option, are sent only when a draft is requested, are handled as the user's reflections rather than verified facts, and remain excluded from Twin Mind chat context. Draft responses report which saved source records were used.
- Surfaced Life Atlas milestone core values in the timeline and added an optional core-value field to milestone creation; bounded values continue through the existing event engine and biography context.
- Connected Butterfly Effect decision labels end to end: the choice dialog now collects optional labels, the analysis reads them, and opt-in Twin Mind/Vision Engine choice context carries them along.
- Made Twin Mind context opt-in (off by default) and removed daily review answers from Twin context queries and prompts. The ongoing persona chat is still stored and included for conversation continuity.
- Kept Vision Engine inputs/results when checking unlock status, and revised Butterfly Effect language to describe possible patterns rather than proved causation.
- Removed broad capsule permission requests from tutorial and composer entry, added matching file count/per-file/total size checks and retryable loading errors, and added a fallback for unavailable capsule image media.
- Central event logging now writes empty metadata for new events. Reflection answers remain in their feature table; capsule text, AI text, and milestone content are no longer copied into new general activity metadata.
- Removed the old momentum-colored orb mode state updates because the mode no longer drives the app theme.
- Added backend tests for visit deduplication behavior, date-range validation, progress response shaping, profile update ownership fields, and privacy-safe activity logging.

## Database change and rollout

The schema initializer now creates `user_app_visits` with `CREATE TABLE IF NOT EXISTS`, a `(user_id, visit_date)` primary key, and an account foreign key. This is an additive, data-preserving schema change. No production database was modified and no historical visit records were fabricated.

The local development MySQL database was inspected: it had 21 tables, and `users.id` is an InnoDB `VARCHAR(255)` primary key. The only local schema change made during this verification was the additive `CREATE TABLE IF NOT EXISTS user_app_visits` from the existing initializer definition. It adds a `(user_id, visit_date)` primary key and account foreign key; it does not modify existing rows and no visits were backfilled. Production databases were not contacted. For another local/staging database, verify the target and back it up before running `npm run init-db`; that initializer includes other additive column/index changes and is not a versioned migration runner.

## Prioritized remaining work

### P0 — Verify this implementation

1. Run manual device checks. The web build and universal Android debug APK compile locally; actual browser/device interaction, iOS builds, and Windows native desktop builds remain unverified. `flutter run -d chrome` is also affected by a Flutter Web debug-service timeout in this environment; the compiled web app is served separately for browser access.
2. Exercise authenticated analytics, capsule, and biography save flows end to end. The 4 November audit connected read-only to the configured local schema and checked row counts/selected relationships; it did not execute feature writes, call Gemini, or use a signed-in device session.
3. Test login → Home → Progress/weekly review → Evolution → Reflect → Profile on phone/tablet/desktop sizes; verify large text, keyboard, screen reader, and loading/retry states.
4. Verify app visit deduplication across retries, app resume, midnight UTC boundary, logout/login, and two active sessions for the same account.
5. Verify that historical `user_activity_logs` rows containing old metadata are not exposed through the new API. Do not bulk-delete such rows without a separate assessed remediation plan.

### P1 — Product reliability and privacy

1. Continue the loading, empty, failure, permission-denied, retry, and offline audit across the remaining feature screens.
2. Review complete Gemini context assembly and error logging across Vision Engine, Butterfly Effect, and biography generation; Twin Mind daily-review exclusion and context opt-in are now covered by tests. Run these paths against an approved service configuration before release.
3. Define and approve account-data retention, export, and deletion behavior, including backups and shared capsule ownership.
4. Configure durable capsule storage if deployment needs restart/multi-instance resilience. Current project constraints prohibit introducing a new storage provider, so the local filesystem limitation remains until an approved compatible deployment storage choice exists.
5. Replace security-answer recovery with email recovery only after a provider is selected and configured; no provider is currently included.
6. Verify profile edits, goal reminders, QR/camera, local notifications, media permissions, and location behavior on actual Android/iOS devices.

### P2 — Further product improvements

1. Add previous-period comparisons only where enough post-rollout visit/activity history exists.
2. Consider custom date ranges if they remain clear and efficient.
3. Add profile photo editing only after a safe upload/URL policy uses the existing storage boundary; do not expose private account images through public URLs.
4. Continue screen-by-screen visual refinement and device testing of feature interiors while retaining feature logic and purposeful capsule styling.

## Current verification record

The row below is the historical verification snapshot from 29 October 2026. For the 4 November 2026 table-to-feature audit, live local row counts, foreign-key checks, and the Life Atlas review-answer change, see [`DATA_FLOW_AUDIT.md`](DATA_FLOW_AUDIT.md). Production was not contacted.

Final checks for this workspace run on 29 October 2026. Results below are from this implementation pass, not prior project reviews.

| Check | Result |
|---|---|
| Git status | Not available: this workspace has no `.git` directory. |
| Backend syntax/route registration | Passed: 32 JavaScript files checked; route registration OK. |
| Backend unit tests | Passed: 32 tests, 0 failures, including partial Progress availability when visit tracking is unavailable. |
| Dart formatting | Passed: 11 touched Dart files formatted. Formatter noted that the external `flutter_lints` cache file could not be read; this did not prevent formatting. |
| Dart analysis | Full-project analysis reports 99 info-level style/deprecation notices and no error-level findings; the command exits nonzero because the project treats info findings as a nonzero result. |
| Flutter widget tests | Passed: 6/6, including phone-width bottom navigation and desktop-width navigation rail. |
| Flutter web build and local serving | `flutter build web --debug --no-pub` passed. Served the compiled app at `http://127.0.0.1:5000`; `index.html` and `main.dart.js` both returned HTTP 200. Flutter's `flutter run -d chrome` debug-service setup timed out in `WebkitDebugger.enable`; the screenshot's refused `$dwdsSseHandler` is a stale/closed Flutter debug-server connection, not the API endpoint. |
| Android build | Passed: `flutter build apk --debug --no-pub --verbose`; produced the universal debug APK at `lifeverse_app/build/app/outputs/flutter-apk/app-debug.apk`. No Android device/emulator was available for installation/runtime testing. |
| Other native targets | iOS cannot be built on this Windows host; Windows native build prerequisites are incomplete (Visual Studio C++ workload unavailable). Responsive desktop/mobile browser layouts are covered by widget tests. |
| Local API health | Passed: `http://127.0.0.1:3000/health` returned HTTP 200 and reported the backend/database ready. Authenticated Home/Progress calls were not exercised with a signed-in test account. |
| Local MySQL schema | Inspected 21 existing tables, confirmed the `users.id` InnoDB key, then added only the missing `user_app_visits` table. No historical visits were inserted. No production database was contacted. |
| Live app API/database flow | Not fully exercised with a signed-in test account. Backend health passed; the local development schema change is documented above. |
| Gemini / Render / production / device test | Not run. |

## Manual development end-to-end checklist

Use an isolated development database and test accounts. Do not use production data.

- Sign up, sign in, restore a session, sign out, and confirm another account cannot read or edit the first account's data.
- Check Home and all five destinations; open every destination twice and confirm its view state is retained.
- Compare Progress 7/30/90-day ranges with saved activity and confirm the weekly review matches the 7-day records.
- Confirm app visit days do not increment growth days; complete a task and submit a daily review to verify activity/XP updates.
- Edit profile fields, create/manage a goal, send/accept a connection, review privacy controls, and exercise account deletion on disposable test data.
- Twin Mind: send with saved context off/on, confirm the context switch is per message, confirm daily review answers are excluded, and simulate an offline/failed send to check draft recovery.
- Vision Engine: load a scenario, edit decision text, refresh status, and confirm the input and loaded scenario remain.
- Life Atlas: add a milestone, generate a biography, edit it, save it, reload, and verify the saved version.
- Butterfly Effect: check the no-record empty state and an analysis with records; both should present results as exploratory patterns, not causal proof.
- Time Capsules: deny location permission, cancel file selection, exceed per-file/total limits, retry a failed friends/capsules request, and open a capsule with an unavailable image.
- Account deletion: verify deletion using disposable data and confirm intended account-owned records are removed without touching other users' records.

These are manual steps, not tests performed in this workspace. Device permission behavior, Gemini responses, database transactions, and account isolation still require runtime verification.
