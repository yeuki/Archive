import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const dateKey = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const addDays = (date, amount) => {
  const next = new Date(date);
  next.setDate(next.getDate() + amount);
  return next;
};

const today = new Date();
today.setHours(12, 0, 0, 0);
const habits = ["Read", "Walk", "Workout", "Journal"];
const entries = Array.from({ length: 14 }, (_, index) => {
  const offset = index - 13;
  const date = dateKey(addDays(today, offset));
  const isToday = offset === 0;
  const completedCount = isToday ? habits.length : 2 + (index % 3);
  return {
    date,
    habits: Object.fromEntries(habits.map((habit, habitIndex) => [habit, habitIndex < completedCount])),
    water: isToday ? 750 : 1250 + ((index % 4) * 250),
    sleep: isToday ? 0 : Number((6.7 + ((index % 5) * 0.3)).toFixed(1)),
    ...(isToday ? {} : {
      sleepSource: index % 3 === 0 ? "manual" : "sync",
      ...(index % 3 === 0 ? {} : {
        sleepProvider: "healthConnect",
        sleepOrigin: "Garmin via Health Connect",
        sleepSyncedAt: addDays(today, offset + 1).toISOString(),
      }),
    }),
    recordedFields: { habits: true, water: true, sleep: !isToday },
  };
});

const workoutDates = [-11, -7, -3];
const workout = {
  schedule: ["", "", "", "", "", "", ""],
  selectedRoutineId: "full-body-base",
  workouts: workoutDates.map((offset, index) => ({
    id: `demo-workout-${index + 1}`,
    date: dateKey(addDays(today, offset)),
    routineId: "full-body-base",
    routineName: "Full Body Base",
    duration: 44 + index * 4,
    notes: index === 2 ? "Felt steady and controlled." : "",
    exercises: [
      { exerciseId: "back-squat", name: "Back Squat", sets: [
        { weight: 135 + index * 5, reps: "5", rpe: 7, done: true },
        { weight: 135 + index * 5, reps: "5", rpe: 8, done: true },
        { weight: 135 + index * 5, reps: "5", rpe: 8, done: true },
      ] },
      { exerciseId: "bench-press", name: "Bench Press", sets: [
        { weight: 95 + index * 5, reps: "8", rpe: 7, done: true },
        { weight: 95 + index * 5, reps: "8", rpe: 8, done: true },
        { weight: 95 + index * 5, reps: "7", rpe: 8, done: true },
      ] },
    ],
  })),
};

const fourDaysAgo = addDays(today, -4).toISOString();
const payload = {
  app: "archive-productivity-tracker",
  version: 4,
  exportedAt: new Date().toISOString(),
  demo: true,
  description: "Opt-in generated Archive demo data. Contains no personal information.",
  data: {
    habitNames: habits,
    trackedHabits: habits,
    entries,
    workout,
    connectedHealth: {
      enabled: true,
      provider: "healthConnect",
      sourceName: "Garmin via Health Connect",
      status: "webPreview",
      lastSyncAt: fourDaysAgo,
    },
    continuity: {
      preferredWaterMl: 250,
      lastOpenedAt: fourDaysAgo,
      previousOpenAt: fourDaysAgo,
      dismissedWeeklyReview: "",
      dailyDrafts: {},
    },
  },
};

const outputDirectory = resolve("backups");
const outputPath = resolve(outputDirectory, "archive-demo-backup.json");
await mkdir(outputDirectory, { recursive: true });
await writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
console.log(outputPath);
