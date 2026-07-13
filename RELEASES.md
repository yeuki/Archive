# Archive release index

Release APKs are immutable. If a packaged build changes, Archive receives a new semantic version rather than replacing an older APK.

| Version | Release date | APK | Summary | Source reference |
| --- | --- | --- | --- | --- |
| 0.2.0 | 2026-07-13 | `Archive-v0.2.0.apk` | Archive Design System 2.0 with premium Home, Sleep, Settings, chart, surface, and navigation refinements. | `main`, tag `v0.2.0` |
| 0.1.0 | 2026-07-13 | `Archive-v0.1.0.apk` | Formal baseline of the current productivity, health, workout, AI coach, and Health Connect experience. | `main`, tag `v0.1.0` |

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
