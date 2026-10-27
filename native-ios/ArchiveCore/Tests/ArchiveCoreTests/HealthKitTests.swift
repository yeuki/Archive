import Foundation
import XCTest
@testable import ArchiveCore

final class HealthKitTests: XCTestCase {
    let sleepID = "00000000-0000-0000-0000-000000000001"
    let date = "2026-10-26"

    func testMorningSleepUsesPreviousLocalWakeDayAndOverridesManual() throws {
        var document = ArchiveDocument()
        document.setManualSleep(6.5, on: date)
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [sleep(sleepID,
            "2026-10-27T01:00:00-04:00", "2026-10-27T09:00:00-04:00")]]))
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 8)
        XCTAssertEqual(document.entry(on: date)?.sleepSource, "sync")
        XCTAssertNil(document.entry(on: "2026-10-27"))
        document.setManualSleep(7, on: date)
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 8)
        document = try ArchiveDocument(backup: document.backup())
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["sleepSessions": [sleepID]]))
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 7)
        XCTAssertEqual(document.entry(on: date)?.sleepSource, "manual")
    }

    func testStagesAcrossMidnightUseEpisodeWakeDayAndIntervalUnion() {
        var document = ArchiveDocument()
        let stages = [
            sleep("a", "2026-10-26T22:00:00-04:00", "2026-10-27T07:00:00-04:00", stage: "inBed"),
            sleep("b", "2026-10-26T23:00:00-04:00", "2026-10-27T03:00:00-04:00", stage: "asleepCore"),
            sleep("c", "2026-10-27T02:00:00-04:00", "2026-10-27T04:00:00-04:00", stage: "asleepDeep"),
            sleep("d", "2026-10-27T04:00:00-04:00", "2026-10-27T07:00:00-04:00", stage: "asleepREM"),
            sleep("e", "2026-10-27T03:00:00-04:00", "2026-10-27T03:30:00-04:00", stage: "awake")]
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": stages + [stages[1]]]))
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 8)
        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue.count, 5)
    }

    func testPreMidnightStagesShareFinalWakeAttributionAndGarminWins() {
        var document = ArchiveDocument()
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [
            sleep("g1", "2026-10-26T21:00:00-04:00", "2026-10-26T23:59:00-04:00"),
            sleep("g2", "2026-10-27T00:00:00-04:00", "2026-10-27T05:01:00-04:00"),
            sleep("apple", "2026-10-26T22:00:00-04:00", "2026-10-27T08:00:00-04:00", source: "Apple Watch")]]))
        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entry(on: date)?.sleepHours ?? -1, 8, accuracy: 0.0001)
    }

    func testAfternoonWakeStillUsesPreviousDayAndDSTUsesElapsedTime() {
        var document = ArchiveDocument()
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [
            sleep("pm", "2026-10-27T06:00:00-04:00", "2026-10-27T14:00:00-04:00"),
            sleep("dst", "2026-11-01T00:00:00-04:00", "2026-11-01T08:00:00-05:00")]]))
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 8)
        XCTAssertEqual(document.entry(on: "2026-10-31")?.sleepHours, 9)
    }

    func testEmptyReadKeepsLegacyAndImportedRecordsAndOnlyExplicitProviderDeletionApplies() throws {
        var document = try documentFromJSON("""
        {"entries":[],"watchData":{"future":7,"sleepSessions":[
        {"id":"legacy","provider":"healthConnect","source":"Garmin","date":"2026-10-25","durationMinutes":420}],
        "workouts":[{"id":"shared","provider":"healthConnect","future":true}]}}
        """)
        document.applyHealthKit(HealthKitBatch(records: ["workouts": [
            .object(["id": .string("shared"), "provider": .string("healthKit"), "future": .number(5)])]]))
        let before = document.data["watchData"]
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [], "workouts": []]))
        XCTAssertEqual(document.data["watchData"], before)
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["workouts": ["shared"], "sleepSessions": ["legacy"]]))
        XCTAssertEqual(document.data["watchData"]?["workouts"].arrayValue.count, 1)
        XCTAssertEqual(document.data["watchData"]?["workouts"].arrayValue.first?["provider"], .string("healthConnect"))
        XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue.count, 1)
        XCTAssertEqual(document.data["watchData"]?["future"], .number(7))
    }

    func testSleepDeletionRemovesOnlyWatchProjectionAndKeepsIndependentWater() {
        var document = ArchiveDocument()
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [sleep(sleepID,
            "2026-10-27T01:00:00-04:00", "2026-10-27T09:00:00-04:00")]]))
        document.addWater(250, on: date)
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["sleepSessions": [sleepID.uppercased()]]))
        XCTAssertNil(document.entry(on: date)?.sleepHours)
        XCTAssertEqual(document.entry(on: date)?.waterML, 250)
        var watchOnly = ArchiveDocument()
        watchOnly.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [sleep(sleepID,
            "2026-10-27T01:00:00-04:00", "2026-10-27T09:00:00-04:00")]]))
        watchOnly.applyHealthKit(HealthKitBatch(deletedIDs: ["sleepSessions": [sleepID]]))
        XCTAssertTrue(watchOnly.entries.isEmpty)
    }

    func testCorrectedSleepMovesDayRestoresOldFallbackAndDoesNotDuplicate() {
        var document = ArchiveDocument()
        document.setManualSleep(6, on: date)
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [sleep(sleepID,
            "2026-10-27T01:00:00-04:00", "2026-10-27T09:00:00-04:00")]]))
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [sleep(sleepID,
            "2026-10-28T01:00:00-04:00", "2026-10-28T08:00:00-04:00")]]))
        XCTAssertEqual(document.entry(on: date)?.sleepHours, 6)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.sleepHours, 7)
        XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue.count, 1)
    }

    func testQuantitiesSelectOneSourcePerDayAndMetricAndDeriveCalories() throws {
        var document = ArchiveDocument()
        let records = [quantity("g", "steps", 100, "Garmin"), quantity("g2", "steps", 150, "Garmin"),
            quantity("a", "steps", 1000, "Apple Watch"), quantity("p", "steps", 2000, "iPhone"),
            quantity("distance", "distance", 500, "Apple Watch"),
            quantity("active", "activeCalories", 200, "Garmin"),
            quantity("basal", "basalCalories", 1500, "Apple Watch")]
        document.applyHealthKit(HealthKitBatch(records: ["quantitySamples": records + [records[0]]]))
        let summary = try XCTUnwrap(document.data["watchData"]?["dailySummaries"].arrayValue.first)
        XCTAssertEqual(summary["steps"], .number(250))
        XCTAssertEqual(summary["distanceMeters"], .number(500))
        XCTAssertEqual(summary["totalCalories"], .number(1700))
        XCTAssertEqual(summary["activeCalories"], .number(200))
        XCTAssertEqual(summary["metricSources"]["steps"]["source"], .string("Garmin"))
        XCTAssertEqual(document.data["watchData"]?["quantitySamples"].arrayValue.count, 7)
        XCTAssertTrue(document.entries.isEmpty, "Activity is not a fabricated manual daily report")
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["quantitySamples": ["g", "g2", "basal"]]))
        let changed = try XCTUnwrap(document.data["watchData"]?["dailySummaries"].arrayValue.first)
        XCTAssertEqual(changed["steps"], .number(1000))
        XCTAssertEqual(changed["totalCalories"], .null, "Missing basal is not zero")
        XCTAssertEqual(try ArchiveDocument(backup: document.backup()).data["watchData"], document.data["watchData"])
    }

    func testSummaryDeletionPreservesLegacySummaryAndUnknownFields() {
        var document = ArchiveDocument()
        document.data["watchData"] = .object(["dailySummaries": .array([
            .object(["id": .string("legacy"), "date": .string(date), "provider": .string("healthConnect"), "steps": .number(99)])])])
        document.applyHealthKit(HealthKitBatch(records: ["quantitySamples": [quantity("g", "steps", 100, "Garmin")]]))
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["quantitySamples": ["g"]]))
        XCTAssertEqual(document.data["watchData"]?["dailySummaries"].arrayValue.count, 1)
        XCTAssertEqual(document.data["watchData"]?["dailySummaries"].arrayValue.first?["steps"], .number(99))
    }

    func testAnchorsAndSamplesPreserveOtherMetadataAndSDNNIdentity() throws {
        var document = ArchiveDocument()
        document.data["nativeIOS"] = .object(["future": .number(8), "healthKitAnchors": .object(["old": .string("keep")])])
        document.data["watchData"] = .object(["samples": .object(["future": .string("retain")])])
        let hrv = JSONValue.object(["id": .string("hrv"), "provider": .string("healthKit"), "value": .number(44), "measurement": .string("SDNN")])
        document.applyHealthKit(HealthKitBatch(records: ["heartRateVariability": [hrv]], anchors: ["hrv": "opaque"]))
        XCTAssertEqual(document.data["watchData"]?["samples"]["heartRateVariability"].arrayValue, [hrv])
        XCTAssertEqual(document.data["watchData"]?["samples"]["future"], .string("retain"))
        XCTAssertEqual(document.data["nativeIOS"]?["future"], .number(8))
        XCTAssertEqual(document.data["nativeIOS"]?["healthKitAnchors"]["old"], .string("keep"))
        XCTAssertEqual(document.data["nativeIOS"]?["healthKitAnchors"]["hrv"], .string("opaque"))
        XCTAssertEqual(try ArchiveDocument(backup: document.backup()).data["watchData"], document.data["watchData"])
    }

    private func sleep(_ id: String, _ start: String, _ end: String,
                       stage: String = "asleep", source: String = "Garmin") -> JSONValue {
        .object(["id": .string(id), "provider": .string("healthKit"), "source": .string(source),
            "sourceId": .string(source == "Garmin" ? "com.garmin.connect" : "com.apple.health"),
            "startedAt": .string(start), "endedAt": .string(end), "date": .string(date),
            "timezone": .string("America/Toronto"), "stage": .string(stage)])
    }

    private func quantity(_ id: String, _ metric: String, _ value: Double, _ source: String) -> JSONValue {
        .object(["id": .string(id), "provider": .string("healthKit"), "source": .string(source),
            "sourceId": .string(source), "date": .string(date), "metric": .string(metric),
            "startedAt": .string("2026-10-26T12:00:00-04:00"),
            "endedAt": .string("2026-10-26T13:00:00-04:00"), "value": .number(value)])
    }
}
