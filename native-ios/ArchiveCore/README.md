# ArchiveCore — task 1, Unreleased

Dependency-free Swift 5.9+ package, declaring macOS 13 and iOS 17 minimums. Production sources import only Foundation;
tests use XCTest. No SwiftUI, HealthKit, networking, disk access, credentials,
generated history, timers or synchronization triggers live here.

## Public contract

`JSONValue` is Codable/Equatable/Sendable with object, array, string, number
(Double), bool and null cases. Typed accessors return empty/zero/false defaults
without coercion. Object lookup returns `.null` when absent; assignment supports
nested value-semantic writeback. Setting a key on a scalar promotes it to an object.

`ArchiveDocument` is an Equatable/Sendable value with public mutable
`data: [String: JSONValue]`. It supplies exactly task 1's initializers, backup,
habit/tracking/daily mutations, `entries: [DailyRecord]`, `entry(on:)`,
`applyHealthKit(_:)`, and `dateKey(_:calendar:)`. Habit names and tracked habits
are `[String]`. Water mutations accept Double millilitres; sleep accepts Double
hours. Invalid dates, nonfinite/negative inputs and manual sleep above 24 hours
are ignored. New water totals above 1,000,000,000 mL are also rejected. Imported
finite extremes remain raw and exportable, but typed DailyRecord display values
are bounded at 1,000,000,000 mL and 24 hours to prevent integer-conversion traps.
Adding water never uses a lossy display clamp as its starting value.
`setWater(0, ...)` and `setManualSleep(0, ...)` record explicit zeros;
`addWater(0, ...)` and unchecking a nonexistent day do not invent a day.

`DailyRecord` exposes date, habits `[String: Bool]`, optional waterML/sleepHours,
and sleepSource (default `manual`; watch projection is `sync`, matching legacy).
Raw entries retain `water` and `sleep`, not duplicate native-only metric fields.
Legacy entries without recordedFields count all three metrics as recorded;
partial entries use only explicitly true flags. Missing partial metrics are nil,
not zero. Habit rename merges colliding completion values with logical OR and
updates historical names/tracking without erasing completions or other fields.

## Backup and transaction safety

Import requires an Archive envelope with app `archive-productivity-tracker`,
integer version 1–4, and an object data containing an entries array. Unwrapped
arbitrary JSON, unsupported versions, invalid dates, duplicate daily dates,
negative/nonnumeric metrics and malformed known containers fail before a new
document is returned. Sparse valid daily entries are supported. Export uses
the same envelope and version 4. Unknown data, entry, watch record and envelope
fields survive unrelated changes; unported workout/module/coach data is not
normalized away. JSON is semantically preserved, not byte-for-byte (key order,
formatting and exportedAt change; numeric values use the Double case).

Unitless legacy water follows the React cups heuristic (target <=30 or all
existing water values <=30), at 250 mL/cup. Explicit waterUnit prevents that
heuristic. The migrated unit is persisted so conversion cannot run twice. This
is deliberately the existing heuristic, including its ambiguity for tiny
unitless values; no new inference about a user's intake is introduced.

Use a copy, reconcile/import it, serialize and atomically persist it, then publish
that copy. Failed decoding or failed persistence must leave the live document
and durable file intact. File protection, a pre-import recovery copy and surfaced
errors belong to ArchiveStore. Secrets must stay outside data in a local vault;
this open document intentionally does not guess which unknown fields to remove.

## Agreed HealthKit transport

`HealthKitBatch(records:deletedIDs:anchors:syncedAt:)` has public mutable fields
and default arguments. Each record has stable `id`, provider `healthKit`, source
display name, sourceId bundle, startedAt/endedAt ISO8601 timestamps, timezone IANA
identifier and date. Service aliases/provenance remain in records unchanged.
Canonical layers are dailySummaries, sleepSessions, workouts, heartRate,
heartRateVariability and quantitySamples. Heart layers persist under
`data.watchData.samples`; other layers persist directly under watchData. Unknown
batch layers can also be retained. Corrected UUID records merge extension fields;
identity is provider+UUID, case-insensitive for UUID matching. Only explicit
deletedIDs remove HealthKit rows in that layer, **except the explicitly approved
HR/HRV retention policy**: on reconciliation only HealthKit heartRate and
heartRateVariability samples older than 30 days relative to batch.syncedAt are
removed, then at most the newest 2,500 per layer remain. Undated HealthKit samples
are also count-bounded, after dated samples. Other-provider/legacy rows and
extension fields on retained rows/containers remain untouched. This age policy
does not infer query completeness or permission. Quantity samples and their old
daily aggregates are never age/count-pruned without a future snapshot contract.
Incoming additions marked deleted in the same batch stay deleted.

Quantity metrics are steps, distance (metres), activeCalories, basalCalories and
floors. Samples are stored by UUID, then one preferred source is selected per
metric/date: Garmin, Apple Watch, then deterministic source identity. Samples
within that one source are additive; overlapping other sources are not added.
Derived summary fields are steps, distanceMeters, activeCalories, basalCalories,
floors, and totalCalories **only when both** active and basal exist. Missing
metrics remain absent. `metricSources` gives per-metric provenance. Derived
summaries carry `nativeIOS.derivedQuantitySummary`; unrelated legacy/provider
summary rows are retained, not summed into them. The UI must choose a summary
per metric/date rather than sum providers or arbitrarily pick a tied date.
HRV remains a source-attributed sample with measurement `SDNN`; no RMSSD rename
or cross-measurement averaging is performed.

Sleep honors explicit isAsleep (including false), otherwise recognized stages;
unknown stages do not count as asleep. Legacy unstaged sessions are accepted.
It groups stages by source and optional sessionId, clustering continuous raw
intervals separated by at most 90 minutes. This bridges midnight stages and
uses the **episode's final wake**, including inBed/awake boundaries. Asleep
intervals are unioned, not summed, and only one preferred source contributes
per day. The previous calendar day is computed in sample timezone (or the local
calendar fallback), regardless of AM/PM; elapsed duration remains DST-correct.
No interval is synthesized to fill a stage gap. Legacy duration-only sessions
keep their explicit date because a wake timestamp is unavailable.

Watch sleep supersedes manual sleep but preserves its recoverable metadata in
the raw entry's `nativeIOS.sleepFallback`, with `nativeIOS.sleepManaged` marking
the projection. Editing manual sleep while watch sleep exists updates that
fallback only. Corrections/deletions re-project surviving watch sources, restore
the manual fallback, or remove only the now-empty watch projection; concurrent
habit/water edits and extension fields survive.

Anchors merge at `data.nativeIOS.healthKitAnchors`, with healthKitSyncedAt. They
are only candidate values until the store persists the entire transaction. The
UI's existing explicit post-reconciliation anchor assignment can be idempotent;
it must not persist anchors independently or drop retained keys.

## Verification and integration handoff

On a machine with Swift:

```sh
swift test --package-path native-ios/ArchiveCore
```

XCTest exercises actual service-shaped fixtures (canonical keys, fractional UTC,
IANA timezone, aliases, device/source metadata, all sleep enum cases and SDNN),
plus unknown-field backup roundtrip, malformed imports, partial daily mutations,
habit history, cups, source selection, unioned sleep, DST, fallback recovery,
provider/layer-scoped deletion, corrected UUIDs, bounded anchored HR/HRV increments,
preserved old quantity totals, huge finite metric safety and no fabricated records.

Windows implementation session: `swift test` was attempted but Swift is not
installed. These tests have **not** been compiled or executed; source inspection
and legacy JS regression scripts cannot establish native correctness. No commit,
version bump or release is part of this task. Review is an author self-review,
not an independent compiler or fresh-reviewer gate.

UI integration requirements: retain all data when editing settings; distinguish
nil metrics from zero; label synced sleep using raw sleepOrigin/sleepProvider;
explain that manual edits during watch coverage update a fallback; select daily
movement per metric/source using metricSources rather than adding provider rows;
normalize absent partial undo flags to false, never `.null`; and atomically commit
the reconciled document plus merged anchors. Other agents own these UI changes.
