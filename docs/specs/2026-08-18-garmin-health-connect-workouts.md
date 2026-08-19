# Major change: Garmin Health Connect workouts

## Control

- **Status:** Ready for device validation
- **Owner:** Kyle / Codex
- **Created:** 2026-08-18
- **Baseline:** v0.13.0 / `5479343`
- **Working branch:** `feature/garmin-health-connect-workouts`
- **Target release:** Unreleased
- **Related issue / task:** Garmin Forerunner 170 workout ingestion feasibility and first implementation slice

## Problem and user outcome

Archive currently reads Health Connect exercise sessions only as shallow watch-data summaries. Those records do not appear in Workout History, discard useful metadata and workout structure, and cannot show whether Garmin supplied laps, strength segments, repetitions, or attributable metrics.

After this change, workouts that Garmin Connect has already written to Health Connect should be imported on Archive's next launch or completed pull-to-refresh, stored exactly once as completed external workouts, and shown in Workout History with every field the stable Health Connect API actually provides. Missing fields must remain visibly unavailable rather than being inferred or converted to zero.

## Approved direction

Keep Health Connect as the provider boundary and stable `connect-client:1.1.0` as the first implementation target. Expand the native snapshot to preserve session metadata, source/device provenance, laps, segments/repetitions, route availability, and attributable run/strength metrics. Store this richer representation in the existing canonical watch-data archive and derive a unified Workout History view without copying external records into manual workout logs.

This first candidate doubles as the real-device contract probe. It must reveal what a Forerunner 170/Garmin Connect installation actually publishes before Archive adopts experimental Health Connect APIs or a direct Garmin integration.

## Preserve

- Exactly two Health Connect read triggers: launch and completed pull-to-refresh.
- Manual Workout Mode, immediate active-session persistence, resume, and Finish workout history lifecycle.
- All existing manual workout history and multiple-workouts-per-day behavior.
- Watch-first sleep policy, daily aggregates, source priority, and local-first persistence.
- Existing navigation, Archive Canvas styling, JSON backup/import compatibility, and package/signing identity.

## Non-goals

- Direct Garmin watch, cloud, Activity API, FIT, OAuth, account, or backend integration.
- Experimental Health Connect `1.2.x` weight, set-index, or RPE fields.
- Automatic fuzzy matching from Garmin segment labels to Archive exercises or routines.
- Route map rendering or storage of raw route coordinates.
- Background, resume, navigation-triggered, or redundant manual-button Health Connect reads.
- Redesigning Workout Mode, navigation, or adjacent health pages.

## Screens and states

| Screen/state | User sees | User can do | Data/source |
| --- | --- | --- | --- |
| Workout History / imported session | Source-attributed completed workout, available summary metrics, laps, and segments | Review imported details | Canonical Health Connect external workout |
| Workout History / partial session | Session summary plus an honest explanation of fields Garmin did not share | Review available details | Health Connect session and permission/completeness flags |
| Workout History / no external sessions | Existing manual history or current empty guidance | Record manually as before | Manual workout archive |
| Settings / workout diagnostics | Imported workout counts, provider origins, sessions with segments/laps/metrics, and missing permissions | Review permissions or open Health Connect | Canonical watch-data archive and native permission state |
| Permission partial | Available layers continue syncing; denied layers remain marked unavailable | Review permissions later | Per-record Health Connect grants |
| Upstream not ready | Existing data remains intact and no new workout is fabricated | Sync Garmin Connect, then launch or pull later | Previous local archive |

## Interaction and motion

No new sync gesture is introduced. Imported details use existing Workout History selection and restrained disclosure. Existing history entrance motion and reduced-motion behavior remain unchanged. External records are read-only; no interaction can start, resume, pause, finish, or discard an Archive active workout.

## Data, persistence, and compatibility

- Persisted fields added/changed: Rich external workout metadata, nullable metric summaries, laps, segments, route state, source device, recording method, and field-availability flags inside `watchData.workouts`.
- Normalization or migration: Existing shallow watch workouts normalize as legacy partial external workouts. Stable Health Connect record identity is preferred when available; older timestamp identity remains the fallback.
- Backup/import impact: The existing complete-state backup automatically includes the richer watch-data shape; backup schema/version and normalization coverage must be updated if required by the final implementation.
- Offline/restart behavior: Previously imported external workouts remain available locally. No Health Connect read occurs outside launch or pull-to-refresh.
- Health/native/API impact: Add read permissions for total calories, speed, elevation, and step cadence; keep stable Health Connect `1.1.0`; allow partial granted-permission reads.
- Security/privacy impact: Preserve only route availability, not coordinates. Do not log personal workout values or commit personal exports.

## Accessibility

External source and missing-data status are communicated with text, not color alone. Existing history controls retain their labels and touch targets. Imported details must tolerate text scaling, avoid horizontal overflow, and remain readable without motion.

## Acceptance criteria

- [ ] A Health Connect exercise session appears once in Workout History after launch or pull-to-refresh.
- [x] Stable Health Connect identity prevents duplication when the session time or title is corrected.
- [x] Imported workouts never enter or mutate `workout.activeSession` or manual `workout.workouts`.
- [x] Available session metadata, summary metrics, laps, segments, and repetitions survive normalization, reconciliation, restart, and JSON backup/import.
- [x] Missing values remain absent and are explained; no fake exercises, zero-value sets, active duration, route, or weight are created.
- [x] Partial permissions do not block unrelated granted Health Connect layers.
- [x] Daily totals continue using Health Connect aggregation and watch sleep behavior is unchanged.
- [x] No additional Health Connect sync trigger exists.
- [ ] No horizontal overflow occurs at 360 x 800 or 412 x 915.
- [x] Relevant deterministic and Android checks pass.
- [x] Durable documentation and `[Unreleased]` notes are updated.
- [ ] A real Forerunner 170 run and strength session are inspected before the candidate is accepted.

## Verification plan

| Risk | Check | Expected evidence |
| --- | --- | --- |
| Garmin exports no `ExerciseSessionRecord` | Sync a uniquely named run and strength workout, then pull-to-refresh | Diagnostics honestly show zero sessions while daily metrics remain intact |
| Duplicate or corrected sessions | Merge the same stable record ID with changed timestamps/title repeatedly | One external record updates in place |
| External data affects active Workout Mode | Normalize/import while an active session exists | Active session is byte-for-byte unchanged |
| Missing optional permission blocks all health data | Deny one new permission and refresh | Granted layers import; denied field is marked unavailable |
| Cross-source metric contamination | Inspect source package and per-session metrics | Workout metrics are filtered to the session's `DataOrigin` |
| UI assumes manual sets | Open run, partial strength, and segmented strength records | Each renders without fabricated rows or runtime error |

## References

- [Garmin Health Connect sharing](https://support.garmin.com/en-IE/?faq=JToBEy0jfe6pIygark2Ui5)
- [Android workout experiences](https://developer.android.com/health-and-fitness/health-connect/experiences/workouts)
- [Health Connect exercise routes](https://developer.android.com/health-and-fitness/health-connect/features/exercise-routes)
- [`ConnectedHealthSnapshotReader.kt`](../../android/app/src/main/java/com/kyle/archive/ConnectedHealthSnapshotReader.kt)
- [`src/App.jsx`](../../src/App.jsx)

## Open questions

- Does Garmin Connect write exercise sessions for Forerunner 170 runs and strength activities?
- Which session fields, laps, segments, repetitions, and attributable metric records are present?
- Do Garmin edits and deletions propagate to the existing Health Connect record ID?
- Is a later stable Health Connect release needed before weight and set index can be considered?

## Decision log

| Date | Decision / revision | Approved by |
| --- | --- | --- |
| 2026-08-18 | Implement the reliable stable Health Connect subset first and use real Garmin imports to determine the remaining boundary. | Kyle |
| 2026-08-18 | Candidate implementation passed the full web regression suite plus Android unit tests, lint, and debug assembly; physical provider validation remains. | Codex verification |
