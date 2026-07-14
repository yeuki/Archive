# Changelog

All notable changes to Archive are documented here. Archive follows semantic versioning where practical and remains in pre-release development until version 1.0.0.

## [Unreleased]

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

[Unreleased]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/yeuki/archive-productivity-tracker/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yeuki/archive-productivity-tracker/releases/tag/v0.1.0
