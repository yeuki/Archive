# Archive release index

Release APKs are immutable. If a packaged build changes, Archive receives a new semantic version rather than replacing an older APK.

| Version | Release date | APK | Summary | Source reference |
| --- | --- | --- | --- | --- |
| 0.1.0 | 2026-07-13 | `Archive-v0.1.0.apk` | Formal baseline of the current productivity, health, workout, AI coach, and Health Connect experience. | `main`, tag `v0.1.0` |

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
