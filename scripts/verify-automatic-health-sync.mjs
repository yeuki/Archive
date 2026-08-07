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
  assert.equal(migrated.automaticSyncEnabled, true, "enabled imports migrate to the unified launch-and-pull policy");
  assert.equal(migrated.automaticSyncIntervalMinutes, 0);
  assert.equal(migrated.automaticSyncSnapshotDays, 30);
  assert.equal(migrated.automaticSyncScheduled, false);
  assert.equal(migrated.backgroundReadAvailable, false);
  assert.equal(migrated.backgroundReadGranted, false);

  const legacyAutomaticOptOut = normalizeConnectedHealth({ enabled: true, automaticSyncEnabled: false });
  assert.equal(
    legacyAutomaticOptOut.automaticSyncEnabled,
    true,
    "the single Health Connect import switch supersedes the removed automatic-sync toggle",
  );

  const nativePatch = nativeAutomaticHealthPatch({
    automaticSyncScheduled: true,
    automaticSyncStatus: "foregroundOnly",
    automaticSyncIntervalMinutes: 60,
    automaticSyncSnapshotDays: 3,
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
    automaticSyncIntervalMinutes: 0,
    automaticSyncSnapshotDays: 30,
  });

  const thirtyDayMerge = mergeWatchData({
    dailySummaries: [
      { date: "2026-06-01", steps: 5000 },
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
    syncWindowStart: "2026-06-15T04:00:00Z",
    syncWindowEnd: "2026-07-14T20:00:00Z",
    syncWindowStartDate: "2026-06-15",
    syncWindowEndDate: "2026-07-14",
    sleepDateStart: "2026-06-14",
    sleepDateEnd: "2026-07-13",
    days: 30,
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
  assert.ok(thirtyDayMerge.dailySummaries.some(({ date }) => date === "2026-06-01"), "history outside the launch/pull window is preserved");
  assert.ok(!thirtyDayMerge.dailySummaries.some(({ date }) => date === "2026-07-12"), "stale records inside the authoritative window are removed");
  assert.equal(thirtyDayMerge.healthSystem.syncWindow.days, 30);

  const manifest = await readFile(new URL("../android/app/src/main/AndroidManifest.xml", import.meta.url), "utf8");
  const workerSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/HealthConnectAutoSync.kt", import.meta.url), "utf8");
  const pluginSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/ConnectedHealthPlugin.kt", import.meta.url), "utf8");
  const readerSource = await readFile(new URL("../android/app/src/main/java/com/kyle/archive/ConnectedHealthSnapshotReader.kt", import.meta.url), "utf8");
  const appSource = await readFile(new URL("../src/App.jsx", import.meta.url), "utf8");

  assert.doesNotMatch(manifest, /READ_HEALTH_DATA_IN_BACKGROUND/);
  assert.doesNotMatch(workerSource, /PeriodicWorkRequestBuilder<HealthConnectSyncWorker>/);
  assert.doesNotMatch(workerSource, /ConnectedHealthSnapshotReader\.read/);
  assert.doesNotMatch(workerSource, /fun saveBackgroundSnapshot/);
  assert.match(workerSource, /cancelUniqueWork\(PERIODIC_WORK_NAME\)/);
  assert.match(workerSource, /Kept as a no-op migration target/);
  assert.match(pluginSource, /"launch", "pullToRefresh", "manual"/);
  assert.match(pluginSource, /if \(trigger == "launch"\)/);
  assert.match(readerSource, /"launch", "pullToRefresh", "manual"/);

  assert.match(appSource, /const HEALTH_SYNC_WINDOW_DAYS = 30/);
  assert.match(appSource, /function ArchiveLaunchLogo/);
  assert.match(appSource, /function ArchiveLaunchScreen/);
  assert.match(appSource, /function PullRefreshIndicator/);
  assert.match(appSource, /trigger: "launch"/);
  assert.match(appSource, /trigger: "pullToRefresh"/);
  assert.match(appSource, /addEventListener\("touchmove", handleTouchMove, \{ passive: false \}\)/);
  assert.doesNotMatch(appSource, /setInterval\(refreshIfActive/);
  assert.doesNotMatch(appSource, /appStateChange/);
  assert.doesNotMatch(appSource, /Sync watch data/);
  assert.doesNotMatch(appSource, /onSyncSleep/);
  assert.doesNotMatch(appSource, /requestAutomaticHealthPermissions/);
  assert.match(appSource, /function BottomNav/);
  assert.match(appSource, /productivity:\s*\[/);
  assert.match(appSource, /health:\s*\[/);
  assert.doesNotMatch(appSource, /function SectionTabs/);

  console.log("Launch-and-pull Health Connect checks passed: 30-day reconciliation, branded launch gating, pull gesture, v0.8 navigation hierarchy, legacy-job cancellation, and no periodic/background/manual-button sync path.");
} finally {
  await vite.close();
}
