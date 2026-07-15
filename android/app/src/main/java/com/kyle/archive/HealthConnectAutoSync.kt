package com.kyle.archive

import android.content.Context
import android.util.AtomicFile
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.work.BackoffPolicy
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.getcapacitor.JSObject
import java.io.File
import java.time.Instant
import java.util.UUID
import java.util.concurrent.TimeUnit

internal data class AutomaticSyncConfig(
    val enabled: Boolean,
    val intervalMinutes: Int,
    val snapshotDays: Int,
)

/** Private native storage for scheduler state and the latest unapplied snapshot. */
internal object HealthConnectAutoSyncStore {
    private const val PREFS_NAME = "archive_health_connect_auto_sync"
    private const val SNAPSHOT_DIRECTORY = "connected-health"
    private const val SNAPSHOT_FILE = "pending-automatic-snapshot.json"

    private const val KEY_ENABLED = "enabled"
    private const val KEY_INTERVAL_MINUTES = "interval_minutes"
    private const val KEY_SNAPSHOT_DAYS = "snapshot_days"
    private const val KEY_STATUS = "status"
    private const val KEY_MESSAGE = "message"
    private const val KEY_LAST_ATTEMPT_AT = "last_attempt_at"
    private const val KEY_LAST_AUTOMATIC_SYNC_AT = "last_automatic_sync_at"
    private const val KEY_LAST_BACKGROUND_SYNC_AT = "last_background_sync_at"
    private const val KEY_LAST_APPLIED_AT = "last_applied_at"
    private const val KEY_PENDING_SNAPSHOT_ID = "pending_snapshot_id"
    private const val KEY_PENDING_CAPTURED_AT = "pending_captured_at"

    private val lock = Any()

    fun config(context: Context): AutomaticSyncConfig {
        val prefs = prefs(context)
        return AutomaticSyncConfig(
            enabled = prefs.getBoolean(KEY_ENABLED, false),
            intervalMinutes = prefs.getInt(KEY_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)
                .coerceIn(MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES),
            snapshotDays = prefs.getInt(KEY_SNAPSHOT_DAYS, DEFAULT_SNAPSHOT_DAYS)
                .coerceIn(1, MAX_SNAPSHOT_DAYS),
        )
    }

    fun updateConfig(
        context: Context,
        enabled: Boolean,
        intervalMinutes: Int,
        snapshotDays: Int,
    ): AutomaticSyncConfig {
        val normalized = AutomaticSyncConfig(
            enabled = enabled,
            intervalMinutes = intervalMinutes.coerceIn(MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES),
            snapshotDays = snapshotDays.coerceIn(1, MAX_SNAPSHOT_DAYS),
        )
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, normalized.enabled)
            .putInt(KEY_INTERVAL_MINUTES, normalized.intervalMinutes)
            .putInt(KEY_SNAPSHOT_DAYS, normalized.snapshotDays)
            .putString(KEY_STATUS, if (enabled) "scheduled" else "off")
            .putString(
                KEY_MESSAGE,
                if (enabled) "Automatic foreground refresh is enabled." else "Automatic health sync is off.",
            )
            .apply()
        return normalized
    }

    fun markAttempt(context: Context, at: String = Instant.now().toString()) {
        prefs(context).edit()
            .putString(KEY_LAST_ATTEMPT_AT, at)
            .putString(KEY_STATUS, "running")
            .putString(KEY_MESSAGE, "Checking Health Connect in the background.")
            .apply()
    }

    fun markForegroundSuccess(context: Context, syncedAt: String) {
        prefs(context).edit()
            .putString(KEY_LAST_ATTEMPT_AT, syncedAt)
            .putString(KEY_LAST_AUTOMATIC_SYNC_AT, syncedAt)
            .putString(KEY_STATUS, "synced")
            .putString(KEY_MESSAGE, "Health data refreshed when Archive became active.")
            .apply()
    }

    fun markPermissionNeeded(context: Context, backgroundAvailable: Boolean) {
        prefs(context).edit()
            .putString(KEY_STATUS, if (backgroundAvailable) "permissionNeeded" else "foregroundOnly")
            .putString(
                KEY_MESSAGE,
                if (backgroundAvailable) {
                    "Allow background health access for hourly sync while Archive is closed."
                } else {
                    "This device supports automatic refresh only while Archive is active."
                },
            )
            .apply()
    }

    fun markError(context: Context, message: String) {
        prefs(context).edit()
            .putString(KEY_STATUS, "error")
            .putString(KEY_MESSAGE, message.take(240))
            .apply()
    }

    fun saveBackgroundSnapshot(context: Context, payload: JSObject) {
        synchronized(lock) {
            val snapshotId = UUID.randomUUID().toString()
            val capturedAt = payload.getString("syncedAt") ?: Instant.now().toString()
            payload.put("automaticSnapshotId", snapshotId)
            payload.put("backgroundCapturedAt", capturedAt)
            payload.put("syncTrigger", "background")

            val atomicFile = snapshotFile(context)
            var output = atomicFile.startWrite()
            try {
                output.write(payload.toString().toByteArray(Charsets.UTF_8))
                atomicFile.finishWrite(output)
            } catch (error: Exception) {
                atomicFile.failWrite(output)
                throw error
            }

            prefs(context).edit()
                .putString(KEY_PENDING_SNAPSHOT_ID, snapshotId)
                .putString(KEY_PENDING_CAPTURED_AT, capturedAt)
                .putString(KEY_LAST_ATTEMPT_AT, capturedAt)
                .putString(KEY_LAST_AUTOMATIC_SYNC_AT, capturedAt)
                .putString(KEY_LAST_BACKGROUND_SYNC_AT, capturedAt)
                .putString(KEY_STATUS, "captured")
                .putString(KEY_MESSAGE, "Background health data is ready to apply in Archive.")
                .apply()
        }
    }

    fun pendingSnapshot(context: Context): JSObject? {
        synchronized(lock) {
            val file = snapshotFile(context)
            if (!file.baseFile.exists()) return null
            return try {
                JSObject(String(file.readFully(), Charsets.UTF_8))
            } catch (_: Exception) {
                markError(context, "Archive could not read its pending background health snapshot.")
                null
            }
        }
    }

    fun acknowledgeSnapshot(context: Context, snapshotId: String): Boolean {
        synchronized(lock) {
            val pendingId = prefs(context).getString(KEY_PENDING_SNAPSHOT_ID, "") ?: ""
            if (snapshotId.isBlank() || snapshotId != pendingId) return false
            snapshotFile(context).delete()
            val appliedAt = Instant.now().toString()
            prefs(context).edit()
                .remove(KEY_PENDING_SNAPSHOT_ID)
                .remove(KEY_PENDING_CAPTURED_AT)
                .putString(KEY_LAST_APPLIED_AT, appliedAt)
                .putString(KEY_STATUS, "synced")
                .putString(KEY_MESSAGE, "Background health data was reconciled into Archive.")
                .apply()
            return true
        }
    }

    fun statusPayload(
        context: Context,
        backgroundAvailable: Boolean,
        backgroundGranted: Boolean,
        workerScheduled: Boolean,
    ): JSObject {
        val prefs = prefs(context)
        val config = config(context)
        val storedStatus = prefs.getString(KEY_STATUS, if (config.enabled) "scheduled" else "off") ?: "off"
        val resolvedStatus = when {
            !config.enabled -> "off"
            !backgroundAvailable -> "foregroundOnly"
            !backgroundGranted -> "permissionNeeded"
            else -> storedStatus
        }
        val resolvedMessage = when {
            !config.enabled -> "Automatic health sync is off."
            !backgroundAvailable -> "This device will refresh automatically whenever Archive is active."
            !backgroundGranted -> "Background permission is needed for hourly sync while Archive is closed."
            else -> prefs.getString(KEY_MESSAGE, "Automatic health sync is scheduled.")
                ?: "Automatic health sync is scheduled."
        }

        return JSObject().apply {
            put("automaticSyncEnabled", config.enabled)
            put("automaticSyncIntervalMinutes", config.intervalMinutes)
            put("automaticSyncSnapshotDays", config.snapshotDays)
            put("automaticSyncScheduled", workerScheduled)
            put("automaticSyncStatus", resolvedStatus)
            put("automaticSyncMessage", resolvedMessage)
            put("backgroundReadAvailable", backgroundAvailable)
            put("backgroundReadGranted", backgroundGranted)
            put("lastAutomaticAttemptAt", prefs.getString(KEY_LAST_ATTEMPT_AT, "") ?: "")
            put("lastAutomaticSyncAt", prefs.getString(KEY_LAST_AUTOMATIC_SYNC_AT, "") ?: "")
            put("lastBackgroundSyncAt", prefs.getString(KEY_LAST_BACKGROUND_SYNC_AT, "") ?: "")
            put("lastAutomaticAppliedAt", prefs.getString(KEY_LAST_APPLIED_AT, "") ?: "")
            put("pendingAutomaticSync", pendingSnapshot(context) != null)
            put("pendingAutomaticSnapshotId", prefs.getString(KEY_PENDING_SNAPSHOT_ID, "") ?: "")
            put("pendingAutomaticCapturedAt", prefs.getString(KEY_PENDING_CAPTURED_AT, "") ?: "")
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun snapshotFile(context: Context): AtomicFile {
        val directory = File(context.filesDir, SNAPSHOT_DIRECTORY)
        if (!directory.exists()) directory.mkdirs()
        return AtomicFile(File(directory, SNAPSHOT_FILE))
    }

    const val DEFAULT_INTERVAL_MINUTES = 60
    const val DEFAULT_SNAPSHOT_DAYS = 3
    const val MIN_INTERVAL_MINUTES = 15
    const val MAX_INTERVAL_MINUTES = 1440
    const val MAX_SNAPSHOT_DAYS = 7
}

internal object HealthConnectAutoSyncScheduler {
    private const val PERIODIC_WORK_NAME = "archive_health_connect_periodic"
    private const val IMMEDIATE_WORK_NAME = "archive_health_connect_initial"

    fun configure(
        context: Context,
        enabled: Boolean,
        intervalMinutes: Int,
        snapshotDays: Int,
        backgroundAllowed: Boolean,
        backgroundAvailable: Boolean,
        enqueueInitial: Boolean = false,
    ): AutomaticSyncConfig {
        val appContext = context.applicationContext
        val config = HealthConnectAutoSyncStore.updateConfig(
            appContext,
            enabled,
            intervalMinutes,
            snapshotDays,
        )
        val workManager = WorkManager.getInstance(appContext)

        if (!enabled || !backgroundAllowed) {
            workManager.cancelUniqueWork(PERIODIC_WORK_NAME)
            workManager.cancelUniqueWork(IMMEDIATE_WORK_NAME)
            if (enabled && !backgroundAllowed) {
                HealthConnectAutoSyncStore.markPermissionNeeded(appContext, backgroundAvailable)
            }
            return config
        }

        val request = PeriodicWorkRequestBuilder<HealthConnectSyncWorker>(
            config.intervalMinutes.toLong(),
            TimeUnit.MINUTES,
        )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .addTag(PERIODIC_WORK_NAME)
            .build()

        workManager.enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )

        if (enqueueInitial) {
            val initial = OneTimeWorkRequestBuilder<HealthConnectSyncWorker>()
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
                .addTag(IMMEDIATE_WORK_NAME)
                .build()
            workManager.enqueueUniqueWork(IMMEDIATE_WORK_NAME, ExistingWorkPolicy.REPLACE, initial)
        }
        return config
    }

    fun workerIsScheduled(config: AutomaticSyncConfig, backgroundAllowed: Boolean): Boolean {
        return config.enabled && backgroundAllowed
    }
}

class HealthConnectSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        val context = applicationContext
        val config = HealthConnectAutoSyncStore.config(context)
        if (!config.enabled) return Result.success()

        HealthConnectAutoSyncStore.markAttempt(context)
        val sdkStatus = try {
            HealthConnectClient.getSdkStatus(context)
        } catch (_: Exception) {
            HealthConnectClient.SDK_UNAVAILABLE
        }
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectAutoSyncStore.markError(context, "Health Connect is unavailable for background sync.")
            return Result.success()
        }

        val client = HealthConnectClient.getOrCreate(context)
        val backgroundAvailable = client.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND,
        ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        if (!backgroundAvailable) {
            HealthConnectAutoSyncStore.markPermissionNeeded(context, false)
            return Result.success()
        }

        val granted = try {
            client.permissionController.getGrantedPermissions()
        } catch (error: Exception) {
            return retryOrContinue("Could not check background health permissions: ${error.message ?: "unknown error"}")
        }
        val backgroundGranted = granted.contains(HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND)
        if (!granted.containsAll(ConnectedHealthSnapshotReader.readPermissions) || !backgroundGranted) {
            HealthConnectAutoSyncStore.markPermissionNeeded(context, true)
            return Result.success()
        }

        return try {
            val payload = ConnectedHealthSnapshotReader.read(
                client = client,
                requestedDays = config.snapshotDays,
                trigger = "background",
            )
            HealthConnectAutoSyncStore.saveBackgroundSnapshot(context, payload)
            Result.success()
        } catch (_: SecurityException) {
            HealthConnectAutoSyncStore.markPermissionNeeded(context, true)
            Result.success()
        } catch (error: Exception) {
            retryOrContinue("Background Health Connect sync failed: ${error.message ?: "unknown error"}")
        }
    }

    private fun retryOrContinue(message: String): Result {
        HealthConnectAutoSyncStore.markError(applicationContext, message)
        return if (runAttemptCount < 2) Result.retry() else Result.success()
    }
}
