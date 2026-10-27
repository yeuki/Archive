import Foundation
import XCTest
@testable import ArchiveCore

final class ArchiveDocumentTests: XCTestCase {
    func testJSONDefaultsSubscriptAndCodable() throws {
        var value = JSONValue.object([:])
        XCTAssertEqual(value["missing"], .null)
        value["future"] = .object(["array": .array([.null, .bool(true), .number(2.5)])])
        XCTAssertEqual(value["future"]["array"].arrayValue.count, 3)
        XCTAssertEqual(JSONValue.null.objectValue, [:])
        XCTAssertEqual(JSONValue.null.arrayValue, [])
        XCTAssertEqual(JSONValue.null.stringValue, "")
        XCTAssertEqual(JSONValue.null.doubleValue, 0)
        XCTAssertFalse(JSONValue.null.boolValue)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)), value)
        XCTAssertThrowsError(try JSONEncoder().encode(JSONValue.number(.infinity)))
    }

    func testUnknownFieldsSurviveImportMutationAndExport() throws {
        var document = try documentFromJSON("""
        {"entries":[{"date":"2026-10-27","habits":{"Read":true},"water":500,"sleep":7,
        "futureEntry":{"nested":[1,null,true]}}],"habitNames":["Read"],"goals":{"waterUnit":"ml","futureGoal":9},
        "workout":{"activeSession":{"unported":[1,2]},"workouts":[{"id":"past"}]},
        "future":{"nested":[false,null,{"x":"untouched"}]}}
        """)
        let future = document.data["future"]
        let workout = document.data["workout"]
        document.addWater(250, on: "2026-10-27")
        let exported = try JSONDecoder().decode(JSONValue.self, from: document.backup())
        XCTAssertEqual(exported["app"], .string("archive-productivity-tracker"))
        XCTAssertEqual(exported["version"], .number(4))
        XCTAssertEqual(exported["envelopeFuture"], .string("keep"))
        let restored = try ArchiveDocument(backup: document.backup())
        XCTAssertEqual(restored.data["future"], future)
        XCTAssertEqual(restored.data["workout"], workout)
        XCTAssertEqual(restored.data["entries"]?.arrayValue.first?["futureEntry"],
                       .object(["nested": .array([.number(1), .null, .bool(true)])]))
        XCTAssertEqual(restored.entry(on: "2026-10-27")?.waterML, 750)
    }

    func testNewDocumentAndDefinitionChangesDoNotFabricateHistory() throws {
        var document = ArchiveDocument()
        XCTAssertTrue(document.entries.isEmpty)
        document.addHabit("Stretch")
        document.setTracked("Stretch", enabled: false)
        document.renameHabit("Stretch", to: "Mobility")
        document.setHabit("Read", completed: false, on: "2026-10-27")
        document.addWater(0, on: "2026-10-27")
        XCTAssertTrue(document.entries.isEmpty)
        document.applyHealthKit(HealthKitBatch())
        XCTAssertTrue(document.entries.isEmpty)
        XCTAssertTrue(try ArchiveDocument(backup: document.backup()).entries.isEmpty)
    }

    func testPartialDailyMutationsRemainIndependentAndZeroIsRecorded() throws {
        var document = ArchiveDocument()
        document.setHabit("Read", completed: true, on: "2026-10-25")
        XCTAssertNil(document.entry(on: "2026-10-25")?.waterML)
        XCTAssertNil(document.entry(on: "2026-10-25")?.sleepHours)
        document.setWater(0, on: "2026-10-26")
        XCTAssertEqual(document.entry(on: "2026-10-26")?.waterML, 0)
        XCTAssertEqual(document.entry(on: "2026-10-26")?.habits, [:])
        XCTAssertNil(document.entry(on: "2026-10-26")?.sleepHours)
        document.setManualSleep(0, on: "2026-10-27")
        XCTAssertNil(document.entry(on: "2026-10-27")?.waterML)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.sleepHours, 0)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.sleepSource, "manual")
        document.addWater(250, on: "2026-10-25")
        document.setManualSleep(7.5, on: "2026-10-25")
        let restored = try ArchiveDocument(backup: document.backup())
        XCTAssertEqual(restored.entry(on: "2026-10-25")?.habits, ["Read": true])
        XCTAssertEqual(restored.entry(on: "2026-10-25")?.waterML, 250)
        XCTAssertEqual(restored.entry(on: "2026-10-25")?.sleepHours, 7.5)
        XCTAssertNil(restored.entry(on: "2026-10-26")?.sleepHours)
    }

    func testLegacyMissingMetricsAreRecordedButExplicitPartialMetricsAreNot() throws {
        let document = try documentFromJSON("""
        {"entries":[{"date":"2026-10-25"},
        {"date":"2026-10-26","water":800,"sleep":8,"recordedFields":{"habits":true}},
        {"date":"2026-10-27","recordedFields":{"water":true}}],"goals":{"waterUnit":"ml"}}
        """)
        XCTAssertEqual(document.entry(on: "2026-10-25")?.waterML, 0)
        XCTAssertEqual(document.entry(on: "2026-10-25")?.sleepHours, 0)
        XCTAssertNil(document.entry(on: "2026-10-26")?.waterML)
        XCTAssertNil(document.entry(on: "2026-10-26")?.sleepHours)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.waterML, 0)
        XCTAssertNil(document.entry(on: "2026-10-27")?.sleepHours)
    }

    func testLegacyCupsMigrationIsIdempotentAndPreservesGoals() throws {
        var document = try documentFromJSON("""
        {"entries":[{"date":"2026-10-27","water":8}],"goals":{"waterTarget":8,"future":true}}
        """)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.waterML, 2000)
        XCTAssertEqual(document.data["goals"]?["waterTarget"], .number(2000))
        XCTAssertEqual(document.data["goals"]?["future"], .bool(true))
        document.addWater(250, on: "2026-10-27")
        XCTAssertEqual(try ArchiveDocument(backup: document.backup()).entry(on: "2026-10-27")?.waterML, 2250)
        let modern = try documentFromJSON("""
        {"entries":[{"date":"2026-10-27","water":8}],"goals":{"waterUnit":"ml"}}
        """)
        XCTAssertEqual(modern.entry(on: "2026-10-27")?.waterML, 8)
    }

    func testRenameMergesHistoryWithoutLosingCompletionsOrOtherFields() throws {
        var document = try documentFromJSON("""
        {"habitNames":["Read","Book"],"trackedHabits":["Read"],"entries":[
        {"date":"2026-10-27","habits":{"Read":true,"Book":false},"water":500,"future":3}]}
        """)
        document.renameHabit("Read", to: "Book")
        XCTAssertEqual(document.habits, ["Book"])
        XCTAssertEqual(document.trackedHabits, ["Book"])
        XCTAssertEqual(document.entry(on: "2026-10-27")?.habits, ["Book": true])
        document.setTracked("Book", enabled: false)
        XCTAssertTrue(document.trackedHabits.isEmpty)
        XCTAssertEqual(document.entry(on: "2026-10-27")?.habits["Book"], true)
        XCTAssertEqual(document.data["entries"]?.arrayValue.first?["future"], .number(3))
    }

    func testMalformedBackupsThrowWithoutReplacingCaller() throws {
        var current = ArchiveDocument()
        current.setWater(500, on: "2026-10-27")
        let original = current
        let invalid = ["not json", "[]", "null", "{}", "{\"hello\":1}",
            "{\"app\":\"other\",\"version\":4,\"data\":{\"entries\":[]}}",
            "{\"app\":\"archive-productivity-tracker\",\"version\":4,\"data\":[]}",
            "{\"app\":\"archive-productivity-tracker\",\"version\":4,\"data\":{\"entries\":\"bad\"}}",
            "{\"app\":\"archive-productivity-tracker\",\"version\":4,\"data\":{\"entries\":[{\"date\":\"2026-02-30\"}]}}",
            "{\"app\":\"archive-productivity-tracker\",\"version\":4,\"data\":{\"entries\":[{\"date\":\"2026-10-27\",\"habits\":[]}]}}",
            "{\"app\":\"archive-productivity-tracker\",\"version\":4,\"data\":{\"entries\":[{\"date\":\"2026-10-27\",\"water\":-1}]}}"]
        for json in invalid {
            XCTAssertThrowsError(try { current = try ArchiveDocument(backup: Data(json.utf8)) }(), json)
            XCTAssertEqual(current, original)
        }
    }

    func testInvalidMutationsAreNoOpsAndDateKeyUsesCalendarTimeZone() {
        var document = ArchiveDocument()
        let original = document
        document.setWater(.nan, on: "2026-10-27")
        document.addWater(-250, on: "2026-10-27")
        document.setManualSleep(.infinity, on: "2026-10-27")
        document.setHabit("Read", completed: true, on: "2026-02-30")
        XCTAssertEqual(document, original)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let date = ISO8601DateFormatter().date(from: "2026-10-27T02:00:00Z")!
        XCTAssertEqual(ArchiveDocument.dateKey(date, calendar: calendar), "2026-10-26")
    }
}

func documentFromJSON(_ json: String) throws -> ArchiveDocument {
    let data = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    let envelope = JSONValue.object(["app": .string("archive-productivity-tracker"),
        "version": .number(4), "data": data, "envelopeFuture": .string("keep")])
    return try ArchiveDocument(backup: JSONEncoder().encode(envelope))
}
