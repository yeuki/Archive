# Major change: Performance and motion pass

## Control

- **Status:** Candidate
- **Owner:** Kyle / Codex
- **Created:** 2026-08-19
- **Baseline:** v0.13.0 plus Garmin Health Connect candidate / `ea850b3`
- **Working branch:** `feature/performance-motion`
- **Target release:** 0.14.0, pending candidate acceptance
- **Related issue / task:** Improve broad app responsiveness and motion without changing Archive's accepted UI or hierarchy

## Problem and user outcome

Archive can feel choppy on capable Android hardware, particularly while scrolling, expanding the liquid-glass navigation, entering data, and moving between content-heavy pages. The current implementation performs synchronous whole-state serialization during interactions, lets scroll chrome state rerender the application shell, repeatedly rebuilds normalized data, and combines live backdrop blur with layout-affecting animation.

After this change, common interactions should feel immediate and visually continuous on the same device and data set. Archive should retain its existing appearance and behavior while doing less JavaScript, layout, paint, and storage work per frame.

## Approved direction

Implement a focused performance and motion pass rather than adding decorative animation. Queue ordinary whole-state persistence outside the input frame while retaining immediate active-workout durability and lifecycle flushes; stabilize derived data and callbacks; isolate scroll-reactive chrome from page rendering; bound glass painting; coordinate page and child motion; reveal charts once rather than on every visit; and lazy-load coherent heavy feature boundaries already extracted from the application shell.

## Preserve

- The v0.13.0 navigation hierarchy, centered Home control, true capsule geometry, expansion behavior, and liquid-glass identity.
- Archive Canvas layouts, modules, semantic colors, charts, dedicated pages, and current interaction model.
- The Garmin Health Connect workout candidate at `ea850b3`, including launch/pull-to-refresh-only reads.
- Existing local data, JSON backup compatibility, Health Connect policy, sleep authority, and workout resume/completion behavior.
- Immediate persistence for active workout progress and an in-place Android update path.

## Non-goals

- Navigation or page restructuring.
- A new visual redesign, new metrics, new service, backend, or production dependency.
- Removing liquid glass, chart identity, module personalization, or accepted motion feedback.
- Replacing localStorage or changing the persisted backup schema in this pass.
- Treating animation as a substitute for reducing work.

## Screens and states

| Screen/state | User sees | User can do | Data/source |
| --- | --- | --- | --- |
| Any normal page | Existing Archive Canvas with calmer, coordinated entrance motion | Scroll and navigate without whole-page scroll-state rerenders | Existing local state |
| Bottom navigation | Existing true liquid-glass capsule and destinations | Expand, collapse, select, and compact smoothly | Local navigation state |
| Chart/module page | Existing chart values and gradients | Review values without repeated reveal animation on ordinary revisits | Canonical records/modules |
| Workout Mode | Existing focused set/rest flow | Complete or edit a set with immediate durable persistence | Active workout session |
| App background/close | No new visible UI | Leave safely while queued state is flushed | Local persistence queue |
| Reduced motion/transparency | Existing content with restrained immediate feedback and opaque fallbacks | Use every interaction without travel or live blur | System preferences |

## Interaction and motion

- Direct manipulation remains immediate; settling uses transform and opacity with shared motion tokens.
- Page navigation uses one coordinated view transition. Child entrance and chart animations are suppressed for the captured page transition so motion does not stack.
- Chart reveals run once per mounted data presentation and do not replay merely because unrelated root state changed.
- The bottom navigation preserves real width animation for circular end caps, but live blur/shadow complexity is reduced while the vessel is moving or the document is actively scrolling.
- Scroll-reactive compact state is local to the navigation chrome and does not update the application root.
- Reduced-motion and reduced-transparency preferences remain authoritative.

## Data, persistence, and compatibility

- Persisted fields added/changed: None.
- Normalization or migration: None; normalized slices become memoized but retain their existing functions and outputs.
- Backup/import impact: None; imports force an immediate durable write.
- Offline/restart behavior: Ordinary writes are coalesced briefly and flushed during idle time, `visibilitychange`, `pagehide`, and unmount. Explicit imports plus Workout Mode start, completed-set/rest/pause progression, finish, and discard write immediately; wheel adjustments flush at the next idle or durable boundary.
- Health/native/API impact: No additional Health Connect trigger or native schema change.
- Security/privacy impact: None; all persistence remains local.

## Accessibility

- Preserve 44px touch targets, labels, focus treatment, safe areas, and keyboard behavior.
- Preserve system reduced-motion and reduced-transparency fallbacks.
- Do not use motion as the only indicator of selection, completion, or progress.
- Keep natural touch scrolling and prevent horizontal overflow at supported phone widths.

## Acceptance criteria

- [x] Synchronous whole-state serialization is removed from ordinary interaction updates.
- [x] Completed-set/session boundaries and backup imports remain immediately durable.
- [x] Queued persistence flushes on lifecycle boundaries and coalesces rapid updates.
- [x] Scroll-reactive navigation no longer rerenders the root application page.
- [x] Derived normalized data and expensive analytics retain stable identities until their source slices change.
- [x] Liquid-glass navigation retains its accepted silhouette and appearance with bounded moving paint cost.
- [x] Page transitions do not stack with repeated child/chart entrance animations.
- [x] Heavy already-separated feature UI is lazy-loaded with a coherent fallback and no layout flash.
- [x] No navigation, data, Health Connect, workout, module, or backup regression is introduced by automated checks.
- [x] No horizontal overflow occurs at 360 x 800 or 412 x 915.
- [x] Reduced-motion and reduced-transparency behavior is verified.
- [x] `npm run verify`, relevant Android checks, and debug assembly pass.
- [ ] The candidate is installed and smoke-tested on the physical phone after ADB reconnects.
- [x] Durable documentation and `[Unreleased]` notes are updated.

## Verification plan

| Risk | Check | Expected evidence |
| --- | --- | --- |
| Queued writes lose data | Persistence regression script plus lifecycle/unit-style checks | Coalesced ordinary writes, immediate urgent writes, and lifecycle flush all persist the newest state |
| Workout resume regresses | `npm run test:workout` and packaged smoke test | Current set/session survives navigation and relaunch |
| Navigation drifts visually | Motion safeguards and 360/412px screenshots/interactions | Same hierarchy and circular capsule ends, without overflow |
| Motion stacks or ignores preferences | `npm run test:motion`, reduced-motion browser run | One page-level transition and immediate reduced-motion state changes |
| Glass optimization changes appearance | Before/after phone-size screenshots and device check | Liquid-glass identity remains recognizable while scrolling and expansion stay responsive |
| Health behavior changes | `npm run test:health`, `npm run test:auto-health`, `npm run test:sleep` | Exactly two sync triggers and existing sleep policy remain intact |

## References

- [`docs/DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md)
- [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md)
- [`docs/DECISIONS.md`](../DECISIONS.md)
- [`docs/reference/README.md`](../reference/README.md)

## Open questions

- Final v0.14.0 publication remains gated on candidate acceptance after device testing.

## Decision log

| Date | Decision / revision | Approved by |
| --- | --- | --- |
| 2026-08-19 | Implement all previously identified rendering, persistence, motion, and component-boundary optimizations while preserving the current UI. | Kyle |
| 2026-08-19 | Candidate uses idle whole-state writes with immediate meaningful workout boundaries, one native page transition, bounded moving glass, lazy Workout Mode/body map, and data-signature chart reveals. | Kyle / Codex |
