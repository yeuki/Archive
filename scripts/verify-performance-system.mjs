import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createStatePersistence } from "../src/runtimePerformance.js";

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
assert.match(css, /\.navigation-chrome\.is-scrolling \.nav-shell[\s\S]*?backdrop-filter: none/);
assert.match(css, /\.page-stage\.native-page-motion[\s\S]*?animation: none/);
assert.match(css, /\.area-chart\.chart-static \.line[\s\S]*?stroke-dashoffset: 0/);
assert.match(css, /content-visibility: auto/);
assert.match(css, /\.workout-value-wheel > button[\s\S]*?will-change: auto/);

console.log("Performance checks passed: queued persistence, urgent durability, isolated scroll chrome, stable rendering boundaries, bounded glass, one-time charts, and lazy feature chunks.");
