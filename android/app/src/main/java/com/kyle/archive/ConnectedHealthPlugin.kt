package com.kyle.archive

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@CapacitorPlugin(name = "ConnectedHealth")
class ConnectedHealthPlugin : Plugin() {
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingPermissionCall: PluginCall? = null

    private val readPermissions
        get() = ConnectedHealthSnapshotReader.readPermissions
    override fun load() {
        permissionLauncher = activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { grantedPermissions ->
            val call = pendingPermissionCall
            pendingPermissionCall = null
            call?.resolve(
                permissionPayload(
                    grantedPermissions,
                    "Health Connect permissions updated.",
                ),
            )
        }

        // Cancel jobs that may have survived an upgrade from the old hourly policy.
        val config = HealthConnectAutoSyncStore.config(context)
        HealthConnectAutoSyncScheduler.configure(
            context = context,
            enabled = config.enabled,
            intervalMinutes = 0,
            snapshotDays = config.snapshotDays,
        )
    }

    @PluginMethod
    fun getStatus(call: PluginCall) {
        val client = healthClientOrNull()
        if (client == null) {
            call.resolve(buildStatusPayload())
            return
        }

        pluginScope.launch {
            val granted = runCatching {
                withContext(Dispatchers.IO) { client.permissionController.getGrantedPermissions() }
            }.getOrDefault(emptySet())
            call.resolve(buildStatusPayload(granted))
        }
    }

    @PluginMethod
    fun getSupportedMetrics(call: PluginCall) {
        val metrics = JSArray().apply {
            put(metric("steps", "Steps", "daily", "steps"))
            put(metric("sleep", "Sleep", "nightly", "sessions"))
            put(metric("exercise", "Exercise sessions", "as completed", "workouts"))
            put(metric("distance", "Distance", "daily", "m"))
            put(metric("activeCalories", "Active calories", "daily", "kcal"))
            put(metric("heartRate", "Heart rate", "samples", "bpm"))
            put(metric("heartRateVariability", "HRV", "samples", "ms"))
            put(metric("floors", "Floors climbed", "daily", "floors"))
        }
        call.resolve(JSObject().apply { put("metrics", metrics) })
    }

    @PluginMethod
    fun checkHealthPermissions(call: PluginCall) {
        val client = healthClientOrNull()
        if (client == null) {
            call.resolve(unavailablePermissionPayload())
            return
        }

        pluginScope.launch {
            try {
                val granted = withContext(Dispatchers.IO) {
                    client.permissionController.getGrantedPermissions()
                }
                call.resolve(permissionPayload(granted, "Health Connect permission status checked."))
            } catch (error: Exception) {
                call.reject("Archive could not check Health Connect permissions.", error)
            }
        }
    }

    @PluginMethod
    fun requestHealthPermissions(call: PluginCall) {
        requestHealthDataPermissions(call)
    }

    @PluginMethod
    fun requestAutomaticSyncPermissions(call: PluginCall) {
        requestHealthDataPermissions(call)
    }

    private fun requestHealthDataPermissions(call: PluginCall) {
        val client = healthClientOrNull()
        val launcher = permissionLauncher
        if (client == null) {
            call.resolve(unavailablePermissionPayload())
            return
        }
        if (launcher == null) {
            call.reject("Health Connect permission launcher is not ready yet. Close and reopen Archive, then try again.")
            return
        }

        pluginScope.launch {
            try {
                val granted = withContext(Dispatchers.IO) {
                    client.permissionController.getGrantedPermissions()
                }
                val requested = readPermissions

                if (granted.containsAll(requested)) {
                    call.resolve(
                        permissionPayload(
                            granted,
                            "All requested Health Connect permissions are already granted.",
                        ),
                    )
                    return@launch
                }

                if (pendingPermissionCall != null) {
                    call.reject("A Health Connect permission request is already open.")
                    return@launch
                }

                pendingPermissionCall = call
                launcher.launch(requested)
            } catch (error: Exception) {
                pendingPermissionCall = null
                call.reject("Archive could not request Health Connect permissions.", error)
            }
        }
    }

    @PluginMethod
    fun syncRecentData(call: PluginCall) {
        val days = (call.getInt("days", 30) ?: 30).coerceIn(1, 30)
        val trigger = when (call.getString("trigger", "manual")) {
            "background", "foregroundAuto", "manual" -> call.getString("trigger", "manual") ?: "manual"
            else -> "manual"
        }
        val client = healthClientOrNull()

        if (client == null) {
            val payload = buildStatusPayload().apply {
                put("synced", false)
                put("needsPermissions", false)
                put("dailySummaries", JSArray())
                put("sleepSessions", JSArray())
                put("workouts", JSArray())
                put("samples", emptySamples())
            }
            call.resolve(payload)
            return
        }

        pluginScope.launch {
            try {
                val granted = withContext(Dispatchers.IO) {
                    client.permissionController.getGrantedPermissions()
                }
                if (!granted.containsAll(readPermissions)) {
                    val payload = permissionPayload(
                        granted,
                        "Health Connect permissions are needed before Archive can import watch data.",
                    ).apply {
                        put("synced", false)
                        put("needsPermissions", true)
                        put("dailySummaries", JSArray())
                        put("sleepSessions", JSArray())
                        put("workouts", JSArray())
                        put("samples", emptySamples())
                    }
                    call.resolve(payload)
                    return@launch
                }

                val payload = withContext(Dispatchers.IO) {
                    ConnectedHealthSnapshotReader.read(client, days, trigger)
                }
                if (trigger == "foregroundAuto") {
                    HealthConnectAutoSyncStore.markForegroundSuccess(
                        context,
                        payload.getString("syncedAt") ?: "",
                    )
                }
                mergeJson(payload, automaticStatusPayload())
                call.resolve(payload)
            } catch (error: Exception) {
                if (trigger == "foregroundAuto") {
                    HealthConnectAutoSyncStore.markError(
                        context,
                        "Automatic health refresh failed: ${error.message ?: "unknown error"}",
                    )
                }
                call.reject("Archive could not sync Health Connect data.", error)
            }
        }
    }

    @PluginMethod
    fun configureAutomaticSync(call: PluginCall) {
        val enabled = call.getBoolean("enabled", true) ?: true
        val intervalMinutes = call.getInt(
            "intervalMinutes",
            HealthConnectAutoSyncStore.DEFAULT_INTERVAL_MINUTES,
        ) ?: HealthConnectAutoSyncStore.DEFAULT_INTERVAL_MINUTES
        val snapshotDays = call.getInt(
            "snapshotDays",
            HealthConnectAutoSyncStore.DEFAULT_SNAPSHOT_DAYS,
        ) ?: HealthConnectAutoSyncStore.DEFAULT_SNAPSHOT_DAYS
        HealthConnectAutoSyncScheduler.configure(
            context = context,
            enabled = enabled,
            intervalMinutes = intervalMinutes,
            snapshotDays = snapshotDays,
        )
        call.resolve(automaticStatusPayload())
    }

    @PluginMethod
    fun getAutomaticSyncStatus(call: PluginCall) {
        call.resolve(automaticStatusPayload())
    }

    @PluginMethod
    fun getPendingAutomaticSync(call: PluginCall) {
        pluginScope.launch {
            val result = automaticStatusPayload()
            val pending = withContext(Dispatchers.IO) {
                HealthConnectAutoSyncStore.pendingSnapshot(context)
            }
            result.put("pending", pending != null)
            if (pending != null) result.put("payload", pending)
            call.resolve(result)
        }
    }

    @PluginMethod
    fun acknowledgeAutomaticSync(call: PluginCall) {
        val snapshotId = call.getString("snapshotId", "") ?: ""
        val acknowledged = HealthConnectAutoSyncStore.acknowledgeSnapshot(context, snapshotId)
        val result = HealthConnectAutoSyncStore.statusPayload(context)
        result.put("acknowledged", acknowledged)
        call.resolve(result)
    }

    @PluginMethod
    fun openSettings(call: PluginCall) {
        val status = buildStatusPayload()
        val candidates = mutableListOf<Intent>()
        val settingsIntent = firstResolvableSettingsIntent()
        val systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        val packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE)

        if (settingsIntent != null) candidates.add(settingsIntent)
        if (packageInstalled) {
            candidates.add(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$HEALTH_CONNECT_PACKAGE")
                },
            )
        }
        candidates.add(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$HEALTH_CONNECT_PACKAGE")))
        candidates.add(Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_STORE_URL)))

        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (!canResolve(intent)) continue
            try {
                activity.startActivity(intent)
                status.put("opened", true)
                status.put(
                    "message",
                    if (packageInstalled || systemIntegrated) {
                        "Opened Health Connect settings."
                    } else {
                        "Opened Health Connect install page."
                    },
                )
                call.resolve(status)
                return
            } catch (_: ActivityNotFoundException) {
                // Try the next safe fallback.
            }
        }

        status.put("opened", false)
        status.put("status", "unavailable")
        status.put("message", "Archive could not find Health Connect settings or the Play Store page on this device.")
        call.resolve(status)
    }

    private fun permissionPayload(grantedPermissions: Set<String>, message: String): JSObject {
        val grantedRequested = grantedPermissions.intersect(readPermissions)
        val missing = readPermissions - grantedPermissions
        val status = buildStatusPayload(grantedPermissions)
        val healthAvailable = status.getBool("available") ?: false

        status.put(
            "status",
            if (!healthAvailable) "unavailable" else if (missing.isEmpty()) "available" else "permissionsNeeded",
        )
        status.put(
            "message",
            if (missing.isEmpty()) message else "Archive needs Health Connect permission before it can import watch data.",
        )
        status.put("allGranted", missing.isEmpty())
        status.put("permissionsGranted", missing.isEmpty())
        status.put("requestedPermissions", stringArray(readPermissions))
        status.put("grantedPermissions", stringArray(grantedRequested))
        status.put("missingPermissions", stringArray(missing))
        status.put("backgroundReadAvailable", false)
        status.put("backgroundReadGranted", false)
        return status
    }

    private fun unavailablePermissionPayload(): JSObject {
        return buildStatusPayload().apply {
            put("allGranted", false)
            put("permissionsGranted", false)
            put("requestedPermissions", stringArray(readPermissions))
            put("grantedPermissions", JSArray())
            put("missingPermissions", stringArray(readPermissions))
            put("backgroundReadAvailable", false)
            put("backgroundReadGranted", false)
        }
    }

    private fun buildStatusPayload(grantedPermissions: Set<String> = emptySet()): JSObject {
        val systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        val packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE)
        val settingsResolvable = firstResolvableSettingsIntent() != null
        val sdkStatus = healthConnectSdkStatus()
        val sdkAvailable = sdkStatus == HealthConnectClient.SDK_AVAILABLE
        val updateRequired = sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED
        val available = sdkAvailable || systemIntegrated || packageInstalled || settingsResolvable
        val client = if (sdkAvailable) HealthConnectClient.getOrCreate(context) else null

        return JSObject().apply {
            put("platform", "android")
            put("available", available)
            put("status", if (available) "available" else "unavailable")
            put("systemIntegrated", systemIntegrated)
            put("packageInstalled", packageInstalled)
            put("settingsResolvable", settingsResolvable)
            put("sdkAvailable", sdkAvailable)
            put("updateRequired", updateRequired)
            put("sdkStatus", sdkStatusLabel(sdkStatus))
            put("healthConnectPackage", HEALTH_CONNECT_PACKAGE)
            put(
                "message",
                when {
                    sdkAvailable -> "Health Connect is available. Archive can request permissions and import watch data."
                    updateRequired -> "Health Connect needs to be installed or updated before Archive can import watch data."
                    available -> "Health Connect settings are visible, but the SDK is not ready yet. Open Health Connect and try again."
                    else -> "Health Connect was not found. Install or enable it, then check again."
                },
            )
            mergeJson(this, automaticStatusPayload())
        }
    }

    private fun automaticStatusPayload(): JSObject {
        return HealthConnectAutoSyncStore.statusPayload(context)
    }

    private fun healthClientOrNull(): HealthConnectClient? {
        return if (healthConnectSdkStatus() == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(context)
        } else {
            null
        }
    }

    private fun healthConnectSdkStatus(): Int {
        return try {
            HealthConnectClient.getSdkStatus(context)
        } catch (_: Exception) {
            HealthConnectClient.SDK_UNAVAILABLE
        }
    }

    private fun sdkStatusLabel(status: Int): String {
        return when (status) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "updateRequired"
            HealthConnectClient.SDK_UNAVAILABLE -> "unavailable"
            else -> "unknown"
        }
    }

    private fun firstResolvableSettingsIntent(): Intent? {
        for (action in HEALTH_CONNECT_SETTINGS_ACTIONS) {
            val directIntent = Intent(action)
            if (canResolve(directIntent)) return directIntent
            val packagedIntent = Intent(action).apply { setPackage(HEALTH_CONNECT_PACKAGE) }
            if (canResolve(packagedIntent)) return packagedIntent
        }
        return null
    }

    private fun canResolve(intent: Intent): Boolean {
        return intent.resolveActivity(context.packageManager) != null
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun metric(id: String, label: String, cadence: String, unit: String): JSObject {
        return JSObject().apply {
            put("id", id)
            put("label", label)
            put("cadence", cadence)
            put("unit", unit)
        }
    }

    private fun stringArray(values: Collection<String>): JSArray {
        return JSArray().apply { values.sorted().forEach { put(it) } }
    }

    private fun emptySamples(): JSObject {
        return JSObject().apply {
            put("heartRate", JSArray())
            put("heartRateVariability", JSArray())
        }
    }

    private fun mergeJson(target: JSObject, source: JSObject) {
        val keys = source.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            target.put(key, source.opt(key))
        }
    }

    companion object {
        private const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
        private const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$HEALTH_CONNECT_PACKAGE"
        private val HEALTH_CONNECT_SETTINGS_ACTIONS = arrayOf(
            "android.health.connect.action.HEALTH_CONNECT_SETTINGS",
            "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS",
            "androidx.health.connect.client.ACTION_HEALTH_CONNECT_SETTINGS",
        )
    }
}
