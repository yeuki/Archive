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
  assert.equal(migrated.automaticSyncEnabled, true, "existing enabled connections migrate to sync-on-open");
  assert.equal(migrated.automaticSyncIntervalMinutes, 0);
  assert.equal(migrated.automaticSyncSnapshotDays, 3);
  assert.equal(migrated.automaticSyncScheduled, false);
  assert.equal(migrated.backgroundReadGranted, false);

  const explicitlyDisabled = normalizeConnectedHealth({ enabled: true, automaticSyncEnabled: false });
  assert.equal(explicitlyDisabled.automaticSyncEnabled, false, "an explicit user opt-out is preserved");

  const nativePatch = nativeAutomaticHealthPatch({
    automaticSyncEnabled: true,
    automaticSyncScheduled: true,
    automaticSyncStatus: "foregroundOnly",
    backgroundReadAvailable: true,
    backgroundReadGranted: true,
    lastBackgroundSyncAt: "2026-07-14T20:00:00Z",
  });
  assert.deepEqual(nativePatch, {
    automaticSyncScheduled: false,
    backgroundReadAvailable: false,
    backgroundReadGranted: false,
    lastBackgroundSyncAt: "2026-07-14T20:00:00.000Z",
    automaticSyncStatus: "foregroundOnly",
  });

  const openMerge = mergeWatchData({
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
  assert.ok(openMerge.dailySummaries.some(({ date }) => date === "2026-07-10"), "open-time windows preserve older canonical history");
  assert.ok(!openMerge.dailySummaries.some(({ date }) => date === "2026-07-12"), "authoritative open-time windows remove stale records only inside their window");
  assert.equal(openMerge.healthSystem.syncWindow.days, 3);

  const manifest = await readFile(new URL("../android/app/src/main/AndroidManifest.xml", import.meta.url), "utf8");
  const workerSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/HealthConnectAutoSync.kt", import.meta.url), "utf8");
  const pluginSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/ConnectedHealthPlugin.kt", import.meta.url), "utf8");
  const appSource = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");
  assert.doesNotMatch(manifest, /READ_HEALTH_DATA_IN_BACKGROUND/);
  assert.doesNotMatch(workerSource, /PeriodicWorkRequestBuilder<HealthConnectSyncWorker>/);
  assert.doesNotMatch(workerSource, /ConnectedHealthSnapshotReader\.read/);
  assert.match(workerSource, /cancelUniqueWork\(PERIODIC_WORK_NAME\)/);
  assert.match(workerSource, /Kept as a no-op migration target/);
  assert.match(workerSource, /AtomicFile/);
  assert.match(pluginSource, /requestAutomaticSyncPermissions/);
  assert.match(pluginSource, /getPendingAutomaticSync/);
  assert.match(pluginSource, /acknowledgeAutomaticSync/);
  assert.doesNotMatch(appSource, /setInterval\(refreshIfActive/);
  assert.doesNotMatch(appSource, /appStateChange/);
  assert.match(appSource, /const OPEN_HEALTH_SNAPSHOT_DAYS = 3/);
  assert.match(appSource, /const STARTUP_MINIMUM_MS = 1500/);
  assert.match(appSource, /function StartupScreen/);

  console.log("Open-only health sync checks passed: migration, three-day reconciliation, no background permission, no periodic worker reads, legacy-job cancellation, and branded startup gating.");
} finally {
  await vite.close();
}
