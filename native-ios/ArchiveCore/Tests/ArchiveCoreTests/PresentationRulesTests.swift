import Foundation
import XCTest
@testable import ArchiveCore

final class PresentationRulesTests: XCTestCase {
    func testModuleSpanIsClampedBeforeIntegerConversion() {
        XCTAssertEqual(ArchiveDocument.moduleSpanDays(.number(1e100)), 365)
        XCTAssertEqual(ArchiveDocument.moduleSpanDays(.number(-1e100)), 1)
        XCTAssertEqual(ArchiveDocument.moduleSpanDays(.number(.nan)), 7)
        XCTAssertEqual(ArchiveDocument.moduleSpanDays(.null), 7)
        XCTAssertEqual(ArchiveDocument.moduleSpanDays(.number(30)), 30)
    }

    func testReorderIncludesHabitNamesRecoveredFromHistory() throws {
        var document = try documentFromJSON(#"{"entries":[{"date":"2026-10-27","habits":{"Walk":true}}],"habitNames":["Read"]}"#)
        XCTAssertEqual(document.habits, ["Read", "Walk"])
        document.reorderHabits(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(document.habits, ["Walk", "Read"])
        XCTAssertEqual(document.entry(on: "2026-10-27")?.habits["Walk"], true)
        let saved = document
        document.reorderHabits(fromOffsets: IndexSet(integer: 999), toOffset: 0)
        XCTAssertEqual(document, saved)
    }
}
