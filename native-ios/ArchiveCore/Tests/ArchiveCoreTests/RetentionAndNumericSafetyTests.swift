import Foundation
import XCTest
@testable import ArchiveCore

final class RetentionAndNumericSafetyTests: XCTestCase {
    private let sync = ISO8601DateFormatter().date(from: "2026-10-27T12:00:00Z")!

    func testThirtyDayHeartRetentionPreservesBoundaryOtherProvidersAndUnknownFields() throws {
        var document = ArchiveDocument()
        let old = sample("old", time: sync.addingTimeInterval(-31 * 86400))
        let boundary = sample("boundary", time: sync.addingTimeInterval(-30 * 86400))
        let recent = sample("recent", time: sync.addingTimeInterval(-100))
        var legacy = old
        legacy["provider"] = .string("healthConnect")
        var rmssd = legacy
        rmssd["measurement"] = .string("RMSSD")
        document.data["watchData"] = .object(["future": .bool(true), "samples": .object([
            "future": .object(["untouched": .number(8)]), "heartRate": .array([old, boundary, legacy]),
            "heartRateVariability": .array([old, boundary, rmssd])])])
        document.applyHealthKit(HealthKitBatch(records: ["heartRate": [recent]], syncedAt: sync))
        let samples = try XCTUnwrap(document.data["watchData"]?["samples"])
        XCTAssertEqual(samples["heartRate"].arrayValue, [boundary, legacy, recent])
        XCTAssertEqual(samples["heartRateVariability"].arrayValue, [boundary, rmssd])
        XCTAssertEqual(samples["future"]["untouched"], .number(8))
        XCTAssertEqual(samples["heartRate"].arrayValue.first?["future"], .object(["keep": .bool(true)]))
        XCTAssertEqual(document.data["watchData"]?["future"], .bool(true))
    }

    func testAnchoredIncrementsStayAt2500PerLayerWhileOtherProvidersRemain() throws {
        var document = ArchiveDocument()
        let first = (0..<2500).map { sample("sample-\($0)", time: sync.addingTimeInterval(Double($0 - 5000))) }
        let extra = sample("newest", time: sync)
        var legacy = sample("other-provider", time: sync.addingTimeInterval(-100 * 86400))
        legacy["provider"] = .string("healthConnect")
        for layer in ["heartRate", "heartRateVariability"] {
            document.applyHealthKit(HealthKitBatch(records: [layer: first], syncedAt: sync))
        }
        var watch = document.data["watchData"]!.objectValue
        var samples = watch["samples"]!.objectValue
        samples["heartRate"] = .array((samples["heartRate"]?.arrayValue ?? []) + [legacy])
        watch["samples"] = .object(samples)
        document.data["watchData"] = .object(watch)
        document.applyHealthKit(HealthKitBatch(records: ["heartRate": [extra], "heartRateVariability": [extra]], syncedAt: sync))
        for layer in ["heartRate", "heartRateVariability"] {
            let stored = document.data["watchData"]!["samples"][layer].arrayValue
            XCTAssertEqual(stored.filter { $0["provider"] == .string("healthKit") }.count, 2500)
            XCTAssertTrue(stored.contains { $0["id"] == .string("newest") })
            XCTAssertFalse(stored.contains { $0["id"] == .string("sample-0") })
        }
        XCTAssertTrue(document.data["watchData"]!["samples"]["heartRate"].arrayValue.contains(legacy))
    }

    func testRetentionNeverPrunesQuantitiesOrTheirOldDailyAggregates() {
        var document = ArchiveDocument()
        var quantity = sample("old-quantity", time: sync.addingTimeInterval(-100 * 86400))
        quantity["date"] = .string("2026-07-19")
        quantity["metric"] = .string("steps")
        quantity["value"] = .number(1234)
        document.applyHealthKit(HealthKitBatch(records: ["quantitySamples": [quantity]], syncedAt: sync))
        let before = document.data["watchData"]
        document.applyHealthKit(HealthKitBatch(syncedAt: sync.addingTimeInterval(31 * 86400)))
        XCTAssertEqual(document.data["watchData"], before)
        XCTAssertEqual(document.data["watchData"]?["dailySummaries"].arrayValue.first?["steps"], .number(1234))
    }

    func testUndatedHeartSamplesAreAlsoCountBoundedWithoutTouchingLegacyRows() {
        var document = ArchiveDocument()
        let records = (0..<2501).map { JSONValue.object(["id": .string("undated-\($0)"), "provider": .string("healthKit")]) }
        document.applyHealthKit(HealthKitBatch(records: ["heartRate": records], syncedAt: sync))
        XCTAssertEqual(document.data["watchData"]?["samples"]["heartRate"].arrayValue.count, 2500)
    }

    func testHugeFiniteImportedMetricsRemainRawButDisplayWithoutIntegerTraps() throws {
        var document = try documentFromJSON("""
        {"entries":[{"date":"2026-10-27","water":1e300,"sleep":1e300}],"goals":{"waterUnit":"ml"}}
        """)
        let day = try XCTUnwrap(document.entry(on: "2026-10-27"))
        XCTAssertEqual(Int(try XCTUnwrap(day.waterML)), 1_000_000_000)
        XCTAssertEqual(Int(try XCTUnwrap(day.sleepHours) * 60), 1440)
        let raw = document.data["entries"]
        document.addWater(250, on: "2026-10-27")
        document.setWater(1e300, on: "2026-10-27")
        document.setManualSleep(1e300, on: "2026-10-27")
        XCTAssertEqual(document.data["entries"], raw, "Do not overwrite huge raw imports with display clamps")
        let restored = try ArchiveDocument(backup: document.backup())
        XCTAssertEqual(restored.data["entries"]?.arrayValue.first?["water"], .number(1e300))
        XCTAssertEqual(restored.data["entries"]?.arrayValue.first?["sleep"], .number(1e300))
    }

    private func sample(_ id: String, time: Date) -> JSONValue {
        .object(["id": .string(id), "provider": .string("healthKit"), "source": .string("Apple Watch"),
            "sourceId": .string("com.apple.health"), "startedAt": .string(ISO8601DateFormatter().string(from: time)),
            "value": .number(60), "future": .object(["keep": .bool(true)])])
    }
}
