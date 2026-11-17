# LifeVerse database-to-feature audit

Audit date: 4 November 2026. This records source-level table reads/writes and a read-only snapshot of the local `lifeverse` database configured by `lifeverse_backend/.env` (`localhost:3306`). The hosted/production database was not contacted. No application rows were changed or deleted during this audit.

## Table connections

| MySQL table | Writes | Reads / product feature | Audit result |
|---|---|---|---|
| `users` | Registration, profile updates | Sign-in, session validation, profile, friend lookup, capsule sender/recipient | Connected account root. `photo_url` currently has no values and the app has no photo upload/display flow. |
| `user_sessions` | Login and session token refresh/logout | Auth middleware validates account, token, active flag, and expiry | Connected. Expired/inactive rows are retained; see cleanup note below. |
| `user_app_state` | Account app-state API | Session restore and saved onboarding/preferences in Home | Connected. |
| `user_activity_logs` | Central life-event engine | Home, Progress, Evolution stats, goals, Twin profile, Vision Engine | Connected, content-free for new events. |
| `user_app_visits` | Authenticated daily visit endpoint | Progress and weekly visit summaries | Connected; unique account/day key prevents duplicate visits. |
| `daily_tasks` | Evolution task generation; Vision Engine quest conversion | Evolution tasks/reviews, task completion, Progress, Vision Engine | Connected. Stores the review prompt set and submitted flag. |
| `survey_answers` | Evolution daily-review submission | Vision Engine context; Life Atlas biography draft when the user leaves “Use my saved daily review answers” selected | Connected. This audit fixed the missing Life Atlas read path. It remains excluded from Twin Mind chat context. |
| `user_hde_stats` | HDE progression service | Evolution and Progress summaries | Connected as account progression state. |
| `user_growth_goals` | Growth-goal API | Goals, Home next step, Progress and weekly review | Connected. Empty until the account creates goals. |
| `legacy_events` | Life Atlas milestones and capsule-created legacy events through the event engine | Life Atlas timeline and biography draft | Core values are collected/displayed in Life Atlas and used in the biography. Media URLs remain a dormant field with no current Flutter attachment flow. |
| `legacy_profiles` | Reviewed biography save | Life Atlas saved story | Connected; AI output remains a draft until explicitly saved in the current app. |
| `digital_twin_profiles` | Aggregation from activity logs | Twin Mind profile/mirror question and Vision Engine context | Connected, derived from recorded activity. |
| `twin_memories` | Twin Mind only after an explicit “remember” request | Twin Mind memory list/opt-in chat context, Life Atlas, Vision Engine | Connected. Empty is expected if no fact was explicitly saved. |
| `twin_conversations` | Twin Mind chat | Persona history and account data controls | Connected. |
| `micro_decisions` | Butterfly Effect decision logging, including optional user labels | Butterfly Effect analysis; optional Twin Mind context; Vision Engine context | Labels now appear in Butterfly analysis and follow the choice into Twin/Vision only when those features use the choice context. |
| `future_simulations` | Vision Engine generation | Latest scenario, feedback, and quest conversion | Connected. |
| `future_simulation_feedback` | User feedback on a scenario | Latest/history and later Vision Engine context | Connected. Empty until a user submits feedback. |
| `friend_requests` | Profile connection requests | Connection requests/list and acceptance | Connected. Empty until a request is sent. |
| `friendships` | Accepted connection workflow | Profile connections and capsule recipient selection | Connected. Empty until a request is accepted. |
| `time_capsules` | Capsule creation/open/delivery workflows | Capsule dashboard, recipient delivery, detail/open flow | Connected. |
| `capsule_media` | Capsule upload metadata | Capsule listing/detail and authenticated media streaming | Connected. File bytes live under the configured upload directory, not in MySQL. |
| `capsule_delivery_acknowledgements` | Recipient delivery acknowledgement | Pending-delivery state and capsule delivery workflow | Connected. |

Every table in the initializer has active source references. Some tables are conditional on a user action, so a zero count does not by itself mean a broken feature.

## Local database snapshot

Read-only exact row counts from the configured local database:

| Table | Rows | Table | Rows |
|---|---:|---|---:|
| `users` | 2 | `user_sessions` | 19 |
| `user_activity_logs` | 81 | `user_app_state` | 2 |
| `user_app_visits` | 4 | `daily_tasks` | 18 |
| `survey_answers` | 11 | `user_hde_stats` | 1 |
| `user_growth_goals` | 0 | `legacy_events` | 4 |
| `legacy_profiles` | 1 | `digital_twin_profiles` | 1 |
| `twin_memories` | 0 | `twin_conversations` | 4 |
| `micro_decisions` | 1 | `future_simulations` | 3 |
| `future_simulation_feedback` | 0 | `friend_requests` | 0 |
| `friendships` | 0 | `time_capsules` | 4 |
| `capsule_media` | 6 | `capsule_delivery_acknowledgements` | 4 |

The empty `user_growth_goals`, `twin_memories`, `future_simulation_feedback`, `friend_requests`, and `friendships` tables are action-driven: a user must create a goal, explicitly ask Twin Mind to remember a fact, rate a scenario, send a connection request, or accept a request. No rows were fabricated to make these counts nonzero. Of the 4 current milestones, all 4 have saved core values and none have media URLs. The 1 saved decision currently has no labels.

The 19 `user_sessions` rows include 6 currently valid sessions and 13 expired sessions. Expired sessions cannot authenticate, but the application has no expiry cleanup job. No session rows were deleted; retention cleanup should be a separate, deliberate change.

No account currently has a stored `photo_url`. All 19 session rows have `device_info`, but there is no user-facing session/device-management screen.

The schema exposes 23 foreign-key constraints. Read-only checks found no orphan capsule-media rows, future-simulation feedback rows, or friendship rows. `survey_answers` has an account foreign key but no direct `daily_task_id` foreign key; submission currently associates an answer to that day’s task inside one transaction using the same account, dimension, and UTC date.

## Field-level findings

- Life Atlas now shows saved core values on milestones and lets the user add values to new milestones. The existing `media_urls` field still has no Flutter attachment or viewing flow; the current local rows do not contain media URLs.
- Butterfly Effect now exposes optional context labels in the choice form and passes them into its analysis. The opt-in Twin Mind and Vision Engine choice context also includes these labels. The current local decision has no labels, so no historical rows were changed.
- `digital_twin_profiles.confidence_score` is currently written as `0` and is not exposed as a feature result. The profile UI uses observed action coverage instead of claiming a personality-confidence score; this column is a legacy placeholder and should be retired or given an explicit product meaning only through a reviewed migration.
- `user_sessions.device_info` is recorded at login but no current session-management screen reads it. Expired rows remain stored; no cleanup or session-history deletion was performed.

## Resolved connection: daily reviews → Life Atlas

Before this audit, daily-review answers were saved to `survey_answers` and used by Vision Engine, but Life Atlas only read milestones and explicitly saved Twin Mind memories. Life Atlas biography generation now:

- Includes up to the 8 most recent daily reviews, with up to 5 bounded answers per review, when the visible checkbox is selected (selected by default); it can be turned off for each draft.
- Sends bounded question/answer context to Gemini only after the user requests a draft.
- Treats answers as personal reflections, not verified biography facts, and treats all saved text as untrusted data rather than instructions.
- Returns source counts so the draft identifies how many milestones, reviews/answers, and saved Twin Mind memories were used.
- Keeps the output editable and unsaved until the user chooses **Save story**.

The endpoint still scopes all reads to the authenticated account. No schema migration is needed for this connection.

The same pass also connected two other persisted fields to their feature flows: Life Atlas milestone core values are now editable and visible, and Butterfly Effect context labels are now entered, analyzed, and carried into optional Twin/Vision choice context.

## Verification boundary and follow-ups

The audit checked source-level write/read paths, current local row counts, foreign-key declarations, and selected relationship integrity. Read-only checks found 23 foreign keys and zero orphan capsule-media, simulation-feedback, or friendship rows. Backend syntax/route checks and all 35 backend unit tests passed, including the review-context, milestone-value, and decision-label connections. Dart formatting parsed and formatted the changed Flutter files; the SDK reported that its cached `flutter_lints` file could not be read. Flutter semantic analysis could not complete because package dependencies under the external Pub cache were inaccessible, and the Flutter CLI itself could not write its lock file under the read-only SDK directory. No Gemini request or authenticated device-screen flow was run. Reflection contents and other accounts' data were not read.
