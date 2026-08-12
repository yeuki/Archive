# Curated visual references

These screenshots are the canonical v0.12.0 visual baseline for Archive Canvas. They were captured on 2026-08-12 at a 412 x 915 CSS-pixel viewport from a clean, isolated local origin with no personal records. The built-in routine structure is visible where needed, but no simulated daily or workout history was created.

Use these references to preserve hierarchy, spacing, material, and interaction intent. They are not a requirement to freeze content or reproduce every pixel after an approved change.

| File | Reference purpose |
| --- | --- |
| [`home.png`](home.png) | Editorial Home hierarchy, daily summary, card depth, and collapsed bottom navigation |
| [`navigation-productivity.png`](navigation-productivity.png) | Expanded Productivity side, centered Home control, and liquid-glass footprint |
| [`workout.png`](workout.png) | Workout overview, primary start/resume action, build-focus hierarchy, and training setup card |
| [`workout-mode.png`](workout-mode.png) | Focused one-set flow, compact progress, wheel selectors, and dominant completion action |
| [`sleep.png`](sleep.png) | Dedicated metric-page hierarchy, semantic sleep color, chart/summary balance, and empty state |
| [`settings.png`](settings.png) | Settings hierarchy, target controls, Health Connect state, and progressive disclosure |

## Curation rules

- Commit only deliberate reference images in this directory; miscellaneous development screenshots stay ignored.
- Capture with a clean origin/profile so screenshots do not contain personal health or productivity data.
- Use the established 412 x 915 viewport for the primary set and verify changed layouts separately at 360 x 800.
- Replace a reference only after the corresponding major visual change is accepted. Record the replacement in `[Unreleased]` or the release notes.
- Keep the previous version recoverable through Git history; do not accumulate near-duplicate images here.
