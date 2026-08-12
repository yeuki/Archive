# Archive architecture

This document records the current technical boundaries and data contracts. It is intentionally more stable than an implementation walkthrough: exact line numbers and component internals may change, but these responsibilities should remain recognizable.

## System overview

Archive is a local-first React application packaged for Android with Capacitor.

```text
React UI and domain state
        |
        +-- browser localStorage (canonical app state and active workout)
        +-- JSON import/export (portable user backup)
        +-- Gemini HTTP API (optional coach, local API key)
        +-- Capacitor bridge
                |
                +-- Android Health Connect plugin
                +-- Android app lifecycle and system settings
```

There is no application backend or account service. GitHub stores source and release history; Google Drive stores immutable release artifacts, not editable source.

## Technology

- React 19 and React DOM
- Vite 7
- Capacitor 7
- Native Android/Kotlin and Gradle
- Browser `localStorage`
- Gemini API integration

## Source map

| Path | Responsibility |
| --- | --- |
| `src/main.jsx` | React entry point |
| `src/App.jsx` | Application shell, page routing, state normalization/persistence, records, modules, health orchestration, and coach integration |
| `src/WorkoutMode.jsx` | Focused live-workout experience and set/rest progression |
| `src/workoutSession.js` | Active-session normalization, defaults, progression, and persistence helpers |
| `src/motion.js` | Motion capability and reduced-motion helpers |
| `src/styles.css` | Archive Canvas tokens, layout, component styling, and animation rules |
| `src/assets/bodymap.js` | Muscle-region body-map data |
| `android/app/src/main/java/com/kyle/archive/` | Capacitor activity and Health Connect native bridge |
| `scripts/verify-*.mjs` | Deterministic regression safeguards |
| `scripts/build-release.ps1` | Signed, immutable release assembly and publication |

`src/App.jsx` is currently broad. New code should be extracted only when a requested change creates a coherent domain or component boundary; avoid a speculative whole-app rewrite.

## State and persistence

The persisted app state includes these conceptual areas:

```text
daily records
habit definitions and tracking state
goals and units
page/module configuration
workout exercises, routines, schedule, profiles, history, and active session
connected-health settings and canonical watch data
coach message history and reviewable proposals
```

State is normalized on load and import so supported older shapes remain usable. New fields require a default and a normalization path. Deleting or renaming a persisted field requires a migration and a recovery/backup consideration.

The optional Gemini key uses a separate local-storage entry and is excluded from normal JSON backups. No secret, personal export, or browser profile may enter Git.

## Health Connect boundary

Android Health Connect is the native provider boundary. The web UI communicates through a Capacitor plugin and stores normalized results in a versioned local health archive.

User-facing reads have exactly two triggers:

1. **Launch initialization.** Archive holds the normal interface behind the centered A loading screen until the data needed for a coherent first render is reconciled or a bounded failure state is reached.
2. **Completed pull-to-refresh.** Appropriate scrollable pages request a sync and then refresh their derived UI without blocking the whole application.

Permission review and Health Connect settings remain available because they are setup/recovery actions, not extra data-sync triggers. Compatibility handling may consume already-produced native state during launch, but must not create periodic, resume, navigation, or background polling.

The health archive stores source/provider and import provenance. Reconciliation updates corrected records and removes provider records that no longer exist within the authoritative window. High-frequency samples remain bounded.

### Sleep policy

- Watch-synced sleep is authoritative over a conflicting manual record.
- A session belongs to the calendar day immediately before its wake date, regardless of AM/PM clock time.
- Manual entry remains available when the watch did not track the session.
- Changes to attribution or precedence require migration tests because they affect existing daily summaries.

## Workout boundary

Routine configuration and active logging are separate experiences.

- Routines may contain zero exercises and permit temporary blank values while being edited.
- Workout Mode creates an active-session snapshot rather than mutating the source routine as the user logs.
- Every completed set is persisted immediately.
- The active session can be paused, exited, restored, edited, skipped, or finished according to the focused flow.
- A historical workout is appended only through **Finish workout**.
- History keeps routine/exercise snapshots so later library edits do not rewrite the past.

Recent completed values provide defaults when an exercise is added to another routine. Any workout-schema change must preserve resume and historical normalization.

## Modules and analytics

Page modules are configuration plus derived presentation. Module order, span, and options persist, while values are computed from canonical daily/workout/health records. Disabling a tracker or removing a module does not erase historical records.

Cross-metric analytics must state their time range and tolerate missing data. Absence is not equivalent to zero unless the metric definition explicitly says so.

## Coach boundary

The coach receives a compact local context assembled from supported app domains. Gemini output is parsed into reviewable proposals and validated against supported actions before application. Invalid actions remain visible with an explanation. A local fallback can produce reviewable proposals when a usable structured response is unavailable.

The coach may propose; it must not silently mutate application state.

## Motion and rendering

Motion uses the shared CSS/runtime helpers and honors reduced motion. Scroll-bound UI should avoid expensive paint work, repeated layout reads/writes, and broad React rerenders. Prefer transforms/opacity, stable component keys, and one-time chart reveals.

## Build and release

- `npm run verify` is the cross-platform web/workspace gate.
- `npm run cap:sync` copies the built web app into Android and updates Capacitor configuration.
- Android validation adds Gradle unit tests, lint, and debug/release assembly as appropriate.
- `npm run release:build` verifies clean/pushed `main`, signing identity, checks, immutable version paths, checksum, Git tag, local archive, and Drive archive.
- Package identity `com.kyle.archive` and the established signing certificate are compatibility contracts.

See [`docs/DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) for change gates and [`docs/RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for publication.
