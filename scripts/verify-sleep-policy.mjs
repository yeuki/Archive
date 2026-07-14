import assert from "node:assert/strict";
import { createServer } from "vite";

const vite = await createServer({
  appType: "custom",
  server: { middlewareMode: true },
});

try {
  const {
    mergeWatchSleepIntoEntries,
    normalizeWatchData,
    watchSleepRecordForDate,
  } = await vite.ssrLoadModule("/src/App.jsx");

  const legacyWatchData = {
    dailySummaries: [
      { date: "2026-07-13", sleepMinutes: 0, steps: 8100 },
      { date: "2026-07-14", sleepMinutes: 465, steps: 7200 },
    ],
    sleepSessions: [
      {
        id: "monday-night",
        source: "Samsung Health",
        date: "2026-07-14",
        startedAt: "2026-07-13T23:15:00-04:00",
        endedAt: "2026-07-14T07:00:00-04:00",
        durationMinutes: 465,
      },
    ],
  };

  const normalized = normalizeWatchData(legacyWatchData);
  const mondaySummary = normalized.dailySummaries.find((summary) => summary.date === "2026-07-13");
  const tuesdaySummary = normalized.dailySummaries.find((summary) => summary.date === "2026-07-14");

  assert.equal(normalized.sleepSessions[0].date, "2026-07-13");
  assert.equal(mondaySummary.sleepMinutes, 465);
  assert.equal(tuesdaySummary.sleepMinutes, 0);

  const migratedEntries = mergeWatchSleepIntoEntries([
    { date: "2026-07-13", habits: {}, water: 2000, sleep: 0 },
    { date: "2026-07-14", habits: {}, water: 1800, sleep: 7.75 },
  ], legacyWatchData, []);
  const migratedMonday = migratedEntries.find((entry) => entry.date === "2026-07-13");
  const migratedTuesday = migratedEntries.find((entry) => entry.date === "2026-07-14");

  assert.equal(migratedMonday.sleep, 7.75);
  assert.equal(migratedMonday.sleepSource, "sync");
  assert.deepEqual(migratedMonday.sleepSessionIds, ["monday-night"]);
  assert.equal(migratedTuesday.sleep, 0);

  const manualEntries = mergeWatchSleepIntoEntries([
    { date: "2026-07-13", habits: {}, water: 2000, sleep: 6.5, sleepSource: "manual" },
  ], legacyWatchData, []);
  assert.equal(manualEntries[0].sleep, 6.5);
  assert.equal(manualEntries[0].sleepSource, "manual");

  const mondaySleep = watchSleepRecordForDate(legacyWatchData, "2026-07-13");
  assert.equal(mondaySleep.available, true);
  assert.equal(mondaySleep.durationMinutes, 465);
  assert.equal(mondaySleep.hours, 7.75);
  assert.deepEqual(mondaySleep.sessionIds, ["monday-night"]);

  console.log("Sleep policy checks passed: start-date attribution, legacy migration, and manual override preservation.");
} finally {
  await vite.close();
}
