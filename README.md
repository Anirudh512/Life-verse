# LifeVerse

LifeVerse is a Flutter client with a Node.js/Express API and MySQL persistence. The API also connects to Gemini for selected AI features.

This workspace is still a prototype. Render is the planned final deployment target; no production service has been deployed or verified. Read [the project status report](PROJECT_STATUS_REPORT.md) for the current review, known limits, and work remaining.

## Project layout

- `lifeverse_app/` — Flutter app for Android, iOS, web, Windows, macOS, and Linux.
- `lifeverse_backend/` — Express API, database schema/migrations, AI integration, and capsule uploads.
- `Dockerfile` — final single-service build for Flutter Web and the Express API on one origin.
- `PROJECT_STATUS_REPORT.md` — implementation status, connections, review findings, and release checklist.
- `docs/PROJECT_GUIDE.md` — product, architecture, database, API, setup, platform, and privacy guide.
- `docs/TOOLS_AND_FEATURES.md` — tools and technologies used, system flow, and plain-language feature descriptions.
- `docs/UI_UX_REDESIGN_BRIEF.md` — current design baseline, screen-by-screen inventory, UX considerations, and a copyable redesign prompt.
- `docs/UI_UX_DESIGN_RECOMMENDATIONS.md` — a detailed proposed visual direction and screen/widget-level redesign ideas.
- `docs/LIFEVERSE_LAVENDER_REDESIGN_PROMPT.md` — a corrected copyable implementation prompt that keeps the lavender style and current feature set.
- `docs/FEATURE_AUDIT_AND_ROADMAP.md` — screen-by-screen source status, implementation notes, and prioritized follow-up work.

## Run locally

### 1. Start MySQL and the API

Create a local API environment file:

```powershell
Copy-Item lifeverse_backend/.env.example lifeverse_backend/.env
```

Set local database credentials and a Gemini API key in `lifeverse_backend/.env`. Keep `.env` private; do not commit it or paste its values into issue reports.

Then install and initialize the API:

```powershell
cd lifeverse_backend
npm install
npm run init-db
npm start
```

The API uses `http://localhost:3000` by default. Visit `http://localhost:3000/health` to check API/database readiness.

### 2. Run the Flutter app

```powershell
cd lifeverse_app
flutter pub get
flutter run -d chrome
```

For Android Emulator, the API URL defaults to `http://10.0.2.2:3000/api`; other local targets use `http://localhost:3000/api`. Production/release builds must set the API URL explicitly, for example:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://your-api-host/api
```

The root `Dockerfile` builds Flutter Web with the same-origin API path `/api`, then serves the web app and API from one Express service. The root `render.yaml` is configured for this final hosting step, but no Render deployment has been performed. Native release builds use the same service URL followed by `/api`.

The production API URL, CORS, database, Gemini access, and upload storage have not been live-verified.

## Backend environment

See `lifeverse_backend/.env.example` for placeholders. The main settings are:

- `DATABASE_URL` or `MYSQL_URL`, or the local `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` values.
- `DB_SSL=true` for hosted MySQL. Certificate verification is on by default; `DB_SSL_REJECT_UNAUTHORIZED=false` is an explicit opt-out.
- `GEMINI_API_KEY` for AI-generated features.
- `ALLOWED_ORIGINS` for comma-separated browser origins; configure this to the deployed client origin before release.
- `UPLOAD_DIR` for capsule files. The local default is `lifeverse_backend/uploads/capsules`.
- `USER_CAPSULE_STORAGE_LIMIT_BYTES` for the per-account media quota. The default is 1 GiB; a single request remains limited to 200 MiB total and 50 MiB per file.
- `PORT` and `HOST` for the API listener.

The schema initializer is `npm run init-db`. The API and database use UTC for daily tasks, streaks, daily rewards, and activity analytics.

## Current feature limits

- Capsule uploads currently use local filesystem storage. A persistent Render disk or object store must be selected and configured before production; local files can be lost on redeploy or unavailable across instances.
- Capsule recipient alerts are in-app when the recipient opens LifeVerse. There is no remote push service. Time-capsule creation schedules a local notification on the sender's device.
- Geo-lock compares client-reported coordinates and does not prove physical presence.
- The profile includes permanent account deletion and asks for the current password. Deletion removes capsules you created, including ones shared with recipients, and removes your access to capsules created by others.
- Account recovery relies on a security answer. There is no email reset provider or real email verification flow yet.
- AI screens disclose that relevant prompts and saved activity are sent to Gemini. A server-enforced AI opt-in and approved privacy/retention policy still need a product decision.
- The app uses MySQL through the backend API for persistent application data. No Firebase integration is used.
- The Android overlay feature was removed from the permission flow because it had no working implementation.
- The app uses platform secure storage for saved session tokens. Browser storage requires HTTPS or localhost and cannot protect an active session from same-origin script compromise.

## Release status

Do not treat this source as production-ready yet. Before release, finish persistent media storage, email recovery, privacy/retention policy, external connection setup, automated coverage, and platform build verification. Deploy to Render only in the planned final stage.

