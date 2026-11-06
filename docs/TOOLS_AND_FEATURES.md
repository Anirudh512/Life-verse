# LifeVerse: Tools and Features

## 1. Project overview

LifeVerse is a personal growth and reflection application. It helps a user set goals, record activities and milestones, review progress, and reflect on possible future choices. The growth model uses four dimensions: Physical, Cognitive, Psychosocial, and Moral.

The project has a Flutter client, a Node.js and Express backend, and a MySQL database. Selected reflective and content-generation features use Google Gemini through the backend.

## 2. Tools and technologies

| Tool or technology | How it is used |
|---|---|
| **Flutter** | Framework used to build the application's screens and shared client experience across supported platforms. |
| **Dart** | Programming language used for the Flutter application. |
| **Provider** | Shares signed-in user and application state between Flutter screens. |
| **HTTP package** | Sends JSON requests from the app to the backend API. Authenticated requests include a session token. |
| **Node.js** | JavaScript runtime used to run the server. |
| **Express** | Defines the backend API, routes, middleware, and health check. |
| **MySQL** | Stores account records, goals, growth activity, connections, conversations, milestones, and capsule metadata. The app accesses it through the backend. |
| **mysql2** | Connects the Node.js backend to MySQL and runs database queries. |
| **Google Gemini API** | Supports selected AI-assisted reflection, mentoring, biography drafting, and hypothetical-scenario features. Requests are made by the backend. |
| **Multer** | Handles media uploads for Time Capsules. The current prototype stores uploaded files in a configured server directory. |
| **Flutter device packages** | Support functions such as secure token storage, charts, file selection, QR display/scanning, local notifications, location checks, and speech input/output. |
| **npm** | Installs backend packages and runs backend scripts, including the server, schema initializer, and checks. |
| **Flutter SDK and Dart tools** | Fetch Flutter packages, run the client, format Dart code, analyze code, and build platform versions. |

### Selected Flutter packages

- `provider` manages shared application state.
- `http` communicates with the API.
- `flutter_secure_storage` stores session tokens securely on supported native platforms.
- `fl_chart` displays progress charts.
- `file_picker` and `image_picker` let users select attachments or images.
- `qr_flutter` and `mobile_scanner` provide QR-code display and scanning for trusted connections.
- `flutter_local_notifications` and `timezone` support local reminders and scheduled notifications.
- `geolocator` supports the optional device-reported location check for a capsule.
- `speech_to_text` and `flutter_tts` support speech input and spoken output in applicable features.

## 3. How the system works

1. The user interacts with the LifeVerse Flutter app and signs in.
2. The app sends requests to the Node.js/Express API over HTTP or HTTPS, depending on the configured environment.
3. The backend checks the session and account ownership before handling protected requests.
4. The backend reads or writes account data in MySQL.
5. For selected AI features, the backend sends the relevant request to Gemini and returns the generated result to the app.
6. Capsule media is uploaded to the backend's configured file storage; MySQL stores information about the files.

The API key for Gemini is configured on the server, rather than embedded in the Flutter client.

## 4. Main features

### Account and profile

Users can register, sign in, manage profile details, and access account-specific data. The profile includes privacy controls and a permanent account-deletion option. The current recovery flow uses a security answer; email-based password reset is not implemented.

### Evolution Matrix and daily growth tasks

The Evolution Matrix organizes personal development around the four growth dimensions. Users can view dimension-specific tasks and reviews, record completed activities, and see related experience points, levels, and streak information. These are app tracking measures and should not be interpreted as clinical assessments.

### Progress and growth goals

Progress views summarize recorded activity over selected periods and show items such as task activity, review activity, dimension progress, and goals. Users can create goals tied to growth activity and monitor their progress. Optional reminders are scheduled locally on the device.

### Twin Mind

Twin Mind is an AI-assisted reflection and mentoring feature. It can use a selected persona for conversation and, when the user enables the available context option, relevant LifeVerse activity or saved facts. Users can review or delete saved facts and clear Twin Mind conversation data. Its responses are generated guidance, not professional advice.

### Vision Engine

Vision Engine creates hypothetical scenarios to help users think through possible choices and future paths. A scenario is a reflection aid, not a prediction or guarantee. Users can provide feedback on whether a result was useful and may turn a suggestion into a growth quest.

### Life Atlas

Life Atlas lets users record personal milestones and chapters. It can draft a biography from saved information; the user can review and edit the draft before choosing to save it.

### Butterfly Effect

Butterfly Effect helps users reflect on small decisions and possible patterns in their effects. Its generated interpretations are possibilities for reflection and do not prove cause and effect.

### Time Capsules

Users can create memories with text and optional media, schedule them to open later, and share them with trusted connections. A capsule can optionally use a device-reported location check. This check is a convenience feature and does not verify physical presence. Recipient alerts are currently available in the app; remote push notifications are not implemented.

### Trusted connections

Users can connect with other accounts through requests and QR-code-assisted discovery. Connections can be selected as recipients for shared capsules. Personal growth records and Twin Mind conversations remain account-specific.

## 5. Current project status and limitations

LifeVerse is a working prototype. Production deployment and live external-service behavior have not been verified. In particular, capsule media currently uses configured server-side file storage, so durable storage must be set up before production use. Email-based account recovery and remote push notifications are not implemented. AI features send relevant prompts and selected context to Gemini when used, so users should avoid entering highly sensitive information.

## 6. Project folders

- `lifeverse_app/` contains the Flutter client.
- `lifeverse_backend/` contains the Express API, database setup, AI integration, and upload handling.
- `docs/PROJECT_GUIDE.md` contains a deeper technical guide and implementation details.
- `docs/FEATURE_AUDIT_AND_ROADMAP.md` records a feature audit, verification notes, and follow-up work.
