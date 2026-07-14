# Changelog

All notable changes to Archive are documented here. Archive follows semantic versioning where practical and remains in pre-release development until version 1.0.0.

## [Unreleased]

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

[Unreleased]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yeuki/archive-productivity-tracker/releases/tag/v0.1.0
