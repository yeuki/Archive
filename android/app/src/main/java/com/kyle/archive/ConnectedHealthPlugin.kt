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
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
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
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@CapacitorPlugin(name = "ConnectedHealth")
class ConnectedHealthPlugin : Plugin() {
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingPermissionCall: PluginCall? = null

    private val readPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(FloorsClimbedRecord::class),
    )

    override fun load() {
        permissionLauncher = activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { grantedPermissions ->
            val call = pendingPermissionCall
            pendingPermissionCall = null
            call?.resolve(permissionPayload(grantedPermissions, "Health Connect permissions updated."))
        }
    }

    @PluginMethod
    fun getStatus(call: PluginCall) {
        call.resolve(buildStatusPayload())
    }

    @PluginMethod
    fun getSupportedMetrics(call: PluginCall) {
        val ret = JSObject()
        val metrics = JSArray()

        metrics.put(metric("steps", "Steps", "daily", "steps"))
        metrics.put(metric("sleep", "Sleep", "nightly", "sessions"))
        metrics.put(metric("exercise", "Exercise sessions", "as completed", "workouts"))
        metrics.put(metric("distance", "Distance", "daily", "m"))
        metrics.put(metric("activeCalories", "Active calories", "daily", "kcal"))
        metrics.put(metric("heartRate", "Heart rate", "samples", "bpm"))
        metrics.put(metric("heartRateVariability", "HRV", "samples", "ms"))
        metrics.put(metric("floors", "Floors climbed", "daily", "floors"))

        ret.put("metrics", metrics)
        call.resolve(ret)
    }

    @PluginMethod
    fun checkHealthPermissions(call: PluginCall) {
        val client = healthClientOrNull()
        if (client == null) {
            val ret = buildStatusPayload()
            ret.put("allGranted", false)
            ret.put("permissionsGranted", false)
            ret.put("requestedPermissions", stringArray(readPermissions))
            ret.put("grantedPermissions", JSArray())
            ret.put("missingPermissions", stringArray(readPermissions))
            call.resolve(ret)
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
        val client = healthClientOrNull()
        val launcher = permissionLauncher

        if (client == null) {
            val ret = buildStatusPayload()
            ret.put("allGranted", false)
            ret.put("permissionsGranted", false)
            ret.put("requestedPermissions", stringArray(readPermissions))
            ret.put("grantedPermissions", JSArray())
            ret.put("missingPermissions", stringArray(readPermissions))
            call.resolve(ret)
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

                if (granted.containsAll(readPermissions)) {
                    call.resolve(permissionPayload(granted, "All requested Health Connect permissions are already granted."))
                    return@launch
                }

                if (pendingPermissionCall != null) {
                    call.reject("A Health Connect permission request is already open.")
                    return@launch
                }

                pendingPermissionCall = call
                launcher.launch(readPermissions)
            } catch (error: Exception) {
                pendingPermissionCall = null
                call.reject("Archive could not request Health Connect permissions.", error)
            }
        }
    }

    @PluginMethod
    fun syncRecentData(call: PluginCall) {
        val days = (call.getInt("days", 30) ?: 30).coerceIn(1, 30)
        val client = healthClientOrNull()

        if (client == null) {
            val ret = buildStatusPayload()
            ret.put("synced", false)
            ret.put("needsPermissions", false)
            ret.put("dailySummaries", JSArray())
            ret.put("sleepSessions", JSArray())
            ret.put("workouts", JSArray())
            ret.put("samples", emptySamples())
            call.resolve(ret)
            return
        }

        pluginScope.launch {
            try {
                val granted = withContext(Dispatchers.IO) {
                    client.permissionController.getGrantedPermissions()
                }

                if (!granted.containsAll(readPermissions)) {
                    val ret = permissionPayload(granted, "Health Connect permissions are needed before Archive can import watch data.")
                    ret.put("synced", false)
                    ret.put("needsPermissions", true)
                    ret.put("dailySummaries", JSArray())
                    ret.put("sleepSessions", JSArray())
                    ret.put("workouts", JSArray())
                    ret.put("samples", emptySamples())
                    call.resolve(ret)
                    return@launch
                }

                val payload = withContext(Dispatchers.IO) {
                    readHealthConnectData(client, days)
                }
                call.resolve(payload)
            } catch (error: Exception) {
                call.reject("Archive could not sync Health Connect data.", error)
            }
        }
    }

    @PluginMethod
    fun openSettings(call: PluginCall) {
        val status = buildStatusPayload()
        val candidates = mutableListOf<Intent>()
        val settingsIntent = firstResolvableSettingsIntent()
        val systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        val packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE)

        if (settingsIntent != null) {
            candidates.add(settingsIntent)
        }

        if (packageInstalled) {
            val appDetails = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            appDetails.data = Uri.parse("package:$HEALTH_CONNECT_PACKAGE")
            candidates.add(appDetails)
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

    private suspend fun readHealthConnectData(client: HealthConnectClient, days: Int): JSObject {
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val today = LocalDate.now(zone)
        val startDate = today.minusDays((days - 1).toLong())
        val startInstant = startDate.atStartOfDay(zone).toInstant()
        val range = TimeRangeFilter.between(startInstant, now)
        val syncedAt = Instant.now().toString()

        val sleepSessions = JSArray()
        val sleepMinutesByDate = mutableMapOf<String, Long>()
        val sleepResponse = client.readRecords(
            ReadRecordsRequest(
                recordType = SleepSessionRecord::class,
                timeRangeFilter = range,
                ascendingOrder = true,
                pageSize = MAX_RECORDS,
            ),
        )

        sleepResponse.records.forEachIndexed { index, record ->
            val startedAt = record.startTime
            val endedAt = record.endTime
            val minutes = durationMinutes(startedAt, endedAt)
            val date = endedAt.atZone(zone).toLocalDate().minusDays(1).toString()
            sleepMinutesByDate[date] = (sleepMinutesByDate[date] ?: 0L) + minutes

            sleepSessions.put(
                JSObject().apply {
                    put("id", recordId(record, "sleep-$index-${startedAt.toEpochMilli()}"))
                    put("source", sourceName(record))
                    put("date", date)
                    put("startedAt", startedAt.toString())
                    put("endedAt", endedAt.toString())
                    put("durationMinutes", minutes)
                    put("type", "sleep")
                    put("notes", "Imported from Health Connect.")
                },
            )
        }

        val workouts = JSArray()
        val exerciseResponse = client.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = range,
                ascendingOrder = true,
                pageSize = MAX_RECORDS,
            ),
        )

        exerciseResponse.records.forEachIndexed { index, record ->
            val startedAt = record.startTime
            val endedAt = record.endTime
            workouts.put(
                JSObject().apply {
                    put("id", recordId(record, "exercise-$index-${startedAt.toEpochMilli()}"))
                    put("source", sourceName(record))
                    put("date", startedAt.atZone(zone).toLocalDate().toString())
                    put("startedAt", startedAt.toString())
                    put("endedAt", endedAt.toString())
                    put("durationMinutes", durationMinutes(startedAt, endedAt))
                    put("type", exerciseTypeLabel(record.exerciseType))
                    put("notes", "Imported from Health Connect.")
                },
            )
        }

        val heartRateSamples = readHeartRateSamples(client, range)
        val hrvSamples = readHeartRateVariabilitySamples(client, range)
        val hrvByDate = hrvSamples
            .groupBy { it.timestamp.atZone(zone).toLocalDate().toString() }
            .mapValues { (_, samples) -> samples.map { it.value }.average() }

        val dailySummaries = JSArray()
        for (offset in 0 until days) {
            val date = startDate.plusDays(offset.toLong())
            val dayStart = date.atStartOfDay(zone).toInstant()
            val dayEnd = if (date == today) now else date.plusDays(1).atStartOfDay(zone).toInstant()
            val aggregate = readDailyAggregate(client, dayStart, dayEnd)

            dailySummaries.put(
                JSObject().apply {
                    put("date", date.toString())
                    put("source", "Health Connect")
                    put("steps", aggregate.steps)
                    put("distanceMeters", aggregate.distanceMeters)
                    put("activeCalories", aggregate.activeCalories)
                    put("floors", aggregate.floors)
                    put("sleepMinutes", sleepMinutesByDate[date.toString()] ?: 0L)
                    put("averageHeartRate", aggregate.averageHeartRate)
                    put("hrvMs", hrvByDate[date.toString()] ?: 0.0)
                    put("updatedAt", syncedAt)
                },
            )
        }

        val samples = JSObject().apply {
            put("heartRate", sampleArray(heartRateSamples.takeLast(MAX_SAMPLES)))
            put("heartRateVariability", sampleArray(hrvSamples.takeLast(MAX_SAMPLES)))
        }

        val payload = buildStatusPayload()
        payload.put("provider", "healthConnect")
        payload.put("sourceName", "Health Connect")
        payload.put("synced", true)
        payload.put("syncedAt", syncedAt)
        payload.put("lastSyncAt", syncedAt)
        payload.put("days", days)
        payload.put("allGranted", true)
        payload.put("permissionsGranted", true)
        payload.put("requestedPermissions", stringArray(readPermissions))
        payload.put("grantedPermissions", stringArray(readPermissions))
        payload.put("missingPermissions", JSArray())
        payload.put("dailySummaries", dailySummaries)
        payload.put("sleepSessions", sleepSessions)
        payload.put("workouts", workouts)
        payload.put("samples", samples)
        payload.put(
            "summary",
            JSObject().apply {
                put("dailySummaries", dailySummaries.length())
                put("sleepSessions", sleepSessions.length())
                put("workouts", workouts.length())
                put("heartRateSamples", heartRateSamples.size.coerceAtMost(MAX_SAMPLES))
                put("heartRateVariabilitySamples", hrvSamples.size.coerceAtMost(MAX_SAMPLES))
            },
        )
        payload.put(
            "message",
            "Imported ${dailySummaries.length()} days, ${sleepSessions.length()} sleep sessions, ${workouts.length()} workouts, ${heartRateSamples.size.coerceAtMost(MAX_SAMPLES)} HR samples, and ${hrvSamples.size.coerceAtMost(MAX_SAMPLES)} HRV samples.",
        )
        return payload
    }

    private suspend fun readDailyAggregate(client: HealthConnectClient, start: Instant, end: Instant): DailyAggregate {
        return try {
            val response = client.aggregate(
                AggregateRequest(
                    metrics = setOf(
                        StepsRecord.COUNT_TOTAL,
                        DistanceRecord.DISTANCE_TOTAL,
                        ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                        FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL,
                        HeartRateRecord.BPM_AVG,
                    ),
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                ),
            )

            DailyAggregate(
                steps = response[StepsRecord.COUNT_TOTAL] ?: 0L,
                distanceMeters = response[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0,
                activeCalories = response[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0,
                floors = response[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL] ?: 0.0,
                averageHeartRate = response[HeartRateRecord.BPM_AVG] ?: 0L,
            )
        } catch (_: Exception) {
            DailyAggregate()
        }
    }

    private suspend fun readHeartRateSamples(
        client: HealthConnectClient,
        range: TimeRangeFilter,
    ): List<WatchSample> {
        return try {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = range,
                    ascendingOrder = true,
                    pageSize = MAX_RECORDS,
                ),
            )
            response.records.flatMapIndexed { recordIndex, record ->
                record.samples.mapIndexed { sampleIndex, sample ->
                    WatchSample(
                        id = "${recordId(record, "heart-rate-$recordIndex")}-${sample.time.toEpochMilli()}-$sampleIndex",
                        timestamp = sample.time,
                        value = sample.beatsPerMinute.toDouble(),
                        source = sourceName(record),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private suspend fun readHeartRateVariabilitySamples(
        client: HealthConnectClient,
        range: TimeRangeFilter,
    ): List<WatchSample> {
        return try {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = range,
                    ascendingOrder = true,
                    pageSize = MAX_RECORDS,
                ),
            )
            response.records.mapIndexed { index, record ->
                WatchSample(
                    id = recordId(record, "hrv-$index-${record.time.toEpochMilli()}"),
                    timestamp = record.time,
                    value = record.heartRateVariabilityMillis,
                    source = sourceName(record),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun permissionPayload(grantedPermissions: Set<String>, message: String): JSObject {
        val grantedRequested = grantedPermissions.intersect(readPermissions)
        val missing = readPermissions - grantedPermissions
        val status = buildStatusPayload()
        val healthAvailable = status.getBool("available") ?: false

        status.put("status", if (!healthAvailable) "unavailable" else if (missing.isEmpty()) "available" else "permissionsNeeded")
        status.put("message", if (missing.isEmpty()) message else "Archive needs Health Connect permission before it can import watch data.")
        status.put("allGranted", missing.isEmpty())
        status.put("permissionsGranted", missing.isEmpty())
        status.put("requestedPermissions", stringArray(readPermissions))
        status.put("grantedPermissions", stringArray(grantedRequested))
        status.put("missingPermissions", stringArray(missing))
        return status
    }

    private fun metric(id: String, label: String, cadence: String, unit: String): JSObject {
        return JSObject().apply {
            put("id", id)
            put("label", label)
            put("cadence", cadence)
            put("unit", unit)
        }
    }

    private fun buildStatusPayload(): JSObject {
        val systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        val packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE)
        val settingsResolvable = firstResolvableSettingsIntent() != null
        val sdkStatus = healthConnectSdkStatus()
        val sdkAvailable = sdkStatus == HealthConnectClient.SDK_AVAILABLE
        val updateRequired = sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED
        val available = sdkAvailable || systemIntegrated || packageInstalled || settingsResolvable

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
        }
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

            val packagedIntent = Intent(action)
            packagedIntent.setPackage(HEALTH_CONNECT_PACKAGE)
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

    private fun stringArray(values: Collection<String>): JSArray {
        val array = JSArray()
        values.sorted().forEach { array.put(it) }
        return array
    }

    private fun emptySamples(): JSObject {
        return JSObject().apply {
            put("heartRate", JSArray())
            put("heartRateVariability", JSArray())
        }
    }

    private fun sampleArray(samples: List<WatchSample>): JSArray {
        val array = JSArray()
        samples.sortedBy { it.timestamp }.forEach { sample ->
            array.put(
                JSObject().apply {
                    put("id", sample.id)
                    put("timestamp", sample.timestamp.toString())
                    put("value", sample.value)
                    put("source", sample.source)
                },
            )
        }
        return array
    }

    private fun durationMinutes(start: Instant, end: Instant): Long {
        return Duration.between(start, end).toMinutes().coerceAtLeast(0L)
    }

    private fun sourceName(record: Record): String {
        val packageName = record.metadata.dataOrigin.packageName
        return if (packageName.isBlank()) "Health Connect" else packageName
    }

    private fun recordId(record: Record, fallback: String): String {
        val id = record.metadata.id
        return if (id.isBlank()) fallback else id
    }

    private fun exerciseTypeLabel(type: Int): String {
        return when (type) {
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "Run"
            ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "Walk"
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "Bike"
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER,
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "Swim"
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "Strength"
            ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "Yoga"
            ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT -> "Workout"
            else -> "Exercise"
        }
    }

    private data class WatchSample(
        val id: String,
        val timestamp: Instant,
        val value: Double,
        val source: String,
    )

    private data class DailyAggregate(
        val steps: Long = 0,
        val distanceMeters: Double = 0.0,
        val activeCalories: Double = 0.0,
        val floors: Double = 0.0,
        val averageHeartRate: Long = 0,
    )

    companion object {
        private const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
        private const val PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=$HEALTH_CONNECT_PACKAGE"
        private const val MAX_RECORDS = 1000
        private const val MAX_SAMPLES = 500
        private val HEALTH_CONNECT_SETTINGS_ACTIONS = arrayOf(
            "android.health.connect.action.HEALTH_CONNECT_SETTINGS",
            "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS",
            "androidx.health.connect.client.ACTION_HEALTH_CONNECT_SETTINGS",
        )
    }
}
