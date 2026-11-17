# LifeVerse Product and Technical Guide

**Scope:** Current source tree and the Progress, navigation, theme, Home, Profile, and privacy changes made in this workspace. This guide records source facts separately from runtime verification. No production database or deployment was contacted.

## Product overview

LifeVerse is a personal growth and reflection application. Its development model has four dimensions: Physical, Cognitive, Psychosocial, and Moral. The product connects daily activities and goals with reflection, personal history, future scenarios, trusted connections, and time capsules.

The current app is a prototype, not a production-verified service. The key future product principles are:

1. **Understand yourself:** reflect on experiences, decisions, and personal history.
2. **Improve yourself:** set goals and complete meaningful activities.
3. **See your growth:** review accurate, clearly defined records over time.

## Technology and architecture

```text
Flutter app
  ├── HTTPS/JSON requests with an account session token
  ├── local notifications, media picker, QR/camera, speech, and location plugins
  └── Express API
        ├── Flutter Web static bundle on the same origin in the single-link release
        ├── MySQL: account data, goals, activity, conversations, capsules, and feature records
        ├── Gemini API: selected generation and reflection features
        └── local capsule-media directory
```

| Area | Current implementation |
|---|---|
| Client | Flutter/Dart under `lifeverse_app/`; provider-based shared account state; Material widgets. |
| API | Node.js and Express under `lifeverse_backend/`. |
| Database | MySQL via `mysql2`; schema initialization is `lifeverse_backend/src/initDb.js`. |
| AI | Google Gemini is called from the backend; the API key is server-side. |
| Sessions | Bearer session token; native token storage uses `flutter_secure_storage`; browser storage has web-specific limits. |
| Uploads | Capsule media is written to the backend's configured local `UPLOAD_DIR`; MySQL holds its metadata. |
| Deployment | Root `Dockerfile` builds the Flutter Web client and Express API into one web service; root `render.yaml` is configured for Render. No production deployment was performed. |

The active signed-in route `/home` is the five-destination `MainNavigation` shell. Secondary feature routes are pushed above that shell so current feature workflows remain reachable.

## Navigation and screen inventory

| Destination | Screen or routes | Purpose |
|---|---|---|
| Home | `/home` → `HomeDashboard` | Optional first-use guide, one next step, compact recorded-week summary, recent activity, and feature shortcuts. Guide dismissal is stored in existing account app state. |
| Progress | `/progress` → `ProgressScreen`; `/weekly-review` → `WeeklyReviewScreen` | 7/30/90-day activity view, visit/growth separation, calendar, dimensions, goals, recent activity, and a factual weekly-review summary with next-step links. Optional data sections show unavailable state separately from zero. Weekly reflection prompts are not saved there. |
| Evolution | `/hde_dashboard`, `/hde_category_tasks` | Four growth dimensions, a short choose/task/record guide, daily tasks, flashcards, daily reviews, XP, streaks, and goal access. Progress summaries live in the Progress destination. |
| Reflect | `/reflect` → `ReflectHubScreen`; then `/digital_twin`, `/future_simulation`, `/legacy_timeline`, `/time_capsules` | Entry point groups Twin Mind, Vision Engine, Butterfly Effect, Life Atlas, and Time Capsules by the user's intent while retaining their feature names. Butterfly Effect opens its analysis from the hub. |
| Profile | `/profile` → `ProfileScreen`; friend rows open `FriendProfileScreen` | Private account overview, editable display name/username, goals, connections, QR, privacy information, Twin Mind data access, and account deletion. Accepted connections can view a compact XP/progress/dimension summary and capsules addressed to them. |

Authentication routes include `/`, `/login`, `/register`, `/recovery`, `/permissions`, `/splash`, `/first_launch`, and `/hde_growth_contract`. Capsule routes include `/create_capsule`, `/capsule_ceremony`, and `/capsule_how_it_works`.

The source also contains `home_content_screen.dart`, a prior home layout. It is not the active `/home` destination after the navigation integration.

## Repository implementation map

| Path | Responsibility |
|---|---|
| `lifeverse_app/lib/main.dart` | Creates app state, restores the cached server session, initializes notifications defensively, defines named routes, and provides the app theme. |
| `lifeverse_app/lib/config/app_config.dart` | Resolves the API base URL by platform/build configuration. Release builds require `API_BASE_URL`. |
| `lifeverse_app/lib/services/api_service.dart` | HTTP/JSON transport, bearer session header, request timeouts, response parsing, and typed API methods for current features. |
| `lifeverse_app/lib/services/user_state.dart` | Authenticated identity, session restore, and account preference state. |
| `lifeverse_app/lib/services/session_token_cache.dart` plus platform storage files | Reads, migrates, stores, and clears session tokens using native secure storage and web-specific storage behavior. |
| `lifeverse_app/lib/services/notification_service.dart` | Local notification setup and reminder scheduling. |
| `lifeverse_app/lib/services/capsule_delivery_service.dart` | In-app capsule delivery checks. The old broad `capsule_permissions_service.dart` helper is not called by the capsule screens; media selection uses the system file picker and location access is requested only when geo-lock is enabled. |
| `lifeverse_app/lib/theme/lifeverse_theme.dart` | Shared dark Material 3 palette and component themes. |
| `lifeverse_app/lib/widgets/lifeverse_components.dart` | Shared headers, section titles, surfaces, metric tiles, and loading/error/empty messages. |
| `lifeverse_app/lib/screens/main_navigation.dart` | Lazy, state-preserving five-tab shell with bottom navigation for compact windows and a navigation rail for wide windows. |
| `lifeverse_app/lib/screens/home_dashboard.dart`, `progress_screen.dart`, `weekly_review_screen.dart` | Real account summaries, visit and growth activity views, goals, date ranges, calendar, recent event labels, and a weekly review built from saved records. |
| `lifeverse_app/lib/screens/hde_dashboard.dart`, `hde_category_tasks_screen.dart`, `growth_goals_screen.dart` | Evolution Matrix, dimension-specific tasks/reviews, XP/levels/streak, and the existing SQL-backed goal system. |
| `lifeverse_app/lib/screens/reflect_hub_screen.dart`, `digital_twin_screen.dart`, `future_simulation_screen.dart`, `legacy_timeline_screen.dart`, `time_capsule_dashboard.dart`, `capsule_creation_screen.dart`, `capsule_open_screen.dart` | Reflection entry point; Twin Mind, Vision Engine, Life Atlas, and capsule flows. Life Atlas supports saved milestones and reviewable biography drafts. Capsule screens report load/media failures and avoid asking for unused permissions on entry. Butterfly Effect is reachable from Twin Mind. |
| `lifeverse_app/lib/screens/profile_screen.dart` | Identity, profile fields, private growth snapshot, goals, connections/QR, privacy controls, and account deletion. |
| `lifeverse_backend/src/index.js` | Express app setup, CORS/body parsing, endpoint mounting, health check, authentication gates, rate limits, global errors, and server startup. |
| `lifeverse_backend/src/middleware/authMiddleware.js` | Session authentication, request identity attachment, and same-account ownership checks. |
| `lifeverse_backend/src/config/db.js` | MySQL pool creation, UTC session setup, TLS options, and local/hosted connection configuration. |
| `lifeverse_backend/src/initDb.js` | Idempotent schema creation and guarded additive column/index upgrades. It is an initializer, not a versioned migration runner. |
| `lifeverse_backend/src/controllers/` | HTTP validation, ownership-aware request handling, response shaping, and feature-specific transaction orchestration. |
| `lifeverse_backend/src/services/` | SQL-backed session, XP/activity, HDE, goals, capsules, timeline, Twin Mind, and Vision Engine domain operations. |
| `lifeverse_backend/src/core/lifeEventEngine.js` | Central server-owned event/XP routing and updates to related growth systems. New general event metadata is intentionally empty. |
| `lifeverse_backend/test/unit.test.js` and `scripts/check-syntax.js` | Node's built-in test suite and syntax/route registration check. |

### Main request and data flows

1. Startup reads a cached session token and validates it with Express. Account identity is held in Flutter `UserState`; the server session digest and expiry are stored in MySQL.
2. Authenticated screens call `ApiService`, which adds the bearer token. Express middleware resolves the session and checks user IDs in route parameters or request bodies against the authenticated user.
3. Task completion and review submission validate against the saved daily task set, then write the feature record and related XP/activity updates through the existing transaction/event paths. Goals derive their progress from task-completion records rather than storing a second counter.
4. Home, Progress, and Weekly Review read the analytics endpoint. Recent activity is constrained to the selected UTC range. Visit records are written separately and are not XP/growth events. Repeated home lifecycle requests are deduplicated in MySQL.
5. Twin Mind, Vision Engine, Butterfly Effect, and biography generation call Gemini from the backend. Their feature data remains in feature tables; their message/answer text is excluded from new general activity metadata.
6. Capsule file bytes are written to `UPLOAD_DIR`; MySQL stores capsule and file metadata. Media reads are authenticated and checked against capsule access rules.
7. Friend profiles require an accepted friendship. They expose profile name, XP totals, 30-day task/review/growth-day counts, dimension XP/levels, streak, and capsule summaries only for capsules addressed to or explicitly shared with the viewer. Reflections, goals, account details, and capsule messages/media remain private.

## Visual system, accessibility, and responsive behavior

The shared palette is defined by `LifeVerseColors`: canvas `#0B0D12`, surface `#131720`, raised surface `#1A202B`, line `#293140`, primary violet `#B7A4FF`, secondary teal `#8EDBD2`, muted text `#A5ADBA`, success `#83D6AE`, warning `#F0C982`, and danger `#F08D9B`. The Material 3 theme uses readable dark surfaces, consistent 14–20 px corner radii, high-contrast focus borders, and 48 px minimum button heights. Capsule ceremony and feature-specific screens retain their purposeful existing visual identity.

The shared `LvMessage` component carries an icon, text, and optional retry action. Home, Progress, and task-generation failures use compact notices with retry while keeping navigation and available actions visible. Progress calendar cells expose semantic labels and tooltips in addition to color. The primary shell switches at a 760 px layout width, preserves tab state, and caps wide content at 1320 px. Home, Evolution, and Reflect use responsive cards on top of the existing dark palette. This is source-level behavior; text-scale, keyboard, screen-reader, contrast, and physical-device checks remain unverified.

## Dependency and device inventory

No dependency was added for this transformation. `lifeverse_app/pubspec.yaml` currently includes Flutter plus `http` (API), `provider` (state), `flutter_secure_storage` and `path_provider` (platform storage), `file_picker` and `image_picker` (media selection), `permission_handler` (permissions), `intl` (date/number formatting), `qr_flutter` and `mobile_scanner` (QR), `fl_chart` and `flutter_animate` (charts/animation), `flutter_local_notifications` and `timezone` (local reminders), `geolocator` (device location), `speech_to_text`, and `flutter_tts`. `flutter_lints` and `flutter_test` are development dependencies.

`lifeverse_backend/package.json` currently uses `express`, `mysql2`, `cors`, `dotenv`, `multer`, and `@google/genai`. The project uses Node's built-in `node:test`; no separate test framework was added. Android declares internet/network, audio, foreground location, camera, media read, notification, and reboot-rescheduling permissions in `lifeverse_app/android/app/src/main/AndroidManifest.xml`. iOS now has purpose-specific camera, location-when-in-use, microphone, photo-library, and speech-recognition usage descriptions in `lifeverse_app/ios/Runner/Info.plist`. Device capabilities are conditional: they still need user permission, hardware/services, and target-specific verification. A plugin being present does not mean every target implements it equally.

## Feature behavior

### Evolution Matrix and Growth Goals

- Daily task sets, flashcards, and five review prompts are generated for one of the four dimensions. The backend has deterministic fallback curricula when Gemini generation fails.
- Task completion is checked against the stored daily task set. XP is server-derived and task completion is routed through the central event service.
- Quest XP is written once with the task completion transaction and included in the lifetime XP total. The Profile tab reloads its saved summary when selected so XP claimed on the Evolution screen appears on return.
- Daily reviews are stored in `survey_answers`; review submission and task completion are transactional in the current controller.
- Goals are stored per account and dimension, with task-count or distinct-active-day measurement, due dates, optional local reminders, and a maximum of ten saved goals.
- Current XP, levels, momentum, streak, and the existing balance index are derived by backend services. XP is an application metric, not a clinical or objective measure of personal improvement.

### Progress and visit records

- `user_app_visits` is a new additive table. An authenticated app open/resume attempts one insert using the database's UTC date; `(user_id, visit_date)` deduplicates retries, repeated resumes, and repeated visits during the same UTC day.
- Visit days are counted separately from completed growth days. Growth days currently mean a UTC date with at least one `TASK_COMPLETED` or `SURVEY_SUBMITTED` event.
- Progress supports 7, 30, and 90 days. It reports task and review totals, period XP, lifetime XP, streak, dimension activity/levels, saved goal progress, and content-free recent event labels.
- Task/review history is required for the analytics response. Visit history, lifetime XP, HDE stats, and growth goals are reported through response availability flags; if an optional query fails, the UI marks that section unavailable rather than converting the missing data into zero.
- The calendar and activity summaries use UTC, matching the backend's current date policy. The UI explicitly says visits before tracking was enabled are unavailable. No historical visit rows are fabricated or backfilled.
- The recent activity API does not select general event metadata. It returns event type, dimension, XP, and timestamp only.
- A MySQL schema initializer run is required before a database can answer the new visit query. This workspace did not run `initDb.js` against any database.

### Trusted connections and friend profiles

- Opening a connection shows a compact profile with lifetime XP, the last 30 days of tasks/reviews/growth days, current streak, and XP/level for each growth dimension.
- The friend profile API checks the accepted friendship on every request. It does not return email, goals, reflections, Twin Mind data, capsule message text, media paths, or location coordinates.
- The capsule list contains only capsules sent or explicitly contributed to by that friend for the signed-in viewer. Ready capsules are fetched through the existing recipient-authorized detail route before opening, preserving geo-lock checks.

### Twin Mind

Twin Mind has a persona-based assistant, saved account-scoped conversations, and explicit user-requested memory storage. Users can review/delete saved facts and clear Twin Mind history. The current chat and its saved persona conversation are used for continuity. Sending additional LifeVerse context (saved facts, recent action summaries, and choices) is off by default and controlled by the screen's opt-in switch. Daily review answers are never queried or sent as Twin Mind context. The Butterfly Effect entry point is in the Twin Mind screen. AI prompts and selected context are sent from the server to Gemini for the requested feature; users should avoid placing highly sensitive information in AI prompts.

### Vision Engine

Vision Engine creates hypothetical future scenarios from available activity, reflections, and choices when the user requests one. It supports usefulness feedback and committing a recommendation as a growth quest. Its disclaimer describes two plausible paths as a thinking aid, not a prediction. Refreshing availability no longer clears the decision text or a previously loaded scenario. Live Gemini behavior and provider quotas have not been verified here.

### Life Atlas and Butterfly Effect

Life Atlas stores user-entered milestones and chapter names. Its biography draft uses saved milestones and explicitly stored Twin Mind facts, and can include recent daily-review answers when the visible option is selected. The current app requests an unsaved draft, lets the user edit it, and writes the existing `legacy_profiles.ai_biography` field only on Save. The legacy POST endpoint still defaults to saving for old clients; the Flutter flow explicitly sends `save: false`. Butterfly Effect stores user-entered micro-decisions and asks Gemini for cautious pattern reflections. Its UI calls interpretations possible patterns and states that they do not prove causation.

### Time Capsules and connections

Time Capsules support scheduled memories, recipients from trusted connections, media, and optional device-reported location checks. Capsule access is authenticated. Location checks are convenience checks, not proof of physical presence. Neither the tutorial nor create screen requests camera, broad storage/photo, or notification permissions on entry; media selection uses the platform file picker, and geolocation is requested only when the user enables geo-lock. Client attachment checks match backend limits of 20 files, 50 MB per file, and 200 MB total. Recipient notifications are in-app on resume/open; remote push delivery is not implemented. Capsule files currently use local filesystem storage, so durable media across server restarts or multiple instances is not guaranteed.

## Database model

The schema is initialized from `lifeverse_backend/src/initDb.js`. Existing account-owned tables use foreign keys with account deletion cascades where defined. A read-only local inspection on 4 November 2026 confirmed 22 tables and checked foreign-key parity; see [`DATA_FLOW_AUDIT.md`](DATA_FLOW_AUDIT.md) for the table-to-feature map and limits of that inspection.

| Table | Purpose |
|---|---|
| `users` | Account identity, password hash, recovery answer hash, QR hash, optional photo URL, creation time. |
| `user_sessions` | Server-side session digests and expiry. |
| `user_app_state` | Per-account client preferences/state. |
| `user_activity_logs` | Content-free action type, dimension, XP, metadata, and timestamp. New central events now pass empty metadata. |
| `user_app_visits` | One authenticated visit row per account and UTC date; new additive schema object, no historical backfill. |
| `user_hde_stats` | XP, level, momentum, streak, and balance fields for four dimensions. |
| `daily_tasks` | Per-account, dimension, and day task/flashcard/review prompt set and submission status. |
| `survey_answers` | Private submitted review answers. Vision Engine reads them, and Life Atlas can include recent answers in a biography draft when the user selects that context. They are not copied into new general activity metadata or Twin Mind chat context. |
| `user_growth_goals` | Account-owned goals and their task/active-day measurement configuration. Progress is derived from task activity. |
| `time_capsules` | Capsule content, schedule, recipient, lock/location settings, and media totals. |
| `capsule_media` | Capsule file metadata; file bytes are stored under `UPLOAD_DIR`. |
| `capsule_delivery_acknowledgements` | Per-recipient delivery acknowledgements. |
| `friend_requests`, `friendships` | Trusted-connection requests and accepted relationships. |
| `legacy_events`, `legacy_profiles` | Life Atlas milestones (including core values) and generated biography data. Media URLs have no current Flutter attachment/viewing flow. |
| `micro_decisions` | Private Butterfly Effect choices and optional labels consumed by its analysis and optional AI context. |
| `digital_twin_profiles` | Aggregated Twin Mind activity profile. |
| `twin_memories` | Explicitly saved Twin Mind facts. |
| `twin_conversations` | Account/persona-scoped Twin Mind conversation turns. |
| `future_simulations`, `future_simulation_feedback` | Generated scenarios and usefulness feedback. |

The current backend `.env` resolves to local MySQL at `localhost:3306`, user `root`, schema `lifeverse`. A read-only inspection on 4 November 2026 confirmed 22 tables and the new `user_app_visits` table. It did not run the schema initializer or contact production. The initializer is not a versioned migration tool: with no URL configured it connects using `DB_HOST` (default `localhost`), `DB_USER` (default `root`), and `DB_NAME` (default `lifeverse`), creates that database if needed, then applies the full schema initializer. It uses `CREATE TABLE IF NOT EXISTS` and duplicate-tolerant additive `ALTER` statements. It also runs `ALTER TABLE twin_conversations MODIFY COLUMN content LONGTEXT NOT NULL`, which changes the column definition and may fail if existing rows violate `NOT NULL`; verify the target and back it up before running it. A full table-to-feature map and local row-count snapshot are in [`DATA_FLOW_AUDIT.md`](DATA_FLOW_AUDIT.md).

## API inventory

Protected personal endpoints use bearer authentication and account ownership middleware. Exact request/response details are implemented in controllers and should be checked there when making API changes.

| Route family | Endpoint responsibilities |
|---|---|
| `/health` | API and MySQL readiness. |
| `/api/auth/*` | Registration, login/logout, session validation, recovery, profile read/update, app-state read/write, and confirmed account deletion. |
| `/api/analytics/xp/:userId` | Existing seven-day XP response retained for current clients. |
| `/api/analytics/progress/:userId?days=7\|30\|90` | Progress summary, UTC daily rows, dimensions, goals, and metadata-free recent activity. |
| `POST /api/analytics/visit` | Authenticated, server-dated, per-account-per-UTC-day visit insert. Body-supplied account IDs are not used. |
| `/api/hde/*` | Daily tasks, HDE stats, task completion, activity logging, and review submission. |
| `/api/growth-goals/*` | Account-owned goal list/create/update/delete. |
| `/api/friends/*` | Requests, acceptance, and trusted connection list. |
| `/api/capsules/*`, `/uploads/capsules/*` | Capsule creation, list/detail/open/delivery, media upload/stream. |
| `/api/legacy/*` | Life Atlas timeline, event creation, biography draft generation, and reviewed biography saving. |
| `/api/twin/*` | Twin profile, mirror question, chat/history, saved facts, and deletion/clear controls. |
| `/api/future/*` | Scenario status/generation/history, feedback, and recommendation commit. |
| `/api/butterfly/*` | Micro-decision save and Butterfly Effect analysis. |

The current route registrations in `lifeverse_backend/src/index.js` and its two feature routers are:

| Method and path | Authentication / purpose |
|---|---|
| `GET /health` | Database readiness check. |
| `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/logout` | Registration and session lifecycle; registration/login have process-local rate limits. |
| `POST` or `GET /api/auth/session/validate` | Validate a bearer/session token. |
| `POST /api/auth/recover`, `POST /api/auth/verify-email`, `POST /api/auth/verify-security` | Existing recovery/verification behavior; real email delivery is not configured. |
| `POST /api/auth/account/delete` | Authenticated, current-account deletion with password confirmation. |
| `GET` / `PUT /api/auth/profile/:userId` | Read and update account-owned profile fields. |
| `GET` / `PUT /api/auth/app-state/:userId` | Read and persist account app preferences. |
| `GET /api/analytics/xp/:userId`, `GET /api/analytics/progress/:userId?days=7\|30\|90`, `POST /api/analytics/visit` | XP compatibility endpoint, progress analytics, and deduplicated visit recording. |
| `GET /api/growth-goals/:userId`, `POST /api/growth-goals`, `PUT` or `DELETE /api/growth-goals/:userId/:goalId` | Account-owned goal operations. |
| `POST /api/friends/request`, `POST /api/friends/accept`, `GET /api/friends/list/:userId` | Trusted connection request and list. |
| `POST /api/hde/tasks`, `GET /api/hde/stats/:userId`, `POST /api/hde/log`, `POST /api/hde/tasks/complete`, `POST /api/hde/survey/submit` | Daily activity, stats, task completion, and review operations. |
| `POST /api/capsules/create`, `POST /api/capsules`, `GET /api/capsules/pending/:userId`, `GET /api/capsules/detail/:capsuleId/:userId`, `GET /api/capsules/:userId`, `GET /api/capsules/status/:userId`, `POST /api/capsules/open`, `POST /api/capsules/delivered`, `GET /api/capsules/lookup/:username`, `GET /uploads/capsules/:filename` | Capsule create/list/open/recipient/media workflows. Media delivery is authenticated. |
| `POST /api/legacy/event`, `GET /api/legacy/timeline/:userId`, `POST /api/legacy/biography`, `PUT /api/legacy/biography` | Add/list milestones, generate biography (`save:false` returns a draft; the Flutter app sends `includeReflections` based on its visible daily-review option), and save reviewed text (trimmed, non-empty, max 20,000 characters). The empty-data starter response remains unsaved. |
| `GET /api/twin/profile/:userId`, `POST /api/twin/mirror`, `GET /api/twin/history/:userId`, `GET /api/twin/memories/:userId`, `DELETE /api/twin/memories/:userId/:memoryId`, `DELETE /api/twin/history/:userId`, `POST /api/twin/chat_twin` | Twin Mind profile, conversation, and explicit memory controls. |
| `GET /api/future/status/:userId`, `GET /api/future/latest/:userId`, `POST /api/future/simulate`, `POST /api/future/feedback`, `POST /api/future/commit` | Vision Engine availability, generation/history, feedback, and quest conversion. |
| `POST /api/butterfly/log`, `GET /api/butterfly/analysis/:userId` | Butterfly Effect decisions and analysis. |
| `POST /api/events` | Retired generic event endpoint; responds `410` and directs clients to specific action routes. |

## Security and privacy notes

- Session authentication and same-account ownership are checked on protected user routes.
- SQL values use parameterized queries in the reviewed paths.
- New general activity log records contain no user event details. This prevents new capsule messages, reflection text, AI conversation content, and private milestone text from being copied into analytics metadata by the central event engine.
- Review answers remain in the feature-specific `survey_answers` table. They may be included in a Life Atlas AI draft only when the user leaves the visible include option selected; they remain excluded from Twin Mind chat context. Historical activity rows may contain older metadata copied before the content-free logging change; the data-flow audit did not bulk-delete or rewrite them.
- Twin Mind conversations and saved memories have separate account-scoped controls. Account deletion uses password confirmation and handles capsule media cleanup status.
- The app has no complete approved retention policy or email recovery provider. Native local session storage does not remove web same-origin script risks.
- Capsule media is local disk and geo checks trust device-reported coordinates. These are known operational/security limitations.

## Configuration and local development

See [`README.md`](../README.md), `lifeverse_backend/.env.example`, root `render.yaml`/`Dockerfile`, and `lifeverse_app/lib/config/app_config.dart`.

| Setting | Purpose |
|---|---|
| `DATABASE_URL` or `MYSQL_URL` | Hosted MySQL connection string. |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Local MySQL connection settings. |
| `DB_SSL`, `DB_SSL_REJECT_UNAUTHORIZED` | Hosted MySQL TLS settings. |
| `GEMINI_API_KEY` | Server-side Gemini access. |
| `ALLOWED_ORIGINS` | Browser origin allowlist. |
| `UPLOAD_DIR` | Local capsule-media directory. |
| `USER_CAPSULE_STORAGE_LIMIT_BYTES` | Per-user capsule-media quota. |
| `HOST`, `PORT`, `NODE_ENV` | API listener/runtime settings. |
| Flutter `API_BASE_URL` | Release-build API URL supplied with `--dart-define`. |

Typical local setup:

```powershell
cd lifeverse_backend
npm install
npm run init-db
npm start
```

Then in another terminal:

```powershell
cd lifeverse_app
flutter pub get
flutter run -d chrome
```

Useful verification commands, when the required local tools and services are available:

```powershell
cd lifeverse_backend
npm test

cd ..\lifeverse_app
dart format lib test
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=https://your-api-host/api
```

The backend test command performs JavaScript syntax and route checks, then runs `test/unit.test.js`. Flutter commands require a working Flutter SDK and may require downloaded dependencies. A live DB/API, Gemini, device plugins, and deployment have their own setup requirements; test reports must name those limits.

Run the schema initializer only against a verified local or staging MySQL target after checking `DATABASE_URL`/`MYSQL_URL` or the `DB_*` settings. This workspace's backend `.env` has no database URL and resolves to loopback; the database itself was not inspected for isolation or user data, so the initializer was not run. With absent settings, the code defaults to localhost/root/`lifeverse` and can create that database before applying the full schema. Production or an unknown target must not be used for an unreviewed initializer run. Connectivity could be checked with the existing read-only `SELECT 1` health query after the target is confirmed, but no connection was made here.

## Platforms, packages, and device requirements

The project is configured for Android, iOS, web, Windows, macOS, and Linux. Flutter packages in `pubspec.yaml` include HTTP, provider, secure storage, file/image selection, QR/camera scanning, charts, animations, local notifications, geolocation, speech-to-text, and text-to-speech. Android/iOS permissions and plugin setup are platform-specific. Supported by Flutter configuration does not mean each platform build or feature was verified.

Camera/QR, local notification, location, file/media, and speech features need the corresponding device permissions and hardware/service support. Exact minimum device specifications are not established in the repository. Live Android/iOS/desktop verification remains outstanding.

## Verification and known limits

Record the actual results in [`FEATURE_AUDIT_AND_ROADMAP.md`](FEATURE_AUDIT_AND_ROADMAP.md). No live database, Gemini account, Render deployment, email provider, or external storage was contacted. The workspace currently has no `.git` directory, so a Git branch/status/diff is unavailable. A Flutter SDK is available at `C:\flutter\flutter` and bundles Dart 3.13.7, which meets the project's `^3.11.5` constraint. On 28 October 2026, the changed Flutter files passed targeted analysis with 15 info-level notices and no errors, all 5 widget tests passed, and the web debug build completed. Full-project analysis reports 198 info-level findings. `lifeverse_app/android/local.properties` still contains a machine-specific SDK path and should be checked on the user's build machine before Android builds.
