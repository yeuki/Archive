import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "vite";
import {
  adjustWorkoutSessionRest,
  completeWorkoutSessionSet,
  createWorkoutSession,
  endWorkoutSessionEarly,
  finishWorkoutSessionRest,
  insertWorkoutWarmupSet,
  isWorkoutSetCounted,
  moveWorkoutSessionCursor,
  normalizeActiveWorkoutSession,
  patchWorkoutSessionSet,
  pauseWorkoutSession,
  skipWorkoutSessionExercise,
  toggleWorkoutRestTimer,
  workoutLogFromSession,
  workoutRestRemainingSeconds,
  workoutSessionElapsedMs,
  workoutSessionStats,
} from "../src/workoutSession.js";

const start = "2026-08-09T14:00:00.000Z";
const exercises = [
  {
    id: "bench-press",
    name: "Bench Press",
    equipment: "Barbell",
    movement: "Horizontal push",
    primaryMuscles: ["Chest"],
    secondaryMuscles: ["Triceps"],
  },
  {
    id: "plank",
    name: "Plank",
    equipment: "Bodyweight",
    movement: "Core hold",
    primaryMuscles: ["Core"],
    secondaryMuscles: [],
  },
];
const routine = {
  id: "focused-test",
  name: "Focused Test",
  exerciseIds: ["bench-press", "plank"],
  plan: {
    "bench-press": { sets: 2, reps: "8", weight: 100, rest: 90 },
    plank: { sets: 1, reps: "45s", weight: 0, rest: 60 },
  },
};
const workouts = [{
  id: "previous",
  date: "2026-08-07",
  exercises: [{
    exerciseId: "bench-press",
    name: "Bench Press",
    sets: [
      { weight: 105, reps: "8", done: true, status: "completed", setType: "working" },
      { weight: 110, reps: "6", done: true, status: "completed", setType: "working" },
      { weight: 45, reps: "10", done: true, status: "completed", setType: "warmup" },
    ],
  }],
}, {
  id: "newer-skipped",
  date: "2026-08-08",
  exercises: [{
    exerciseId: "bench-press",
    name: "Bench Press",
    sets: [{ weight: 999, reps: "1", done: false, status: "skipped", setType: "working" }],
  }],
}];

let session = createWorkoutSession({ routine, exercises, workouts, now: start });
assert.equal(session.status, "active");
assert.equal(session.exercises.length, 2);
assert.equal(session.exercises[0].sets.length, 2);
assert.equal(session.exercises[0].sets[0].weight, 105, "latest working-set weight becomes the quick default");
assert.equal(session.exercises[0].sets[1].reps, "6", "set-specific history is retained");
assert.equal(session.exercises[1].metricKind, "duration", "duration prescriptions use a duration picker");

const restored = normalizeActiveWorkoutSession(JSON.parse(JSON.stringify(session)));
assert.deepEqual(restored.cursor, { exerciseIndex: 0, setIndex: 0 });
assert.equal(restored.exercises[0].sets[0].previousWeight, 105, "resume data survives serialization");

session = patchWorkoutSessionSet(session, session.cursor, { weight: 112.5, reps: "7" }, "2026-08-09T14:00:20.000Z");
session = completeWorkoutSessionSet(session, { status: "completed" }, "2026-08-09T14:00:30.000Z");
assert.equal(session.status, "resting");
assert.deepEqual(session.cursor, { exerciseIndex: 0, setIndex: 1 });
assert.equal(workoutRestRemainingSeconds(session, "2026-08-09T14:00:30.000Z"), 90);

session = toggleWorkoutRestTimer(session, "2026-08-09T14:01:00.000Z");
assert.equal(session.rest.paused, true);
assert.equal(session.rest.remainingSec, 60, "rest-only pause freezes the remaining countdown");
session = adjustWorkoutSessionRest(session, 15, "2026-08-09T14:02:00.000Z");
assert.equal(session.rest.remainingSec, 75);
session = toggleWorkoutRestTimer(session, "2026-08-09T14:02:00.000Z");
assert.equal(session.rest.paused, false);
session = finishWorkoutSessionRest(session, "2026-08-09T14:02:05.000Z");
assert.equal(session.status, "active");

session = insertWorkoutWarmupSet(session, "2026-08-09T14:02:06.000Z");
assert.equal(session.exercises[0].sets[1].setType, "warmup");
assert.equal(session.exercises[0].sets.length, 3);
session = completeWorkoutSessionSet(session, { status: "completed" }, "2026-08-09T14:02:20.000Z");
assert.equal(session.rest.durationSec, 45, "warm-up rest is shorter than the exercise's working rest");
session = finishWorkoutSessionRest(session, "2026-08-09T14:03:05.000Z");
session = completeWorkoutSessionSet(session, { status: "failed" }, "2026-08-09T14:03:20.000Z");
assert.equal(session.exercises[0].sets[2].effort, "failed");
session = finishWorkoutSessionRest(session, "2026-08-09T14:04:50.000Z");
session = skipWorkoutSessionExercise(session, "2026-08-09T14:04:55.000Z");
assert.equal(session.status, "summary");

const stats = workoutSessionStats(session);
assert.equal(stats.workingSets, 2, "failed attempts remain recorded working sets");
assert.equal(stats.warmups, 1);
assert.equal(stats.failed, 1);
assert.equal(stats.skipped, 1);
assert.equal(stats.pending, 0);

const log = workoutLogFromSession(session, "2026-08-09T14:05:00.000Z");
assert.equal(log.id, session.id, "session ID makes finalization idempotent");
assert.equal(log.exercises[0].sets[1].setType, "warmup");
assert.equal(isWorkoutSetCounted(log.exercises[0].sets[1]), false, "warm-ups do not inflate working volume");
assert.equal(isWorkoutSetCounted(log.exercises[0].sets[2]), true, "failed attempts retain their actual volume");
assert.equal(isWorkoutSetCounted(log.exercises[1].sets[0]), false, "skipped sets do not inflate analytics");

let pauseSession = createWorkoutSession({ routine, exercises, workouts: [], now: start });
pauseSession = pauseWorkoutSession(pauseSession, "2026-08-09T14:01:00.000Z");
pauseSession = moveWorkoutSessionCursor(pauseSession, { exerciseIndex: 0, setIndex: 1 }, "2026-08-09T14:02:00.000Z");
assert.equal(pauseSession.status, "active", "choosing a pending set from a paused outline resumes safely");
assert.equal(pauseSession.accumulatedPausedMs, 60000);
pauseSession = endWorkoutSessionEarly(pauseSession, "2026-08-09T14:03:00.000Z");
assert.equal(workoutSessionElapsedMs(pauseSession, "2026-08-09T14:04:00.000Z"), 120000, "paused time is excluded from final duration");
pauseSession = moveWorkoutSessionCursor(pauseSession, { exerciseIndex: 0, setIndex: 0 }, "2026-08-09T14:03:10.000Z");
assert.equal(pauseSession.summaryAt, "", "returning to an incomplete set restarts active duration accounting");

const emptySession = createWorkoutSession({
  routine: { id: "run", name: "Run", exerciseIds: [], plan: {} },
  exercises,
  workouts: [],
  now: start,
});
assert.equal(emptySession.status, "summary", "zero-exercise routines remain finishable");

const vite = await createServer({
  appType: "custom",
  optimizeDeps: { noDiscovery: true },
  server: { middlewareMode: true, hmr: false },
});

try {
  const { normalizeWorkoutState } = await vite.ssrLoadModule("/src/App.jsx");
  const normalizedWorkout = normalizeWorkoutState({
    exercises,
    routines: [routine],
    selectedRoutineId: routine.id,
    schedule: Array(7).fill(""),
    workouts: [],
    activeSession: restored,
  });
  assert.equal(normalizedWorkout.activeSession.id, restored.id, "root workout normalization preserves active sessions");

  const appSource = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");
  const modeSource = await readFile(new URL("../src/WorkoutMode.jsx", import.meta.url), "utf8");
  const styles = await readFile(new URL("../src/styles.css", import.meta.url), "utf8");
  const workoutPageSource = appSource.slice(appSource.indexOf("function WorkoutPage"), appSource.indexOf("function connectedHealthStatusLabel"));

  assert.match(workoutPageSource, /<WorkoutMode/);
  assert.doesNotMatch(workoutPageSource, /<WorkoutLogger/, "the live workout no longer renders the editable table logger");
  assert.match(appSource, /activeSession: normalizeActiveWorkoutSession/);
  assert.match(appSource, /\.workout-mode-screen/);
  assert.match(modeSource, /Complete \$\{set\.setType/);
  assert.match(modeSource, /Pause timer/);
  assert.match(modeSource, /Finish workout/);
  assert.match(modeSource, /Add effort note/);
  assert.match(modeSource, /createPortal/);
  assert.match(modeSource, /appShell\.inert = true/);
  assert.match(styles, /scroll-snap-type: y mandatory/);
  assert.match(styles, /body\.workout-mode-active/);
} finally {
  await vite.close();
}

console.log("Workout Mode checks passed: persistent resume, set and rest transitions, adaptive pickers, warm-ups, failed/skipped sets, pause accounting, idempotent history conversion, and focused live UI.");
