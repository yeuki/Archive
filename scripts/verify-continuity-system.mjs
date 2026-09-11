import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  addWaterToEntries,
  buildWeeklyReflection,
  chooseHomeContinuation,
  normalizeContinuity,
  restoreWaterInEntries,
} from "../src/continuity.js";

const date = "2026-09-03";
const goals = { waterTarget: 2000 };
const habits = ["Read", "Walk"];

assert.deepEqual(normalizeContinuity({ preferredWaterMl: 999 }).preferredWaterMl, 250);
assert.equal(normalizeContinuity({ dailyDrafts: { [date]: { water: "350", sleepMode: "manual", manualSleep: "7.5" } } }).dailyDrafts[date].water, "350");

const active = chooseHomeContinuation({
  todayEntry: null,
  habitNames: habits,
  goals,
  workout: { activeSession: { routineName: "Full body", status: "active", exercises: [] } },
  scheduledRoutine: { name: "Legs" },
});
assert.equal(active.kind, "active-workout");

const scheduled = chooseHomeContinuation({ todayEntry: null, habitNames: habits, goals, workout: {}, scheduledRoutine: { name: "Legs" } });
assert.equal(scheduled.kind, "scheduled-workout");

const habit = chooseHomeContinuation({ todayEntry: null, habitNames: habits, goals, workout: {}, scheduledRoutine: null });
assert.equal(habit.kind, "habit");

const before = {
  date,
  habits: { Read: true, Walk: false },
  water: 100,
  sleep: 7.25,
  sleepSource: "manual",
  recordedFields: { habits: true, water: false, sleep: true },
};
const added = addWaterToEntries([before], { date, amount: 250, habitNames: habits });
assert.equal(added[0].water, 350);
assert.deepEqual(added[0].habits, before.habits);
assert.equal(added[0].sleep, before.sleep);
assert.equal(added[0].recordedFields.water, true);
assert.equal(added[0].recordedFields.habits, true);
assert.equal(added[0].recordedFields.sleep, true);
assert.deepEqual(restoreWaterInEntries(added, { date, previousEntry: before }), [before]);

const water = chooseHomeContinuation({ todayEntry: { ...before, habits: { Read: true, Walk: true }, recordedFields: { habits: true, water: false, sleep: false } }, habitNames: habits, goals, workout: {}, scheduledRoutine: null });
assert.equal(water.kind, "water");
const caughtUp = chooseHomeContinuation({ todayEntry: { ...before, water: 2200, recordedFields: { habits: true, water: true, sleep: false }, habits: { Read: true, Walk: true } }, habitNames: habits, goals, workout: {}, scheduledRoutine: null });
assert.equal(caughtUp.kind, "caught-up");
assert.match(caughtUp.copy, /expected-later sleep/i);

const insufficient = buildWeeklyReflection([], { today: new Date("2026-09-03T12:00:00Z") });
assert.equal(insufficient.available, false);

const source = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");
assert.doesNotMatch(source, /Sleep to habit completion|Water to energy rating|fallbackScores|fallbackSleep/);
assert.match(source, /Save water only/);
assert.match(source, /Save sleep only/);

console.log("Continuity checks passed: deterministic Home priority, exact partial hydration and undo, draft normalization, truthful sleep timing, and evidence gates.");
