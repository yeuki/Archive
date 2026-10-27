# Native Archive Implementation Plan

> Execution authorized by the user's request to start rebuilding the approved A/C design. Implement in this session and review the result before any publication.

**Goal:** Create the first useful native SwiftUI Archive increment with safe legacy-data migration and a clear route to full parity.

**Architecture:** Separate `native-ios/` app plus dependency-free `ArchiveCore` Swift package. Keep legacy sources as the reference. Native UI observes an atomic file-backed document; HealthKit feeds source-attributed JSON into the same document.

**Spec:** `docs/specs/2026-10-27-native-swiftui-rebuild.md`.

## Global constraints

- iOS 17+, Xcode 26+, genuine Liquid Glass behind availability checks.
- Preserve all nine destinations and semantic metric colors; no synthetic history.
- Preserve unknown JSON fields and independent daily presence; native migration is explicit.
- Only launch and completed refresh can read HealthKit; permissions are explicit setup.
- Sleep belongs to previous local wake day and supersedes manual sleep.
- No release, merge, deployment or personal-phone installation in this candidate.

## Tasks

- [ ] 1. Build Foundation-only lossless document/backup/domain package and behavioral XCTest coverage. Contract: `JSONValue` Codable/Equatable/Sendable (`object`, `array`, `string`, `number`, `bool`, `null`), readable `objectValue`, `arrayValue`, `stringValue`, `doubleValue`, `boolValue`, object key subscript. `ArchiveDocument` value type with mutable `data: [String: JSONValue]`, `init()`, `init(backup: Data) throws`, `backup() throws -> Data`, `habits`, `trackedHabits`, `entries: [DailyRecord]`, `entry(on: String) -> DailyRecord?`, `setHabit(_:completed:on:)`, `addHabit(_:)`, `renameHabit(_:to:)`, `setTracked(_:enabled:)`, `addWater(_:on:)`, `setWater(_:on:)`, `setManualSleep(_:on:)`, `applyHealthKit(_:)`. `DailyRecord` has `date`, `habits`, optional `waterML`, optional `sleepHours`, `sleepSource`. `HealthKitBatch` has `records: [String: [JSONValue]]`, `deletedIDs: [String: [String]]`, `anchors: [String: String]`, `syncedAt: Date`. Use explicit deletion UUIDs, never empty-query pruning.
- [ ] 2. Implement native HealthKit actor/service in `native-ios/Archive/Services/HealthKitService.swift`, independently of the UI. Contract `actor HealthKitService { func requestAccess() async throws; func read(anchors: [String: String]) async throws -> HealthKitBatch; static var available: Bool }`; explicit read access action, stable source UUIDs, source-attributed records, persisted anchors with stable query boundaries and bounded output.
- [ ] 3. Implement native theme, document store, navigation, Home/Habit/Water/Sleep/Stats/Settings. Use domain contract from task 1. Add native file import/export and recoverable failures. Implement genuine system glass with an accessible fallback, accessible hold action and undo.
- [ ] 4. Implement focused native workout/history starting slice, retain unported features in backups and document parity gaps. Add Xcode project generation, shared scheme, assets and signing setup instructions. Add macOS CI for native tests and unsigned simulator build.
- [ ] 5. Run baseline/regression/project checks, review the complete diff for data loss and unavailable API risks, fix findings and document exact verification limits. Update architecture/design/decision notes and Unreleased only.

## Review focus

- Denied or revoked HealthKit reads must not erase historical imports.
- Invalid backup content must not replace a valid document; unknown fields survive unrelated edits.
- Native writes must not mark missing water/sleep as recorded zero.
- Hold cancellation, accessible activation, large text and reduced-transparency navigation remain usable.
- Empty/custom routines, multiple workouts per day and old active-session shapes must remain recoverable even where native feature parity is incomplete.

## Execution record

- 2026-10-27: Implemented tasks 1–4 as a native migration increment. A fresh code reviewer identified unsafe imported span conversion, ordering recovered habits against an incomplete raw array, partial-habit undo presence and unknown nested presence metadata. Each has a regression test and a focused correction.
- Existing `npm run verify` passes. The first hosted Mac run passed domain tests and compiled the SwiftUI app. Its simulator test step exposed an architecture mismatch when reusing package build products; Debug now selects the active architecture consistently. The corrected tests and storage regressions are being run in draft PR #2.
- Native visual/accessibility/device checks and the full parity list remain acceptance work. No merge, release version, deployment or phone installation has occurred.
