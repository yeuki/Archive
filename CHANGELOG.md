# Changelog

All notable changes to Archive are documented here. Archive follows semantic versioning where practical and remains in pre-release development until version 1.0.0.

## [Unreleased]

## [0.10.1] - 2026-08-07

### Changed

- Replaced the horizontal Archive launch wordmark with the standalone flowing A mark while preserving the established grey-to-pastel loading reveal.
- Centered the A itself on both axes by moving the loader to a square SVG canvas and removing the visible loading caption.
- Remapped the full habit-pink, sleep-purple, water-blue, and move-green gradient across the narrower mark so every Archive color remains represented.

### Preserved

- Kept the v0.8.0/v0.10.0 liquid-glass expanding navigation, centered Home button, nine separate destinations, page hierarchy, Health Connect launch synchronization, and pull-to-refresh behavior unchanged.
- Kept the launch status available to assistive technology even though the visible screen now contains only the animated A.

### Fixed

- Removed the wide invisible wordmark footprint that prevented the A itself from occupying the exact visual center of the launch screen.
- Added a focused regression check for the square A loader alongside the existing navigation and Health Connect policy checks.

### Known issues and unfinished work

- The four-button navigation consolidation discussed for a future release is intentionally not part of v0.10.1; this patch retains the current hierarchy until a direction is approved.
- Samsung Health publication timing and Android-only Health Connect support remain unchanged from v0.10.0.

## [0.10.0] - 2026-08-07

### Added

- Added a dedicated launch gate that keeps the normal interface hidden while Archive initializes and performs its Health Connect reconciliation.
- Added a horizontal Archive loading lockup built from the approved flowing A geometry, two-wave crossbar, and wordmark; the mark begins muted grey and fills from left to right through habit pink, sleep purple, water blue, and move green.
- Added native-feeling pull-to-refresh on normal scrollable pages with resisted drag, release threshold, compact material progress indicator, success/error feedback, and reduced-motion and reduced-transparency accommodations.

### Changed

- Restored the v0.8.0 navigation bar, navigation behavior, nine separate destinations, page hierarchy, layouts, and Archive Canvas interaction model as the source of truth; the consolidated v0.9.0 hierarchy is not carried forward.
- Simplified Health Connect to exactly two data-read triggers: one authoritative 30-day reconciliation on cold launch and one authoritative 30-day reconciliation after a completed pull-to-refresh gesture.
- Replaced separate automatic-sync controls with the existing Health Connect Import switch: when import is on, launch and pull syncing are on; when import is off, neither reads health data.
- Changed the daily sleep Sync option to consume the latest already-imported watch record. It no longer starts a third Health Connect read; missing data directs the user to pull down on a main page or use Manual fallback.
- Retained connection checks, standard Health Connect permission review, canonical source provenance, previous-day sleep ownership, watch-over-manual priority, correction/deletion reconciliation, and local persistence.

### Removed

- Removed foreground-resume syncing, visibility-triggered syncing, 15-minute active polling, periodic background reads, background Health Connect permission requests, manual sync buttons in Settings, and the sleep-sheet Sync now action.
- Removed every v0.9.0 section-tab, merged-destination, four-button dock, and Settings-as-utility change from the active application interface.

### Fixed

- Added upgrade cleanup that cancels WorkManager jobs left behind by older automatic-sync policies and leaves the retained migration worker unable to read Health Connect data.
- Prevented the underlying interface and document scrollbar from appearing during launch initialization.
- Preserved zero horizontal overflow at both 412 x 915 and 360 x 800 while keeping the exact v0.8.0 bottom navigation implementation.

### Known issues and unfinished work

- Samsung Health controls when watch records reach Health Connect, so a successful Archive refresh cannot import data Samsung has not published yet.
- Browser previews can verify the loader, layout, and gesture wiring but cannot execute Android Health Connect reads or permission flows.
- Health Connect remains Android-only; iOS packaging and Apple Health integration remain future work.
- v0.9.0 remains preserved in Git and the immutable APK archive for release-history integrity, but v0.10.0 intentionally supersedes its navigation and hierarchy.

## [0.9.0] - 2026-08-07

### Added

- Added a focused four-destination navigation model: Today, Track, Train, and Progress.
- Added compact in-page destination switchers so Track contains Habits, Water, and Sleep; Train contains Today and History; and Progress contains Insights and Coach without turning any one page into an overloaded dashboard.
- Added a branded startup screen whose Archive mark fills from muted grey to its full pastel gradient from left to right while the app prepares recent data.
- Added a minimum 1.5-second startup presentation so fast launches still feel deliberate, with an upper wait bound so a slow Health Connect response cannot trap the user on the loader.

### Changed

- Replaced the eight-destination, edge-to-edge bottom taskbar with a slimmer centered dock while keeping Settings available as a top-level utility rather than a primary destination.
- Changed automatic Health Connect behavior to one recent three-day refresh per cold app launch; returning to the foreground and leaving the app open no longer triggers repeated watch reads.
- Retained explicit manual Health Connect refreshes for users who want an update without restarting Archive.
- Removed the background health permission and disabled periodic and immediate WorkManager scheduling, while keeping the existing canonical reconciliation and local persistence model intact.
- Hardened the release builder to verify `VERSION`, `package.json`, and both root package versions in `package-lock.json`, finalize and push the built APK checksum before tagging, and place both generic and version-named release notes beside each Drive APK.

### Fixed

- Cancelled legacy periodic jobs during configuration and converted the retained migration worker to a no-op, preventing an older installed scheduling policy from continuing watch reads after upgrade.
- Preserved zero horizontal overflow at 412 x 915 and 360 x 800 phone sizes across the consolidated navigation and startup experience.

### Known issues and unfinished work

- Archive can only import data after Samsung Health has shared it with Health Connect, so newly recorded watch data may still reflect Samsung's upstream delay when the app opens.
- Browser previews show the branded minimum-duration loader but cannot exercise native Health Connect permissions or watch synchronization.
- The Progress destination establishes the information architecture for future progress feedback, but levels, achievements, and the optional character system are not included in this release.
- Health Connect remains Android-only; iOS packaging and Apple Health integration remain future work.

## [0.8.0] - 2026-07-15

### Added

- Extended the Archive Canvas visual language to Workout, Workout History, Coach, and Settings with atmospheric metric heroes, editorial section hierarchy, continuous page backgrounds, and shared translucent materials.
- Added live summary layers for today's training plan, monthly workout activity, coach health signals, and local-first privacy settings.
- Added purposeful entrance motion for training meters, monthly calendar cells, workout sessions, coach messages, and expanded settings groups, with reduced-motion support throughout.
- Added compact progressive disclosure for unusually long coach responses so a single saved message cannot dominate the conversation surface.

### Changed

- Rebuilt Workout around a training-plan hero, active-session section, build-focus story, concise training-setup launcher, and the shared pinned-panel section.
- Reframed Workout History around monthly training totals, a larger tactile calendar, clearer scheduled-miss states, and an editorial session-detail area while retaining past-workout backfill.
- Reworked Coach into a scroll-safe data-signal canvas with calmer message materials, bounded conversation scrolling, a liquid composer, and compact long-response handling.
- Reorganized Settings into Personal, Connections, and Intelligence sections with a quick Health Connect status and sync surface; connection details, integrity diagnostics, watch layers, and scoring weights now expand only when requested.
- Refined Workout Settings and Coach proposal overlays to use the same spacing, corner, depth, and translucent-material rules as the main app.

### Fixed

- Prevented Coach's jump-to-latest behavior from scrolling the redesigned page away from its hero; only the conversation now moves to its newest message.
- Preserved zero horizontal overflow at both 412-pixel and 360-pixel phone widths across all redesigned pages.

### Known issues and unfinished work

- Existing malformed text from an earlier Gemini response remains preserved in local coach history; Archive now collapses unusually long responses, but does not silently rewrite saved conversation content.
- Health Connect remains Android-only, and iOS packaging plus Apple Health integration are future work.
- Browser previews cannot exercise native Health Connect permissions, background work, or watch synchronization.

## [0.7.1] - 2026-07-15

### Fixed

- Added a dedicated centered 72% safe-zone scale to the Android adaptive foreground so Samsung One UI and other aggressive launcher masks no longer zoom the Archive mark against the icon edges.
- Kept legacy and round launcher artwork at its original size while padding only the independently masked adaptive layer.
- Updated the editable adaptive SVG and deterministic generator together so future icon regeneration preserves the OEM-safe geometry.

### Known issues and unfinished work

- An existing Samsung home-screen shortcut may briefly retain the v0.7.0 cached rendering; removing and re-adding the shortcut or restarting the launcher forces a refresh.
- A dedicated Android monochrome themed-icon layer and matching iOS asset catalog remain future packaging work.

## [0.7.0] - 2026-07-15

### Added

- Added Archive's first custom launcher identity: a flowing capital A with a two-wave crossbar and a final endpoint that represents the latest point in the archive.
- Added editable SVG brand masters, 1024-pixel reference renders, and a reproducible Android icon generator so every density is derived from one geometry and palette.

### Changed

- Replaced the default Capacitor launcher artwork across Android's legacy, round, and adaptive icon resources.
- Mapped the mark through Archive's established metric colors in order: habit pink, sleep purple, water blue, and move green.
- Changed the launcher field to restrained charcoal so the pastel mark remains legible on both light and dark home screens.

### Known issues and unfinished work

- Some Android launchers may briefly cache the previous icon after an in-place update; restarting the launcher or removing and re-adding an existing home-screen shortcut refreshes it.
- A dedicated Android monochrome themed-icon layer and matching iOS asset catalog remain future packaging work.

## [0.6.0] - 2026-07-14

### Added

- Added automatic Health Connect refresh whenever Archive launches or returns to the foreground, plus throttled refreshes every 15 minutes while the app remains active.
- Added Android background-read permission support and an inexact hourly WorkManager schedule for devices that expose Health Connect background access.
- Added a crash-safe native snapshot handoff: background reads are written atomically, reconciled into Archive's canonical health store on resume, and acknowledged only after local persistence.
- Added Automatic sync, Background access, Last automatic, and background-capture status to Connected Health Settings, with a dedicated permission action.
- Added focused automatic-sync verification for migration defaults, bounded reconciliation windows, manifest permissions, worker scheduling, and durable snapshot handoff.

### Changed

- Shared one canonical native snapshot reader between foreground and background imports so source identity, previous-day sleep ownership, timezone handling, and completeness metadata cannot drift between paths.
- Frequent foreground and background refreshes use a recent 3-day window, while Archive performs a full authoritative 30-day correction and deletion pass at least every six hours while active.
- Existing users with Health Connect import enabled migrate to automatic foreground refresh; an explicit automatic-sync opt-out remains preserved.
- Added Capacitor's native app lifecycle bridge so Android resume events trigger reconciliation directly, with browser visibility retained as a fallback.
- Pinned WorkManager to the Kotlin 1.9-compatible 2.9 release line instead of forcing a project-wide Kotlin migration.

### Fixed

- Prevented unapplied background snapshots from being discarded if Archive is interrupted while reconciling local state.
- Prevented short background windows from suppressing older Health Connect corrections by tracking full-window reconciliation separately.
- Kept automatic imports idempotent across repeated resumes, duplicate lifecycle events, and retries after process interruption.

### Known issues and unfinished work

- Android schedules background work opportunistically; hourly checks can be delayed by Doze, battery restrictions, manufacturer policies, or Health Connect availability.
- Background sync requires a separate user-granted Health Connect permission. Without it, launch, resume, and active-app refresh still work automatically.
- Archive can only import data already shared into Health Connect; Samsung Health and the watch retain control of their own upstream sync timing.
- Health Connect remains Android-only; Apple Health integration and iOS packaging are future work.

## [0.5.0] - 2026-07-14

### Added

- Added Archive's first canonical health-data schema with explicit provider, source record ID, origin, import time, timezone, policy version, and sync-window metadata.
- Added a Health Data Integrity section in Settings showing freshness, source priority, canonical-layer completeness, provenance, retention policy, and reconciliation diagnostics.
- Added focused health-system verification for timezone-stable sleep ownership, duplicates, corrections, deletions, stale synced sleep, rolling samples, and manual fallback preservation.

### Changed

- Replaced additive 30-day Health Connect imports with authoritative reconciliation for daily summaries, sleep sessions, and workouts, so the local archive mirrors corrected source data.
- Health Connect sleep remains watch-first and is consistently filed on the day before wake-up; the policy no longer depends on whether sleep began before or after midnight.
- Native sleep and workout reads now follow Health Connect pagination and report whether each canonical layer was complete.
- Heart-rate and HRV storage is now explicitly treated as a bounded rolling sample set instead of being presented as a complete historical archive.
- Advanced JSON backups now use schema version 2 while continuing to normalize and import older Archive backups.

### Fixed

- Removed stale synced records when they are deleted from Health Connect inside the latest reconciliation window.
- Deduplicated records using stable source, timestamp, session, and value identities rather than relying only on provider record IDs.
- Preserved manual sleep when no watch session exists, while allowing a later Health Connect session to replace the fallback authoritatively.
- Kept sleep dates stable when the device timezone changes by retaining and applying the timezone used during import.

### Known issues and unfinished work

- Health Connect synchronization is still user-initiated; scheduled background refresh is a separate future release.
- Standard Health Connect access remains limited to the recent 30-day window unless history permission is added.
- HR and HRV retain the latest 500 samples per metric from each import and are not a complete long-term raw-signal store.
- Health Connect remains Android-only; Apple Health integration and iOS packaging are future work.

## [0.4.3] - 2026-07-14

### Changed

- Sleep sessions now belong to the calendar day immediately before their wake-up date, regardless of whether sleep began before or after midnight.
- Health Connect sleep is authoritative whenever a synced and manual value conflict; the synced duration replaces the manual fallback.
- Manual sleep remains available only when Archive has no watch record for the selected day, and the daily sheet now explains this precedence directly.
- Existing watch sessions and daily records are migrated from both the former wake-date and start-date policies into the corrected previous-day policy.
- Expanded the focused sleep-policy checks with a 2:00 a.m. start, a normal cross-midnight sleep, superseded-record cleanup, manual fallback retention, and synced-value precedence.

### Known issues and unfinished work

- Health Connect import is still user-initiated rather than a scheduled background sync.
- Watch sleep availability depends on Samsung Health sharing the session with Health Connect.
- Health Connect remains Android-only; Apple Health integration and iOS packaging are future work.

## [0.4.2] - 2026-07-14

### Added

- Added an explicit Sync or Manual sleep choice to the daily-recording sheet, with watch sync selected by default and a blank manual fallback for nights the watch misses.
- Added sleep-source provenance to daily records so later Health Connect imports can refresh synced values without overwriting intentional manual entries.
- Added a focused sleep-policy check covering overnight attribution, migration of previously imported records, and preservation of manual fallbacks.

### Changed

- Health Connect sleep sessions are now assigned to the local calendar date on which sleep began; for example, Monday night through Tuesday morning is filed under Monday.
- Existing imported sleep values that exactly match the former wake-date mapping are migrated to their start date while habits, water, and explicit manual sleep remain intact.
- Removed the fabricated 7.25-hour default from new daily records and added clear sync status, duration, timing, and date-attribution guidance.

### Known issues and unfinished work

- Health Connect import is still user-initiated rather than a scheduled background sync.
- Watch sleep availability depends on Samsung Health sharing the session with Health Connect; Manual remains the fallback when a session is absent.
- Health Connect remains Android-only; Apple Health integration and iOS packaging are future work.

## [0.4.1] - 2026-07-14

### Changed

- Enlarged the resting liquid-glass navigation dock to give its refraction, specular highlight, active lens, and lower caustic more visible depth.
- Increased the Home control, navigation glyphs, and internal vertical spacing without making the iconography visually heavy.
- Rebalanced expanded-dock widths and control spacing at 400, 380, and 360-pixel breakpoints so every destination remains fully accessible.
- Preserved the smaller compact-on-scroll state, allowing the dock to feel spacious at rest and discreet while reading content.

### Known issues and unfinished work

- The Capacitor WebView treatment approximates optical refraction through composited material layers rather than true background-pixel displacement.
- Workout, Workout History, Coach, and Settings retain their previous page compositions.
- Background Health Connect synchronization and iOS packaging remain future work.

## [0.4.0] - 2026-07-14

### Added

- Added Archive Canvas, a content-first visual architecture for Home, Habit, Water, Sleep, and Stats with integrated metric heroes, atmospheric page color, and edge-to-edge primary visualizations.
- Added scroll-reactive page chrome that compacts the top bar and minimizes the bottom navigation while scrolling down, then restores both when scrolling upward.
- Added shared visual continuity between page summaries, charts, and details through coordinated page, value, chart, and sheet-origin motion.
- Added canvas-specific accessibility behavior for reduced motion, reduced transparency, and increased contrast preferences.

### Changed

- Replaced the uniform stack of elevated white cards on core metric pages with typography, spacing, hairlines, grouped canvas surfaces, and selectively elevated actions.
- Integrated weekly charts into each metric hero so the current value and its recent pattern read as one story.
- Reworked Home into an atmospheric daily canvas with guidance, weekly value, metric balance, and patterns presented with fewer nested containers.
- Preserved optional modules as Pinned Panels while visually separating customization from the primary page narrative.
- Refined corner concentricity, section rhythm, chart scale, action grouping, and compact-screen behavior across the core health and productivity experience.

### Known issues and unfinished work

- Workout, Workout History, Coach, and Settings retain their previous page compositions, although they inherit the shared scroll-reactive chrome.
- Background Health Connect synchronization and iOS packaging remain future work.
- True cross-page native shared-element transitions remain limited by the current Capacitor WebView architecture.

## [0.3.1] - 2026-07-14

### Added

- Added a multi-layer optical treatment to the expanding bottom navigation with a refractive rim, moving specular light, a soft internal caustic, and live touch-position response.
- Added an active-page lens that glides between destinations and gives the selected control a clearer spatial relationship to the glass shell.

### Changed

- Refined the collapsed and expanded navigation proportions, contrast, edge lighting, shadows, icon rendering, and spring timing for a more convincing liquid-glass appearance.
- Kept all four destinations visible on either expanded side at narrow phone widths while increasing touch clarity.
- Added opaque, reduced-motion, and unsupported-backdrop fallbacks without changing navigation behavior.

### Known issues and unfinished work

- The WebView treatment approximates optical lensing with composited backdrop layers; true pixel displacement remains a future native Android or GPU-rendered experiment.
- Workout, Workout History, Coach, and Settings retain their existing page structures.
- Health Connect synchronization remains manual, and iOS packaging remains future work.

## [0.3.0] - 2026-07-13

### Added

- Added a curated story hierarchy to Home, Habit, Water, Sleep, and Stats using fixed heroes, editorial sections, weekly patterns, highlights, details, and personalization areas.
- Added dynamic For You guidance on Home and metric-specific Archive insights on the core health pages.
- Added a shared motion system for staggered bar growth, left-to-right line drawing, a traveling chart marker, progress growth, metric reveals, section transitions, and tactile press feedback.
- Added explicit reduced-motion behavior that preserves every value and state without relying on movement.

### Changed

- Kept the existing module engine and persistence model while presenting optional modules as Pinned Panels within a deliberate page structure.
- Reframed the Add flow as Add or Customize, and updated the gallery language around pinning, configuring, and arranging panels.
- Reorganized Home into For You, Pinned Summary, Patterns, and Pinned Panels instead of a uniform stack of equal-weight cards.
- Reorganized Habit, Water, Sleep, and Stats around a shared chart-first information architecture.
- Improved empty-state language so pages distinguish missing data from genuine zero values.
- Replaced placeholder ten-week Stats values with weekly averages calculated only from real saved records.

### Known issues and unfinished work

- Workout, Workout History, Coach, and Settings retain their existing page structures and can adopt the curated hierarchy in a later release.
- Health Connect synchronization remains manual and still uses the recent access window.
- Background synchronization, iOS packaging, and Apple Health integration remain future work.

## [0.2.1] - 2026-07-13

### Changed

- Restored Archive's signature white-to-tone gradient on compact bar charts with ten or fewer columns, including Daily Value and Previous 10 Weeks.
- Kept month value grids, streak grids, workout calendars, and other dense data views solid for clearer scanning and tapping.

### Known issues and unfinished work

- Health Connect synchronization remains manual and still uses the recent access window.
- iOS packaging and Apple Health integration remain future work.

## [0.2.0] - 2026-07-13

### Added

- Introduced Archive Design System 2.0 with a quieter surface hierarchy, editorial typography, refined spacing, and adaptive glass controls.
- Added a Today summary hero to Home with the current daily value, record state, date, progress gauge, and direct record/review action.
- Added a dedicated sleep summary with seven-day average, target progress, key metrics, and a clearer weekly chart hierarchy.
- Added a privacy-focused Settings introduction and compact preference highlights.

### Changed

- Rebuilt top bars around a consistent Archive eyebrow, stronger page titles, and a grouped glass action control.
- Rebalanced panel borders and shadows so content surfaces feel layered without every card appearing heavily elevated.
- Replaced gradient histogram bars with solid semantic metric tones.
- Reflowed Settings details beneath their labels, preventing narrow right-aligned descriptions from wrapping into tall columns.
- Refined Connected Health actions, status badges, module panels, summary rows, and the expanding bottom navigation.
- Updated the README screenshot to the new Home interface.

### Fixed

- Corrected the shortest-night calculation so populated sleep weeks no longer incorrectly report `0h`.
- Kept the expanded four-item productivity navigation fully inside narrow phone layouts.

### Known issues and unfinished work

- Health Connect synchronization remains manual and still uses the recent access window.
- Home correlation copy remains a lightweight summary; deeper evidence-backed correlation explanations are future work.
- Additional screen-specific polish beyond the global system and the Home, Sleep, and Settings showcase screens remains planned.
- iOS packaging and Apple Health integration remain future work.

## [0.1.0] - 2026-07-13

### Baseline

- Established Archive's first formal versioned release.
- Preserved the current productivity, health, and workout experience as the reference baseline.
- Added immutable local and Google Drive APK archives, release checksums, and a repeatable release build script.
- Aligned the web package and Android application version with the repository `VERSION` file.

### Present functionality

- Daily habit, water, and sleep tracking with editable historical records.
- Modular dashboard panels, month-based value grids, charts, correlations, scores, and timelines.
- Workout schedules, routines, exercise library, workout logging, and detailed workout history.
- Approval-based Gemini coach with access to health, productivity, and workout context.
- Health Connect permissions and manual imports for steps, sleep, exercise, distance, calories, heart rate, HRV, and floors.
- Local-first persistence with JSON import and export.

### Known issues and unfinished work

- Health Connect synchronization is manual; background synchronization is not yet implemented.
- Health Connect history is limited to the recent access window unless extended history permission is added.
- The visual system is functional and consistent but has not yet received the planned premium design-system refinement.
- iOS packaging and Apple Health integration are future work.

[Unreleased]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.3...v0.5.0
[0.4.3]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yeuki/archive-productivity-tracker/releases/tag/v0.1.0
