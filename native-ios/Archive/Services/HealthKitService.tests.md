# HealthKitService contract and validation

Apple-toolchain compilation is exercised by the native workflow in draft PR #2.
Physical HealthKit authorization and real Garmin transport remain **pending**;
none of the device scenarios below should be interpreted as having run on an iPhone.

## Integration contract

- `requestAccess()` requests read access only. Completion means the system review
  completed, **not** that any read category was granted. It never queries records.
- Only the app's explicit cold-launch and completed-refresh paths call `read`.
  Setup, navigation, foregrounding, observers and background delivery do not.
- Apply a returned batch and its anchors in one durable document transaction.
  An explicit `HKErrorDomain` / `errorAuthorizationDenied` query error discards
  only that type's staged pages, deletions and candidate anchor/boundary, retaining
  its old cursor and allowing unrelated types to complete. It is not inferred
  from empty results. On any other thrown error retain all previous records and
  anchors. Do not treat an empty layer as permission evidence or as a request to
  prune existing records.
- Raw cumulative samples go in `quantitySamples`, **not** `dailySummaries`.
  Core must aggregate by day with source/overlap deduplication; never simply sum
  overlapping phone/watch samples. Metrics: `steps`/`count`, `distance`/`m`,
  `activeCalories`/`kcal`, `basalCalories`/`kcal`, `floors`/`count`.
- Other layers are `sleepSessions`, `workouts`, `heartRate` (`bpm`) and
  `heartRateVariability` (`ms`, `measurement: "SDNN"`, never RMSSD).
- Every record has `id` (HealthKit UUID), `provider: "healthKit"`, `source`
  (actual display name), `sourceId` (actual source bundle ID), `healthKitType`,
  fractional ISO-8601 UTC `startedAt`/`endedAt`, `date` (local **start** date, not
  attributed sleep date), `timezone` (timezone identifier), `timeZoneSource`,
  `sourceRevision`, nullable `device`, and selected identity `metadata`.
  No source UUID is invented:
  HealthKit exposes the sample UUID and source bundle identity separately.
- Compatibility aliases `startDate`/`endDate`, `timeZone`, `sourceName` and
  `sourceBundleId` retain the identical timestamps/zone/source identity.
- Sleep records retain raw `sleepStage`, numeric `stage`/`sleepStageValue`, `isAsleep` and
  `durationSeconds`, including awake/in-bed intervals. Core must union/deduplicate
  asleep intervals, ignore awake/in-bed duration, preserve real sources and
  attribute the session to the local calendar day **before its wake date** using
  `endedAt` and `timezone`, not the raw record's `date` or start clock time.
  The exact mapping is `0: inBed/false`, `1: asleepUnspecified/true`,
  `2: awake/false`, `3: asleepCore/true`, `4: asleepDeep/true`,
  `5: asleepREM/true`, unknown values: `unknown/false`. Core must honor the
  explicit boolean, including `false` for future unknown stages.
- Workout records retain numeric HealthKit `activityType`, `durationSeconds`,
  nullable `distanceMeters` and `activeCalories`. No inferred weights, sets,
  routes or laps are produced. Workout energy is not additional daily energy.
- `deletedIDs` uses the same canonical layer names and plain sample UUIDs.
  Quantity deletions are under `quantitySamples`; core must look up the old
  sample's metric/date before deleting it and recompute affected aggregates.
  A deleted HealthKit object supplies no quantity/metric value to reconstruct.
- Anchor keys are HealthKit sample-type identifiers; each has a paired
  `<identifier>.startDate`. The boundary is initialized once at now minus 30 days
  (seven days for high-frequency HR/HRV)
  and never moves while that anchor is retained. Values are secure-coded
  `HKQueryAnchor` archives encoded as base64 (encoding is not encryption).
  Store them in the protected local document; do not log them. Corrupt anchors or
  an anchor without its boundary fail closed, never silently restart/prune.

## Acceptance scenarios to run on macOS / iPhone

| Scenario | Expected result |
| --- | --- |
| Build the app using Xcode 26+, iOS 17 deployment target, Swift 5.9 language mode | No unavailable APIs, continuation errors or actor-isolation errors. Enable complete concurrency checking as an additional diagnostic. |
| Request access; deny all, allow a subset, then revoke access in Health | No sharing request; no query from setup; no inferred category grants; empty reads never clear previously imported rows. |
| Review access again after enabling a previously denied category | Store invalidates old in-flight results and resets device cursors; the next launch/pull replays the bounded window, retaining existing UUIDs until actual replacement/deletion. Setup itself never reads data. |
| Return an actual authorization-denied error after some pages of one quantity type, while other types are readable | Only that type's staged samples/deletions are discarded; its old anchor/boundary is unchanged; other quantity metrics in the shared layer and other layers still import. No other error code/domain is silently swallowed. |
| Read unavailable HealthKit or a locked/protected store | A surfaced error, unchanged durable data/anchors, no automatic retry/query. |
| Initial query and second read several days later | Exact same per-type lower predicate boundary, no moving upper boundary; only the second query's anchor changes. |
| Malformed base64/archive, oversized archive, missing or invalid boundary | Throw before advancing any durable anchor; no silent nil-anchor reset. |
| Seed over 500 samples or over 500 deletions for one type | Drain one-shot pages until an empty page; preserve every UUID; no observer/update handler. |
| Reach sample, byte, page, deadline or stalled-anchor limit; fail the last type | Throw without returning a partial batch or new durable anchors. A healthy retry replays all changes. |
| Cancel before query registration, during callback, or immediately after it | Exactly one continuation resume, active query stopped, no returned batch after cancellation. |
| Query never calls its handler | Timeout stops query and resumes once; late callback is ignored. |
| Start a second read while the first awaits HealthKit | Second call fails as busy, rather than racing the same old anchors. |
| 123 steps, 1.5 km, 4184 J energy, 2 floors, 1 beat/sec, 0.050 s SDNN | 123 count, 1500 m, 1 kcal, 2 count, 60 bpm, 50 ms SDNN, respectively. |
| Delete one sample of each quantity metric | UUID appears in `quantitySamples` deletions; core removes only the identified sample and recalculates its old metric/day. |
| Correct a sample by deleting its old UUID and adding another | Both deletion and replacement survive the same batch; no deletion by empty-window inference. |
| Overlapping asleep/core/REM/in-bed/awake samples, two providers, a nap, DST and travel | Raw stages and provider metadata survive; core counts only deduplicated asleep time and owns previous-wake-day attribution. |
| Workout with and without supplied energy/distance | Supplied units are correct, missing values are null, and no fabricated strength/lap fields appear. |
| Historical samples with/without valid timezone metadata | Valid sample timezone preserved; otherwise device-zone fallback is explicitly labelled, not represented as known historical timezone. |

The caps deliberately fail closed rather than returning a truncated first import.
Very dense 30-day histories may need a separately approved chunked-transaction
design. Broader history, source-selection/day aggregation, storage protection,
entitlements/usage text and the two caller triggers belong to the other tasks.

Limits: 500 samples/page, 128 pages/type, 25,000 combined samples/deletions,
64 KiB/record or anchor archive, 16 MiB complete payload, 15 seconds/query and
90 seconds/read. Denied-type rollback also rolls back its staged budget usage.
Legacy workout total accessors intentionally preserve supplied data when modern
energy statistics are absent; Xcode may issue deprecation warnings for them.
HealthKit retains deletion tombstones for a limited time: a launch/refresh-only
import cannot guarantee discovering deletions after an arbitrarily long absence.
It never compensates by pruning history from an empty query.

## Local verification record

- `npm run verify`: passed the existing repository regression scripts and web
  build. These tests do not compile or execute this Swift service.
- Ten read-only source contract checks: passed (API, read-only request isolation,
  one-shot query construction, all nine types, canonical fields/layers, SDNN,
  boundary/archive safeguards, denied-type staging, bounds and asleep mappings).
- Final review: author self-review, not an independent native reviewer. Checked
  continuation registration/cancellation/timeout races, per-type denial rollback,
  canonical core fields and delayed anchor commit. Native race tests remain pending.
- `swift` and `xcodebuild`: unavailable. No Swift build, XCTest, simulator,
  HealthKit-permission, device-concurrency or iPhone performance result is claimed.
- Only this service and this document are task-2 deliverables; no commit.

## API references reviewed

- [Anchored query parameters and callback semantics](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery/init(type:predicate:anchor:limit:resultshandler:))
- [Read-authorization privacy](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Sleep category values](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
- [Sample timezone metadata](https://developer.apple.com/documentation/healthkit/hkmetadatakeytimezone)
- [Workout statistics](https://developer.apple.com/documentation/healthkit/hkworkout/statistics(for:))
- [Legacy workout distance](https://developer.apple.com/documentation/healthkit/hkworkout/totaldistance)
- [Deletion tombstone lifetime](https://developer.apple.com/documentation/healthkit/hkhealthstore/deleteobjects(of:predicate:withcompletion:))
