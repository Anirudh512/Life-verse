# LifeVerse project status and review

## Update — 29 October 2026

This workspace contains the Home/Progress/Profile and five-destination navigation transformation documented in [`docs/PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md) and [`docs/FEATURE_AUDIT_AND_ROADMAP.md`](docs/FEATURE_AUDIT_AND_ROADMAP.md). This pass simplifies the beginner journey while keeping the existing dark palette and names: Home has an optional, database-backed first-use guide and compact factual summary; Evolution Matrix explains the choose/task/record flow; Reflect groups existing features by intent; and progress/task failures have compact retry states. Progress analytics now distinguishes optional unavailable data from zero. Previous feature work remains: Twin Mind context opt-in, Vision Engine input retention, Life Atlas reviewed biography saves, and safer Time Capsule loading/permissions. During the follow-up audit, the local development MySQL schema received only the additive `user_app_visits` table after its referenced key was inspected; no existing rows were changed or backfilled, and no production database was contacted.

Static route review confirms authenticated ownership checks for analytics, tasks, reviews, goals, connections, Life Atlas, Twin Mind, Vision Engine, and private capsule reads. Visit insertion uses the authenticated session identity and the `(user_id, visit_date)` key. Analytics queries omit metadata and reflection/chat/capsule content. Existing login and account-deletion handlers were not changed; the existing deletion unit tests passed. These are source and mocked-test checks, not live account-isolation verification.

The current workspace has no Git repository, so a branch, diff, and uncommitted-change baseline could not be established. The user explicitly instructed the work to proceed without creating a repository. Backend verification passed: 32 JavaScript files passed syntax checks, route registration passed, and all 32 Node unit tests passed. Dart formatting completed for 11 touched files; the formatter could not read the external `flutter_lints` cache config but formatted successfully. Full-project analysis reports 99 info-level style/deprecation notices and no error-level findings. All 6 Flutter widget tests passed. `flutter build web --debug --no-pub` completed successfully, and the compiled app was served at `http://127.0.0.1:5000`; the index and main JavaScript returned HTTP 200. `flutter run -d chrome` still times out while attaching Flutter's Web debug service (`WebkitDebugger.enable`); the refused `$dwdsSseHandler` in the screenshot is a stale debug-server connection. `flutter build apk --debug --no-pub --verbose` succeeded and produced `lifeverse_app/build/app/outputs/flutter-apk/app-debug.apk`; no emulator/device was connected for runtime testing. iOS native builds are unavailable from this Windows host, and Windows native builds need the missing Visual Studio C++ workload. Local `/health` on port 3000 returned HTTP 200 and reported the backend/database ready. The backend `.env` has no database URL and resolves to a loopback MySQL host. The local development schema was inspected and received only the additive `user_app_visits` table after confirming the referenced `users.id` key; no existing rows were changed, no historical visits were inserted, and no production database was contacted. Database row contents/isolation were not independently audited, so no full initializer or signed-in DB flow test was run. Without URL configuration the initializer defaults to `localhost`, `root`, database `lifeverse`, creates the database if absent, then applies the full initializer. No production runtime behavior is claimed. A source snapshot was saved before this pass at `C:\Users\jerip\.codex\visualizations\2026\10\27\01a17eab-f289-70f1-a458-de99e3879d84\LifeVerse_preverification_20261028_source.zip` (234 files; excludes `.env`, credentials, dependencies, generated SDK config, builds, logs, uploads, database files, symlinks, and partial backups). It predates the UI/reliability changes in this pass. The older review below is preserved as a dated historical review and is not evidence for this update.

**Reviewed:** 23 October 2026  
**Scope:** Flutter client, Express API, MySQL schema, Gemini calls, uploads, and deployment configuration. No production service was contacted.

## Executive assessment

LifeVerse is a substantial prototype, not a release-ready product. It has a Flutter app, a Node/Express API, and MySQL-backed flows for accounts, growth tasks, time capsules, friends, a timeline, a digital twin, and future simulations. Those features are connected in source, but production connections and platform builds have not been verified.

This is fixable without rewriting the app. The most important local correctness and security gaps have been addressed in this workspace. The remaining release blockers depend on decisions or setup outside the source tree: durable upload storage, real password-reset email, privacy/retention policy, production connection values, and deployment/build verification.

Render remains the planned final deployment stage. No Render deployment or production database change was made.

## Project map and connections

```text
Flutter app ── HTTPS/JSON + bearer session ──> Express API
                                                   ├──> MySQL
                                                   ├──> Gemini API
                                                   └──> local capsule upload directory

Flutter device ──> local notifications, camera/media/location features
```

| Component | What the source connects | Current status |
|---|---|---|
| Flutter → API | `API_BASE_URL`, bearer session header | Local defaults point to localhost; release builds now require the URL to be supplied. No production URL or live API check is recorded. |
| API → MySQL | `DATABASE_URL`/`MYSQL_URL`, or local `DB_*` variables | Local development DB health returned ready and the additive visit table was applied after schema inspection. Signed-in query flows and production DB behavior remain untested. DB sessions now use UTC. |
| API → Gemini | `GEMINI_API_KEY`, Gemini 2.5 Flash | AI calls are implemented for tasks, Twin, Butterfly, biography, and future simulations. Key validity, quota, and provider behavior are unverified. |
| Capsule media | Multer writes to `UPLOAD_DIR`; MySQL stores metadata | Upload limits and a default 1 GiB per-account quota exist. Files still use local disk; a persistent Render disk or object store must be selected and configured. |
| Email and remote push | No email provider or remote push implementation | Password recovery still uses the account security answer. Recipient alerts are in-app when LifeVerse is opened; sender-side notifications are local. |
| Device features | Local notifications, camera/QR, media picker, location | Android debug APK compiles; actual device behavior and iOS builds remain unverified. Geo checks use coordinates reported by the client and do not prove physical presence. |

## Work completed in the current workspace

| Area | Changes |
|---|---|
| XP, HDE, surveys | Generic event XP endpoint is disabled; HDE logging cannot choose event type or reward. Task rewards are derived from stored tasks and clamped. Task completion, survey submission, XP, stats, timeline, and Twin updates are transactional/idempotent where applicable. |
| HDE progress | The Evolution Matrix now loads the signed-in user's XP analytics from MySQL-backed API data, displays weekly XP, streak, momentum, balance, and per-dimension levels, and supports retry/pull-to-refresh. |
| Personal growth goals | SQL-backed and tied to one of the four HDE dimensions. Each goal measures completed tasks or distinct active days; users can create, edit, refresh, and delete up to 10 goals. Optional Android/iOS reminders are scheduled locally for the day before the due date, with Android reboot rescheduling configured. |
| Capsules | Create/open effects are transactional; open rewards happen once. Create requests accept an idempotency key, and the Flutter composer reuses its key on retry until the draft changes. Upload type/size/count limits and a per-user storage quota are enforced. Capsule ownership is assigned from the authenticated session after multipart parsing, not from a submitted account ID. |
| Trusted connections | Requests serialize by user pair and are used to select time-capsule recipients. Accepted connections can inspect a compact XP/progress/dimension summary; reflections, goals, account details, and chats remain private. Capsule summaries appear only for capsules shared with that viewer; messages and media still use recipient/contributor access checks. |
| Future simulations | Recommendation dimensions and text are bounded, same-day duplicate commits are handled, and task/activity writes are transactional. Each new reflection shows its data coverage and can be rated useful/not useful; ratings tune guidance style and are not prediction-accuracy labels. |
| Twin Mind mentoring | Chat turns persist in SQL by account and persona and reload when the user returns. The mentor uses recent conversation, HDE activity, reflections, choices, and saved facts. It stores the user's wording only after an explicit request and only for non-sensitive preferences, goals, interests, hobbies, routines, or values. Users can review and delete individual saved facts or clear all Twin Mind conversations and facts. Profile signals now describe recorded activity and coverage instead of inferred personality scores. |
| Vision Engine mentoring | Scenarios now include the user's growth profile, recent HDE records, reflections, choices, and explicitly saved facts. Prompts call them uncertain scenarios rather than exact predictions; input and response shapes are bounded/validated. Users choose the HDE dimension when committing a scenario as a quest. |
| App preferences | `UserState.updateAppState` now debounces and serializes SQL saves, covering the selected Twin Mind persona and other app preferences. |
| Navigation and home | Home cards show the Twin Mind activity signal and actual Vision Engine readiness when available. Unknown route names now land on a recovery page with a direct return-home action instead of silently opening the dashboard. |
| Sessions and recovery | Server stores SHA-256 session digests and no longer accepts query-string tokens. Login/recovery/registration have process-local rate limits; new/reset passwords require 12–128 characters; recovery responses are generic. Retired verification endpoints return 410. |
| Client session storage | Native session tokens use `flutter_secure_storage`; previous native-file and browser `localStorage` values migrate on first read. Android backup is disabled for the token store, and macOS keychain entitlements were added. Web storage needs HTTPS or localhost and cannot prevent same-origin script compromise. |
| Account privacy control | Profile has permanent account deletion with current-password confirmation. The API cascades user-owned records, removes the user’s sent capsules/media, clears recipient/contributor references, and reports incomplete file cleanup. Deleting a sender also removes shared capsules for their recipients. |
| AI and geo disclosures | AI screens explain that prompts/activity go to Gemini and that Twin Mind conversation history and explicitly requested non-sensitive facts are stored in the LifeVerse SQL account. Users can clear Twin Mind data from its menu. Geo-lock copy says it checks device-reported location. A full privacy/retention policy is still needed. |
| Misleading sample metrics | Removed hard-coded profile rank/progress/counts and fabricated home-card dates/confidence/chapter values. |
| Startup and writes | App starts before optional service setup; temporary session-validation failures preserve the cached session and offer retry. Failed HDE saves roll back optimistic state. |
| Flutter cleanup | Fixed pressed-state variables that reset during auth-button rebuilds, removed obsolete capsule-open code/imports, and removed unreachable dimension-switch fallbacks. |
| Data backend cleanup | Removed unused Google/Firebase configuration, Android Gradle hooks, a service-account key, and a script that could delete remote auth users. Application records remain in MySQL. The remote service-account key, if active, still needs revocation in Google Cloud IAM. |
| Deployment and docs | Release Flutter builds require `API_BASE_URL`; the root Dockerfile now packages Flutter Web and Express behind one origin, with `/api` used for browser requests. Render configuration runs schema initialization and exposes a DB-backed health check. No deployment was performed. |

## Remaining work, ordered by release importance

### P1 — Required before a public release

1. **Choose durable media storage.** Configure a persistent Render disk or object storage, set `UPLOAD_DIR` or the storage adapter/credentials, and verify files remain available after restart/redeploy. The default per-account limit is 1 GiB; tune it for the chosen provider.
2. **Replace security-answer recovery.** Connect a real email provider, issue expiring one-time reset tokens, and implement email verification. Current endpoints do not send email.
3. **Approve privacy and retention behavior.** The app explains Gemini processing and has account deletion, but there is no approved privacy/retention policy or server-enforced AI opt-in. Decide what Gemini data is sent/retained and how deletion requests treat logs and third-party shared content.
4. **Complete production connection setup.** At the final deployment stage, set an HTTPS `API_BASE_URL`, MySQL connection/TLS values, Gemini key, browser origins, and upload storage. Verify CORS, migrations, `/health`, and representative flows against the actual services.
5. **Verify platform builds and end-to-end behavior.** Backend unit coverage is useful but partial. Add API tests with an isolated test database and Flutter tests for failure/retry/session flows. The local Flutter widget test and standard JavaScript web release build pass; verify Android release builds/device flows and live service flows after production providers are configured.
6. **Treat geo-lock as a convenience check.** The API accepts client-reported coordinates, so a modified client can bypass the location check. If physical-presence assurance is a requirement, choose a trusted attestation design; otherwise keep the current accurate “location check” wording.

### P2 — Product decisions and polish

- Decide whether recipients need remote push/background delivery. Current recipients are notified in-app when they open or resume LifeVerse.
- Future feedback currently captures usefulness preference, not whether scenarios came true. Add outcome review and calibration only if the product later needs measured prediction accuracy.
- Review existing historical database rows created before the transactional changes for duplicate or inconsistent XP/activity state.
- Verify secure-storage plugin setup on each target platform. `flutter pub get --offline` succeeds from the local package cache. Growth-goal Flutter flows still need widget coverage; Android device/runtime and release-build verification remain pending.
- Run the backend schema initializer against the intended SQL database so `user_growth_goals` and its reminder/metric columns, `twin_conversations`, and `future_simulation_feedback` exist. Only the additive `user_app_visits` table was applied to the inspected local development DB; production was not contacted.
- Add goal-screen widget coverage and verify local notification permission/scheduling on Android and iOS. Android scheduled reminders use inexact alarm timing to avoid asking for exact-alarm access.

## Validation performed

- `node scripts/check-syntax.js` — passed after the current changes; 32 backend JavaScript files checked and route registration passed.
- `node --test test/unit.test.js` — passed, 32/32 in the latest backend run. Mocked unit tests do not exercise live SQL integration.
- `dart format` — passed for 11 touched Flutter files. The formatter warned that the external `flutter_lints` cache file could not be read.
- Historical verification before the 28 October 2026 UX pass: targeted `dart analyze` could not resolve packages under the restricted cache; an earlier dashboard widget run passed 2/2; Android build was not confirmed. These results are superseded for the changed Flutter files by the current results above.
- Current widget suite passed 6/6; the standard web build completed and returned HTTP 200 when served locally. `flutter run -d chrome` hit a Flutter Web debug-service timeout; a static web build is served at `http://127.0.0.1:5000`. Android debug APK compilation passed; Android device and release builds remain unverified.
- Signed-in SQL flows, Gemini behavior, and account-scoped chat/history were not exercised. Test with an isolated database before release.
- No production MySQL, Gemini, Render, email, or storage service was contacted. No Firebase records or remote cloud account were accessed.
- The workspace has no `.git` directory, so branch, commit history, diff state, and remote synchronization cannot be reported.

## Key files

- App startup and routes: `lifeverse_app/lib/main.dart`
- API URL and calls: `lifeverse_app/lib/config/app_config.dart`, `lifeverse_app/lib/services/api_service.dart`
- Account deletion and session recovery: `lifeverse_backend/src/controllers/authController.js`
- Friends: `lifeverse_backend/src/controllers/friendController.js`
- Capsule writes/storage: `lifeverse_backend/src/controllers/timeCapsuleController.js`, `lifeverse_backend/src/services/timeCapsuleService.js`, `lifeverse_backend/src/middleware/uploadMiddleware.js`
- Schema and date policy: `lifeverse_backend/src/initDb.js`, `lifeverse_backend/src/config/db.js`
- Backend routes/startup: `lifeverse_backend/src/index.js`
- Gemini integration: `lifeverse_backend/src/ai/geminiService.js`
- Twin Mind persistence and coaching: `lifeverse_app/lib/screens/digital_twin_screen.dart`, `lifeverse_backend/src/controllers/digitalTwinController.js`
- Vision Engine scenarios and recommendations: `lifeverse_app/lib/screens/future_simulation_screen.dart`, `lifeverse_backend/src/controllers/futureSimController.js`
- Render configuration: root `render.yaml`
- Tests: `lifeverse_backend/test/unit.test.js`, `lifeverse_app/test/widget_test.dart`
- HDE progress and growth goals: `lifeverse_app/lib/screens/hde_dashboard.dart`, `lifeverse_app/lib/screens/growth_goals_screen.dart`, `lifeverse_app/lib/services/notification_service.dart`, `lifeverse_backend/src/services/growthGoalService.js`
- Android scheduled notifications: `lifeverse_app/android/app/src/main/AndroidManifest.xml`
