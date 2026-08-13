import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  hasAnyDailyField,
  isDailyFieldRecorded,
  normalizeRecordedFields,
  setHabitCompletionInEntries,
} from "../src/dailyRecords.js";

const root = process.cwd();
const app = fs.readFileSync(path.join(root, "src", "App.jsx"), "utf8");
const deck = fs.readFileSync(path.join(root, "src", "HabitHoldDeck.jsx"), "utf8");
const css = fs.readFileSync(path.join(root, "src", "styles.css"), "utf8");

assert.deepEqual(normalizeRecordedFields({ date: "2026-08-10" }), {
  habits: true,
  water: true,
  sleep: true,
});
assert.deepEqual(normalizeRecordedFields(null), {
  habits: false,
  water: false,
  sleep: false,
});

let entries = setHabitCompletionInEntries([], {
  date: "2026-08-12",
  habit: "Read",
  completed: true,
});
assert.equal(entries.length, 1);
assert.equal(entries[0].habits.Read, true);
assert.deepEqual(entries[0].recordedFields, {
  habits: true,
  water: false,
  sleep: false,
});
assert.equal(isDailyFieldRecorded(entries[0], "habits"), true);
assert.equal(isDailyFieldRecorded(entries[0], "water"), false);
assert.equal(isDailyFieldRecorded(entries[0], "sleep"), false);
assert.equal(hasAnyDailyField(entries[0]), true);

entries = setHabitCompletionInEntries(entries, {
  date: "2026-08-12",
  habit: "Walk",
  completed: true,
});
entries = setHabitCompletionInEntries(entries, {
  date: "2026-08-12",
  habit: "Walk",
  completed: false,
});
assert.equal(entries.length, 1);
assert.equal(entries[0].habits.Read, true);
assert.equal(entries[0].habits.Walk, false);

entries = setHabitCompletionInEntries(entries, {
  date: "2026-08-12",
  habit: "Read",
  completed: false,
});
assert.deepEqual(entries, []);

const waterOnly = [{
  date: "2026-08-12",
  habits: {},
  water: 1800,
  sleep: 0,
  recordedFields: { habits: false, water: true, sleep: false },
}];
const withHabit = setHabitCompletionInEntries(waterOnly, {
  date: "2026-08-12",
  habit: "Read",
  completed: true,
});
assert.equal(withHabit[0].water, 1800);
assert.equal(withHabit[0].recordedFields.habits, true);
const restoredWaterOnly = setHabitCompletionInEntries(withHabit, {
  date: "2026-08-12",
  habit: "Read",
  completed: false,
  restore: {
    habitsRecorded: false,
    habitPresent: false,
    habitValue: false,
  },
});
assert.deepEqual(restoredWaterOnly[0].habits, {});
assert.deepEqual(restoredWaterOnly[0].recordedFields, {
  habits: false,
  water: true,
  sleep: false,
});

assert.ok(app.includes("recordedFields: normalizeRecordedFields(entry)"), "Daily-entry normalization must preserve field presence.");
assert.ok(app.includes("setHabitCompletionInEntries(current.entries"), "Habit completion must use the partial-record update helper.");
assert.ok(app.includes("<HabitHoldDeck"), "The Habit page must render the focused completion deck.");
assert.ok(!app.includes("daily.waterAverage7 || 0"), "Missing water must not be described to the coach as zero.");
assert.ok(!app.includes("daily.sleepAverage7 || 0"), "Missing sleep must not be described to the coach as zero.");
assert.ok(deck.includes("const HOLD_DURATION_MS = 620"), "The touch hold duration is missing.");
assert.ok(deck.includes("completionLockRef.current"), "Completion needs an immediate duplicate-input lock.");
assert.ok(deck.includes("event.detail === 0"), "Keyboard and assistive activation need a conventional click path.");
assert.ok(deck.includes("activateWithKeyboard"), "The hold control needs an explicit keyboard activation path.");
assert.ok(deck.includes("data-no-pull-refresh"), "The hold target must not conflict with pull-to-refresh.");
assert.ok(css.includes(".habit-hold-control.holding .habit-hold-progress"), "The hold progress treatment is missing.");
assert.ok(css.includes("@media (prefers-reduced-motion: reduce)"), "The deck needs a reduced-motion fallback.");

console.log("Habit Hold Deck checks passed: partial records, exact undo, focused completion wiring, gesture isolation, and accessibility fallbacks.");
