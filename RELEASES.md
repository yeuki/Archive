# Archive release index

Release APKs are immutable. If a packaged build changes, Archive receives a new semantic version rather than replacing an older APK.

| Version | Release date | APK | Summary | Source reference |
| --- | --- | --- | --- | --- |
| 0.4.1 | 2026-07-14 | `Archive-v0.4.1.apk` | Roomier liquid-glass dock with stronger optics, larger controls, and preserved scroll compaction. | `main`, tag `v0.4.1` |
| 0.4.0 | 2026-07-14 | `Archive-v0.4.0.apk` | Archive Canvas with integrated metric stories, reduced card chrome, and scroll-reactive continuity. | `main`, tag `v0.4.0` |
| 0.3.1 | 2026-07-14 | `Archive-v0.3.1.apk` | Layered liquid-glass bottom navigation with responsive optics and refined interaction. | `main`, tag `v0.3.1` |
| 0.3.0 | 2026-07-13 | `Archive-v0.3.0.apk` | Curated metric stories, pinned-panel personalization, and a purposeful motion system. | `main`, tag `v0.3.0` |
| 0.2.1 | 2026-07-13 | `Archive-v0.2.1.apk` | Restores Archive's signature gradient on compact charts while preserving solid dense-data views. | `main`, tag `v0.2.1` |
| 0.2.0 | 2026-07-13 | `Archive-v0.2.0.apk` | Archive Design System 2.0 with premium Home, Sleep, Settings, chart, surface, and navigation refinements. | `main`, tag `v0.2.0` |
| 0.1.0 | 2026-07-13 | `Archive-v0.1.0.apk` | Formal baseline of the current productivity, health, workout, AI coach, and Health Connect experience. | `main`, tag `v0.1.0` |

## 0.4.1 — Roomier liquid-glass dock

- APK filename: `Archive-v0.4.1.apk`
- Local archive: `releases/v0.4.1/Archive-v0.4.1.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.4.1/Archive-v0.4.1.apk`
- GitHub reference: `main`, tag `v0.4.1`
- SHA-256: `0b75c8d0a7234518a3172704f11e6221b478890330d520e1fce6dcb7ac86dc55`
- Summary: Gives Archive's persistent navigation the proportions of a compact mobile dock while retaining its expanding two-sided hierarchy.
- Main UI changes: taller glass vessel, wider resting and expanded states, larger Home control and glyphs, broader specular light, stronger refraction, and a more visible lower caustic.
- Structural changes: centralizes responsive dock geometry in shared size variables for regular, 400-pixel, 380-pixel, 360-pixel, and compact-scroll states.
- Functional changes: navigation destinations and hierarchy are unchanged; compact-on-scroll behavior remains active.
- Known issues: WebView optics do not perform true background-pixel displacement; background Health Connect sync and iOS packaging remain future work.

## 0.4.0 — Archive Canvas

- APK filename: `Archive-v0.4.0.apk`
- Local archive: `releases/v0.4.0/Archive-v0.4.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.4.0/Archive-v0.4.0.apk`
- GitHub reference: `main`, tag `v0.4.0`
- SHA-256: `297f9b3140d31cbed4f30723be97224563664ee50efe6e068d7c36a9c60fa7e1`
- Summary: Rebuilds the core Archive experience around continuous, atmospheric metric canvases while retaining the existing local-first data and module systems.
- Main UI changes: integrated hero charts, metric-tinted page atmospheres, fewer white containers, scroll-reactive top and bottom chrome, concentric geometry, stronger typography, and continuity-focused motion.
- Structural changes: introduces shared canvas hero, canvas section, scroll-state, and presentation primitives for Home, Habit, Water, Sleep, and Stats.
- Functional changes: no stored-data migration; all record, module, habit, chart, history, and editing workflows remain available.
- Known issues: Workout, Workout History, Coach, and Settings retain the prior page composition; no native cross-page transition engine, background Health Connect sync, or iOS package yet.

## 0.3.1 — Liquid-glass navigation

- APK filename: `Archive-v0.3.1.apk`
- Local archive: `releases/v0.3.1/Archive-v0.3.1.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.3.1/Archive-v0.3.1.apk`
- GitHub reference: `main`, tag `v0.3.1`
- SHA-256: `54fa6b05b4a672283fc716f76c3baf1190e31cf7355f5fb7f6b73616af6f501e`
- Summary: Focuses Archive's liquid-glass visual language on the persistent navigation layer, preserving the restrained content surfaces above it.
- Main UI changes: layered refractive rim, dynamic specular highlight, internal caustic, gliding active lens, cleaner icon contrast, deeper separation, and more fluid expansion.
- Structural changes: the navigation exposes dedicated optical and selection layers while keeping the existing page hierarchy and state model intact.
- Functional changes: touch position subtly influences lighting; navigation destinations and interaction semantics are unchanged.
- Known issues: WebView optics do not perform true background-pixel displacement; manual Health Connect sync and no iOS package remain.

## 0.3.0 — Curated stories and motion

- APK filename: `Archive-v0.3.0.apk`
- Local archive: `releases/v0.3.0/Archive-v0.3.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.3.0/Archive-v0.3.0.apk`
- GitHub reference: `main`, tag `v0.3.0`
- SHA-256: `41dd86d639344f860de04e384e0dcf94ce77ded226a0644ac0dcc947319b8864`
- Summary: Evolves Archive from a uniform module stack into a curated health and productivity story while preserving the existing module engine as an optional personalization layer.
- Main UI changes: fixed metric heroes, editorial page sections, Home For You guidance, chart-first metric pages, clearer empty states, Pinned Panels, and updated customization language.
- Structural changes: introduced reusable page-section, metric-hero, guided-highlight, and pinned-panel presentation components without changing persisted module or record formats.
- Functional changes: ten-week Stats now derives exclusively from saved records instead of placeholder values; existing add, remove, edit, and reorder behavior remains available.
- Motion changes: staggered bar growth, left-to-right line drawing with a traveling marker, animated progress and metric values, section reveals, press feedback, and reduced-motion fallbacks.
- Known issues: Workout, Workout History, Coach, and Settings still use the earlier page structure; manual Health Connect sync and no iOS package remain.

## 0.2.1 — Compact chart gradients

- APK filename: `Archive-v0.2.1.apk`
- Local archive: `releases/v0.2.1/Archive-v0.2.1.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.2.1/Archive-v0.2.1.apk`
- GitHub reference: `main`, tag `v0.2.1`
- SHA-256: `922554719e01c80b343d41cca015900d93fc432672f43bc1aaa92f493621b559`
- Summary: Restores the soft white-to-tone gradient as a distinctive Archive detail on compact charts without weakening dense-data readability.
- Main UI changes: Daily Value and Previous 10 Weeks bars once again transition from a soft white-tinted base into their semantic metric tone; configurable compact module bars retain the same visual language.
- Structural changes: none.
- Functional changes: none.
- Known issues: manual Health Connect sync, no iOS package, and further screen-specific refinement remains planned.

## 0.2.0 — Archive Design System 2.0

- APK filename: `Archive-v0.2.0.apk`
- Local archive: `releases/v0.2.0/Archive-v0.2.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.2.0/Archive-v0.2.0.apk`
- GitHub reference: `main`, tag `v0.2.0`
- SHA-256: `2c7e61fbcf56bc88bd63fd692d67127e51d763e5e7310da07aec3043783e5da4`
- Summary: A premium visual release inspired by current first-party mobile health interfaces while retaining Archive's monochrome, personal, and minimal identity.
- Main UI changes: new Today hero, sleep summary, Settings introduction, editorial top bars, calmer layered panels, solid chart tones, refined action controls, and improved narrow-screen navigation.
- Structural changes: centralized the new visual system in shared surface, typography, control, metric, and navigation rules while preserving the existing data model.
- Functional changes: direct Home record/review action and a corrected shortest-night calculation; established workflows and persistence remain unchanged.
- Known issues: manual Health Connect sync, no iOS package, and further screen-specific refinement remains planned.

## 0.1.0 — Baseline

- APK filename: `Archive-v0.1.0.apk`
- Local archive: `releases/v0.1.0/Archive-v0.1.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.1.0/Archive-v0.1.0.apk`
- GitHub reference: tag `v0.1.0`
- SHA-256: `de4be0edce54e351430e7b19cb82709e225923fda1c1593e090e36892c855130`
- Summary: Archive's first formal version, preserving the application immediately before the premium visual-system update.
- Main UI changes: none; this is the visual and functional baseline.
- Structural changes: introduced semantic version metadata, immutable release folders, checksums, and release documentation.
- Functional state: habits, water, sleep, modules, workouts, history, AI coach, backups, and manual Health Connect sync are operational.
- Known issues: manual-only Health Connect sync, no iOS package, and visual refinement still planned.

See [`CHANGELOG.md`](CHANGELOG.md) for the user-facing history and [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md) for the release workflow.
