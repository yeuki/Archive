import assert from "node:assert/strict";
import { createServer } from "vite";

const vite = await createServer({
  appType: "custom",
  optimizeDeps: { noDiscovery: true },
  server: { middlewareMode: true, hmr: false },
});

const syncMetadata = {
  provider: "healthConnect",
  healthSchemaVersion: 1,
  policyVersion: "archive-health-1",
  timeZone: "America/Toronto",
  syncedAt: "2026-07-14T14:00:00Z",
  syncWindowStart: "2026-07-10T04:00:00Z",
  syncWindowEnd: "2026-07-14T14:00:00Z",
  syncWindowStartDate: "2026-07-10",
  syncWindowEndDate: "2026-07-14",
  sleepDateStart: "2026-07-09",
  sleepDateEnd: "2026-07-13",
  days: 5,
  completeSnapshot: true,
  snapshotCompleteness: {
    dailySummaries: true,
    sleepSessions: true,
    workouts: true,
    heartRate: false,
    heartRateVariability: false,
  },
  sampleRetention: { mode: "rolling", limitPerMetric: 500 },
};

try {
  const {
    mergeWatchData,
    mergeWatchSleepIntoEntries,
    normalizeHealthSystem,
    normalizeWatchData,
  } = await vite.ssrLoadModule("/src/App.jsx");

  const normalizedSystem = normalizeHealthSystem(syncMetadata);
  assert.equal(normalizedSystem.timezone, "America/Toronto");
  assert.equal(normalizedSystem.sleepDatePolicy, "previous-day-from-wake");
  assert.deepEqual(normalizedSystem.sourcePriority.sleep, ["healthConnect", "manual"]);
  assert.equal(normalizedSystem.syncWindow.sleepDateStart, "2026-07-09");

  const timezoneStable = normalizeWatchData({
    ...syncMetadata,
    timeZone: "Asia/Tokyo",
    sleepSessions: [{
      id: "tokyo-sleep",
      source: "Samsung Health",
      startedAt: "2026-07-13T18:00:00Z",
      endedAt: "2026-07-14T03:00:00Z",
      durationMinutes: 540,
    }],
  });
  assert.equal(timezoneStable.sleepSessions[0].date, "2026-07-13");
  assert.equal(timezoneStable.sleepSessions[0].timezone, "Asia/Tokyo");

  const current = {
    dailySummaries: [
      { date: "2026-07-08", steps: 5000 },
      { date: "2026-07-10", steps: 6000, sleepMinutes: 400 },
      { date: "2026-07-11", steps: 6100 },
    ],
    sleepSessions: [
      {
        id: "deleted-sleep",
        source: "Samsung Health",
        startedAt: "2026-07-09T05:00:00Z",
        endedAt: "2026-07-10T12:00:00Z",
        durationMinutes: 420,
      },
      {
        id: "corrected-sleep-old",
        source: "Samsung Health",
        startedAt: "2026-07-10T06:00:00Z",
        endedAt: "2026-07-11T11:00:00Z",
        durationMinutes: 410,
      },
    ],
    workouts: [{
      id: "deleted-workout",
      source: "Samsung Health",
      startedAt: "2026-07-12T14:00:00Z",
      endedAt: "2026-07-12T14:40:00Z",
      durationMinutes: 40,
      type: "Run",
    }],
    samples: {
      heartRate: [{ id: "old-hr", source: "Samsung Health", timestamp: "2026-07-10T12:00:00Z", value: 65 }],
      heartRateVariability: [],
    },
  };

  const incoming = {
    ...syncMetadata,
    dailySummaries: [
      { date: "2026-07-10", steps: 7000 },
      { date: "2026-07-11", steps: 7100 },
      { date: "2026-07-12", steps: 7200 },
      { date: "2026-07-13", steps: 7300 },
      { date: "2026-07-14", steps: 7400 },
      { date: "2026-07-14", steps: 7400 },
      { date: "not-a-date", steps: 9999 },
    ],
    sleepSessions: [
      {
        id: "corrected-sleep-new",
        source: "Samsung Health",
        startedAt: "2026-07-10T06:00:00Z",
        endedAt: "2026-07-11T11:00:00Z",
        durationMinutes: 420,
      },
      {
        id: "corrected-sleep-duplicate",
        source: "Samsung Health",
        startedAt: "2026-07-10T06:00:00Z",
        endedAt: "2026-07-11T11:00:00Z",
        durationMinutes: 420,
      },
    ],
    workouts: [],
    samples: {
      heartRate: [
        { id: "new-hr", source: "Samsung Health", timestamp: "2026-07-14T12:00:00Z", value: 70 },
        { id: "new-hr-duplicate", source: "Samsung Health", timestamp: "2026-07-14T12:00:00Z", value: 70 },
      ],
      heartRateVariability: [],
    },
  };

  const merged = mergeWatchData(current, incoming);
  assert.ok(merged.dailySummaries.some((summary) => summary.date === "2026-07-08"));
  assert.equal(merged.dailySummaries.find((summary) => summary.date === "2026-07-10").steps, 7000);
  assert.equal(merged.sleepSessions.length, 1);
  assert.equal(merged.sleepSessions[0].durationMinutes, 420);
  assert.equal(merged.workouts.length, 0);
  assert.equal(merged.samples.heartRate.length, 2, "rolling samples preserve prior bounded data and add the new sample");
  assert.equal(merged.healthSystem.integrity.status, "review");
  assert.ok(merged.healthSystem.integrity.duplicateRecordsRemoved >= 2);
  assert.equal(merged.healthSystem.integrity.invalidRecordsDropped, 1);
  assert.ok(merged.healthSystem.integrity.staleRecordsRemoved >= 2);
  assert.ok(merged.healthSystem.integrity.conflictsResolved >= 2);

  const entries = mergeWatchSleepIntoEntries([
    { date: "2026-07-09", habits: {}, water: 0, sleep: 7, sleepSource: "sync" },
    { date: "2026-07-10", habits: {}, water: 0, sleep: 6, sleepSource: "manual" },
    { date: "2026-07-11", habits: {}, water: 0, sleep: 6.5, sleepSource: "manual" },
  ], merged, []);
  const deletedSync = entries.find((entry) => entry.date === "2026-07-09");
  const watchOverride = entries.find((entry) => entry.date === "2026-07-10");
  const manualFallback = entries.find((entry) => entry.date === "2026-07-11");
  assert.equal(deletedSync.sleep, 0);
  assert.equal(deletedSync.sleepSource, "sync");
  assert.equal(watchOverride.sleep, 7);
  assert.equal(watchOverride.sleepSource, "sync");
  assert.equal(watchOverride.sleepProvider, "healthConnect");
  assert.equal(manualFallback.sleep, 6.5);
  assert.equal(manualFallback.sleepSource, "manual");

  console.log("Health system checks passed: provenance, timezone policy, deduplication, reconciliation, deletion cleanup, and watch-first sleep precedence.");
} finally {
  await vite.close();
}
