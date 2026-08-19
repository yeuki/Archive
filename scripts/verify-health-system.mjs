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
    combinedWorkoutHistory,
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

  const garminSnapshot = {
    ...syncMetadata,
    healthSchemaVersion: 2,
    policyVersion: "archive-health-2",
    dailySummaries: [],
    sleepSessions: [],
    workouts: [{
      id: "hc-run-1",
      healthConnectRecordId: "hc-run-1",
      identityVersion: 2,
      source: "com.garmin.android.apps.connectmobile",
      startedAt: "2026-07-13T11:00:00Z",
      endedAt: "2026-07-13T11:48:00Z",
      durationMinutes: 48,
      elapsedDurationSeconds: 2880,
      activeDurationSeconds: 2760,
      type: "Running",
      title: "Morning run",
      distanceMeters: 8100,
      activeCalories: 575,
      averageHeartRate: 151,
      maximumHeartRate: 176,
      averageCadence: 169,
      elevationGainedMeters: 62,
      routeStatus: "available",
      metricPermissions: {
        distance: true,
        activeCalories: true,
        totalCalories: true,
        heartRate: true,
        speed: true,
        elevation: true,
        cadence: true,
      },
      metricAvailability: {
        distance: true,
        activeCalories: true,
        totalCalories: false,
        heartRate: true,
        speed: false,
        elevation: true,
        cadence: true,
      },
      laps: [{ index: 1, durationSeconds: 1380, distanceMeters: 4000 }],
      segments: [{ index: 1, type: "Running", durationSeconds: 2760, repetitions: null }],
    }],
    samples: { heartRate: [], heartRateVariability: [] },
  };
  const normalizedGarmin = normalizeWatchData(garminSnapshot);
  assert.equal(normalizedGarmin.workouts.length, 1);
  assert.equal(normalizedGarmin.workouts[0].healthConnectRecordId, "hc-run-1");
  assert.equal(normalizedGarmin.workouts[0].source, "com.garmin.android.apps.connectmobile");
  assert.equal(normalizedGarmin.workouts[0].distanceMeters, 8100);
  assert.equal(normalizedGarmin.workouts[0].laps.length, 1);
  assert.equal(normalizedGarmin.workouts[0].segments.length, 1);
  assert.equal(normalizedGarmin.workouts[0].segments[0].weightKg, null, "missing set weight stays unknown rather than becoming zero");
  assert.equal(normalizedGarmin.workouts[0].routeStatus, "available");
  const backupRoundTrip = normalizeWatchData(JSON.parse(JSON.stringify(normalizedGarmin)));
  assert.deepEqual(backupRoundTrip.workouts[0], normalizedGarmin.workouts[0], "rich workouts survive a JSON backup round trip");

  const manualWorkout = {
    id: "archive-workout-1",
    date: "2026-07-13",
    routineName: "Archive routine",
    duration: 40,
    exercises: [],
  };
  const unifiedHistory = combinedWorkoutHistory([manualWorkout], normalizedGarmin.workouts);
  assert.equal(unifiedHistory.length, 2);
  assert.equal(unifiedHistory.filter(({ historyKind }) => historyKind === "external").length, 1);
  assert.equal(manualWorkout.historyKind, undefined, "deriving unified history does not mutate Archive workout records");

  const partialWorkout = normalizeWatchData({
    workouts: [{
      id: "partial-session",
      source: "com.garmin.android.apps.connectmobile",
      date: "2026-07-13",
      type: "Strength",
      segments: [{}],
    }],
  }).workouts[0];
  assert.equal(partialWorkout.elapsedDurationSeconds, null, "an absent duration remains unknown");
  assert.equal(partialWorkout.segments.length, 0, "an empty provider segment is not turned into a fake exercise");

  const correctedGarmin = mergeWatchData(normalizedGarmin, {
    ...garminSnapshot,
    syncedAt: "2026-07-14T15:00:00Z",
    workouts: [{
      ...garminSnapshot.workouts[0],
      title: "Corrected morning run",
      endedAt: "2026-07-13T11:50:00Z",
      durationMinutes: 50,
      elapsedDurationSeconds: 3000,
    }],
  });
  assert.equal(correctedGarmin.workouts.length, 1, "a corrected Health Connect record replaces its prior version");
  assert.equal(correctedGarmin.workouts[0].title, "Corrected morning run");
  assert.equal(correctedGarmin.workouts[0].elapsedDurationSeconds, 3000);

  const partialDaily = mergeWatchData({
    dailySummaries: [{
      date: "2026-07-13",
      steps: 7000,
      distanceMeters: 6500,
      totalCalories: 2400,
      fieldAvailability: { steps: true, distance: true, totalCalories: true },
    }],
  }, {
    ...syncMetadata,
    snapshotCompleteness: {
      ...syncMetadata.snapshotCompleteness,
      dailySummaries: false,
    },
    dailySummaries: [{
      date: "2026-07-13",
      steps: 7600,
      distanceMeters: 0,
      totalCalories: 0,
      fieldAvailability: { steps: true, distance: false, totalCalories: false },
    }],
    sleepSessions: [],
    workouts: [],
    samples: { heartRate: [], heartRateVariability: [] },
  });
  const partialDay = partialDaily.dailySummaries.find(({ date }) => date === "2026-07-13");
  assert.equal(partialDay.steps, 7600);
  assert.equal(partialDay.distanceMeters, 6500, "a missing optional permission does not erase the last attributed distance");
  assert.equal(partialDay.totalCalories, 2400, "a missing optional permission does not erase the last attributed calorie total");

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

  console.log("Health system checks passed: provenance, timezone policy, rich Garmin workout normalization, correction identity, partial permissions, reconciliation, deletion cleanup, and watch-first sleep precedence.");
} finally {
  await vite.close();
}
