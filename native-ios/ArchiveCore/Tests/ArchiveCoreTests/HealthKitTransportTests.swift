import Foundation
import XCTest
@testable import ArchiveCore

/// Fixtures mirror HealthKitService.record, not a made-up higher-level session.
/// All timestamps are fractional UTC; local sample-start date is NOT sleep date.
final class HealthKitTransportTests: XCTestCase {
    func testEveryActualTransportSleepCategoryHonorsExplicitAsleepFlag() throws {
        let stages: [(Double, String, Bool)] = [(0, "inBed", false), (1, "asleepUnspecified", true),
            (2, "awake", false), (3, "asleepCore", true), (4, "asleepDeep", true),
            (5, "asleepREM", true), (999, "unknown", false)]
        for (value, stage, asleep) in stages {
            var document = ArchiveDocument()
            var record = try transportRecord()
            record["sleepStageValue"] = .number(value)
            record["sleepStage"] = .string(stage)
            record["isAsleep"] = .bool(asleep)
            record["durationSeconds"] = .number(28800)
            document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [record]]))
            XCTAssertEqual(document.entry(on: "2026-10-26")?.sleepHours, asleep ? 8 : nil, stage)
            XCTAssertNil(document.entry(on: "2026-10-27"), stage)
            XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue, [record])
        }
    }

    func testExplicitFalseWinsEvenWhenStageSaysAsleepAndUnknownStageDoesNotInventSleep() throws {
        var document = ArchiveDocument()
        var record = try transportRecord()
        record["sleepStage"] = .string("asleepCore")
        record["isAsleep"] = .bool(false)
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [record]]))
        XCTAssertTrue(document.entries.isEmpty)
        var object = record.objectValue
        object.removeValue(forKey: "isAsleep")
        object["sleepStage"] = .string("futureUnsupportedCategory")
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [.object(object)]]))
        XCTAssertTrue(document.entries.isEmpty)
    }

    func testActualQuantityAndHRVShapesRoundtripAndUUIDDeletionIsLayerScoped() throws {
        var document = ArchiveDocument()
        let syncedAt = ISO8601DateFormatter().date(from: "2026-10-27T14:00:00Z")!
        var quantity = try transportRecord()
        quantity["healthKitType"] = .string("HKQuantityTypeIdentifierStepCount")
        quantity["metric"] = .string("steps")
        quantity["value"] = .number(4321)
        quantity["unit"] = .string("count")
        var hrv = quantity
        hrv["healthKitType"] = .string("HKQuantityTypeIdentifierHeartRateVariabilitySDNN")
        hrv["metric"] = .string("heartRateVariability")
        hrv["value"] = .number(44)
        hrv["unit"] = .string("ms")
        hrv["measurement"] = .string("SDNN")
        document.applyHealthKit(HealthKitBatch(records: ["quantitySamples": [quantity], "heartRateVariability": [hrv]], syncedAt: syncedAt))
        XCTAssertEqual(document.data["watchData"]?["dailySummaries"].arrayValue.first?["steps"], .number(4321))
        let restored = try ArchiveDocument(backup: document.backup())
        XCTAssertEqual(restored.data["watchData"]?["quantitySamples"].arrayValue, [quantity])
        XCTAssertEqual(restored.data["watchData"]?["samples"]["heartRateVariability"].arrayValue, [hrv])
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["quantitySamples": [quantity["id"].stringValue.lowercased()]], syncedAt: syncedAt))
        XCTAssertEqual(document.data["watchData"]?["samples"]["heartRateVariability"].arrayValue, [hrv])
        XCTAssertEqual(document.data["watchData"]?["dailySummaries"].arrayValue, [])
    }

    func testCorrectedUUIDPreservesExtensionFieldsAndCaseInsensitiveIdentity() throws {
        var document = ArchiveDocument()
        var record = try transportRecord()
        record["sleepStage"] = .string("asleepUnspecified")
        record["isAsleep"] = .bool(true)
        record["future"] = .object(["x": .array([.number(3), .null])])
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [record]]))
        var corrected = record.objectValue
        corrected.removeValue(forKey: "future")
        corrected["id"] = .string(record["id"].stringValue.lowercased())
        corrected["endedAt"] = .string("2026-10-27T12:00:00.000Z")
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [.object(corrected)]]))
        XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue.count, 1)
        XCTAssertEqual(document.data["watchData"]?["sleepSessions"].arrayValue.first?["future"], record["future"])
        XCTAssertEqual(document.entry(on: "2026-10-26")?.sleepHours, 7)
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["sleepSessions": [record["id"].stringValue]]))
        XCTAssertTrue(document.entries.isEmpty)
    }

    func testManualFallbackAndItsUnknownMetadataSurviveWatchEditsAndDeletion() throws {
        var document = ArchiveDocument()
        document.setManualSleep(6, on: "2026-10-26")
        var raw = try XCTUnwrap(document.data["entries"]?.arrayValue.first)
        raw["nativeIOS"] = .object(["future": .bool(true), "sleepFallback": .object(["futureFallback": .string("retain")])])
        document.data["entries"] = .array([raw])
        var record = try transportRecord()
        record["sleepStage"] = .string("asleepUnspecified")
        record["isAsleep"] = .bool(true)
        document.applyHealthKit(HealthKitBatch(records: ["sleepSessions": [record]]))
        document.setManualSleep(7, on: "2026-10-26")
        document.setWater(750, on: "2026-10-26")
        document.applyHealthKit(HealthKitBatch(deletedIDs: ["sleepSessions": [record["id"].stringValue]]))
        XCTAssertEqual(document.entry(on: "2026-10-26")?.sleepHours, 7)
        XCTAssertEqual(document.entry(on: "2026-10-26")?.waterML, 750)
        let stored = try XCTUnwrap(document.data["entries"]?.arrayValue.first)
        XCTAssertEqual(stored["nativeIOS"]["future"], .bool(true))
        XCTAssertEqual(stored["nativeIOS"]["sleepFallback"]["futureFallback"], .string("retain"))
    }

    private func transportRecord() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data("""
        {"id":"AEABCDEF-0000-0000-0000-000000000001","provider":"healthKit",
        "source":"Connect","sourceId":"com.garmin.connect.mobile",
        "startedAt":"2026-10-27T05:00:00.000Z","endedAt":"2026-10-27T13:00:00.000Z",
        "timezone":"America/Toronto","date":"2026-10-27",
        "startDate":"2026-10-27T05:00:00.000Z","endDate":"2026-10-27T13:00:00.000Z",
        "timeZone":"America/Toronto","timeZoneSource":"sampleMetadata",
        "sourceName":"Connect","sourceBundleId":"com.garmin.connect.mobile",
        "sourceRevision":{"name":"Connect","bundleIdentifier":"com.garmin.connect.mobile","version":"1",
        "productType":null,"operatingSystemVersion":{"major":26,"minor":0,"patch":0}},
        "device":{"name":"Garmin","manufacturer":"Garmin","model":"watch","localIdentifier":null},
        "metadata":{"HKTimeZone":"America/Toronto","HKWasUserEntered":false}}
        """.utf8))
    }
}
