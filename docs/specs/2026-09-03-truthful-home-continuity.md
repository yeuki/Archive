# Major change: Truthful Home continuity

## Control

- **Status:** Candidate
- **Owner:** Kyle
- **Created:** 2026-09-03
- **Baseline:** unreleased `feature/performance-motion` / `b7a8222`
- **Working branch:** `feature/truthful-home-continuity`
- **Target release:** Unreleased
- **Related issue / task:** Retention and continuity exploration approved for implementation on 2026-09-03.

## Problem and user outcome

Home currently asks for a broad daily record, routes contextual prompts through a general choice sheet, describes expected-later sleep as missing, and displays analytical claims that can look personal without enough evidence. The user should instead see one truthful next action, reach it directly, record water independently, resume interrupted work, and receive only evidence-backed summaries.

## Approved direction

Use deterministic local rules to choose one dominant Home continuation. Prefer an active workout, its summary, today's scheduled workout, the next habit, hydration, and genuine manual fallbacks in that order. Add independent hydration capture with exact undo, preserve daily-sheet drafts, show factual launch/return context and evidence-gated weekly reflection, and replace synthetic analytics with honest coverage states.

## Preserve

- Existing page hierarchy, centered Home control, and liquid-glass navigation.
- Archive Canvas, semantic colors, progressive disclosure, and reduced-motion behavior.
- Local-first persistence and complete JSON backup/import.
- Launch and completed pull-to-refresh as the only Health Connect read triggers.
- Watch-first previous-day sleep attribution and exact active-workout resume.
- Existing module configuration and full daily sheet for deliberate multi-field editing.

## Non-goals

- Notifications, widgets, AI recommendations, cloud services, or background reads.
- Release, merge, version assignment, APK publication, or phone installation.
- Navigation restructuring or redesign of unrelated pages.

## Screens and states

| Screen/state | User sees | User can do | Data/source |
| --- | --- | --- | --- |
| Home / active workout | Exact saved progress | Resume Workout Mode | Persisted active session |
| Home / scheduled workout | Today's routine | Start it directly | Local schedule |
| Home / pending habit | Next incomplete habit | Open focused Habit flow | Today's habit record |
| Home / hydration | Current total and remembered increment | Add water or undo | Today's water field |
| Home / caught up | Calm completion copy | Continue browsing | Local derived state |
| Home / insufficient history | Coverage requirement | Record normally | Real recorded fields only |
| Daily sheet / interruption | Restored unsaved values | Continue or explicitly discard | Local draft state |
| Return after absence | Recovered/fresh context without backlog | Take one current action | Local timestamps and reconciled data |

## Interaction and motion

Home actions use existing button and page-transition language. Quick hydration updates immediately and exposes one exact undo action. No new continuous animation is introduced. Reduced motion retains immediate state changes and feedback.

## Data, persistence, and compatibility

- Persisted fields added/changed: normalized `continuity` preferences, last-open state, dismissed review key, and daily drafts.
- Normalization or migration: absent or malformed continuity state receives safe defaults; old records remain untouched.
- Backup/import impact: continuity state is included through the existing normalized full-state backup.
- Offline/restart behavior: all features remain local and drafts survive relaunch.
- Health/native/API impact: no new read trigger or native dependency.
- Security/privacy impact: no new external transmission; health details stay inside Archive.

## Accessibility

Quick controls use named buttons and existing focus treatment, retain 44px targets, do not rely on color, and expose completion/undo text through live status feedback.

## Acceptance criteria

- [x] Home displays one evidence-backed dominant continuation after launch.
- [x] An active workout resumes at the exact saved set from Home.
- [x] Contextual actions avoid the unrelated general choice sheet.
- [x] Water is recorded in no more than two intentional taps and the increment is remembered.
- [x] Saving water never records or alters habits or sleep, and exact undo is available.
- [x] Expected-later sleep is not described as overdue.
- [x] No chart, correlation, score, or insight fabricates personal history.
- [x] Returning after a gap does not create a failure backlog.
- [x] Weekly insight requires defined coverage and reports it.
- [x] Daily drafts survive interruption and remain backup-compatible.
- [x] No new Health Connect read occurs beyond launch and completed pull-to-refresh.
- [x] No horizontal overflow occurs at 360 x 800 or 412 x 915.
- [x] Relevant deterministic checks, build, and interactive checks pass.
- [x] Durable documentation and `[Unreleased]` notes are updated.

## Verification plan

| Risk | Check | Expected evidence |
| --- | --- | --- |
| Priority/routing drift | Deterministic continuity tests | Each state selects one expected action |
| Partial-record corruption | Water mutation/undo tests | Only `recordedFields.water` changes |
| Synthetic analytics | Source scan and UI test | No fixed personal correlations/fallback series |
| Persistence compatibility | Normalization/backup tests | Defaults and drafts round-trip |
| Navigation/workout regression | Existing workout and motion suites | Exact resume and transitions pass |
| Responsive UI | Browser checks at both required sizes | No overflow or runtime errors |

## References

- `AGENTS.md`
- `docs/PRODUCT.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `Archive-Retention-Exploration-Handoff.md` (temporary proposal source)

## Open questions

- Native notification and widget work remains deliberately separate.

## Decision log

| Date | Decision / revision | Approved by |
| --- | --- | --- |
| 2026-09-03 | Implement the reviewed retention proposal while preserving Archive's design characteristics. | Kyle |
| 2026-09-03 | Candidate completed on top of the performance/Garmin branch; notifications and widgets remain separate future work. | Codex |
