import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createServer } from "vite";

const vite = await createServer({
  appType: "custom",
  optimizeDeps: { noDiscovery: true },
  server: { middlewareMode: true, hmr: false },
});

try {
  const {
    mergeWatchData,
    nativeAutomaticHealthPatch,
    normalizeConnectedHealth,
  } = await vite.ssrLoadModule("/src/App.jsx");

  const migrated = normalizeConnectedHealth({ enabled: true });
  assert.equal(migrated.automaticSyncEnabled, true, "existing enabled connections migrate to automatic foreground sync");
  assert.equal(migrated.automaticSyncIntervalMinutes, 60);
  assert.equal(migrated.automaticSyncSnapshotDays, 3);

  const explicitlyDisabled = normalizeConnectedHealth({ enabled: true, automaticSyncEnabled: false });
  assert.equal(explicitlyDisabled.automaticSyncEnabled, false, "an explicit user opt-out is preserved");

  const nativePatch = nativeAutomaticHealthPatch({
    automaticSyncEnabled: true,
    automaticSyncScheduled: true,
    automaticSyncStatus: "scheduled",
    backgroundReadAvailable: true,
    backgroundReadGranted: true,
    lastBackgroundSyncAt: "2026-07-14T20:00:00Z",
  });
  assert.deepEqual(nativePatch, {
    automaticSyncScheduled: true,
    backgroundReadAvailable: true,
    backgroundReadGranted: true,
    lastBackgroundSyncAt: "2026-07-14T20:00:00.000Z",
    automaticSyncStatus: "scheduled",
  });

  const backgroundMerge = mergeWatchData({
    dailySummaries: [
      { date: "2026-07-10", steps: 5000 },
      { date: "2026-07-12", steps: 6000 },
    ],
    sleepSessions: [],
    workouts: [],
    samples: { heartRate: [], heartRateVariability: [] },
  }, {
    provider: "healthConnect",
    healthSchemaVersion: 1,
    policyVersion: "archive-health-1",
    timeZone: "America/Toronto",
    syncedAt: "2026-07-14T20:00:00Z",
    syncWindowStart: "2026-07-12T04:00:00Z",
    syncWindowEnd: "2026-07-14T20:00:00Z",
    syncWindowStartDate: "2026-07-12",
    syncWindowEndDate: "2026-07-14",
    sleepDateStart: "2026-07-11",
    sleepDateEnd: "2026-07-13",
    days: 3,
    completeSnapshot: true,
    snapshotCompleteness: {
      dailySummaries: true,
      sleepSessions: true,
      workouts: true,
      heartRate: false,
      heartRateVariability: false,
    },
    dailySummaries: [
      { date: "2026-07-13", steps: 7000 },
      { date: "2026-07-14", steps: 8000 },
    ],
    sleepSessions: [],
    workouts: [],
    samples: { heartRate: [], heartRateVariability: [] },
  });
  assert.ok(backgroundMerge.dailySummaries.some(({ date }) => date === "2026-07-10"), "background windows preserve older canonical history");
  assert.ok(!backgroundMerge.dailySummaries.some(({ date }) => date === "2026-07-12"), "authoritative background windows remove stale records only inside their window");
  assert.equal(backgroundMerge.healthSystem.syncWindow.days, 3);

  const manifest = await readFile(new URL("../android/app/src/main/AndroidManifest.xml", import.meta.url), "utf8");
  const workerSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/HealthConnectAutoSync.kt", import.meta.url), "utf8");
  const pluginSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/ConnectedHealthPlugin.kt", import.meta.url), "utf8");
  assert.match(manifest, /READ_HEALTH_DATA_IN_BACKGROUND/);
  assert.match(workerSource, /PeriodicWorkRequestBuilder<HealthConnectSyncWorker>/);
  assert.match(workerSource, /AtomicFile/);
  assert.match(pluginSource, /requestAutomaticSyncPermissions/);
  assert.match(pluginSource, /getPendingAutomaticSync/);
  assert.match(pluginSource, /acknowledgeAutomaticSync/);

  console.log("Automatic health sync checks passed: migration, native status mapping, bounded background reconciliation, permission declaration, worker scheduling, and durable snapshot handoff.");
} finally {
  await vite.close();
}
