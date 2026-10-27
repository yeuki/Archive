# Native Archive — first working increment

- Status: In progress; design and implementation direction authorized by Kyle on 2026-10-27.
- Baseline: `d1f8a8c`, Archive 0.13.0 plus accepted main changes.
- Branch: `codex/swiftui-rebuild`. Target release: Unreleased.

## Intent and approved design

Build Archive natively in SwiftUI. The approved combination is concept A's warm ivory, gentle semantic pastels, regular elegant system-serif headings/values and quiet system-sans controls, applied to concept C's compact layout. The emotional goal is reassurance and encouragement, including on incomplete days. The first increment is a real, locally persistent native app, not a WebView reskin. Existing web/Android functionality stays available during migration.

## Approaches and decision

The earlier React/Capacitor boundary offered reuse but cannot supply a completely native experience. A single immediate destructive replacement would put existing records and unported features at risk. Kyle chose native SwiftUI; implement it as a separate `native-ios/` project in the same repository and migrate features in reviewable increments. This supersedes D-020 for the new native iOS product only. Web/Android remain supported reference implementations.

## First increment

- Native Home, Habit, Water, Sleep, Stats, Settings and the established centered Home / expandable Productivity and Health dock. Keep all nine destination identities.
- Durable native storage, independent daily fields, habit management, hydration logging/undo, manual sleep fallback, editable dates and goals, source-labelled watch data and portable legacy JSON imports/exports.
- Workout and history adapters preserve imported configuration/history/active sessions and offer native focused logging where implemented. A parity matrix must identify remaining work instead of claiming the port is complete.
- Read-only HealthKit service for sleep, steps, distance, energy, HR, HRV, floors and workouts. Request access only from explicit setup. Read only on cold launch and completed refresh. Handle denied/empty results conservatively, preserve UUID/source identity, do not turn missing data into zeros, and never infer read authorization from a completed permission sheet.
- Genuine `glassEffect` on iOS 26+, an accessible material fallback on older supported versions, reduced motion/transparency and Dynamic Type. Target iOS 17+; build with Xcode 26+.

## Data and safety

Use a Foundation-only Swift package for lossless JSON, compatible backups and daily/health rules. Preserve unknown fields, module definitions, workout snapshots, coach history and future additions on import/export. A failed import must leave the current document untouched. Retain an automatic pre-import backup; use atomic disk writes and surface errors. No fabricated personal records. API credentials remain outside exports. Sleep belongs to the local day before wake date even for AM starts; imported sleep supersedes manual fallback while keeping the fallback recoverable. Existing high-frequency samples stay bounded. HealthKit HRV SDNN must retain its measurement identity and must not be labelled RMSSD.

The native document is a new store. Browser/Android records move through explicit JSON export/import; do not imply automatic access to Safari localStorage. No publication, release number, signing changes or device installation is included in this implementation request.

## Verification and completion boundary

Run existing repository verification. Add native domain XCTest coverage for lossless backups, partial days, non-destructive malformed imports, independent hydration, watch sleep precedence/date attribution and explicit health deletions. Add a reproducible Xcode project and macOS CI build/test workflow. On Windows, project/resource/contract checks are supporting evidence only: they do not establish Swift compilation, native visual correctness, permissions or device performance. Mark Xcode/simulator/iPhone checks pending until actually performed.

## Remaining parity work

Maintain `native-ios/PARITY.md` with honest implemented/partial/pending states for modules, analytics, workout edge cases, coach proposals, notifications and Garmin watch actions. The old app remains the functional baseline until the user accepts native parity. No lost or hidden data is an acceptable shortcut.
