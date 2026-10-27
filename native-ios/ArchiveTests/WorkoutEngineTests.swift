import Foundation
import XCTest
import ArchiveCore
@testable import Archive

final class WorkoutEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func json(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    private func session() throws -> JSONValue {
        let routine = try json(#"{"id":"r","name":"My routine","exerciseIds":["squat"],"plan":{"squat":{"sets":2,"reps":"5","weight":20,"rest":90}},"future":{"keep":true}}"#)
        let library = try json(#"[{"id":"squat","name":"Squat","equipment":"Barbell"}]"#).arrayValue
        return NativeWorkoutEngine.newSession(routine: routine, library: library, history: [], now: start)
    }

    func testCompletionSavesSetBeforeTimestampRestAndNeverCreatesHistory() throws {
        let active = try session()
        let completed = NativeWorkoutEngine.completeSet(active, now: start.addingTimeInterval(10))
        XCTAssertEqual(completed.w("status"), .string("resting"))
        XCTAssertEqual(completed.w("cursor").w("setIndex"), .number(1))
        let set = completed.w("exercises").arrayValue[0].w("sets").arrayValue[0]
        XCTAssertEqual(set.w("status"), .string("completed"))
        XCTAssertFalse(set.w("completedAt").stringValue.isEmpty)
        XCTAssertEqual(NativeWorkoutEngine.restRemaining(completed, now: start.addingTimeInterval(40)), 60)
        XCTAssertEqual(NativeWorkoutEngine.restRemaining(completed, now: start.addingTimeInterval(200)), 0)
        XCTAssertEqual(completed.w("workouts"), .null)
    }

    func testPausedTimerIsDifferentFromPausedWorkoutAndSurvivesRoundTrip() throws {
        let completed = NativeWorkoutEngine.completeSet(try session(), now: start)
        let timerPaused = NativeWorkoutEngine.toggleRest(completed, now: start.addingTimeInterval(20))
        XCTAssertEqual(timerPaused.w("status"), .string("resting"))
        XCTAssertEqual(NativeWorkoutEngine.restRemaining(timerPaused, now: start.addingTimeInterval(500)), 70)
        let paused = NativeWorkoutEngine.pause(timerPaused, now: start.addingTimeInterval(30))
        let restored = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(paused))
        XCTAssertEqual(restored.w("status"), .string("paused"))
        let resumed = NativeWorkoutEngine.resume(restored, now: start.addingTimeInterval(130))
        XCTAssertEqual(resumed.w("status"), .string("resting"))
        XCTAssertEqual(resumed.w("accumulatedPausedMs"), .number(100_000))
        XCTAssertEqual(NativeWorkoutEngine.restRemaining(resumed, now: start.addingTimeInterval(140)), 60)
    }

    func testUnknownSessionExerciseSetAndDocumentFieldsSurviveFinish() throws {
        var active = try session()
        active = active.wMerging(["future": .string("session")])
        var exercises = active.w("exercises").arrayValue
        var sets = exercises[0].w("sets").arrayValue
        sets[0] = sets[0].wMerging(["futureSet": .bool(true)])
        exercises[0] = exercises[0].wMerging(["futureExercise": .number(42), "sets": .array(sets)])
        active = active.wMerging(["exercises": .array(exercises)])
        let completed = NativeWorkoutEngine.completeSet(active, now: start)
        let summary = NativeWorkoutEngine.review(completed, now: start.addingTimeInterval(60))
        var data: [String: JSONValue] = ["futureRoot": .bool(true), "workout": .object([
            "activeSession": summary, "futureWorkout": .string("keep"),
            "workouts": .array([try json(#"{"id":"other","date":"2027-01-15","routineName":"Earlier"}"#)])
        ]), "watchData": try json(#"{"workouts":[{"id":"watch","date":"2027-01-15"}]}"#)]
        let watch = data["watchData"]
        NativeWorkoutEngine.finish(in: &data, sessionID: summary.w("id").stringValue, now: start.addingTimeInterval(60))
        let workout = try XCTUnwrap(data["workout"])
        XCTAssertEqual(workout.w("activeSession"), .null)
        XCTAssertEqual(workout.w("futureWorkout"), .string("keep"))
        XCTAssertEqual(data["futureRoot"], .bool(true))
        XCTAssertEqual(data["watchData"], watch)
        let logs = workout.w("workouts").arrayValue
        XCTAssertEqual(logs.count, 2)
        let saved = try XCTUnwrap(logs.first { $0.w("sessionId") == summary.w("id") })
        XCTAssertEqual(saved.w("future"), .string("session"))
        XCTAssertEqual(saved.w("routineSnapshot").w("future").w("keep"), .bool(true))
        XCTAssertEqual(saved.w("exercises").arrayValue[0].w("futureExercise"), .number(42))
        XCTAssertEqual(saved.w("exercises").arrayValue[0].w("sets").arrayValue[0].w("futureSet"), .bool(true))
        // A duplicate callback must not create another log, even if the active value is restored.
        data["workout"] = workout.wMerging(["activeSession": summary])
        NativeWorkoutEngine.finish(in: &data, sessionID: summary.w("id").stringValue, now: start)
        XCTAssertEqual(data["workout"]?.w("workouts").arrayValue.count, 2)
    }

    func testUnfinishedSessionCannotBeFinishedWithoutReviewAndStaleIDCannotClearIt() throws {
        let active = try session()
        var data: [String: JSONValue] = ["workout": .object(["activeSession": active])]
        NativeWorkoutEngine.finish(in: &data, sessionID: active.w("id").stringValue, now: start)
        XCTAssertEqual(data["workout"]?.w("activeSession"), active)
        let reviewed = NativeWorkoutEngine.review(active, now: start)
        data["workout"] = .object(["activeSession": reviewed])
        NativeWorkoutEngine.finish(in: &data, sessionID: "stale", now: start)
        XCTAssertEqual(data["workout"]?.w("activeSession"), reviewed)
    }

    func testEmptyRoutineHasNoInventedExercisesAndNeedsExplicitFinish() throws {
        let routine = try json(#"{"id":"empty","name":"Empty","exerciseIds":[],"plan":{}}"#)
        let active = NativeWorkoutEngine.newSession(routine: routine, library: [], history: [], now: start)
        XCTAssertEqual(active.w("status"), .string("summary"))
        XCTAssertEqual(active.w("exercises"), .array([]))
        var data: [String: JSONValue] = ["workout": .object(["activeSession": active])]
        XCTAssertEqual(data["workout"]?.w("workouts"), .null)
        NativeWorkoutEngine.finish(in: &data, sessionID: active.w("id").stringValue, now: start)
        XCTAssertEqual(data["workout"]?.w("workouts").arrayValue.count, 1)
    }

    func testImportedCursorFindsPendingSetWithoutDroppingUnknownFields() throws {
        let imported = try json(#"{"id":"imported","status":"active","future":true,"cursor":{"exerciseIndex":99,"setIndex":99,"futureCursor":true},"exercises":[{"exerciseId":"x","sets":[{"done":true,"reps":"5"},{"weight":"12.5","reps":"45s","futureSet":7}]}]}"#)
        let normalized = try XCTUnwrap(NativeWorkoutEngine.normalized(imported))
        XCTAssertEqual(normalized.w("cursor").w("setIndex"), .number(1))
        XCTAssertEqual(normalized.w("cursor").w("futureCursor"), .bool(true))
        let edited = NativeWorkoutEngine.patchCurrentSet(normalized, fields: ["weight": .number(15)], now: start)
        XCTAssertEqual(edited.w("future"), .bool(true))
        XCTAssertEqual(edited.w("exercises").arrayValue[0].w("sets").arrayValue[1].w("futureSet"), .number(7))
        XCTAssertEqual(edited.w("exercises").arrayValue[0].w("sets").arrayValue[1].w("reps"), .string("45s"))
    }

    func testLatestCountedHistoryProvidesDefaultsButNotWarmupOrSkippedSets() throws {
        let routine = try json(#"{"id":"r","name":"R","exerciseIds":["x"],"plan":{"x":{"sets":2,"reps":"8","weight":0,"rest":0}}}"#)
        let library = try json(#"[{"id":"x","name":"Press"}]"#).arrayValue
        let history = try json(#"[{"date":"2026-10-01","exercises":[{"exerciseId":"x","sets":[{"weight":10,"reps":"8","done":true}]}]},{"date":"2026-10-02","exercises":[{"exerciseId":"x","sets":[{"weight":5,"reps":"4","status":"completed","setType":"warmup"},{"weight":20,"reps":"6","status":"failed"},{"weight":99,"reps":"2","status":"skipped"}]}]}]"#).arrayValue
        let active = NativeWorkoutEngine.newSession(routine: routine, library: library, history: history, now: start)
        let sets = active.w("exercises").arrayValue[0].w("sets").arrayValue
        XCTAssertEqual(sets[0].w("weight"), .number(20))
        XCTAssertEqual(sets[1].w("previousReps"), .string("6"))
        XCTAssertEqual(sets[0].w("plannedReps"), .string("8"))
    }

    func testPlansDoNotImposeTwelveSetOrTenMinuteRestCeilings() throws {
        let routine = try json(#"{"id":"r","name":"R","exerciseIds":["x"],"plan":{"x":{"sets":13,"reps":"20001","weight":100001,"rest":1200}}}"#)
        let active = NativeWorkoutEngine.newSession(routine: routine, library: [], history: [], now: start)
        XCTAssertEqual(active.w("exercises").arrayValue[0].w("sets").arrayValue.count, 13)
        let completed = NativeWorkoutEngine.completeSet(active, now: start)
        XCTAssertEqual(NativeWorkoutEngine.restRemaining(completed, now: start.addingTimeInterval(1)), 1199)
        let set = completed.w("exercises").arrayValue[0].w("sets").arrayValue[0]
        XCTAssertEqual(set.w("weight"), .number(100001))
        XCTAssertEqual(set.w("reps"), .string("20001"))
    }

    func testAllocationGuardDoesNotRewriteImportedRoutineOrSnapshot() throws {
        let routine = try json(#"{"id":"r","name":"R","exerciseIds":["x"],"plan":{"x":{"sets":1000000}}}"#)
        let active = NativeWorkoutEngine.newSession(routine: routine, library: [], history: [], now: start)
        XCTAssertEqual(active.w("exercises").arrayValue[0].w("sets").arrayValue.count, 100)
        XCTAssertEqual(active.w("routineSnapshot"), routine)
        XCTAssertEqual(routine.w("plan").w("x").w("sets"), .number(1000000))
    }

    func testSkippingDoesNotStartRestAndFinalSetOnlyEntersReview() throws {
        let skipped = NativeWorkoutEngine.completeSet(try session(), outcome: "skipped", now: start)
        XCTAssertEqual(skipped.w("status"), .string("active"))
        XCTAssertEqual(skipped.w("rest"), .null)
        let final = NativeWorkoutEngine.completeSet(skipped, now: start.addingTimeInterval(5))
        XCTAssertEqual(final.w("status"), .string("summary"))
        XCTAssertEqual(final.w("exercises").arrayValue[0].w("sets").arrayValue[0].w("status"), .string("skipped"))
        XCTAssertEqual(final.w("exercises").arrayValue[0].w("sets").arrayValue[1].w("status"), .string("completed"))
        XCTAssertEqual(final.w("workouts"), .null)
    }

    func testRestExpiryAutomaticallyAdvancesOnlyAtMatchingDeadline() throws {
        let resting = NativeWorkoutEngine.completeSet(try session(), now: start)
        let id = resting.w("id").stringValue
        let deadline = resting.w("rest").w("endsAt").stringValue
        XCTAssertEqual(NativeWorkoutEngine.expireRest(resting, sessionID: id, deadline: deadline, now: start.addingTimeInterval(89)), resting)
        let advanced = NativeWorkoutEngine.expireRest(resting, sessionID: id, deadline: deadline, now: start.addingTimeInterval(90))
        XCTAssertEqual(advanced.w("status"), .string("active"))
        XCTAssertEqual(advanced.w("rest"), .null)
        XCTAssertEqual(advanced.w("cursor").w("setIndex"), .number(1))
        XCTAssertEqual(advanced.w("exercises").arrayValue[0].w("sets").arrayValue[0].w("status"), .string("completed"))
        // Relaunching long after the deadline advances, without another set completion.
        let restored = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(resting))
        XCTAssertEqual(NativeWorkoutEngine.expireRest(restored, sessionID: id, deadline: deadline, now: start.addingTimeInterval(200)).w("status"), .string("active"))
    }

    func testStaleRestTaskCannotAdvancePausedResumedSkippedOrOtherSession() throws {
        let resting = NativeWorkoutEngine.completeSet(try session(), now: start)
        let id = resting.w("id").stringValue
        let deadline = resting.w("rest").w("endsAt").stringValue
        let timerPaused = NativeWorkoutEngine.toggleRest(resting, now: start.addingTimeInterval(10))
        XCTAssertEqual(NativeWorkoutEngine.expireRest(timerPaused, sessionID: id, deadline: deadline, now: start.addingTimeInterval(100)), timerPaused)
        let workoutPaused = NativeWorkoutEngine.pause(resting, now: start.addingTimeInterval(10))
        XCTAssertEqual(NativeWorkoutEngine.expireRest(workoutPaused, sessionID: id, deadline: deadline, now: start.addingTimeInterval(100)), workoutPaused)
        let resumed = NativeWorkoutEngine.resume(workoutPaused, now: start.addingTimeInterval(50))
        XCTAssertEqual(NativeWorkoutEngine.expireRest(resumed, sessionID: id, deadline: deadline, now: start.addingTimeInterval(100)), resumed)
        let skipped = NativeWorkoutEngine.finishRest(resting, now: start.addingTimeInterval(10))
        XCTAssertEqual(NativeWorkoutEngine.expireRest(skipped, sessionID: id, deadline: deadline, now: start.addingTimeInterval(100)), skipped)
        XCTAssertEqual(NativeWorkoutEngine.expireRest(resting, sessionID: "other-session", deadline: deadline, now: start.addingTimeInterval(100)), resting)
    }

    @MainActor
    func testStoreRelaunchRestoresCompletedSetAndFinishPersistsBothChangesTogether() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let active = try session()
        let store = ArchiveStore(directory: directory)
        store.change { data in data["workout"] = .object(["activeSession": active, "future": .bool(true)]) }
        store.change { data in
            let workout = data["workout"] ?? .null
            data["workout"] = workout.wMerging(["activeSession": NativeWorkoutEngine.completeSet(workout.w("activeSession"), now: start)])
        }
        let relaunched = ArchiveStore(directory: directory)
        let restored = try XCTUnwrap(relaunched.document.data["workout"])
        XCTAssertEqual(restored.w("activeSession").w("status"), .string("resting"))
        XCTAssertEqual(restored.w("activeSession").w("exercises").arrayValue[0].w("sets").arrayValue[0].w("status"), .string("completed"))
        XCTAssertEqual(restored.w("workouts"), .null)
        relaunched.change { data in
            let workout = data["workout"] ?? .null
            data["workout"] = workout.wMerging(["activeSession": NativeWorkoutEngine.review(workout.w("activeSession"), now: start)])
            NativeWorkoutEngine.finish(in: &data, sessionID: active.w("id").stringValue, now: start)
        }
        let finished = ArchiveStore(directory: directory)
        XCTAssertEqual(finished.document.data["workout"]?.w("activeSession"), .null)
        XCTAssertEqual(finished.document.data["workout"]?.w("workouts").arrayValue.count, 1)
        XCTAssertEqual(finished.document.data["workout"]?.w("future"), .bool(true))
        XCTAssertNil(finished.errorMessage)
    }

    @MainActor
    func testFailedPersistenceKeepsActiveSessionAndDoesNotCreateHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ArchiveStore(directory: directory)
        let reviewed = NativeWorkoutEngine.review(try session(), now: start)
        store.change { $0["workout"] = .object(["activeSession": reviewed]) }
        XCTAssertEqual(store.document.data["workout"]?.w("activeSession"), reviewed)
        // Occupy the records path with a nonempty directory: an atomic file rename
        // must fail, without depending on process-specific permission behavior.
        let records = directory.appendingPathComponent("records.json")
        try FileManager.default.removeItem(at: records)
        try FileManager.default.createDirectory(at: records.appendingPathComponent("occupied"), withIntermediateDirectories: true)
        store.change { data in NativeWorkoutEngine.finish(in: &data, sessionID: reviewed.w("id").stringValue, now: start) }
        XCTAssertEqual(store.document.data["workout"]?.w("activeSession"), reviewed)
        XCTAssertEqual(store.document.data["workout"]?.w("workouts"), .null)
        XCTAssertNotNil(store.errorMessage)
    }
}
