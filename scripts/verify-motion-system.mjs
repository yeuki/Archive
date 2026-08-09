import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const app = fs.readFileSync(path.join(root, "src", "App.jsx"), "utf8");
const workout = fs.readFileSync(path.join(root, "src", "WorkoutMode.jsx"), "utf8");
const motion = fs.readFileSync(path.join(root, "src", "motion.js"), "utf8");
const css = fs.readFileSync(path.join(root, "src", "styles.css"), "utf8");
const motionCss = css.split("/* Archive 0.12.0 — unified motion and compositor pass */")[1] ?? "";

function check(condition, message) {
  if (!condition) throw new Error(message);
}

check(motion.includes("runArchiveTransition"), "Shared view-transition coordinator is missing.");
check(motion.includes("flushSync(update)"), "View transitions must capture synchronous React state changes.");
check(motion.includes("archivePrefersReducedMotion"), "Shared motion must respect reduced-motion preferences.");
check(motion.includes("useFlipLayout"), "Reorderable content needs shared FLIP layout motion.");
check(motion.includes("translate: `${deltaX}px ${deltaY}px`"), "FLIP movement must use compositor-friendly translate.");

check(app.includes("runArchiveTransition(updatePage, { kind: \"page\""), "Page changes are not using the shared transition coordinator.");
check(app.includes("groups.productivity.map(renderPageButton)"), "Productivity buttons must remain mounted during dock collapse.");
check(app.includes("groups.health.map(renderPageButton)"), "Health buttons must remain mounted during dock collapse.");
check(app.includes("aria-hidden={visible ? \"false\" : \"true\"}"), "Collapsed dock buttons need accessible hidden state.");
check(app.includes("--selection-scale"), "The navigation selection lens must move and resize through transforms.");
check(app.includes("useFlipLayout(habitNames.join"), "Habit reordering is missing FLIP continuity.");
check(app.includes("modules.map((module) => module.instanceId).join"), "Module reordering is missing FLIP continuity.");
check(app.includes("className=\"settings-section-reveal\""), "Settings disclosure content must remain mounted while collapsing.");
check(app.includes("--sheet-drag-y"), "The daily sheet drag must be painted through a CSS transform variable.");
check(!app.includes("const [dragY, setDragY]"), "The daily sheet must not rerender its full form on every drag frame.");
check(app.includes("motion-popover"), "Expandable menus need reversible open and close motion.");

check(workout.includes("const WHEEL_RANGE = 48"), "Workout wheels need a stable buffered range.");
check(workout.includes("const [rangeAnchor, setRangeAnchor]"), "Workout wheel options must not rebuild around every selected value.");
check(workout.includes("scheduleWheelPaint"), "Workout wheel presentation must be synchronized with requestAnimationFrame.");
check(workout.includes("wheel-current"), "Workout wheel rows need continuous centered emphasis.");
check(workout.includes("archivePrefersReducedMotion() ? \"auto\" : \"smooth\""), "Programmatic wheel movement must honor reduced motion.");
check(workout.includes("kind: \"workout-stage\""), "Workout stage changes need continuity transitions.");
check(workout.includes("kind: \"workout-sheet\""), "Workout sheets need reversible transition handling.");

check(motionCss.includes("--motion-page: 520ms"), "The shared motion token set is missing.");
check(motionCss.includes("view-transition-name: archive-page"), "Page snapshots are not isolated for view transitions.");
check(motionCss.includes("scaleX(var(--dock-resting-scale))"), "The liquid-glass dock must morph through a fixed compositor surface.");
check(motionCss.includes("width: var(--dock-expanded-width)"), "The dock raster must keep one fixed width while moving.");
check(motionCss.includes(".workout-value-wheel > button.wheel-current"), "Centered wheel styling is missing.");
check(motionCss.includes(".settings-section.collapsed .settings-section-reveal"), "Settings collapse animation is missing.");
check(motionCss.includes(".motion-popover.motion-closed"), "Popover exit animation is missing.");
check(motionCss.includes("@media (prefers-reduced-motion: reduce)"), "The motion system needs a reduced-motion fallback.");
check(!motionCss.includes("filter: blur("), "The v0.12 motion layer must not animate paint-heavy blur filters.");

console.log("Motion system checks passed: fixed-raster glass, continuous wheels, FLIP reordering, reversible disclosure, sheet drag compositing, view transitions, and reduced-motion fallbacks.");
