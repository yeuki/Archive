package com.kyle.archive

import android.content.Context
import android.util.AtomicFile
import androidx.work.CoroutineWorker
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.getcapacitor.JSObject
import java.io.File
import java.time.Instant

internal data class AutomaticSyncConfig(
    val enabled: Boolean,
    val intervalMinutes: Int,
    val snapshotDays: Int,
)

/** Private native storage for launch policy and a legacy unapplied snapshot. */
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
                if (enabled) "Health data refreshes on launch and pull-to-refresh." else "Health Connect import is off.",
            )
            .apply()
        return normalized
    }

    fun markAttempt(context: Context, at: String = Instant.now().toString()) {
        prefs(context).edit()
            .putString(KEY_LAST_ATTEMPT_AT, at)
            .putString(KEY_STATUS, "running")
            .putString(KEY_MESSAGE, "Refreshing Health Connect data while Archive launches.")
            .apply()
    }

    fun markForegroundSuccess(context: Context, syncedAt: String) {
        prefs(context).edit()
            .putString(KEY_LAST_ATTEMPT_AT, syncedAt)
            .putString(KEY_LAST_AUTOMATIC_SYNC_AT, syncedAt)
            .putString(KEY_STATUS, "synced")
            .putString(KEY_MESSAGE, "Health data refreshed when Archive launched.")
            .apply()
    }

    fun markError(context: Context, message: String) {
        prefs(context).edit()
            .putString(KEY_STATUS, "error")
            .putString(KEY_MESSAGE, message.take(240))
            .apply()
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

    fun statusPayload(context: Context): JSObject {
        val prefs = prefs(context)
        val config = config(context)
        val storedStatus = prefs.getString(KEY_STATUS, if (config.enabled) "scheduled" else "off") ?: "off"
        val resolvedStatus = when {
            !config.enabled -> "off"
            storedStatus in setOf("running", "synced", "error") -> storedStatus
            else -> "foregroundOnly"
        }
        val resolvedMessage = when {
            !config.enabled -> "Health Connect import is off."
            else -> prefs.getString(KEY_MESSAGE, "Health data refreshes on launch and pull-to-refresh.")
                ?: "Health data refreshes on launch and pull-to-refresh."
        }

        return JSObject().apply {
            put("automaticSyncEnabled", config.enabled)
            put("automaticSyncIntervalMinutes", 0)
            put("automaticSyncSnapshotDays", config.snapshotDays)
            put("automaticSyncScheduled", false)
            put("automaticSyncStatus", resolvedStatus)
            put("automaticSyncMessage", resolvedMessage)
            put("backgroundReadAvailable", false)
            put("backgroundReadGranted", false)
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

    const val DEFAULT_INTERVAL_MINUTES = 0
    const val DEFAULT_SNAPSHOT_DAYS = 30
    const val MIN_INTERVAL_MINUTES = 0
    const val MAX_INTERVAL_MINUTES = 1440
    const val MAX_SNAPSHOT_DAYS = 30
}

internal object HealthConnectAutoSyncScheduler {
    private const val PERIODIC_WORK_NAME = "archive_health_connect_periodic"
    private const val IMMEDIATE_WORK_NAME = "archive_health_connect_initial"

    fun configure(
        context: Context,
        enabled: Boolean,
        intervalMinutes: Int,
        snapshotDays: Int,
    ): AutomaticSyncConfig {
        val appContext = context.applicationContext
        val config = HealthConnectAutoSyncStore.updateConfig(
            appContext,
            enabled,
            intervalMinutes,
            snapshotDays,
        )
        val workManager = WorkManager.getInstance(appContext)
        // Version upgrades may leave WorkManager jobs created by the old hourly
        // policy. Always cancel both unique jobs; launch and pull-to-refresh
        // syncing now run only from explicit foreground WebView interactions.
        workManager.cancelUniqueWork(PERIODIC_WORK_NAME)
        workManager.cancelUniqueWork(IMMEDIATE_WORK_NAME)
        return config
    }

}

class HealthConnectSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        // Kept as a no-op migration target so a job persisted by an older APK
        // cannot perform a watch read before the new policy cancels it.
        return Result.success()
    }
}
