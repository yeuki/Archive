# Archive Living Canvas and native product shell

## Status

- Direction: approved by the user on 2026-09-24.
- Release state: `[Unreleased]`; no version is assigned until visual and device acceptance.
- Baseline: `codex/optical-dock-material` at `87b337d`.

## Problem

Archive is visually calm, but much of the application still reads as a collection of similarly elevated cards. Large summary surfaces, repeated panel chrome, and page-specific interaction patterns flatten the hierarchy and make the experience feel assembled rather than intentionally composed. The product also needs a credible iOS path without discarding the established React implementation or creating a second copy of Archive's business logic.

## Outcome

Create one cohesive, task-first interface language across the existing React application and establish a narrow iOS-native boundary for capabilities that genuinely benefit from Apple frameworks. React remains the canonical product UI and domain implementation.

The redesign should make Archive feel like one continuous personal journal:

1. The current state and next useful action appear first.
2. Supporting context follows as calm, mostly borderless sections.
3. Cards are reserved for contained objects or actions.
4. Personalization remains available without making the everyday interface look like an editor.
5. Motion preserves origin and context without replaying decorative animation.

## Preserved behavior

- Centered Home and the separate Productivity and Health destinations.
- Existing expanded-navigation behavior and destination order.
- The accepted optical dock candidate unless a direct visual correction is required.
- Existing records, modules, workout state, backups, reminders, Coach proposals, and Health Connect behavior.
- Exactly two Health Connect read triggers: launch and completed pull-to-refresh.
- Watch-sleep authority and previous-day attribution.
- Focused Workout Mode and finish-only workout history.
- Semantic Habit, Sleep, Water, and Move colors.
- Local-first behavior and complete JSON portability.

## React interface changes

### Shared page grammar

Every standard page uses the same hierarchy:

1. Context label and large page title.
2. One clear contextual action plus a quieter utility menu.
3. One primary state surface containing real data and the next useful action.
4. Continuous editorial sections separated mainly by rhythm and fine rules.
5. Optional personalized modules at the end of the core experience.

### Surface hierarchy

- Reduce full card treatment on static summaries, chart containers, and nested panels.
- Retain contained surfaces for direct actions, sessions, alerts, calendars, forms, and transient overlays.
- Use one restrained elevation scale and two principal shape families: content corners and true capsules.
- Reserve liquid glass for navigation and transient controls.

### Typography and actions

- Use sentence case and fewer repeated uppercase labels.
- Give numbers stable alignment and allow titles to carry hierarchy before borders or shadows.
- Replace the permanent three-button utility cluster with one primary add/customize control and an accessible utility menu for history and backup.
- Keep all existing actions available.

### Motion and gestures

- Preserve one coordinated page transition and existing reduced-motion support.
- Add immediate press feedback and continuity for disclosure surfaces without animating blur or large shadows.
- Retain standard pull-to-refresh, long-press reorder, sheet dismissal, chart inspection, Habit hold, and Workout selectors.
- Do not introduce gesture-only functionality.

### Module presentation

- Keep add, configure, remove, and reorder behavior.
- Make pinned modules visually part of the page in ordinary use.
- Keep edit and drag affordances explicit when a module is being manipulated.

## Native iOS boundary

React remains the source of truth for screens and domain behavior. The iOS project may contain native code only for boundaries where the system framework provides a material benefit:

- HealthKit authorization and data access.
- Native lifecycle and background-delivery hooks.
- Secure platform storage and notifications when adopted.
- Future SwiftUI control or navigation surfaces only after a measured WebView limitation is demonstrated.

The first native foundation must:

- Add the Capacitor iOS platform without changing Android behavior.
- Define an Archive-native bridge contract rather than duplicating React state.
- Include a SwiftUI Health access explanation/permission surface that can be presented by the native bridge.
- Keep native health results source-attributed and normalized by the shared React boundary.
- Document that final signing, entitlement configuration, and simulator/device validation require Xcode on macOS.

Native navigation is intentionally not introduced in this iteration. Replacing only the dock before the broader React hierarchy stabilizes would create two navigation implementations and could make the remaining web controls feel inconsistent.

## Non-goals

- No backend, accounts, subscriptions, analytics service, or paid dependency.
- No full SwiftUI rewrite.
- No React Native migration.
- No hierarchy merge or return to the rejected v0.9 navigation model.
- No data schema deletion or fabricated history.
- No App Store release, immutable APK release, tag, or phone installation before acceptance.

## Acceptance criteria

- Home, Habit, Water, Sleep, Stats, Workout, Workout History, Coach, and Settings share the same page hierarchy and spacing language.
- The primary action is identifiable without scanning three equally prominent controls.
- Static information does not appear as nested card-on-card UI.
- Existing page functionality and module personalization remain available.
- The navigation remains above content and retains accepted geometry and behavior.
- No horizontal overflow at 360 x 800 or 412 x 915.
- Reduced-motion and reduced-transparency modes remain usable.
- `npm run verify`, `npm run build`, `npm run test:motion`, and `npm run test:performance` pass.
- Android continues to build after the shared React changes.
- The generated iOS project and Swift sources are structurally inspectable on Windows; Xcode build/device validation is explicitly deferred to a Mac.

## Verification plan

1. Run all deterministic web checks.
2. Inspect Home, Habit, Water, Sleep, Stats, Workout, Workout History, Coach, and Settings at both established phone sizes.
3. Check top-level navigation, history/backup utility access, module customization, overlays, Habit hold, Workout Mode, pull-to-refresh, and reduced motion.
4. Build and sync Android, then assemble the debug APK without publishing it.
5. Inspect iOS project references and Swift bridge code; complete compilation, entitlement, and physical-device validation later in Xcode on macOS.
