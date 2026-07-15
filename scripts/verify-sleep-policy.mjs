import assert from "node:assert/strict";
import { createServer } from "vite";

const vite = await createServer({
  appType: "custom",
  optimizeDeps: { noDiscovery: true },
  server: { middlewareMode: true, hmr: false },
});

try {
  const {
    mergeWatchSleepIntoEntries,
    normalizeWatchData,
    watchSleepRecordForDate,
  } = await vite.ssrLoadModule("/src/App.jsx");

  const afterMidnightWatchData = {
    dailySummaries: [
      { date: "2026-07-13", sleepMinutes: 0, steps: 8100 },
      { date: "2026-07-14", sleepMinutes: 420, steps: 7200 },
    ],
    sleepSessions: [
      {
        id: "after-midnight-sleep",
        source: "Samsung Health",
        date: "2026-07-14",
        startedAt: "2026-07-14T02:00:00-04:00",
        endedAt: "2026-07-14T09:00:00-04:00",
        durationMinutes: 420,
      },
    ],
  };

  const normalized = normalizeWatchData(afterMidnightWatchData);
  const mondaySummary = normalized.dailySummaries.find((summary) => summary.date === "2026-07-13");
  const tuesdaySummary = normalized.dailySummaries.find((summary) => summary.date === "2026-07-14");

  assert.equal(normalized.sleepSessions[0].date, "2026-07-13");
  assert.equal(mondaySummary.sleepMinutes, 420);
  assert.equal(tuesdaySummary.sleepMinutes, 0);

  const migratedEntries = mergeWatchSleepIntoEntries([
    { date: "2026-07-13", habits: {}, water: 2000, sleep: 6.5, sleepSource: "manual" },
    { date: "2026-07-14", habits: {}, water: 1800, sleep: 7, sleepSource: "sync" },
  ], afterMidnightWatchData, []);
  const migratedMonday = migratedEntries.find((entry) => entry.date === "2026-07-13");
  const migratedTuesday = migratedEntries.find((entry) => entry.date === "2026-07-14");

  assert.equal(migratedMonday.sleep, 7);
  assert.equal(migratedMonday.sleepSource, "sync");
  assert.deepEqual(migratedMonday.sleepSessionIds, ["after-midnight-sleep"]);
  assert.equal(migratedTuesday.sleep, 0);

  const manualFallbackEntries = mergeWatchSleepIntoEntries([
    { date: "2026-07-12", habits: {}, water: 2000, sleep: 6.5, sleepSource: "manual" },
  ], afterMidnightWatchData, []);
  const untouchedFallback = manualFallbackEntries.find((entry) => entry.date === "2026-07-12");
  assert.equal(untouchedFallback.sleep, 6.5);
  assert.equal(untouchedFallback.sleepSource, "manual");

  const mondaySleep = watchSleepRecordForDate(afterMidnightWatchData, "2026-07-13");
  assert.equal(mondaySleep.available, true);
  assert.equal(mondaySleep.durationMinutes, 420);
  assert.equal(mondaySleep.hours, 7);
  assert.deepEqual(mondaySleep.sessionIds, ["after-midnight-sleep"]);

  const crossMidnight = normalizeWatchData({
    sleepSessions: [{
      id: "cross-midnight-sleep",
      startedAt: "2026-07-13T23:15:00-04:00",
      endedAt: "2026-07-14T07:00:00-04:00",
      durationMinutes: 465,
    }],
  });
  assert.equal(crossMidnight.sleepSessions[0].date, "2026-07-13");

  console.log("Sleep policy checks passed: previous-day attribution, migration, and authoritative watch precedence.");
} finally {
  await vite.close();
}
