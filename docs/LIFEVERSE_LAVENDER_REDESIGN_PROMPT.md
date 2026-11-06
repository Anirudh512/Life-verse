# Copyable prompt: LifeVerse lavender UI/UX redesign

The prompt below is corrected to describe the current LifeVerse implementation. It treats the supplied image as a visual reference, not as a source of new product features.

```text
Act as a senior product designer and Flutter UI/UX engineer. Redesign the existing LifeVerse app's visual style and user experience using the current codebase as the source of truth.

IMPORTANT: This is a redesign of the existing app, not a new product. Do not add, invent, duplicate, rename, or remove features. Do not add new navigation destinations or new product capabilities. Do not implement feature ideas that appear in the reference prompt or image unless they already exist in the current LifeVerse source. Daily tasks already exist within Evolution Matrix; keep that existing flow there and do not create a separate Daily Tasks module. Do not add mini-games, a constellation map, or other new feature areas. Do not create separate mood tracking, a new journal, achievements, new AI personas/tools, or renamed memory products. The reference image is for visual inspiration only; its extra feature tiles are not a product request.

## Existing project

- Frontend: Flutter and Dart.
- Backend: Node.js and Express.
- Database: MySQL.
- Selected AI functions: Google Gemini through the backend.
- Preserve the existing architecture, API contracts, authentication, saved data, privacy controls, and business logic. Treat this as a UI/UX and presentation redesign only.

## Existing main navigation

Keep exactly the current five main destinations and their product roles:

1. Home
2. Progress
3. Evolution
4. Reflect
5. Profile

Keep bottom navigation on compact layouts and the existing responsive side rail on wide layouts. Do not replace Evolution with a new Explore destination.

## Existing feature inventory — redesign these, do not expand it

- Home: welcome, optional first-use guide, suggested next step, saved weekly summary, recent activity, existing shortcuts.
- Progress: 7/30/90-day analytics, activity calendar, growth dimensions, goals, and recent activity.
- Evolution Matrix: the four areas (Physical, Cognitive, Psychosocial, Moral), existing daily tasks, flashcards, daily reviews, experience/level/streak information, and Growth Goals access.
- Growth Goals: existing account goals measured by completed tasks or active days, due dates, and optional local reminders.
- Reflect hub and its existing features: Twin Mind, Vision Engine, Butterfly Effect, Life Atlas, and Time Capsules.
- Twin Mind: persona-based chat, saved conversation continuity, optional LifeVerse context (off by default), saved-fact review/deletion, and history controls.
- Vision Engine: hypothetical scenarios, usefulness feedback, and existing option to turn a suggestion into a growth quest.
- Butterfly Effect: decision reflection and possible-pattern analysis; it is not proof of causation.
- Life Atlas: user-saved milestones/chapters and a generated biography draft that the user can review/edit before saving.
- Time Capsules: existing memory creation, themes, recipients from trusted connections, attachments, future unlock time, optional device-reported location check, launch/opening, and in-app delivery.
- Profile: overview, editable display name/username, connections and QR flow, privacy and Twin Mind data controls, sign-out, and account deletion.
- Account entry flows: welcome, login, registration, security-answer recovery, permission explanation, session loading, and offline retry.

Before implementing, inspect the current screens, routes, reusable widgets, state management, theme file, API usage, and responsive behavior. Do not treat old screenshots or concept labels as proof that a feature exists. Keep current feature names and destinations. Do not create a feature registry or duplicate feature detail screens.

## Visual direction: preserve the lavender theme

The user specifically likes the lavender theme and cosmic mood in the supplied reference. Keep this as the visual identity. Use deep indigo/navy, prominent lavender accents, soft lavender/light surfaces for readable cards, and selective starry or sky imagery in hero areas. The overall result should feel modern, hopeful, polished, personal, and easy to use.

Use lavender as the primary brand color and the current dark appearance as the core theme. A pale lavender card or panel is welcome for contrast. Do not replace the identity with a warm beige theme. Do not add a new light/dark theme switch or appearance setting; that would be a new feature.

Suggested starting tokens (adjust for contrast and consistency):
- Deep canvas: #0D0E2B
- Main indigo surface: #17183D
- Raised indigo surface: #24234F
- Soft lavender surface: #F1ECFF
- Main text on dark: #F7F4FF
- Muted text on dark: #C1BDDC
- Primary lavender: #B69AFF (keep the existing lavender identity around #B7A4FF)
- Strong lavender action in light panels: #7653D6
- Supporting blue/teal: #83DDF2
- Restrained warm highlight: #FFD477
- Borders: #3B3968 on dark and #DDD5F1 on pale lavender panels

Use star fields, illustration, glows, and gradients selectively, such as one hero panel or an intentional capsule reveal. Do not put starry backgrounds behind dense text, and do not give every card a separate saturated gradient. Keep icons consistent, use clear typography and hierarchy, and make every text label readable.

## UX and component requirements

- Create consistent reusable tokens and widgets for page headers, section titles, standard and interactive cards, buttons, inputs, chips, metric tiles, charts, progress indicators, AI notices, dialogs, snackbars, loading, empty, unavailable, retry, and error states.
- Give each screen one clear purpose and one obvious primary action. Reduce duplicate summaries and competing card emphasis.
- Use existing real data only. Do not invent user names, history, trends, achievements, scores, completion, or AI predictions.
- Distinguish zero from missing/unavailable data. Preserve retry actions and user-entered text when a request fails.
- Keep AI and privacy disclosures visible where they matter. Twin Mind's added LifeVerse context stays off by default and opt-in.
- Describe Vision Engine results as possible scenarios, not predictions. Describe Butterfly Effect output as possible patterns, not causal proof. Mark generated Life Atlas biography as a draft until the user explicitly saves it.
- Keep location optional and contextual. Explain that the capsule location check uses device-reported location and is not proof of physical presence.
- Keep charts readable with labels and legends; do not rely on color alone. Support text scaling, keyboard/focus behavior, semantic labels, usable touch targets, reduced motion, and mobile/tablet/desktop layouts.
- Preserve capsule theme choices and emotional opening, but make motion skippable and ensure message/media content remains accessible if animation or media fails.
- Do not modify the backend, database schema, API behavior, or stored user records. Do not add packages unless essential and justified.

## Suggested work sequence

1. Show a concise current-screen map and a lavender design-system proposal based on this prompt.
2. Update the shared theme tokens and reusable components.
3. Apply the refreshed design to the existing five destinations.
4. Apply it to all existing nested features, account flows, and error/empty/loading states.
5. Review mobile, tablet, and desktop layouts with screenshots and check both normal and failure states.
6. Report exactly what visual files changed and list anything that could not be visually reviewed. Do not claim unverified features or behavior.

The goal is to make the current LifeVerse feel beautiful and professional while keeping its lavender cosmic identity and its existing feature set intact. Improve the experience of current features; do not add new ones.
```
