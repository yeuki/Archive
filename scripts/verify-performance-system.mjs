import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createStatePersistence } from "../src/runtimePerformance.js";
import { createNavGlassLight } from "../src/navGlass.js";

const writes = [];
const hostListeners = new Map();
const documentListeners = new Map();
let nextHandle = 0;
let idleCallback = null;

const storage = {
  setItem(key, value) {
    writes.push({ key, value: JSON.parse(value) });
  },
};

const host = {
  requestIdleCallback(callback) {
    idleCallback = callback;
    nextHandle += 1;
    return nextHandle;
  },
  cancelIdleCallback() {},
  setTimeout(callback) {
    idleCallback = callback;
    nextHandle += 1;
    return nextHandle;
  },
  clearTimeout() {},
  addEventListener(name, callback) {
    hostListeners.set(name, callback);
  },
  removeEventListener(name) {
    hostListeners.delete(name);
  },
};

const documentTarget = {
  visibilityState: "visible",
  addEventListener(name, callback) {
    documentListeners.set(name, callback);
  },
  removeEventListener(name) {
    documentListeners.delete(name);
  },
};

const persistence = createStatePersistence({
  storageKey: "archive-test",
  storage,
  host,
  documentTarget,
});

persistence.schedule({ revision: 1 });
persistence.schedule({ revision: 2 });
assert.equal(writes.length, 0, "ordinary writes must stay out of the interaction frame");
assert.equal(persistence.hasPending(), true);
idleCallback?.();
assert.deepEqual(writes.at(-1)?.value, { revision: 2 }, "rapid writes must coalesce to the newest state");
assert.equal(persistence.hasPending(), false);

persistence.schedule({ revision: 3 });
persistence.schedule({ revision: 4 }, { immediate: true });
assert.deepEqual(writes.at(-1)?.value, { revision: 4 }, "urgent writes must synchronously flush the newest state");

const detachLifecycle = persistence.attachLifecycle();
persistence.schedule({ revision: 5 });
hostListeners.get("pagehide")?.();
assert.deepEqual(writes.at(-1)?.value, { revision: 5 }, "pagehide must flush queued state");

persistence.schedule({ revision: 6 });
documentTarget.visibilityState = "hidden";
documentListeners.get("visibilitychange")?.();
assert.deepEqual(writes.at(-1)?.value, { revision: 6 }, "backgrounding the app must flush queued state");
detachLifecycle();

const app = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");
const workoutMode = await readFile(new URL("../src/WorkoutMode.jsx", import.meta.url), "utf8");
const css = await readFile(new URL("../src/styles.css", import.meta.url), "utf8");

assert.match(app, /createStatePersistence\(\{ storageKey: STORAGE_KEY \}\)/);
assert.doesNotMatch(app, /function saveState\(/, "legacy synchronous whole-state persistence must not return");
assert.match(app, /setTrackerState\(importedState, \{ immediate: true \}\)/, "backup imports must remain immediately durable");
assert.match(app, /\}, \{ immediate: true \}\);\s+setWorkoutModeOpen\(false\)/, "finished workouts must flush immediately");
assert.match(workoutMode, /\{ immediate: false \}/, "wheel edits should be coalesced until a durable workout transition");
assert.doesNotMatch(app, /\[chromeCompact, setChromeCompact\]/, "scroll chrome must not live in root React state");
assert.match(app, /className="navigation-chrome"/);
assert.match(app, /const goals = useMemo\(\(\) => normalizeGoals/);
assert.match(app, /const watchData = useMemo\(\(\) => normalizeWatchData/);
assert.match(app, /const WorkoutMode = lazy\(loadWorkoutMode\)/);
assert.match(app, /const BodyMapVisual = lazy\(loadBodyMapVisual\)/);
assert.match(app, /const MemoHomePage = memo\(HomePage\)/);

assert.match(css, /Archive 0\.14\.0 candidate — bounded rendering and coordinated motion/);
assert.doesNotMatch(css, /\.navigation-chrome\.is-scrolling/, "scrolling must never substitute an opaque dock");
assert.doesNotMatch(app, /classList\.add\("is-scrolling"\)/);
assert.doesNotMatch(css, /nav-caustic/, "decorative caustics must not survive the material replacement");
assert.doesNotMatch(css, /animation: navIn/, "retained entrance opacity must not isolate the page backdrop");
const namedDockRules = [...css.matchAll(/([^{}]+)\{[^{}]*view-transition-name: archive-navigation;[^{}]*\}/g)];
assert.equal(namedDockRules.length, 1, "the dock has exactly one temporary snapshot name");
assert.equal(namedDockRules[0][1].trim().split("\n").at(-1), 'html[data-archive-transition="page"] .bottom-nav', "idle dock must not be a named backdrop root");
assert.match(css, /html\[data-archive-transition="page"\]::view-transition-group\(archive-navigation\)\s*\{\s*z-index: 20;/, "dock snapshot must render above named page panels");
assert.match(css, /clip-path: inset\(var\(--archive-nav-snapshot-inset, 0\) round 999px\)/, "transition backdrop must be bounded to the capsule, never across the screen");
assert.match(app, /feDisplacementMap in="SourceGraphic" in2="bevel" scale="0\.01"/, "refraction must use bounded edge displacement");
const opticalCss = css.split("/* Optical dock")[1];
assert.ok(opticalCss, "the consolidated optical material must exist");
assert.match(opticalCss, /backdrop-filter: blur\(3px\) saturate\(1\.12\)/);
assert.match(opticalCss, /Continuous optical body/);
assert.match(opticalCss, /inset 0 7px 10px -5px/, "soft thickness must blend into the whole body rather than a hard inner outline");
assert.match(opticalCss, /mask: var\(--nav-optical-mask\)/, "optical highlights must use the feathered capsule mask");
assert.match(opticalCss, /radial-gradient\(circle at right center/);
assert.match(opticalCss, /radial-gradient\(circle at left center/);
assert.doesNotMatch(opticalCss, /mask-composite: exclude|content-box|padding: 1px/, "optical edge must not recreate a hard punched-out border");
assert.doesNotMatch(opticalCss, /brightness\(|blur\((?:[1-9]\d|[4-9])px\)/, "dock sampling must stay small and brightness-neutral");
assert.match(css, /\.page-stage\.native-page-motion[\s\S]*?animation: none/);
assert.match(css, /\.area-chart\.chart-static \.line[\s\S]*?stroke-dashoffset: 0/);
assert.match(css, /content-visibility: auto/);
assert.match(css, /\.workout-value-wheel > button[\s\S]*?will-change: auto/);

// Exercise actual light-controller behavior with deterministic frames.
const pendingFrames = new Map();
const lightValues = new Map();
const classes = new Set();
let clock = 0;
let frameHandle = 0;
let reduceMotion = false;
const lightHost = {
  matchMedia: () => ({ matches: reduceMotion }),
  requestAnimationFrame(callback) { pendingFrames.set(++frameHandle, callback); return frameHandle; },
  cancelAnimationFrame(handle) { pendingFrames.delete(handle); },
};
const lightNav = {
  style: { setProperty: (name, value) => lightValues.set(name, value), removeProperty: (name) => lightValues.delete(name) },
  classList: { add: (name) => classes.add(name), remove: (name) => classes.delete(name), contains: (name) => classes.has(name) },
  querySelector: () => ({ getBoundingClientRect: () => ({ left: 10, top: 20, width: 200, height: 64 }) }),
};
const runLightFrames = () => {
  let count = 0;
  while (pendingFrames.size) {
    assert.ok(++count < 40, "lighting must stop when settled, never loop while idle");
    const batch = [...pendingFrames.values()];
    pendingFrames.clear();
    clock += 16;
    batch.forEach((callback) => callback(clock));
  }
  return count;
};
const light = createNavGlassLight(lightNav, lightHost);
light.move({ clientX: 210, clientY: 84, pointerType: "touch" });
assert.equal(pendingFrames.size, 0, "unpressed touch/scroll must not animate light");
light.press({ clientX: 210, clientY: 84, pointerType: "touch" });
light.move({ clientX: 400, clientY: 100 });
assert.equal(pendingFrames.size, 1, "pointer bursts must coalesce into one frame");
runLightFrames();
assert.equal(lightValues.get("--glass-light-x"), "100.00%", "pointer values must clamp to the vessel");
assert.equal(lightValues.get("--glass-light-y"), "100.00%");
light.settle();
assert.equal(classes.has("is-touching"), false);
assert.ok(runLightFrames() > 1, "release should settle smoothly, not snap");
assert.equal(lightValues.get("--glass-light-x"), "50.00%");
assert.equal(lightValues.get("--glass-light-y"), "12.00%");
light.settle();
assert.equal(pendingFrames.size, 0, "an already neutral light needs no frames");
reduceMotion = true;
light.press({ clientX: 210, clientY: 84 });
light.settle();
assert.equal(pendingFrames.size, 0, "reduced motion must not animate tracking or release");
reduceMotion = false;
light.press({ clientX: 100, clientY: 20 });
light.dispose();
assert.equal(pendingFrames.size, 0, "unmount must cancel outstanding animation");
assert.equal(lightValues.size, 0);
light.press({ clientX: 100, clientY: 20 });
assert.equal(pendingFrames.size, 0, "disposed controllers must stay inert");

console.log("Performance checks passed: queued persistence, urgent durability, isolated scroll chrome, stable rendering boundaries, consistent optical glass, bounded touch lighting, one-time charts, and lazy feature chunks.");
