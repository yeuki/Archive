import ArchiveCore
import Foundation
import XCTest
@testable import Archive

final class ArchiveStoreTests: XCTestCase {
    @MainActor
    func testUndoRestoresMissingHabitPresenceAndPreservesNestedMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ArchiveStore(directory: folder)
        store.change { data in
            data["entries"] = .array([.object([
                "date": .string("2026-10-27"), "habits": .object(["Read": .bool(false)]),
                "recordedFields": .object(["habits": .bool(false), "water": .bool(false), "sleep": .bool(false), "futureMetadata": .object(["keep": .number(1)])])
            ])])
        }
        store.setHabit("Read", completed: true, on: "2026-10-27")
        store.undo()
        let raw = try XCTUnwrap(store.document.data["entries"]?.arrayValue.first)
        XCTAssertEqual(raw["recordedFields"]["habits"], .bool(false))
        XCTAssertEqual(raw["recordedFields"]["futureMetadata"]["keep"], .number(1))
        store.addWater(250, on: "2026-10-27")
        store.undo()
        XCTAssertEqual(store.document.data["entries"]?.arrayValue.first?["recordedFields"]["futureMetadata"]["keep"], .number(1))
    }

    @MainActor
    func testWaterUndoPreservesSubsequentHabitAndUnknownEntryFields() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ArchiveStore(directory: folder)
        let day = "2026-10-27"
        store.addWater(250, on: day)
        store.commit { document in
            document.setHabit("Read", completed: true, on: day)
            var entries = document.data["entries"]!.arrayValue
            entries[0]["futureEntry"] = .string("keep")
            document.data["entries"] = .array(entries)
        }
        store.undo()
        XCTAssertNil(store.document.entry(on: day)?.waterML)
        XCTAssertEqual(store.document.entry(on: day)?.habits["Read"], true)
        XCTAssertEqual(store.document.data["entries"]?.arrayValue.first?["futureEntry"], .string("keep"))
        let restored = ArchiveStore(directory: folder)
        XCTAssertEqual(restored.document.data, store.document.data)
    }

    @MainActor
    func testHabitUndoOnlyRestoresThatHabit() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ArchiveStore(directory: folder)
        store.setHabit("Read", completed: true, on: "2026-10-27")
        store.commit { $0.setHabit("Journal", completed: true, on: "2026-10-27") }
        store.undo()
        XCTAssertNotEqual(store.document.entry(on: "2026-10-27")?.habits["Read"], true)
        XCTAssertEqual(store.document.entry(on: "2026-10-27")?.habits["Journal"], true)
    }

    @MainActor
    func testFailedWriteLeavesPublishedDocumentUnchanged() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let moved = folder.appendingPathExtension("moved")
        defer { try? FileManager.default.removeItem(at: moved); try? FileManager.default.removeItem(at: folder) }
        let store = ArchiveStore(directory: folder)
        store.addWater(250, on: "2026-10-27")
        let original = store.document
        try FileManager.default.moveItem(at: folder, to: moved)
        store.addWater(500, on: "2026-10-27")
        XCTAssertEqual(store.document, original)
        XCTAssertNotNil(store.errorMessage)
    }

    @MainActor
    func testCorruptStartupFileIsNotOverwrittenAndImportKeepsRecoveryCopy() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("records.json")
        let corrupt = Data("corrupt records".utf8)
        try corrupt.write(to: file)
        let store = ArchiveStore(directory: folder)
        store.addWater(250, on: "2026-10-27")
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        var replacement = ArchiveDocument()
        replacement.setWater(500, on: "2026-10-26")
        store.importBackup(try replacement.backup())
        XCTAssertEqual(store.document.entry(on: "2026-10-26")?.waterML, 500)
        let recovery = try FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil)
        XCTAssertEqual(recovery.count, 1)
        XCTAssertEqual(try Data(contentsOf: recovery[0]), corrupt)
    }

    @MainActor
    func testMalformedImportDoesNotChangeDataAndPortableImportResetsDeviceCursors() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ArchiveStore(directory: folder)
        store.addWater(250, on: "2026-10-27")
        let original = store.document
        store.importBackup(Data("{}".utf8))
        XCTAssertEqual(store.document, original)
        var next = ArchiveDocument()
        next.data["futureRoot"] = .string("retained")
        next.data["nativeIOS"] = .object(["healthKitEnabled": .bool(true), "healthKitAnchors": .object(["type": .string("another-phone-cursor")])])
        store.importBackup(try next.backup())
        XCTAssertEqual(store.document.data["futureRoot"], .string("retained"))
        XCTAssertFalse(store.healthEnabled)
        XCTAssertEqual(store.nativeSettings["healthKitAnchors"], .object([:]))
    }
}
