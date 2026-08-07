package com.kyle.archive

import androidx.health.connect.client.HealthConnectClient
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
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.reflect.KClass

/**
 * Creates the canonical Health Connect snapshot used by app-open and manual
 * synchronization. Keeping this reader independent of the UI makes the
 * foreground import predictable and easy to verify.
 */
internal object ConnectedHealthSnapshotReader {
    val readPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(FloorsClimbedRecord::class),
    )

    suspend fun read(
        client: HealthConnectClient,
        requestedDays: Int,
        trigger: String,
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
            "background", "foregroundAuto", "manual" -> trigger
            else -> "manual"
        }

        val sleepSessions = JSArray()
        val sleepMinutesByDate = mutableMapOf<String, Long>()
        val sleepResponse = readAllRecords(client, SleepSessionRecord::class, range)

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
        val exerciseResponse = readAllRecords(client, ExerciseSessionRecord::class, range)

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
        var dailySummariesComplete = true
        for (offset in 0 until days) {
            val date = startDate.plusDays(offset.toLong())
            val dayStart = date.atStartOfDay(zone).toInstant()
            val dayEnd = if (date == today) now else date.plusDays(1).atStartOfDay(zone).toInstant()
            val aggregate = readDailyAggregate(client, dayStart, dayEnd)
            dailySummariesComplete = dailySummariesComplete && aggregate.complete

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
            put("completeSnapshot", true)
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
            put("allGranted", true)
            put("permissionsGranted", true)
            put("requestedPermissions", stringArray(readPermissions))
            put("grantedPermissions", stringArray(readPermissions))
            put("missingPermissions", JSArray())
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
                    put("heartRateSamples", heartRateSamples.size.coerceAtMost(MAX_SAMPLES))
                    put("heartRateVariabilitySamples", hrvSamples.size.coerceAtMost(MAX_SAMPLES))
                },
            )
            put(
                "message",
                "Imported ${dailySummaries.length()} days, ${sleepSessions.length()} sleep sessions, " +
                    "${workouts.length()} workouts, ${heartRateSamples.size.coerceAtMost(MAX_SAMPLES)} HR samples, " +
                    "and ${hrvSamples.size.coerceAtMost(MAX_SAMPLES)} HRV samples.",
            )
        }
    }

    private suspend fun readDailyAggregate(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
    ): DailyAggregate {
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
            DailyAggregate(complete = false)
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

    private data class RecordBatch<T : Record>(
        val records: List<T>,
        val complete: Boolean,
    )

    private data class DailyAggregate(
        val steps: Long = 0,
        val distanceMeters: Double = 0.0,
        val activeCalories: Double = 0.0,
        val floors: Double = 0.0,
        val averageHeartRate: Long = 0,
        val complete: Boolean = true,
    )

    private const val MAX_DAYS = 30
    private const val MAX_RECORDS = 1000
    private const val MAX_RECORD_PAGES = 50
    private const val MAX_SAMPLES = 500
    private const val HEALTH_SCHEMA_VERSION = 1
    private const val HEALTH_POLICY_VERSION = "archive-health-1"
    private const val SLEEP_DATE_POLICY = "previous-day-from-wake"
}
