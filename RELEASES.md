# Archive release index

Release APKs are immutable. If a packaged build changes, Archive receives a new semantic version rather than replacing an older APK.

| Version | Release date | APK | Summary | Source reference |
| --- | --- | --- | --- | --- |
| 0.13.0 | 2026-08-13 | `Archive-v0.13.0.apk` | Focused hold-to-complete habits, independently recorded daily metrics, and persistence-confirmed glass feedback in the restored capsule dock. | `main`, tag `v0.13.0` |
| 0.12.0 | 2026-08-09 | `Archive-v0.12.0.apk` | Unified, performance-conscious motion across navigation, pages, disclosures, gestures, charts, and Workout Mode. | `main`, tag `v0.12.0` |
| 0.11.0 | 2026-08-09 | `Archive-v0.11.0.apk` | Focused, persistent Workout Mode with touch value wheels, automatic rest, safe resume, and concise review. | `main`, tag `v0.11.0` |
| 0.10.1 | 2026-08-07 | `Archive-v0.10.1.apk` | Centers the standalone Archive A in a cleaner grey-to-pastel launch animation without changing navigation. | `main`, tag `v0.10.1` |
| 0.10.0 | 2026-08-07 | `Archive-v0.10.0.apk` | Restores the v0.8 hierarchy and introduces launch-gated plus pull-to-refresh Health Connect reconciliation. | `main`, tag `v0.10.0` |
| 0.9.0 | 2026-08-07 | `Archive-v0.9.0.apk` | Four focused destinations, a slimmer dock, and one battery-conscious Health Connect refresh behind a branded startup screen. | `main`, tag `v0.9.0` |
| 0.8.0 | 2026-07-15 | `Archive-v0.8.0.apk` | Archive Canvas completed across Workout, History, Coach, and Settings with shared hierarchy, material, and motion. | `main`, tag `v0.8.0` |
| 0.7.1 | 2026-07-15 | `Archive-v0.7.1.apk` | Samsung-safe adaptive icon sizing with a dedicated centered foreground safe zone. | `main`, tag `v0.7.1` |
| 0.7.0 | 2026-07-15 | `Archive-v0.7.0.apk` | First custom Archive identity with a flowing pastel A across adaptive, round, and legacy Android launchers. | `main`, tag `v0.7.0` |
| 0.6.0 | 2026-07-14 | `Archive-v0.6.0.apk` | Lifecycle-aware automatic Health Connect refresh with durable hourly background snapshots. | `main`, tag `v0.6.0` |
| 0.5.0 | 2026-07-14 | `Archive-v0.5.0.apk` | Canonical health archive with provenance, authoritative reconciliation, integrity diagnostics, and stable watch-first sleep. | `main`, tag `v0.5.0` |
| 0.4.3 | 2026-07-14 | `Archive-v0.4.3.apk` | Previous-day sleep attribution with authoritative watch-sync precedence. | `main`, tag `v0.4.3` |
| 0.4.2 | 2026-07-14 | `Archive-v0.4.2.apk` | Watch-first sleep entry with manual fallback and start-night attribution. | `main`, tag `v0.4.2` |
| 0.4.1 | 2026-07-14 | `Archive-v0.4.1.apk` | Roomier liquid-glass dock with stronger optics, larger controls, and preserved scroll compaction. | `main`, tag `v0.4.1` |
| 0.4.0 | 2026-07-14 | `Archive-v0.4.0.apk` | Archive Canvas with integrated metric stories, reduced card chrome, and scroll-reactive continuity. | `main`, tag `v0.4.0` |
| 0.3.1 | 2026-07-14 | `Archive-v0.3.1.apk` | Layered liquid-glass bottom navigation with responsive optics and refined interaction. | `main`, tag `v0.3.1` |
| 0.3.0 | 2026-07-13 | `Archive-v0.3.0.apk` | Curated metric stories, pinned-panel personalization, and a purposeful motion system. | `main`, tag `v0.3.0` |
| 0.2.1 | 2026-07-13 | `Archive-v0.2.1.apk` | Restores Archive's signature gradient on compact charts while preserving solid dense-data views. | `main`, tag `v0.2.1` |
| 0.2.0 | 2026-07-13 | `Archive-v0.2.0.apk` | Archive Design System 2.0 with premium Home, Sleep, Settings, chart, surface, and navigation refinements. | `main`, tag `v0.2.0` |
| 0.1.0 | 2026-07-13 | `Archive-v0.1.0.apk` | Formal baseline of the current productivity, health, workout, AI coach, and Health Connect experience. | `main`, tag `v0.1.0` |

## 0.13.0 - Habit Hold Deck and partial-day records

- APK filename: `Archive-v0.13.0.apk`
- Local archive: `releases/v0.13.0/Archive-v0.13.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.13.0/Archive-v0.13.0.apk`
- GitHub reference: `main`, tag `v0.13.0`
- SHA-256: `PENDING-FINAL-BUILD`
- Summary: Makes habit logging an effortless throughout-the-day interaction while preserving Archive's existing page hierarchy, local-first data model, and full-report workflow.
- Main UI changes: adds a calm one-habit-at-a-time Focus Deck, a deliberate hold-to-complete control, ordered progress, an **All habits** chooser, direct correction and exact undo, layered Archive glass, persistence-confirmed semantic bloom and liquid ripples, and a restored true-capsule bottom dock with circular end caps.
- Structural changes: introduces a dedicated Habit Hold Deck component, explicit daily-field presence metadata, centralized daily-record normalization helpers, and focused regression coverage integrated into `npm run verify`.
- Functional changes: habit completion saves immediately without requiring water or sleep; partial daily records no longer treat unrecorded metrics as zero; legacy records and backups normalize compatibly; watch-created sleep records mark only sleep as present; duplicate, cancelled, and rejected hold gestures cannot report false success.
- Preserved behavior: existing Habit analytics and modules, historical editing, combined daily sheet, habit configuration and ordering, Health Connect policy, Workout Mode, navigation destinations, centered Home control, and all other Archive pages remain available.
- Accessibility: includes keyboard and assistive activation, descriptive status, large touch targets, non-color completion feedback, reduced-motion and reduced-transparency fallbacks, and phone-width overflow protection.
- Validation: habit, motion, health, automatic Health Connect, sleep, Workout Mode, workspace, and production-build suites; mobile Chromium interaction checks at 360 x 800 and 412 x 915; Android unit tests, lint, certificate validation, and release assembly through the immutable release pipeline.
- Known issues: hold duration, haptic feel, card proportions, and success wording may benefit from later physical-use tuning; vibration remains best effort when Android or WebView settings suppress it; Health Connect remains Android-only; and supersets/circuits remain linear in Workout Mode.

## 0.12.0 - Unified motion system

- APK filename: `Archive-v0.12.0.apk`
- Local archive: `releases/v0.12.0/Archive-v0.12.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.12.0/Archive-v0.12.0.apk`
- GitHub reference: `main`, tag `v0.12.0`
- SHA-256: `bec9b83d69f19838cb994b3751464ae36a664b2f8b0a65fa4c823e1a69186c84`
- Summary: Gives every meaningful movement one coherent, calm rhythm while removing the rendering patterns that made scrolling, navigation expansion, sheets, menus, and Workout Mode controls feel choppy.
- Main UI changes: smoother page and full-screen-flow transitions; a compositor-driven liquid-glass dock with fluid expansion and selection movement; continuous depth-aware workout wheels; reversible menus and settings disclosures; animated habit and module reordering; responsive sheet gestures; and consistent press, hover, chart, and overlay motion.
- Structural changes: introduces a shared JavaScript motion coordinator, reusable FLIP layout animation, stable mounted disclosure states, animation-frame gesture updates, unified CSS motion tokens, and an automated motion-system regression suite included in the release pipeline.
- Functional changes: no application hierarchy or data behavior was changed; the same navigation destinations, workout lifecycle, Health Connect launch and pull-to-refresh policy, records, backups, and module controls remain available with smoother feedback.
- Performance work: keeps the dock's blurred glass raster at a fixed size, shifts frequent wheel and drag updates outside React rendering, favors transform and opacity animation, removes expensive entrance blur, and avoids rebuilding scroll-wheel rows while momentum is active.
- Accessibility: system reduced-motion preferences disable or greatly shorten nonessential movement; closed mounted controls are inert and hidden from assistive technology; existing touch targets and keyboard behavior are preserved.
- Validation: motion regression suite; existing health, automatic Health Connect, sleep, and Workout Mode suites; production Vite build; mobile Chromium checks at 412 x 915 with zero horizontal overflow; continuous dock, wheel, disclosure, and sheet-drag frame sampling; Android unit tests, lint, and release assembly through the immutable release pipeline.
- Known issues: Archive cannot access Apple's private native refraction shaders from a Capacitor WebView; performance can still vary with WebView version, thermal state, and battery-saving settings; supersets/circuits remain linear; and Health Connect remains Android-only.

## 0.11.0 - Focused Workout Mode

- APK filename: `Archive-v0.11.0.apk`
- Local archive: `releases/v0.11.0/Archive-v0.11.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.11.0/Archive-v0.11.0.apk`
- GitHub reference: `main`, tag `v0.11.0`
- SHA-256: `18781e9361df31f364aadee525c2e00edcbfa323bab1d7636ff102ad99086782`
- Summary: Replaces the overwhelming live workout table with a calm, full-screen set, rest, and review flow that saves every meaningful action and resumes exactly where the user stopped.
- Main UI changes: one current exercise and set at a time; vertical touch wheels for weight, reps, and duration; adaptive bodyweight controls; automatic rest timer; compact progress outline; optional effort; progressive-disclosure exception actions; and a concise completion summary.
- Structural changes: introduces a normalized active-session schema, immutable routine/exercise snapshots, absolute rest deadlines, pause accounting, idempotent history conversion, top-layer portal rendering, future superset metadata, and a dedicated Workout Mode component and regression suite.
- Functional changes: previous working sets become sensible defaults; warm-ups, substitutions, failed/skipped outcomes, per-exercise rest, set corrections, early ending, zero-exercise routines, leave/resume, reload recovery, and one-active-session protection are supported; working analytics exclude warm-up, skipped, and pending sets.
- Preserved behavior: the v0.10.1 navigation and page hierarchy, Archive Canvas Workout page, routine editor, exercise library, weekly schedule, dedicated Workout History page, missed-workout backfill table, local backups, Health Connect launch/pull policy, and all existing health data handling remain intact.
- Validation: focused session-model regression suite; existing health, automatic Health Connect, and sleep policy suites; production Vite build; 412 × 915 and 360 × 800 browser interaction checks; zero horizontal overflow; Android unit tests, lint, and release assembly through the release pipeline.
- Known issues: supersets/circuits are schema-ready but remain linear in v0.11.0; haptics are best effort; weight units are not yet configurable; multi-device resume requires future backend support; and Health Connect remains Android-only.

## 0.10.1 - Centered A launch mark

- APK filename: `Archive-v0.10.1.apk`
- Local archive: `releases/v0.10.1/Archive-v0.10.1.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.10.1/Archive-v0.10.1.apk`
- GitHub reference: `main`, tag `v0.10.1`
- SHA-256: `dd0fbd82a3bd05f235a84584f9e2ba4fcc1d302fbfea06ab8fe03b2876be7219`
- Summary: Refines Archive's launch presentation to the standalone flowing A, centered precisely while retaining the existing grey-to-pastel loading behavior.
- Main UI changes: removes the Archive wordmark and visible status caption from the launch screen, places the A on a responsive square canvas, and distributes the full four-color Archive gradient across the mark.
- Structural changes: introduces a single shared SVG reveal-width constant and regression coverage for the square loader; the v0.8.0/v0.10.0 navigation component, routes, page hierarchy, layouts, and interactions are untouched.
- Functional changes: none; cold-launch Health Connect reconciliation, the bounded launch gate, pull-to-refresh, permissions, canonical data handling, and local persistence continue unchanged.
- Known issues: the proposed four-button information architecture remains a future decision; Samsung Health publication timing remains upstream of Archive; and Health Connect remains Android-only.

## 0.10.0 - v0.8 hierarchy with launch and pull health sync

- APK filename: `Archive-v0.10.0.apk`
- Local archive: `releases/v0.10.0/Archive-v0.10.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.10.0/Archive-v0.10.0.apk`
- GitHub reference: `main`, tag `v0.10.0`
- SHA-256: `a90efa632ade404ff10d68e49044a06044a34dc0d031eb54e68984c23f74dee0`
- Summary: Re-establishes v0.8.0 as Archive's UI and hierarchy baseline, then adds a polished launch gate and pull-to-refresh as the only Health Connect read paths.
- Main UI changes: the exact v0.8.0 liquid-glass expanding navigation and separate Workout, Workout History, Habit, Coach, Home, Water, Sleep, Stats, and Settings pages are restored; launch now presents a horizontal grey-to-pastel Archive lockup; and a compact material refresh indicator follows the pull gesture without blocking the interface.
- Structural changes: app initialization owns one bounded launch-sync promise; a root gesture controller owns pull-to-refresh without modifying page components; the native migration layer cancels obsolete WorkManager jobs; and no post-v0.8 section tabs, merged screens, or alternate hierarchy remain.
- Functional changes: enabled Health Connect imports perform a full 30-day canonical read once on cold launch and after a completed pull gesture; resume, visibility, interval, and background reads are absent; permissions and connection utilities remain; and the sleep Sync choice uses already-imported watch data rather than launching another read.
- Known issues: upstream Samsung Health publication delays remain outside Archive's control; browser previews cannot execute native reads; Apple Health/iOS support is future work; and v0.9.0 remains archived but is superseded for continued development.

## 0.9.0 - Focused navigation and open-time health

- APK filename: `Archive-v0.9.0.apk`
- Local archive: `releases/v0.9.0/Archive-v0.9.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.9.0/Archive-v0.9.0.apk`
- GitHub reference: `main`, tag `v0.9.0`
- SHA-256: `377fa12c168e2f6fdee9c61b66d8c5a7ea19acc252e36711f51ccf79fcad34ed`
- Summary: Consolidates Archive into four clear destinations and limits automatic Health Connect work to a single app-open refresh presented behind an intentional branded loader.
- Main UI changes: centered four-button dock for Today, Track, Train, and Progress; compact section switchers for grouped pages; Settings promoted to a utility action; and a grey-to-gradient Archive logo fill with a minimum 1.5-second presentation.
- Structural changes: the former eight primary destinations now map into three grouped section view sets, while the startup controller coordinates a bounded Health Connect promise with loader progress and transition timing.
- Functional changes: automatic imports use a recent three-day window only on cold launch; foreground-resume and 15-minute polling are removed; periodic and immediate WorkManager jobs are cancelled; the background-read permission is removed; manual sync and canonical reconciliation remain available.
- Release tooling changes: the release builder validates every required version reference, finalizes and pushes the actual APK checksum before tagging, and writes both `RELEASE_NOTES.md` and `Archive-v0.9.0-release-notes.md` beside the Drive APK.
- Known issues: Samsung Health controls when watch data reaches Health Connect; browser previews cannot verify the native bridge; progress levels, achievements, and the optional character are future work; and Apple Health/iOS packaging are not yet available.

## 0.8.0 - Canvas everywhere

- APK filename: `Archive-v0.8.0.apk`
- Local archive: `releases/v0.8.0/Archive-v0.8.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.8.0/Archive-v0.8.0.apk`
- GitHub reference: `main`, tag `v0.8.0`
- SHA-256: `42ac12272b4ef029b93f043f4922f40b59b32828661193dabe4d5b2c13443305`
- Summary: Completes the Archive Canvas redesign across every primary destination while preserving the app's established local-first workflows.
- Main UI changes: atmospheric training, history, coach, and privacy heroes; editorial section hierarchy; tactile monthly calendar; calmer conversation bubbles and composer; quick Health Connect summary; progressive settings disclosure; consistent translucent surfaces, spacing, shadows, and motion.
- Structural changes: Workout, Workout History, Coach, and Settings now compose the existing shared `CanvasHero`, `PageSection`, `GuidedHighlight`, and `PinnedModulesSection` primitives; advanced `SettingsSection` groups support accessible expansion without introducing a data migration.
- Functional changes: Coach scroll stays inside the conversation, unusually long saved responses are reviewable in a collapsed state, Health Connect keeps a prominent one-tap sync action, and all existing workout logging, missed-workout backfill, AI proposal approval, health configuration, and backup behavior remains available.
- Known issues: malformed legacy Gemini text is preserved rather than rewritten, native Health Connect behavior is unavailable in browser previews, and Apple Health/iOS packaging remain future work.

## 0.7.1 - Adaptive icon safe zone

- APK filename: `Archive-v0.7.1.apk`
- Local archive: `releases/v0.7.1/Archive-v0.7.1.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.7.1/Archive-v0.7.1.apk`
- GitHub reference: `main`, tag `v0.7.1`
- SHA-256: `6e60087076a9c6feb4ae3cf1038c027d66f30a4af481b5dbf95c97e147db8f72`
- Summary: Corrects the oversized v0.7.0 launcher rendering on Samsung One UI without changing Archive's approved mark.
- Main UI changes: the adaptive foreground is centered at 72% scale, restoring intentional charcoal breathing room while retaining the full pastel A and endpoint.
- Structural changes: the adaptive SVG and raster generator now encode the universal safe-zone treatment separately from legacy and round icon output.
- Functional changes: none; application data, navigation, Health Connect synchronization, and all existing behavior are unchanged.
- Known issues: an already pinned Samsung shortcut may cache the previous rendering until it is recreated or the launcher restarts; monochrome themed and iOS icon sets remain future work.

## 0.7.0 - Archive identity

- APK filename: `Archive-v0.7.0.apk`
- Local archive: `releases/v0.7.0/Archive-v0.7.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.7.0/Archive-v0.7.0.apk`
- GitHub reference: `main`, tag `v0.7.0`
- SHA-256: `1cf44d50e77e6f7dab7f302d9e92e74611b9049d4e9c5efe9685eb3ce481dfe9`
- Summary: Replaces the generated framework launcher artwork with Archive's first intentional visual identity.
- Main UI changes: a flowing capital A, calm two-wave crossbar, four-stage pastel metric gradient, green endpoint, and charcoal launcher field.
- Structural changes: editable SVG masters, generated 1024-pixel references, one deterministic PowerShell asset generator, and complete Android legacy, round, and adaptive density sets.
- Functional changes: Android launchers now present Archive's own mark while preserving the existing application ID, signing identity, local data, and in-place update path.
- Known issues: launchers can temporarily cache an older shortcut icon; Android monochrome themed-icon artwork and an iOS asset catalog are not yet included.

## 0.6.0 - Automatic connected health

- APK filename: `Archive-v0.6.0.apk`
- Local archive: `releases/v0.6.0/Archive-v0.6.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.6.0/Archive-v0.6.0.apk`
- GitHub reference: `main`, tag `v0.6.0`
- SHA-256: `d82898465e01c21ef8bd7ca6be2d95e89d61cda5103915d34839155ee2df9f01`
- Summary: Makes Health Connect synchronization automatic when Archive opens, remains active, or is allowed to run periodic background work.
- Main UI changes: Connected Health Settings now exposes automatic-sync control, background-access state, cadence guidance, last automatic refresh, last background capture, and a dedicated background permission action.
- Structural changes: shared native canonical reader, WorkManager scheduler, separate background permission, atomic private snapshot cache, persisted scheduler diagnostics, Capacitor lifecycle integration, and an apply-then-ack handoff protocol.
- Functional changes: launch and resume reconciliation, 15-minute active-app throttling, inexact hourly background snapshots, 3-day frequent windows, six-hour full 30-day cleanup passes, retry-safe idempotence, and foreground-only fallback when background access is unavailable.
- Known issues: Android may defer background work under Doze or manufacturer battery policies, background access requires separate user approval, upstream watch data must first reach Health Connect, and iOS/Apple Health support remains future work.

## 0.5.0 - Definitive health foundation

- APK filename: `Archive-v0.5.0.apk`
- Local archive: `releases/v0.5.0/Archive-v0.5.0.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.5.0/Archive-v0.5.0.apk`
- GitHub reference: `main`, tag `v0.5.0`
- SHA-256: `397ee06bc8ae67633c66e6e4a394e2c6c6b48cacc59d6b3091fe0fd2d356adff`
- Summary: Establishes one canonical, inspectable health archive between Health Connect and Archive's daily records.
- Main UI changes: a dedicated Health Data Integrity section reports freshness, sleep ownership, watch-first source priority, reconciliation coverage, canonical-layer completeness, provenance, and cleanup counts.
- Structural changes: versioned health schema, timezone-stable canonical records, source metadata, explicit sync windows, layer-completeness contracts, bounded vital-sample retention, and backup schema version 2.
- Functional changes: 30-day snapshots reconcile corrections and deletions, stable identities remove duplicates, paginated native reads protect sleep and workout completeness, stale synced sleep is cleared, manual fallback sleep is preserved, and real watch sleep remains authoritative.
- Known issues: sync remains user-initiated, standard history remains limited to Health Connect's recent window, HR and HRV are bounded rolling samples, and iOS/Apple Health support remains future work.

## 0.4.3 - Corrected sleep-day policy

- APK filename: `Archive-v0.4.3.apk`
- Local archive: `releases/v0.4.3/Archive-v0.4.3.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.4.3/Archive-v0.4.3.apk`
- GitHub reference: `main`, tag `v0.4.3`
- SHA-256: `4ab7cbc0122ec6b84e0bd82e8873ffd66a054a3c2eff199c0d8e534c3985d70e`
- Summary: Assigns every watch sleep session to the day before wake-up and makes synced watch sleep authoritative over manual fallback data.
- Main UI changes: clearer previous-day wording and a disabled Manual option whenever a watch-backed value already exists.
- Structural changes: canonical sleep normalization now derives the record date from the local wake-up date minus one calendar day.
- Functional changes: after-midnight sleep is attributed correctly, superseded start-date and wake-date imports migrate safely, and watch values replace manual conflicts.
- Known issues: synchronization remains user-initiated, Android Health Connect is the only live watch bridge, and iOS health integration remains future work.

## 0.4.2 - Watch-first sleep records

- APK filename: `Archive-v0.4.2.apk`
- Local archive: `releases/v0.4.2/Archive-v0.4.2.apk`
- Google Drive archive: `Archive Productivity Tracker/Releases/v0.4.2/Archive-v0.4.2.apk`
- GitHub reference: `main`, tag `v0.4.2`
- SHA-256: `b74c0d31277548fe568de776ed9b3d132e27deceb3afddd1e5d07ce2fba479a7`
- Summary: Makes Health Connect the primary sleep source in daily recording while retaining a deliberate manual fallback.
- Main UI changes: Sync and Manual segmented control, synced duration and sleep-window summary, clear missing-session guidance, and a compact manual-hours fallback.
- Structural changes: daily records can retain sleep source, sync timestamp, and contributing session identifiers; focused policy checks cover the migration path.
- Functional changes: overnight sleep is attributed to the date it started, synced values can refresh safely, legacy wake-date imports are moved when confidently matched, and manual values are protected from later syncs.
- Known issues: synchronization remains user-initiated, Android Health Connect is the only live watch bridge, and iOS health integration remains future work.

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
