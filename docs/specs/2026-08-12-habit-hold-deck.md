# Major change: Habit Hold Deck

## Control

- **Status:** Accepted
- **Owner:** Kyle / Codex
- **Created:** 2026-08-12
- **Baseline:** v0.12.0 / `f8f8002`
- **Working branch:** `feature/habit-hold-deck`
- **Target release:** v0.13.0
- **Related issue / task:** Habit-completion redesign approved in the current Codex task

## Problem and user outcome

Habit completion is currently hidden inside the combined daily-report sheet and feels like a generic checkbox grid. The user should be able to visit Habit throughout the day, focus on one habit, hold a large tactile control, and have that completion saved immediately without entering water or sleep.

## Approved direction

Add an Archive-styled Focus Deck near the top of the existing Habit page. It presents one habit at a time, uses a short hold-to-complete ring, advances through pending habits, exposes an All habits chooser for out-of-order completion, and provides direct undo. Use Archive Canvas typography, surfaces, Habit pink, restrained motion, and the unchanged liquid-glass navigation.

Daily records gain explicit field-presence metadata so habits, water, and sleep can be persisted independently. Legacy records continue to mean that all of their existing fields were recorded.

The approved visual revision restores the navigation vessel to the accepted real-width capsule geometry with circular end caps, while retaining the v0.12 icon and selection continuity. It also deepens the Hold card material and adds a brief liquid-glass ripple and semantic bloom only after the canonical completion record confirms success.

## Preserve

- Existing Habit navigation, page destination, analytics, modules, tracking preferences, history, and habit ordering.
- Existing habit names, binary completion semantics, ignored-habit history, and JSON backup/import behavior.
- Existing Home, Water, Sleep, Stats, Workout, Coach, Settings, and bottom-navigation hierarchy.
- Centered Home, existing destinations, icon placement, selected states, safe-area position, and liquid-glass expansion behavior.
- Local-first and offline operation with no new dependency or native service.

## Non-goals

- Habit creation, scheduling, streak rules, analytics design, and historical editing redesign.
- Per-habit icons, points, badges, confetti, or punitive failure states.
- Adjacent navigation or page restructuring.
- Release version assignment, APK publication, installation, or merging before user acceptance.

## Screens and states

| Screen/state | User sees | User can do | Data/source |
| --- | --- | --- | --- |
| Habit / pending | Daily count, focused habit, hold ring, next habit | Hold to complete, select another habit | Today's tracked habits and partial daily record |
| Habit / pressing | Compressed control and filling ring | Continue holding or release/cancel | Transient pointer state only |
| Habit / completed | Check response and undo status | Undo or continue to the next habit | Immediately persisted habit boolean |
| Habit / all complete | Calm completion card and review action | Review and reopen completed habits | Today's habit map |
| Habit / empty | No tracked habits message | Use existing tracking controls | Existing tracked-habit list |
| All habits chooser | Ordered pending/completed list | Select any habit or mark a completed habit incomplete | Existing configured habit order |

## Interaction and motion

- Touch or pointer input completes after a roughly 600 ms hold. Releasing, scrolling, moving beyond the cancellation threshold, or losing the pointer before completion changes nothing.
- Keyboard and assistive activation complete through a conventional immediate button action.
- Successful completion persists before the card advances, produces a restrained check transition, and may use one light vibration when available.
- Confirmed completion produces one or two short refractive ripples and a Habit color bloom beneath the glass; no ripple, bloom, check, or haptic fires before the canonical record reflects success.
- Motion uses transform/opacity and a localized SVG stroke; no animated blur or broad page transition occurs for each completion.
- Reduced motion removes travel, scale, ripple, and flourish while preserving the hold timer, immediate color change, and visible check/status.

## Data, persistence, and compatibility

- Persisted fields added/changed: daily entries gain `recordedFields.habits`, `recordedFields.water`, and `recordedFields.sleep` booleans.
- Normalization or migration: legacy entries without metadata normalize as fully recorded; new habit-only and watch-sleep-only entries mark only their real fields.
- Backup/import impact: the normalized field metadata remains inside the existing complete state backup; older backups continue to import.
- Offline/restart behavior: each successful habit completion writes through the existing local state path before success motion advances.
- Health/native/API impact: Health Connect remains unchanged except that sleep-only records no longer imply water or habit values.
- Security/privacy impact: None.

## Accessibility

- The hold target is substantially larger than 44 x 44 CSS pixels and does not require precision.
- Completion is communicated through text and a check, not color alone.
- The hold button has a descriptive accessible name; keyboard and synthesized assistive clicks do not require timed holding.
- The chooser is a labelled modal-style sheet with close and Escape behavior.
- Long labels wrap without horizontal overflow, and reduced-motion behavior remains complete.

## Acceptance criteria

- [x] Any tracked habit can be completed in any order from the Habit page.
- [ ] Releasing or scrolling before the hold threshold never changes data. (Early browser release and regression wiring pass; physical touch review remains.)
- [ ] A successful hold persists exactly once and survives reload. (Persistence, confirmation gating, and duplicate resistance pass; physical hold review remains.)
- [x] Undo is available through one normal tap and does not create a false empty daily record.
- [x] Habit-only records do not count missing water or sleep as zero in pages, scores, or coach analytics.
- [x] Legacy records and JSON backups normalize without losing existing values or historical habit keys.
- [x] Empty, pending, completed, and all-complete states are coherent.
- [x] No horizontal overflow occurs at 360 x 800 or 412 x 915.
- [x] Reduced-motion, keyboard, screen-reader naming, and minimum touch targets are preserved.
- [x] Existing navigation, tracking preferences, daily-sheet editing, Health Connect, and Workout Mode remain intact.
- [x] Relevant deterministic, web-build, and phone-size checks pass.
- [x] Durable documentation and `[Unreleased]` notes are updated.
- [x] Bottom navigation uses real capsule widths with circular end caps at rest and while expanded.
- [x] Centered Home, all destinations, selected states, expansion, touch targets, and safe-area spacing remain intact.
- [x] Hold cards show layered Archive glass depth with clear text and control separation.
- [x] Early release returns cleanly without ripple, bloom, check, haptic, or persistence.
- [x] Confirmed completion produces a bounded liquid ripple and semantic bloom exactly once through the verified activation path.
- [x] Reduced-motion removes expanding effects and reduced-transparency preserves opaque hierarchy.

## Verification plan

| Risk | Check | Expected evidence |
| --- | --- | --- |
| Partial records pollute other metrics | Daily-record regression test | Habit-only record has missing water/sleep and a habit-only score |
| Gesture records accidentally | Mobile browser interaction | Early release and vertical scroll cancel; completed hold records once |
| State is lost | Browser reload and local-state check | Completion and undo survive appropriately |
| Layout becomes oversized | 360 x 800 and 412 x 915 inspection | Primary action, chooser, and navigation remain usable with no overflow |
| Motion/accessibility regress | Motion checks and reduced-motion inspection | No paint-heavy animation and complete non-motion feedback |

## References

- Approved directional Focus Deck illustration attached in the current Codex task.
- `docs/DESIGN_SYSTEM.md`
- `docs/reference/home.png`
- `docs/reference/navigation-productivity.png`
- `docs/reference/workout-mode.png`
- `src/App.jsx`
- `src/styles.css`

## Open questions

- Polish of hold timing, card proportions, and final success wording can be tuned after phone review.

## Decision log

| Date | Decision / revision | Approved by |
| --- | --- | --- |
| 2026-08-12 | Use the Focus Deck interaction, permit partial-day records, target today, and prioritize the functional first pass. | Kyle |
| 2026-08-12 | Restore the accepted capsule dock and upgrade Hold cards with persistence-confirmed glass ripples and semantic bloom. | Kyle |
| 2026-08-13 | Accept the revised candidate and authorize the v0.13.0 GitHub, local, Google Drive, APK, and phone release workflow. | Kyle |
