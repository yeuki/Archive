package com.kyle.archive

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsCadenceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.reflect.KClass

/**
 * Creates the canonical Health Connect snapshot used by launch and
 * pull-to-refresh synchronization. Keeping this reader independent of the UI
 * makes both foreground import paths predictable and easy to verify.
 */
internal object ConnectedHealthSnapshotReader {
    val exerciseReadPermission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)

    val readPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        exerciseReadPermission,
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(FloorsClimbedRecord::class),
        HealthPermission.getReadPermission(SpeedRecord::class),
        HealthPermission.getReadPermission(ElevationGainedRecord::class),
        HealthPermission.getReadPermission(StepsCadenceRecord::class),
    )

    suspend fun read(
        client: HealthConnectClient,
        requestedDays: Int,
        trigger: String,
        grantedPermissions: Set<String>,
    ): JSObject {
        val days = requestedDays.coerceIn(1, MAX_DAYS)
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val today = LocalDate.now(zone)
        val startDate = today.minusDays((days - 1).toLong())
        val startInstant = startDate.atStartOfDay(zone).toInstant()
        val range = TimeRangeFilter.between(startInstant, now)
        val syncedAt = now.toString()
        val safeTrigger = when (trigger) {
            "launch", "pullToRefresh", "manual" -> trigger
            else -> "manual"
        }

        val sleepSessions = JSArray()
        val sleepMinutesByDate = mutableMapOf<String, Long>()
        val sleepResponse = if (hasPermission(grantedPermissions, SleepSessionRecord::class)) {
            readAllRecords(client, SleepSessionRecord::class, range)
        } else {
            RecordBatch<SleepSessionRecord>(emptyList(), false)
        }

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
        val exerciseResponse = if (hasPermission(grantedPermissions, ExerciseSessionRecord::class)) {
            readAllRecords(client, ExerciseSessionRecord::class, range)
        } else {
            RecordBatch<ExerciseSessionRecord>(emptyList(), false)
        }

        exerciseResponse.records.forEachIndexed { index, record ->
            val startedAt = record.startTime
            val endedAt = record.endTime
            val aggregate = readWorkoutAggregate(client, record, grantedPermissions)
            val recordDate = record.startZoneOffset
                ?.let { startedAt.atOffset(it).toLocalDate() }
                ?: startedAt.atZone(zone).toLocalDate()
            val segments = segmentArray(record.segments)
            val laps = lapArray(record.laps)
            val activeDurationSeconds = record.segments
                .filterNot { isRestSegment(it.segmentType) }
                .sumOf { durationSeconds(it.startTime, it.endTime) }
                .takeIf { it > 0 }
            val restDurationSeconds = record.segments
                .filter { isRestSegment(it.segmentType) }
                .sumOf { durationSeconds(it.startTime, it.endTime) }
                .takeIf { it > 0 }
            val metadata = record.metadata
            val device = metadata.device
            workouts.put(
                JSObject().apply {
                    val stableId = recordId(record, "exercise-$index-${startedAt.toEpochMilli()}")
                    put("id", stableId)
                    put("healthConnectRecordId", stableId)
                    put("recordType", "exerciseSession")
                    put("identityVersion", 2)
                    put("source", sourceName(record))
                    put("date", recordDate.toString())
                    put("startedAt", startedAt.toString())
                    put("endedAt", endedAt.toString())
                    put("durationMinutes", durationMinutes(startedAt, endedAt))
                    put("elapsedDurationSeconds", durationSeconds(startedAt, endedAt))
                    activeDurationSeconds?.let { put("activeDurationSeconds", it) }
                    restDurationSeconds?.let { put("restDurationSeconds", it) }
                    put("type", exerciseTypeLabel(record.exerciseType))
                    put("typeCode", record.exerciseType)
                    record.title?.takeIf { it.isNotBlank() }?.let { put("title", it) }
                    record.notes?.takeIf { it.isNotBlank() }?.let { put("notes", it) }
                    record.startZoneOffset?.let { put("startZoneOffset", it.toString()) }
                    record.endZoneOffset?.let { put("endZoneOffset", it.toString()) }
                    metadata.clientRecordId?.takeIf { it.isNotBlank() }?.let { put("clientRecordId", it) }
                    put("clientRecordVersion", metadata.clientRecordVersion)
                    put("lastModifiedAt", metadata.lastModifiedTime.toString())
                    put("recordingMethod", recordingMethodLabel(metadata.recordingMethod))
                    if (device != null) {
                        put(
                            "sourceDevice",
                            JSObject().apply {
                                put("type", deviceTypeLabel(device.type))
                                device.manufacturer?.takeIf { it.isNotBlank() }?.let { put("manufacturer", it) }
                                device.model?.takeIf { it.isNotBlank() }?.let { put("model", it) }
                            },
                        )
                    }
                    put("routeStatus", routeStatus(record.exerciseRouteResult))
                    put("laps", laps)
                    put("segments", segments)
                    put("metricsComplete", aggregate.complete)
                    put("metricPermissions", workoutMetricPermissionPayload(grantedPermissions))
                    put("metricAvailability", aggregate.availabilityPayload())
                    aggregate.distanceMeters?.let { put("distanceMeters", it) }
                    aggregate.activeCalories?.let { put("activeCalories", it) }
                    aggregate.totalCalories?.let { put("totalCalories", it) }
                    aggregate.averageHeartRate?.let { put("averageHeartRate", it) }
                    aggregate.minimumHeartRate?.let { put("minimumHeartRate", it) }
                    aggregate.maximumHeartRate?.let { put("maximumHeartRate", it) }
                    aggregate.averageSpeedMetersPerSecond?.let { put("averageSpeedMetersPerSecond", it) }
                    aggregate.maximumSpeedMetersPerSecond?.let { put("maximumSpeedMetersPerSecond", it) }
                    aggregate.elevationGainedMeters?.let { put("elevationGainedMeters", it) }
                    aggregate.averageCadence?.let { put("averageCadence", it) }
                    aggregate.maximumCadence?.let { put("maximumCadence", it) }
                },
            )
        }

        val heartRateSamples = if (hasPermission(grantedPermissions, HeartRateRecord::class)) {
            readHeartRateSamples(client, range)
        } else {
            emptyList()
        }
        val hrvSamples = if (hasPermission(grantedPermissions, HeartRateVariabilityRmssdRecord::class)) {
            readHeartRateVariabilitySamples(client, range)
        } else {
            emptyList()
        }
        val hrvByDate = hrvSamples
            .groupBy { it.timestamp.atZone(zone).toLocalDate().toString() }
            .mapValues { (_, samples) -> samples.map { it.value }.average() }

        val dailySummaries = JSArray()
        var dailySummariesComplete = true
        for (offset in 0 until days) {
            val date = startDate.plusDays(offset.toLong())
            val dayStart = date.atStartOfDay(zone).toInstant()
            val dayEnd = if (date == today) now else date.plusDays(1).atStartOfDay(zone).toInstant()
            val aggregate = readDailyAggregate(client, dayStart, dayEnd, grantedPermissions)
            dailySummariesComplete = dailySummariesComplete && aggregate.complete

            dailySummaries.put(
                JSObject().apply {
                    put("date", date.toString())
                    put("source", "Health Connect")
                    put("steps", aggregate.steps)
                    put("distanceMeters", aggregate.distanceMeters)
                    put("activeCalories", aggregate.activeCalories)
                    put("totalCalories", aggregate.totalCalories)
                    put("floors", aggregate.floors)
                    put("sleepMinutes", sleepMinutesByDate[date.toString()] ?: 0L)
                    put("averageHeartRate", aggregate.averageHeartRate)
                    put("hrvMs", hrvByDate[date.toString()] ?: 0.0)
                    put("fieldAvailability", dailyPermissionPayload(grantedPermissions))
                    put("updatedAt", syncedAt)
                },
            )
        }

        val samples = JSObject().apply {
            put("heartRate", sampleArray(heartRateSamples.takeLast(MAX_SAMPLES)))
            put("heartRateVariability", sampleArray(hrvSamples.takeLast(MAX_SAMPLES)))
        }

        val grantedRequestedPermissions = grantedPermissions.intersect(readPermissions)
        val missingPermissions = readPermissions - grantedPermissions
        val allGranted = missingPermissions.isEmpty()
        val canSync = grantedRequestedPermissions.isNotEmpty()
        val completeSnapshot = dailySummariesComplete && sleepResponse.complete && exerciseResponse.complete
        val workoutsWithSegments = exerciseResponse.records.count { it.segments.isNotEmpty() }
        val workoutsWithLaps = exerciseResponse.records.count { it.laps.isNotEmpty() }
        val garminWorkouts = exerciseResponse.records.count { sourceName(it).contains("garmin", ignoreCase = true) }

        return JSObject().apply {
            put("platform", "android")
            put("available", true)
            put("status", "synced")
            put("provider", "healthConnect")
            put("sourceName", "Health Connect")
            put("synced", true)
            put("syncedAt", syncedAt)
            put("lastSyncAt", syncedAt)
            put("syncTrigger", safeTrigger)
            put("days", days)
            put("healthSchemaVersion", HEALTH_SCHEMA_VERSION)
            put("policyVersion", HEALTH_POLICY_VERSION)
            put("sleepDatePolicy", SLEEP_DATE_POLICY)
            put("timeZone", zone.id)
            put("syncWindowStart", startInstant.toString())
            put("syncWindowEnd", now.toString())
            put("syncWindowStartDate", startDate.toString())
            put("syncWindowEndDate", today.toString())
            put("sleepDateStart", startDate.minusDays(1).toString())
            put("sleepDateEnd", today.minusDays(1).toString())
            put("completeSnapshot", completeSnapshot)
            put(
                "snapshotCompleteness",
                JSObject().apply {
                    put("dailySummaries", dailySummariesComplete)
                    put("sleepSessions", sleepResponse.complete)
                    put("workouts", exerciseResponse.complete)
                    put("heartRate", false)
                    put("heartRateVariability", false)
                },
            )
            put(
                "sampleRetention",
                JSObject().apply {
                    put("mode", "rolling")
                    put("limitPerMetric", MAX_SAMPLES)
                },
            )
            put("allGranted", allGranted)
            put("permissionsGranted", allGranted)
            put("canSync", canSync)
            put("partialPermissions", canSync && !allGranted)
            put("workoutPermissionGranted", grantedPermissions.contains(exerciseReadPermission))
            put("needsPermissions", !canSync)
            put("requestedPermissions", stringArray(readPermissions))
            put("grantedPermissions", stringArray(grantedRequestedPermissions))
            put("missingPermissions", stringArray(missingPermissions))
            put("dailySummaries", dailySummaries)
            put("sleepSessions", sleepSessions)
            put("workouts", workouts)
            put("samples", samples)
            put(
                "summary",
                JSObject().apply {
                    put("dailySummaries", dailySummaries.length())
                    put("sleepSessions", sleepSessions.length())
                    put("workouts", workouts.length())
                    put("garminWorkouts", garminWorkouts)
                    put("workoutsWithSegments", workoutsWithSegments)
                    put("workoutsWithLaps", workoutsWithLaps)
                    put("heartRateSamples", heartRateSamples.size.coerceAtMost(MAX_SAMPLES))
                    put("heartRateVariabilitySamples", hrvSamples.size.coerceAtMost(MAX_SAMPLES))
                },
            )
            put(
                "message",
                "Imported ${dailySummaries.length()} days, ${sleepSessions.length()} sleep sessions, " +
                    "${workouts.length()} workouts, ${heartRateSamples.size.coerceAtMost(MAX_SAMPLES)} HR samples, " +
                    "and ${hrvSamples.size.coerceAtMost(MAX_SAMPLES)} HRV samples." +
                    if (missingPermissions.isEmpty()) "" else " ${missingPermissions.size} optional data types still need permission.",
            )
        }
    }

    private suspend fun readDailyAggregate(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
        grantedPermissions: Set<String>,
    ): DailyAggregate {
        val metrics = mutableSetOf<AggregateMetric<*>>()
        if (hasPermission(grantedPermissions, StepsRecord::class)) metrics.add(StepsRecord.COUNT_TOTAL)
        if (hasPermission(grantedPermissions, DistanceRecord::class)) metrics.add(DistanceRecord.DISTANCE_TOTAL)
        if (hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class)) {
            metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
        }
        if (hasPermission(grantedPermissions, TotalCaloriesBurnedRecord::class)) {
            metrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
        }
        if (hasPermission(grantedPermissions, FloorsClimbedRecord::class)) {
            metrics.add(FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL)
        }
        if (hasPermission(grantedPermissions, HeartRateRecord::class)) metrics.add(HeartRateRecord.BPM_AVG)

        val requiredDailyPermissionsGranted =
            hasPermission(grantedPermissions, StepsRecord::class) &&
                hasPermission(grantedPermissions, DistanceRecord::class) &&
                hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class) &&
                hasPermission(grantedPermissions, FloorsClimbedRecord::class) &&
                hasPermission(grantedPermissions, HeartRateRecord::class)

        if (metrics.isEmpty()) return DailyAggregate(complete = false)

        return try {
            val response = client.aggregate(
                AggregateRequest(
                    metrics = metrics,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                ),
            )

            DailyAggregate(
                steps = if (hasPermission(grantedPermissions, StepsRecord::class)) {
                    response[StepsRecord.COUNT_TOTAL] ?: 0L
                } else {
                    0L
                },
                distanceMeters = if (hasPermission(grantedPermissions, DistanceRecord::class)) {
                    response[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0
                } else {
                    0.0
                },
                activeCalories = if (hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class)) {
                    response[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0
                } else {
                    0.0
                },
                totalCalories = if (hasPermission(grantedPermissions, TotalCaloriesBurnedRecord::class)) {
                    response[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0
                } else {
                    0.0
                },
                floors = if (hasPermission(grantedPermissions, FloorsClimbedRecord::class)) {
                    response[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL] ?: 0.0
                } else {
                    0.0
                },
                averageHeartRate = if (hasPermission(grantedPermissions, HeartRateRecord::class)) {
                    response[HeartRateRecord.BPM_AVG] ?: 0L
                } else {
                    0L
                },
                complete = requiredDailyPermissionsGranted,
            )
        } catch (_: Exception) {
            DailyAggregate(complete = false)
        }
    }

    private suspend fun readWorkoutAggregate(
        client: HealthConnectClient,
        record: ExerciseSessionRecord,
        grantedPermissions: Set<String>,
    ): WorkoutAggregate {
        val metrics = mutableSetOf<AggregateMetric<*>>()
        if (hasPermission(grantedPermissions, DistanceRecord::class)) metrics.add(DistanceRecord.DISTANCE_TOTAL)
        if (hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class)) {
            metrics.add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
        }
        if (hasPermission(grantedPermissions, TotalCaloriesBurnedRecord::class)) {
            metrics.add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
        }
        if (hasPermission(grantedPermissions, HeartRateRecord::class)) {
            metrics.add(HeartRateRecord.BPM_AVG)
            metrics.add(HeartRateRecord.BPM_MIN)
            metrics.add(HeartRateRecord.BPM_MAX)
        }
        if (hasPermission(grantedPermissions, SpeedRecord::class)) {
            metrics.add(SpeedRecord.SPEED_AVG)
            metrics.add(SpeedRecord.SPEED_MAX)
        }
        if (hasPermission(grantedPermissions, ElevationGainedRecord::class)) {
            metrics.add(ElevationGainedRecord.ELEVATION_GAINED_TOTAL)
        }
        if (hasPermission(grantedPermissions, StepsCadenceRecord::class)) {
            metrics.add(StepsCadenceRecord.RATE_AVG)
            metrics.add(StepsCadenceRecord.RATE_MAX)
        }
        if (metrics.isEmpty()) return WorkoutAggregate(complete = false)

        return try {
            val response = client.aggregate(
                AggregateRequest(
                    metrics = metrics,
                    timeRangeFilter = TimeRangeFilter.between(record.startTime, record.endTime),
                    dataOriginFilter = setOf(record.metadata.dataOrigin),
                ),
            )

            WorkoutAggregate(
                distanceMeters = response[DistanceRecord.DISTANCE_TOTAL]?.inMeters,
                activeCalories = response[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories,
                totalCalories = response[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories,
                averageHeartRate = response[HeartRateRecord.BPM_AVG],
                minimumHeartRate = response[HeartRateRecord.BPM_MIN],
                maximumHeartRate = response[HeartRateRecord.BPM_MAX],
                averageSpeedMetersPerSecond = response[SpeedRecord.SPEED_AVG]?.inMetersPerSecond,
                maximumSpeedMetersPerSecond = response[SpeedRecord.SPEED_MAX]?.inMetersPerSecond,
                elevationGainedMeters = response[ElevationGainedRecord.ELEVATION_GAINED_TOTAL]?.inMeters,
                averageCadence = response[StepsCadenceRecord.RATE_AVG],
                maximumCadence = response[StepsCadenceRecord.RATE_MAX],
            )
        } catch (_: Exception) {
            WorkoutAggregate(complete = false)
        }
    }

    private suspend fun <T : Record> readAllRecords(
        client: HealthConnectClient,
        recordType: KClass<T>,
        range: TimeRangeFilter,
    ): RecordBatch<T> {
        val records = mutableListOf<T>()
        var pageToken: String? = null
        var pagesRead = 0

        do {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = recordType,
                    timeRangeFilter = range,
                    ascendingOrder = true,
                    pageSize = MAX_RECORDS,
                    pageToken = pageToken,
                ),
            )
            records.addAll(response.records)
            pageToken = response.pageToken
            pagesRead += 1
        } while (!pageToken.isNullOrBlank() && pagesRead < MAX_RECORD_PAGES)

        return RecordBatch(records = records, complete = pageToken.isNullOrBlank())
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

    private fun sampleArray(samples: List<WatchSample>): JSArray {
        return JSArray().apply {
            samples.sortedBy { it.timestamp }.forEach { sample ->
                put(
                    JSObject().apply {
                        put("id", sample.id)
                        put("timestamp", sample.timestamp.toString())
                        put("value", sample.value)
                        put("source", sample.source)
                    },
                )
            }
        }
    }

    private fun stringArray(values: Collection<String>): JSArray {
        return JSArray().apply {
            values.sorted().forEach { put(it) }
        }
    }

    private fun lapArray(laps: List<ExerciseLap>): JSArray {
        return JSArray().apply {
            laps.forEachIndexed { index, lap ->
                put(
                    JSObject().apply {
                        put("index", index + 1)
                        put("startedAt", lap.startTime.toString())
                        put("endedAt", lap.endTime.toString())
                        put("durationSeconds", durationSeconds(lap.startTime, lap.endTime))
                        lap.length?.let { put("distanceMeters", it.inMeters) }
                    },
                )
            }
        }
    }

    private fun segmentArray(segments: List<ExerciseSegment>): JSArray {
        return JSArray().apply {
            segments.forEachIndexed { index, segment ->
                put(
                    JSObject().apply {
                        put("index", index + 1)
                        put("typeCode", segment.segmentType)
                        put("type", exerciseSegmentTypeLabel(segment.segmentType))
                        put("startedAt", segment.startTime.toString())
                        put("endedAt", segment.endTime.toString())
                        put("durationSeconds", durationSeconds(segment.startTime, segment.endTime))
                        if (segment.repetitions > 0) put("repetitions", segment.repetitions)
                        put("isRest", isRestSegment(segment.segmentType))
                    },
                )
            }
        }
    }

    private fun dailyPermissionPayload(grantedPermissions: Set<String>): JSObject {
        return JSObject().apply {
            put("steps", hasPermission(grantedPermissions, StepsRecord::class))
            put("distance", hasPermission(grantedPermissions, DistanceRecord::class))
            put("activeCalories", hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class))
            put("totalCalories", hasPermission(grantedPermissions, TotalCaloriesBurnedRecord::class))
            put("floors", hasPermission(grantedPermissions, FloorsClimbedRecord::class))
            put("heartRate", hasPermission(grantedPermissions, HeartRateRecord::class))
            put("hrv", hasPermission(grantedPermissions, HeartRateVariabilityRmssdRecord::class))
            put("sleep", hasPermission(grantedPermissions, SleepSessionRecord::class))
        }
    }

    private fun workoutMetricPermissionPayload(grantedPermissions: Set<String>): JSObject {
        return JSObject().apply {
            put("distance", hasPermission(grantedPermissions, DistanceRecord::class))
            put("activeCalories", hasPermission(grantedPermissions, ActiveCaloriesBurnedRecord::class))
            put("totalCalories", hasPermission(grantedPermissions, TotalCaloriesBurnedRecord::class))
            put("heartRate", hasPermission(grantedPermissions, HeartRateRecord::class))
            put("speed", hasPermission(grantedPermissions, SpeedRecord::class))
            put("elevation", hasPermission(grantedPermissions, ElevationGainedRecord::class))
            put("cadence", hasPermission(grantedPermissions, StepsCadenceRecord::class))
        }
    }

    private fun <T : Record> hasPermission(grantedPermissions: Set<String>, recordType: KClass<T>): Boolean {
        return grantedPermissions.contains(HealthPermission.getReadPermission(recordType))
    }

    private fun durationMinutes(start: Instant, end: Instant): Long {
        return Duration.between(start, end).toMinutes().coerceAtLeast(0L)
    }

    private fun durationSeconds(start: Instant, end: Instant): Long {
        return Duration.between(start, end).seconds.coerceAtLeast(0L)
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

    private fun exerciseSegmentTypeLabel(type: Int): String {
        return when (type) {
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_ARM_CURL -> "Arm curl"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BACK_EXTENSION -> "Back extension"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BALL_SLAM -> "Ball slam"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BARBELL_SHOULDER_PRESS -> "Barbell shoulder press"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BENCH_PRESS -> "Bench press"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BENCH_SIT_UP -> "Bench sit-up"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_BURPEE -> "Burpee"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_CRUNCH -> "Crunch"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DEADLIFT -> "Deadlift"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DOUBLE_ARM_TRICEPS_EXTENSION -> "Double-arm triceps extension"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DUMBBELL_CURL_LEFT_ARM -> "Dumbbell curl · left"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DUMBBELL_CURL_RIGHT_ARM -> "Dumbbell curl · right"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DUMBBELL_FRONT_RAISE -> "Dumbbell front raise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DUMBBELL_LATERAL_RAISE -> "Dumbbell lateral raise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_DUMBBELL_ROW -> "Dumbbell row"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_FRONT_RAISE -> "Front raise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING -> "High-intensity interval"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_HIP_THRUST -> "Hip thrust"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_JUMPING_JACK -> "Jumping jack"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_JUMP_ROPE -> "Jump rope"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_KETTLEBELL_SWING -> "Kettlebell swing"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LATERAL_RAISE -> "Lateral raise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LAT_PULL_DOWN -> "Lat pulldown"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LEG_CURL -> "Leg curl"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LEG_EXTENSION -> "Leg extension"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LEG_PRESS -> "Leg press"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LEG_RAISE -> "Leg raise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_LUNGE -> "Lunge"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_MOUNTAIN_CLIMBER -> "Mountain climber"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_OTHER_WORKOUT -> "Other exercise"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE -> "Pause"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_PLANK -> "Plank"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_PULL_UP -> "Pull-up"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_REST -> "Rest"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_ROWING_MACHINE -> "Rowing machine"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING -> "Running"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_RUNNING_TREADMILL -> "Treadmill running"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SHOULDER_PRESS -> "Shoulder press"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SIT_UP -> "Sit-up"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SQUAT -> "Squat"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_STAIR_CLIMBING -> "Stair climbing"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_STRETCHING -> "Stretching"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_WALKING -> "Walking"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_WEIGHTLIFTING -> "Weightlifting"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_YOGA -> "Yoga"
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_UNKNOWN -> "Unknown exercise"
            else -> "Exercise type $type"
        }
    }

    private fun isRestSegment(type: Int): Boolean {
        return type == ExerciseSegment.EXERCISE_SEGMENT_TYPE_REST ||
            type == ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE
    }

    private fun routeStatus(result: ExerciseRouteResult): String {
        return when (result) {
            is ExerciseRouteResult.Data -> "available"
            is ExerciseRouteResult.ConsentRequired -> "consentRequired"
            is ExerciseRouteResult.NoData -> "none"
            else -> "unknown"
        }
    }

    private fun recordingMethodLabel(method: Int): String {
        return when (method) {
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED -> "active"
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED -> "automatic"
            Metadata.RECORDING_METHOD_MANUAL_ENTRY -> "manual"
            else -> "unknown"
        }
    }

    private fun deviceTypeLabel(type: Int): String {
        return when (type) {
            Device.TYPE_WATCH -> "watch"
            Device.TYPE_PHONE -> "phone"
            Device.TYPE_SCALE -> "scale"
            Device.TYPE_RING -> "ring"
            Device.TYPE_FITNESS_BAND -> "fitnessBand"
            Device.TYPE_CHEST_STRAP -> "chestStrap"
            else -> "unknown"
        }
    }

    private data class WatchSample(
        val id: String,
        val timestamp: Instant,
        val value: Double,
        val source: String,
    )

    private data class RecordBatch<T : Record>(
        val records: List<T>,
        val complete: Boolean,
    )

    private data class DailyAggregate(
        val steps: Long = 0,
        val distanceMeters: Double = 0.0,
        val activeCalories: Double = 0.0,
        val totalCalories: Double = 0.0,
        val floors: Double = 0.0,
        val averageHeartRate: Long = 0,
        val complete: Boolean = true,
    )

    private data class WorkoutAggregate(
        val distanceMeters: Double? = null,
        val activeCalories: Double? = null,
        val totalCalories: Double? = null,
        val averageHeartRate: Long? = null,
        val minimumHeartRate: Long? = null,
        val maximumHeartRate: Long? = null,
        val averageSpeedMetersPerSecond: Double? = null,
        val maximumSpeedMetersPerSecond: Double? = null,
        val elevationGainedMeters: Double? = null,
        val averageCadence: Double? = null,
        val maximumCadence: Double? = null,
        val complete: Boolean = true,
    ) {
        fun availabilityPayload(): JSObject {
            return JSObject().apply {
                put("distance", distanceMeters != null)
                put("activeCalories", activeCalories != null)
                put("totalCalories", totalCalories != null)
                put("heartRate", averageHeartRate != null || minimumHeartRate != null || maximumHeartRate != null)
                put("speed", averageSpeedMetersPerSecond != null || maximumSpeedMetersPerSecond != null)
                put("elevation", elevationGainedMeters != null)
                put("cadence", averageCadence != null || maximumCadence != null)
            }
        }
    }

    private const val MAX_DAYS = 30
    private const val MAX_RECORDS = 1000
    private const val MAX_RECORD_PAGES = 50
    private const val MAX_SAMPLES = 500
    private const val HEALTH_SCHEMA_VERSION = 2
    private const val HEALTH_POLICY_VERSION = "archive-health-2"
    private const val SLEEP_DATE_POLICY = "previous-day-from-wake"
}
