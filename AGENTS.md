# Archive repository instructions

These instructions apply to the entire repository. Archive is a local-first personal productivity, health, and workout application built with React, Vite, Capacitor, and native Android integrations.

## Authority and required context

Use this order when sources disagree:

1. The user's current explicit request and any specification or screenshots approved for that request.
2. Durable product, design, architecture, and decision documents in `docs/` when present.
3. Tests and the current implementation.
4. `CHANGELOG.md` and `RELEASES.md` as historical context, not as the current product specification.

If a conflict would materially change navigation, data, established behavior, or release output, surface it instead of guessing. A current explicit user request may intentionally reverse an older decision; document the reversal when implementing it.

Before working:

- Read `VERSION` and inspect the current Git status and relevant implementation.
- For substantial UI or navigation work, read `docs/PRODUCT.md`, `docs/DESIGN_SYSTEM.md`, and `docs/DECISIONS.md` when those files exist.
- For persistence, backups, Health Connect, workout state, or native Android work, read `docs/ARCHITECTURE.md` when it exists.
- Before any release, read `docs/RELEASE_PROCESS.md`, `MULTI_COMPUTER_SETUP.md`, `CHANGELOG.md`, and `RELEASES.md`.

## Product and navigation invariants

- Preserve Archive as a calm, personal, information-rich application without making screens crowded or clinical.
- Preserve the current separate-page hierarchy unless the user explicitly approves a change:
  - Center: Home.
  - Productivity: Workout, Workout History, Habit, and AI Coach.
  - Health: Water, Sleep, Stats, and Settings.
- Do not restore the rejected v0.9.0 four-destination model, merge pages, shrink the hierarchy, or restructure navigation as an adjacent change.
- Preserve the centered Home control and liquid-glass expanding bottom navigation unless a task explicitly targets them.
- Preserve module addition, removal, editing, configuration, and reordering unless a task explicitly replaces that interaction model.
- Do not create simulated daily records, workout history, watch data, or other personal history for new users.

## Design invariants

- Preserve Archive Canvas: white space, monochrome typography, restrained corners, editorial hierarchy, soft depth, and progressive disclosure.
- Apple interfaces are inspiration for clarity, material, hierarchy, and motion; Archive must retain its own identity rather than becoming an imitation.
- Preserve semantic metric colors:
  - Habit: `#FFC5D3`.
  - Sleep: `#C9A0DC`.
  - Water: `#A2BFFE`.
  - Move: `#E5F9E4`.
- Keep Archive's gradient treatment on simple charts with a small number of values, roughly fewer than ten columns. Dense grids and high-volume views should use solid semantic tones.
- Motion should be smooth, purposeful, and interruptible. Prefer transform and opacity, avoid paint-heavy animated blur, and preserve reduced-motion behavior.
- Do not increase information density, add decorative controls, or expose advanced configuration without a clear user benefit.
- Keep touch targets comfortable, prevent horizontal overflow, and verify important UI at 360 x 800 and 412 x 915.

## Data and behavioral invariants

- Preserve existing user data and normalize older formats. Never make a destructive migration without an explicit, tested recovery path.
- Browser storage remains local-first, and JSON import/export must remain a complete portable backup.
- Health Connect reads have exactly two user-facing triggers: launch initialization and a completed pull-to-refresh gesture. Do not add periodic, navigation-triggered, background, or redundant manual-button sync paths.
- Preserve Health Connect permission and settings flows required for reliable synchronization.
- Synced watch sleep is authoritative over a conflicting manual entry. Preserve the established previous-day attribution policy and do not infer attribution solely from clock time.
- Active workouts must autosave and resume without progress loss. A workout enters history only after **Finish workout** is completed.
- Preserve multiple workouts on one date, full set details, routine snapshots, and historical compatibility.
- Active Workout Mode remains a focused set-by-set flow. Do not reintroduce the full editable workout spreadsheet into the live session.
- API keys remain local and must never be hard-coded, logged, exported unintentionally, or committed.

## Working method

- Inspect before editing. Trace the existing state, persistence, UI, and test paths affected by the request.
- If the user requests analysis, diagnosis, a proposal, or says not to implement, do not modify the repository.
- For a substantial UI, navigation, architecture, or data change, provide a plan and wait for approval unless the user has already explicitly asked to implement that defined change.
- Keep the requested scope narrow. Do not redesign adjacent pages or perform opportunistic cleanup that changes unrelated behavior.
- Do not add a production dependency, external service, backend, or paid product without explicit approval.
- Preserve unrelated user changes in a dirty worktree. Never discard or overwrite them to simplify the task.
- Use focused patches. When touching oversized files, extract a feature only when the requested work creates a clear boundary; do not perform a whole-app rewrite.
- Prefer `rg` for repository search and the existing scripts for deterministic checks.
- Parallelize independent inspection or validation when useful, but do not allow concurrent work to edit the same files or overlapping behavior.

## Verification

Run checks in proportion to the change:

- Documentation-only changes: inspect the final diff and run `git diff --check`; no APK or app-version change is required.
- General React, state, or CSS changes: run `npm run build` and the relevant regression scripts.
- Health or persistence changes: run `npm run test:health`, `npm run test:auto-health`, and `npm run test:sleep` as applicable.
- Workout changes: run `npm run test:workout`.
- Navigation, animation, gesture, or visual-motion changes: run `npm run test:motion` and perform mobile browser interaction checks.
- Meaningful Android or packaged-app changes: run the web checks, sync Capacitor, and run Android unit tests, lint, and the appropriate APK assembly.
- UI changes must be checked for runtime errors, touch behavior, reduced motion, and horizontal overflow at the established phone dimensions.

Static string checks are safeguards, not substitutes for behavioral and visual verification.

## Git, security, and releases

- GitHub is the source of truth for editable code. Google Drive is for immutable versioned APKs, checksums, and release notes, not source synchronization.
- Do not commit API keys, personal backup JSON, browser profiles, logs, keystores, signing passwords, `local.properties`, `node_modules`, `dist`, or Gradle build output.
- Preserve package `com.kyle.archive` and the established signing identity. Never replace, regenerate, expose, or relocate signing material without explicit approval.
- Documentation, tests, and workflow-only changes do not require an Archive version bump or APK unless they alter packaged behavior.
- Keep experimental work under `[Unreleased]` unless the user has explicitly designated a target release. Do not finalize or publish a version until the change is accepted or the user explicitly requests it.
- Major UI, navigation, structural, or behavioral updates require a new semantic version and separately preserved APK. Never overwrite an existing release folder or APK.
- Publish a release only with explicit authorization, from a clean `main` that matches `origin/main`, through the established release process.
- When installing an update on a connected phone, use an in-place update that preserves app data. Never uninstall, clear storage, or change signing identity as a workaround without explicit approval.

## Code review rules

When reviewing a change, prioritize:

- Data loss, failed migrations, or incomplete backup coverage.
- Navigation or hierarchy drift.
- Additional Health Connect sync triggers or altered sleep authority.
- Workout resume, completion, or history regressions.
- Reduced-motion, accessibility, touch-target, or overflow regressions.
- Expensive animation patterns, unnecessary rerenders, or unstable gesture behavior.
- Secrets, personal data, signing material, or generated artifacts entering Git.
- Scope expansion and visual inconsistency with Archive Canvas.

## Definition of done

A task is complete only when:

- The requested outcome and approved acceptance criteria are satisfied.
- Unrelated product behavior and user data are preserved.
- Relevant automated checks and builds pass.
- Risky UI changes are verified interactively at phone dimensions.
- Behavior changes update the relevant documentation and `[Unreleased]` notes.
- The final handoff states what changed, what was verified, known limitations, and any remaining manual check.
- If a release was requested, the GitHub source/tag, local archive, Drive archive, checksum, and phone installation are verified as applicable.
