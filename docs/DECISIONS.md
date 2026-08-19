# Archive decision record

This is a compact record of accepted and rejected product/technical directions. Add a new entry when a change reverses or materially qualifies one of these decisions; do not silently rewrite the old rationale.

## D-001 — Preserve the separate-page navigation hierarchy

- **Status:** Accepted
- **Decision:** Keep centered Home, four Productivity destinations, and four Health destinations with the expanding liquid-glass bottom navigation.
- **Rationale:** Dedicated pages keep each task legible and avoid an overwhelming mixed-metric dashboard.
- **Consequence:** The four-destination page-merging model explored in v0.9.0 is rejected and must not return as an adjacent UI cleanup.

## D-002 — Limit Health Connect reads to launch and pull-to-refresh

- **Status:** Accepted
- **Decision:** The two user-facing synchronization triggers are launch initialization and a completed pull-to-refresh gesture.
- **Rationale:** This produces fresh data at predictable moments without repeated navigation syncs, periodic polling, or visible mid-page churn.
- **Consequence:** Permission/settings actions remain, but redundant sync buttons and background/resume/navigation triggers are not part of the current product.

## D-003 — Treat watch sleep as authoritative and attribute it to the previous day

- **Status:** Accepted
- **Decision:** Synced watch sleep overrides conflicting manual sleep. A session is assigned to the calendar day before its wake date regardless of clock time.
- **Rationale:** The user wants the record to describe the day associated with going to bed, including atypical AM sleep schedules.
- **Consequence:** Attribution cannot use a simple AM/PM cutoff, and migrations/tests must preserve existing precedence.

## D-004 — Remain local-first with portable JSON backup

- **Status:** Accepted
- **Decision:** Core records persist locally and remain exportable/importable without an Archive account or backend.
- **Rationale:** Archive is currently a private personal app, and local ownership minimizes operational complexity and unwanted data exposure.
- **Consequence:** Cloud sync, authentication, and public multi-user readiness are future product decisions, not incidental dependencies.

## D-005 — Keep releases immutable and signed consistently

- **Status:** Accepted
- **Decision:** Every accepted significant update receives a semantic version, preserved APK/checksum, Git history/tag, local release folder, and Drive release folder. Existing release artifacts are never overwritten.
- **Rationale:** Older installable versions must remain recoverable, and Android in-place updates require a stable package/signing identity.
- **Consequence:** Release publication happens only from clean pushed `main` through the guarded release process.

## D-006 — Never generate simulated personal history

- **Status:** Accepted
- **Decision:** New installs may include structure such as exercise definitions, but no fabricated daily, workout, sleep, or watch records.
- **Rationale:** Fake records undermine trust and can contaminate analytics.
- **Consequence:** Empty states must teach through copy and structure rather than plausible sample data.

## D-007 — Use focused Workout Mode for live logging

- **Status:** Accepted
- **Decision:** Active workouts present one exercise/set at a time with touch-oriented selectors, immediate autosave, rest progression, resume, and a final summary.
- **Rationale:** The earlier full editable set table was too dense and required excessive typing during training.
- **Consequence:** Full review and correction remain available, but the spreadsheet-like table must not become the primary live-workout surface.

## D-008 — Preserve Archive Canvas and semantic pastel colors

- **Status:** Accepted
- **Decision:** Maintain the white editorial canvas, restrained depth, monochrome typography, liquid-glass navigation, and fixed Habit/Sleep/Water/Move colors.
- **Rationale:** This combination is the app's recognizable identity and balances calmness with intuitive metric grouping.
- **Consequence:** Apple is a design-quality reference, not a request to clone proprietary visuals or replace Archive's color identity.

## D-009 — Retain modular metric-page personalization

- **Status:** Accepted
- **Decision:** Modules remain addable, configurable, removable, and reorderable on their dedicated pages.
- **Rationale:** Personal relevance differs by metric and over time; a fixed dashboard cannot serve every use equally well.
- **Consequence:** New presentation concepts must preserve equivalent personalization unless an approved specification explicitly replaces it.

## D-010 — Stage major work under Unreleased and version after acceptance

- **Status:** Accepted
- **Decision:** Major work begins from a written, approved direction on a focused branch and remains under `[Unreleased]` until accepted. The semantic version is finalized before release preparation, unless the user explicitly designates it earlier.
- **Rationale:** Experiments should not consume release numbers or generate immutable APKs before their direction is accepted.
- **Consequence:** Documentation/tooling-only work needs no app version or APK when packaged behavior is unchanged.

## D-011 — Prefer smooth, bounded motion over maximum visual complexity

- **Status:** Accepted
- **Decision:** Animate purposefully with transform/opacity, stable rendering, bounded effects, and reduced-motion support.
- **Rationale:** Perceived polish depends more on continuity and response than on expensive refraction, blur, or repeated entrance effects.
- **Consequence:** Performance regressions are design regressions even when the static frame looks more elaborate.

## D-012 — Permit partial daily records and focused habit completion

- **Status:** Accepted
- **Decision:** Allow habits, water, and sleep to be persisted independently. Today's habits use a focused hold-to-complete deck on the existing Habit page, with immediate save, ordered or direct selection, review, and exact undo.
- **Rationale:** Habits are completed throughout the day, so requiring the user to submit hydration and sleep at the same time creates friction and can turn missing data into misleading zeroes.
- **Consequence:** Every daily metric consumer must respect explicit field-presence metadata. The combined daily sheet remains available for full entry and historical editing, while habit completion no longer depends on it.

## D-013 — Preserve true capsule geometry for bottom navigation

- **Status:** Accepted
- **Decision:** The liquid-glass navigation vessel uses real collapsed and expanded widths with fully circular end caps. Keep the centered Home control and existing expansion behavior, but do not non-uniformly scale one wide shell when that distorts its outer silhouette.
- **Rationale:** The accepted pre-v0.12 dock and curated navigation references read as a calm floating capsule; horizontally compressing the wide raster made its ends elliptical and could appear scalloped or cradled.
- **Consequence:** Navigation motion may animate the fixed floating vessel's width and position because preserving the recognized silhouette takes precedence over the later fixed-raster optimization. Icon and selection motion remain compositor-based.

## D-014 — Keep imported workouts source-attributed and separate from Archive logs

- **Status:** Accepted
- **Decision:** Import completed exercise sessions through stable Health Connect as read-only external workouts, preserve every reliably supplied field, and present them alongside Archive workouts without copying them into the manual workout store.
- **Rationale:** Garmin and other providers can supply useful run and activity records, but Health Connect does not guarantee Archive's routine/exercise/set schema. Honest source attribution and nullable fields preserve trust while allowing the real provider contract to be measured.
- **Consequence:** Imported sessions may mark a Workout History day as active, but cannot complete a scheduled Archive routine by fuzzy matching, affect Workout Mode, or fabricate weights, sets, routes, or exercises. Direct Garmin and experimental Health Connect APIs remain separate future decisions.
