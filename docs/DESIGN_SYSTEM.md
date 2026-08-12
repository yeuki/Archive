# Archive design system

Archive Canvas is a calm editorial interface with soft depth, a small semantic color vocabulary, and carefully staged detail. Apple platforms are a reference for hierarchy, material, motion, and accessibility; Archive keeps its own identity and avoids literal imitation.

## Visual principles

1. **Quiet first impression.** White space and typography establish hierarchy before borders or color.
2. **Depth without decoration.** Soft shadows and translucent material separate layers; they do not become ornaments.
3. **Color carries meaning.** Pastels identify metric families. They are not generic accent colors.
4. **One dominant action.** Each state should make the next useful action obvious.
5. **Details on demand.** Configuration and historical depth appear after a deliberate tap, long press, or drill-in.
6. **Motion explains change.** Animation communicates entry, continuity, progress, and completion rather than delaying the user.

## Foundation

### Typography

- Use the native Apple-like system stack already established in `src/styles.css`.
- Prefer sentence case for controls and headings.
- Use weight, size, and spacing before adding extra rules or labels.
- Large page titles should feel editorial; compact eyebrow labels may use uppercase and modest tracking.
- Numeric values use a stable width where changing digits would otherwise cause layout jitter.

### Color

The interface is predominantly white, gray, and near-black. The four semantic metric colors are fixed references:

| Metric | Color | Use |
| --- | --- | --- |
| Habit | `#FFC5D3` | Habit completion, summaries, and selected habit data |
| Sleep | `#C9A0DC` | Sleep duration, quality, stages, and sleep summaries |
| Water | `#A2BFFE` | Hydration progress and water records |
| Move | `#E5F9E4` | Steps, activity, movement, and training-adjacent totals |

Use black or charcoal for primary content, medium gray for secondary content, and pale gray for dividers and inactive states. Do not introduce a new persistent accent family without an approved product reason.

### Surfaces and material

- The page canvas remains white or subtly off-white.
- Content cards use restrained corner radii, fine neutral edges, and a soft two-part shadow that remains readable on white.
- Liquid-glass material is reserved for floating navigation and similarly elevated transient controls.
- Avoid stacking several translucent surfaces; text and controls must maintain contrast over changing content.
- Animated blur and large continuously repainted shadows are prohibited on scrolling content. Animate `transform` and `opacity` where possible.

### Spacing and shape

- Reuse existing spacing and radius tokens before introducing a new value.
- Maintain even vertical rhythm between sections and consistent internal card padding.
- Keep touch targets at least 44 x 44 CSS pixels where practical.
- Preserve safe-area padding and test phone widths at 360 x 800 and 412 x 915.
- No primary screen should require horizontal scrolling.

## Component language

### Page hierarchy

A standard page should contain only the layers it needs:

1. A clear title and concise current-state summary.
2. The primary action or active task.
3. A short sequence of cards or modules.
4. Configuration and uncommon actions farther down or behind disclosure.

Do not repeat the same metric as a large hero, card headline, and navigation badge on one screen.

### Modules

- A module has one question to answer and one clear information hierarchy.
- Module titles, time spans, legends, and tap behavior remain consistent across metric pages.
- Empty states explain what real action will populate the module; they never invent sample history that resembles user data.
- Drag, long-press edit, remove, and add-gallery behaviors remain discoverable without permanent visual clutter.

### Charts and grids

- Simple charts with roughly fewer than ten values may retain Archive's gradient fill.
- Dense calendars, contribution grids, and high-volume views use solid semantic tones with discrete intensity steps.
- Labels may be reduced, but exact values must remain available through selection or detail views.
- Entry animation may reveal bars upward or draw a trend from left to right once. It must not replay during ordinary scrolling or compete with direct manipulation.

### Navigation

- Preserve the centered Home control and expanding Productivity/Health sides.
- The bottom bar floats above content, respects safe areas, and uses a readable liquid-glass treatment.
- Expansion, selection, and collapse share a smooth spring-like motion without shifting the underlying page layout.
- Navigation actions remain reachable with one hand and cannot be hidden by the device gesture area.

### Forms and selectors

- Prefer large rows, segmented choices, steppers, or short wheel selectors over dense editable tables.
- Allow temporary blank numeric fields while editing where the underlying domain permits it.
- A destructive action is visually separated and requires clear intent.
- Long lists use the established custom menu/sheet treatment rather than an unstyled operating-system select where consistency matters.

## Motion

Motion should feel continuous, responsive, and interruptible.

- Page and card entry: short opacity/vertical-transform transitions with modest staggering.
- Charts: one purposeful reveal when their data/state first becomes visible.
- Direct manipulation: track the finger immediately; settle with a short easing or spring.
- Bottom sheets: enter from the viewport edge and remain fixed to the viewport, never the document bottom.
- Workout selectors: preserve momentum but snap decisively to one centered value.
- Loading: the centered Archive A reveals its normal gradient within the unchanged gray silhouette.
- Reduced motion: remove travel, parallax, repeated chart drawing, and spring overshoot; preserve an immediate state change or short fade.

Avoid animating layout-affecting properties (`height`, `top`, large blur radii) during scroll when a transform-based implementation can express the same relationship.

## Accessibility and feedback

- Maintain readable contrast even when translucency is unavailable or reduced.
- Do not rely on color alone for completion, selection, or failure.
- Controls need accessible names, visible focus treatment, and predictable keyboard behavior in the web build.
- Haptic feedback may confirm a selected value, completed set, or completed pull-to-refresh on supported devices; it should not fire continuously while scrolling.
- Dynamic text must not overlap chart labels, descriptions, or tap targets.

## Curated references

The canonical v0.12.0 visual references are indexed in [`docs/reference/README.md`](reference/README.md). Use them to preserve hierarchy and tone, not as pixel-perfect constraints when content changes.

## Review checklist

Before accepting a visual change, confirm:

- It solves the named user problem without redesigning adjacent pages.
- The primary action is obvious and the screen is not denser than before.
- Metric colors retain their semantic meaning.
- Motion remains smooth during scroll and respects reduced motion.
- Touch targets, contrast, overflow, loading, empty, error, and long-content states were considered.
- The result was checked at both established phone sizes against the curated references.
