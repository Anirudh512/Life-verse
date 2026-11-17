# LifeVerse UI/UX Redesign Brief

This brief describes the current interface based on the Flutter source and project guides, then gives a full prompt to copy into a design or coding AI. It covers the main navigation, feature screens, repeated widgets, and important user flows. It is a source review rather than a screenshot-by-screenshot visual audit; use current app screenshots as extra visual references if available.

## 1. Product and design goal

LifeVerse is a personal growth and reflection app. Users work on growth goals, record activities, review progress, explore decisions, keep milestones, and save memories for later. Its four growth areas are **Physical, Cognitive, Psychosocial, and Moral**. Its five reflective features are **Twin Mind, Vision Engine, Butterfly Effect, Life Atlas, and Time Capsules**.

The redesign goal is to make the complete app feel polished, trustworthy, calm, personal, and easy to understand. Keep the lavender-led cosmic style shown in the user's visual reference: deep indigo/navy, prominent lavender accents, pale lavender panels, and selective starry hero artwork. Refine the current dark theme for professional readability and restraint; do not add a light-mode switch or appearance setting. Do not add features or destinations that are not currently implemented. Daily tasks already exist within Evolution Matrix; preserve that flow and do not create a separate Daily Tasks feature.

## 2. Current visual and interaction baseline

### Shared style

- The main Flutter theme is Material 3 and dark-only.
- Current palette: canvas `#0B0D12`, surface `#131720`, raised surface `#1A202B`, border `#293140`, primary lavender `#B7A4FF`, secondary teal `#8EDBD2`, muted text `#A5ADBA`, success `#83D6AE`, warning `#F0C982`, and danger `#F08D9B`.
- Cards and surfaces use rounded corners, commonly 16–20 px, thin borders, and little or no elevation. Inputs use a raised dark fill, rounded corners, and a lavender focus border. Shared buttons have a 48 px minimum height.
- The capsule composer has four selectable visual themes of its own: gold, cosmic purple, rose, and ocean blue. Some reflective screens use feature-specific accent colors and custom layouts.
- Common UI is built from `LvPageHeader`, `LvSectionTitle`, `LvSurface`, `LvMetricTile`, and `LvMessage`. These provide a page title/subtitle, section title/action, bordered content card, compact metric, and information/error/retry message.

### Navigation and layout

- The five persistent destinations are **Home, Progress, Evolution, Reflect, and Profile**.
- On compact layouts, navigation is at the bottom. At widths of 760 px and above, it becomes a labeled left navigation rail. The rail layout preserves destination state and main content is capped at 1320 px.
- Most overview pages are vertically scrollable, centered, and constrained to a readable width. Reflect and Evolution use responsive card grids.
- Nested feature pages are opened from the relevant destination and use back navigation. The app currently uses a slide-and-fade page transition.

### Current experience patterns

- Home has an optional, dismissible first-use guide, a greeting, a short saved-activity summary, recent activity, and feature shortcuts.
- Progress offers 7-, 30-, and 90-day ranges, a calendar, metrics, growth dimensions, goals, and recent activity. Visit days and completed growth days have distinct meanings. Missing optional data should appear as unavailable, not as zero.
- Loading, empty, and retry states exist in important data screens. A few feature screens have their own status cards, forms, timelines, dialogs, or animation treatments.
- Profile is split into Overview, Connections, and Privacy & account tabs. Capsule creation asks for optional permissions only when the related feature is used.

### Design opportunities

- Extend one coherent type scale, spacing system, color roles, icon style, and component library across all screens. Keep feature colors meaningful but define them centrally instead of introducing one-off colors.
- Improve hierarchy and scanability, especially on data-heavy pages: give each screen one clear purpose, make its main action easy to find, and avoid presenting every metric or shortcut at the same visual weight.
- Make forms, charts, tabs, chips, cards, bottom navigation/rail, dialogs, banners, empty states, loading states, and error/retry states feel like parts of the same product.
- Give the reflective features a warm and human tone while keeping AI context controls and data-use explanations visible and understandable.
- Review text contrast, text scaling, keyboard behavior, focus states, touch target sizes, semantic labels, and color-independent chart meaning. Those areas are not fully verified across devices.

## 3. Feature-by-feature screen inventory

The descriptions below identify what each surface does today and what the redesign should communicate. Treat this as the checklist; include nested and special-case flows, not only the five main tabs.

| Screen or feature | Current content and appearance | Redesign focus |
|---|---|---|
| **Welcome / authentication intro** | LifeVerse mark, a welcome message, a short explanation of the choose → do → record flow, and Log in / Create account actions. | Make the purpose clear immediately; establish the new visual identity; give the two actions clear hierarchy and keep the layout comfortable on narrow screens. |
| **Login** | Sign-in form and navigation to account creation or recovery. | Use clear labels, input focus/error states, password visibility, loading feedback, and an obvious primary action. |
| **Registration** | New-account form and validation. | Keep the form simple, explain password requirements near the field, and make errors specific and easy to correct. |
| **Account recovery** | Recovery flow based on the account security answer. | Clearly explain each step and result; do not suggest email reset is available. Keep success/error messaging consistent with the new system. |
| **Permissions explanation** | Permission-related information and a continue action. | Explain why a permission is needed at the moment it matters. Avoid implying a feature requires access when it does not. |
| **Session startup / splash / offline retry** | Restores a saved session, shows a connecting/loading state, or offers retry when the server is unreachable. | Use a branded but brief transition, show useful offline/retry feedback, and avoid leaving users on a blank or indefinite screen. |
| **First-launch story and growth contract** | A timed, fading story sequence and a growth-contract/commitment screen are available as routed flows. | Keep motion optional and skippable, respect reduced-motion settings, and explain any commitment in plain language before confirmation. |
| **Home** | Welcome and date, optional first-use guide, one suggested next step, compact weekly summary, recent activity, and shortcuts into Evolution, Twin Mind, Life Atlas, and Progress. | Make the next useful action the visual anchor. Let the activity summary scan quickly, show recent records clearly, and avoid a crowded dashboard. |
| **Progress** | 7/30/90-day selector, weekly-review link, summary metric tiles, activity calendar, four growth dimensions, goals, and recent records. | Clarify chart labels and units; distinguish visits, completed growth days, goals, and XP; use readable charts and a clear unavailable-data state. |
| **Weekly Review** | Recorded-week summary, dimension activity, noteworthy activity, goal progress, recent records, and optional prompts that link to the daily review. | Make the review feel reflective rather than like a report card. Keep prompts clearly separate from saved answers and make next actions easy to reach. |
| **Evolution Matrix** | Introductory choose → task → record guide, AI/data notice, four area cards, and a Growth Goals link. | Make the four dimensions recognizable and balanced. Present the next step clearly without duplicating the detailed Progress dashboard. |
| **Dimension task list** | Tasks for the selected Physical, Cognitive, Psychosocial, or Moral dimension; completion and retry/loading behavior. | Create calm, legible task cards with a clear completion action and visible state change. Avoid pressure, streak shame, or unearned success claims. |
| **Flashcards and daily review** | Flashcard interaction and a short set of reflection/review prompts embedded in the growth flow. | Design clear front/back and progress states; make prompts comfortable to answer; distinguish saved/submitted, incomplete, and failed-to-save states. |
| **Growth Goals** | Create/edit/delete goals, choose a growth area, measure completed tasks or active days, set a due date, and optionally set a local reminder. | Make goal setup a short guided form. Show progress, due date, measurement, and reminder status consistently; confirm destructive actions clearly. |
| **Reflect hub** | Feature cards grouped under “Talk it through,” “Explore your choices,” and “Save and revisit.” It links to Twin Mind, Vision Engine, Butterfly Effect, Life Atlas, and Time Capsules. | Explain each feature in one sentence and help a user pick the right one. Keep the grouping, but improve card hierarchy, labels, and responsive layout. |
| **Twin Mind** | Persona-based AI chat, saved conversation continuity, optional LifeVerse-context switch (off by default), review/delete saved facts, clear history, and message retry/older-message controls. | Make it feel like a thoughtful conversation, not a generic chatbot. Distinguish user and AI messages, make the context toggle and privacy explanation explicit, and design safe empty/error/loading states. |
| **Butterfly Effect** | Decision entry and AI-generated “possible patterns” reflection. It can be opened as a mode from the Reflect hub/Twin Mind flow. | Visually separate user-entered decision, generated interpretation, and any suggested reflection. State that patterns are possibilities, not proof of cause and effect. |
| **Vision Engine** | Availability/progress status, user decision input, generated hypothetical paths/timelines, contextual evidence, usefulness feedback, disclaimer, and option to turn a suggestion into a growth quest. | Make the process understandable from input to result. Present paths neutrally, label uncertainty, keep evidence distinct from generated speculation, and use a clear feedback/quest action. |
| **Life Atlas** | Saved milestones and chapters, counts, add-milestone form, biography draft generation, editable draft, and explicit Save or Discard actions. | Use a warm timeline/story structure. Keep generated biography visibly marked as a draft and preserve the review-before-save step. |
| **Time Capsules dashboard** | Capsule list/cards, schedules, recipient/media indicators, location-check status, and New Capsule action. | Make open, scheduled, and shared states easy to distinguish; give capsule cards a consistent hierarchy and preserve the user-selected theme as a personal detail. |
| **Capsule guide and creation** | Explains capsule workflow. Composer includes four themes, title, message, optional future prediction, trusted recipient, attachments, unlock date, and optional location check. | Turn the composer into clear steps or grouped sections. Show attachment limits and date requirements early; request location permission only when geo-lock is enabled. |
| **Capsule launch ceremony, delivery, and opening** | Launch confirmation animation, in-app delivery card with Open Capsule / Save for later, and a cinematic opening with message/media content. | Preserve the emotional reveal, but keep it fast, accessible, skippable, and consistent with the global typography and controls. Include graceful media-unavailable states. |
| **Profile — Overview** | Account identity, editable display name/username, account information, growth snapshot, dimension metrics, and goals. | Prioritize identity and useful summary; align metrics with the Progress design and make edit actions discoverable. |
| **Profile — Connections** | Trusted-connection list/request actions and QR-code-assisted discovery for capsule sharing. | Make request state, accepted connections, and QR scanning easy to understand. Explain why a connection is useful before requesting access. |
| **Profile — Privacy & account** | Privacy information, Twin Mind data controls, activity-data information, sign-out, and permanent account deletion. | Use clear groups and plain language. Visually separate routine settings from irreversible deletion and explain the consequences before confirmation. |
| **Unknown route / unavailable feature states** | A recovery page provides a message and a way back when a route is unknown. Data screens also have loading, empty, unavailable, and retry states. | Bring all system states into the design system and always provide a sensible next action. |

## 4. Reusable widgets and design-system checklist

When proposing or implementing the new style, define consistent appearance and behavior for each of these reusable elements:

1. **App shell and navigation:** mobile bottom bar, wide-screen rail, active/inactive states, labels, badges if needed, and safe-area spacing.
2. **Page header:** title, optional subtitle, optional trailing action, back navigation, and compact/wide variants.
3. **Section heading:** title, optional action, and consistent vertical spacing.
4. **Cards and surfaces:** standard, interactive, selected, disabled, and warning/destructive variants. Define padding, radius, border/elevation, and pressed/focus feedback.
5. **Metric tile:** label, value, icon, optional detail, loading/unavailable state, and a responsive chart/summary alternative.
6. **Buttons and links:** primary, secondary, outlined, text, icon-only, loading, disabled, destructive, and retry.
7. **Form fields:** label, hint, validation, focus, error, password, multiline, date, selection, and attachment states.
8. **Progress components:** progress bar, streak/XP treatment, goals, calendar cells, dimension indicators, and charts. Do not rely on color alone to explain values.
9. **Messages and feedback:** inline information, AI/privacy notice, empty state, success, warning, failure, retry, snackbar, and confirmation dialog.
10. **Reflective content:** chat bubble, AI response, scenario/timeline card, milestone row, saved memory, capsule preview, attachment preview, and draft badge.
11. **Responsive behavior:** mobile, tablet, and desktop layouts; readable maximum line length; keyboard-safe forms; large text and small-width handling.
12. **Motion and accessibility:** focus indicators, semantic labels, contrast, reduced-motion support, touch sizes, and animation rules.

## 5. Product rules to preserve during a visual redesign

- Keep the five main destinations and all current feature names unless a separate product decision is made.
- Keep account data private and account-scoped. Do not imply that profile, chat, reflection, or capsule information is public.
- Twin Mind's additional LifeVerse context is opt-in and off by default. Keep the switch and its explanation visible.
- Generated AI content is a reflection aid: future scenarios are not predictions, pattern reflections do not prove causality, and biography output must remain a reviewable draft until the user saves it.
- A missing optional data section is not the same as a measured zero. Design explicit loading, empty, unavailable, error, and retry states.
- Keep permission prompts contextual. Location is optional and only requested when a user enables the capsule location check.
- Preserve existing interactions and data behavior. Do not invent metrics, achievements, or personal activity that the app has not recorded.
- LifeVerse is currently a prototype. Avoid marketing the UI as a clinically validated health product or implying production integrations that are not verified.

## 6. Copy-and-paste prompt for a design or coding AI

```text
I want to redesign the complete LifeVerse app UI and UX so it feels professional, cohesive, modern, calm, personal, and trustworthy. Read the attached UI_UX_REDESIGN_BRIEF.md and inspect the existing Flutter source before proposing changes. The brief is based on the current code and lists every main destination, feature flow, and reusable widget.

PRODUCT
LifeVerse is a personal growth and reflection app. Its four growth areas are Physical, Cognitive, Psychosocial, and Moral. The five main navigation destinations are Home, Progress, Evolution, Reflect, and Profile. Reflect includes Twin Mind, Vision Engine, Butterfly Effect, Life Atlas, and Time Capsules.

CURRENT STYLE
The existing app uses Flutter Material 3 with a dark navy/charcoal canvas, lavender and teal accents, rounded bordered cards, shared headers/surfaces/metric/error widgets, a bottom navigation bar on compact screens, and a left navigation rail on wide screens. Capsule creation also has four personal color themes. You may rethink the palette and overall visual direction substantially. Propose a refined design system and, if useful, coordinated light and dark themes. Keep the result warm and human, not clinical, corporate-dashboard-like, or excessively neon/glassy/gamified.

WHAT I NEED
1. First propose a clear design direction based on the lavender cosmic reference, plus typography, actual color values, spacing/radius/elevation rules, icon treatment, motion, and reusable component states.
2. Create a screen-by-screen redesign plan for every existing screen and feature in this brief, including authentication, the current five tabs, nested feature screens, profile tabs, capsule creation/opening, dialogs, forms, charts, empty/loading/error states, and responsive navigation.
3. Then implement only the approved visual/UX redesign in the existing Flutter project. Reuse or improve shared components and theme tokens so the experience stays consistent. Make responsive layouts work on phone, tablet, and desktop.
4. Preserve all existing feature names, routes, API calls, account behavior, and working interactions. Do not add features, duplicate features, or create a new navigation destination. Daily tasks are already part of Evolution Matrix; keep them there without creating a separate Daily Tasks feature. Treat this as a presentation and UX redesign; do not change backend/business logic. If an interaction is unclear from the source, explain the assumption instead of silently changing behavior.
5. Keep the UX accessible: readable contrast, scalable text, keyboard/focus support, clear labels, usable touch targets, reduced-motion support, and charts that communicate meaning without color alone.
6. Preserve accurate product language: AI scenarios are possibilities rather than predictions; Butterfly Effect does not prove causality; Twin Mind context sharing remains opt-in and off by default; generated biographies remain drafts until the user saves them; missing data must not be presented as zero.
7. Do not invent user data, achievements, metrics, service capabilities, or new feature concepts. Keep location optional and contextual. Use real app data and provide polished loading, empty, unavailable, success, and retry states.

Before coding, show me the proposed visual direction and screen map. After implementation, summarize the files changed and note any screen or behavior that still needs visual review. Use real app content and existing data flows; do not replace them with static mockup data.
```

## 7. Useful source files for a redesign pass

- `lifeverse_app/lib/theme/lifeverse_theme.dart` — global colors and Material theme.
- `lifeverse_app/lib/widgets/lifeverse_components.dart` — shared page header, section title, surface, metric, and message widgets.
- `lifeverse_app/lib/screens/main_navigation.dart` — five-destination navigation and responsive rail/bottom bar.
- `lifeverse_app/lib/screens/home_dashboard.dart`, `progress_screen.dart`, `weekly_review_screen.dart` — home and progress experience.
- `lifeverse_app/lib/screens/hde_dashboard.dart`, `hde_category_tasks_screen.dart`, `growth_goals_screen.dart` — Evolution Matrix and goals.
- `lifeverse_app/lib/screens/reflect_hub_screen.dart`, `digital_twin_screen.dart`, `future_simulation_screen.dart`, `legacy_timeline_screen.dart` — reflection features.
- `lifeverse_app/lib/screens/time_capsule_dashboard.dart`, `capsule_creation_screen.dart`, `capsule_ceremony_screen.dart`, `capsule_open_screen.dart` — capsule flows.
- `lifeverse_app/lib/screens/profile_screen.dart` — profile, connections, and privacy/account sections.
- `lifeverse_app/lib/screens/auth_intro_screen.dart`, `login_screen.dart`, `register_screen.dart`, `recovery_screen.dart`, `permissions_screen.dart` — entry and account flows.
- `lifeverse_app/lib/widgets/ai_data_notice.dart`, `daily_review_survey.dart`, `flashcard_widget.dart`, `capsule_delivery_overlay.dart` — reusable feature interactions and notices.
