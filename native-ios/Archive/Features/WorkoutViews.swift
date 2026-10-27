import Foundation
import SwiftUI
import ArchiveCore

// Feature-local JSON access. Mutations merge only the fields this increment owns;
// imported snapshots, future keys, and unrelated document areas remain intact.
extension JSONValue {
    func w(_ key: String) -> JSONValue { objectValue[key] ?? .null }
    func wMerging(_ fields: [String: JSONValue]) -> JSONValue {
        .object(objectValue.merging(fields) { _, new in new })
    }
    func wText(_ fallback: String = "") -> String {
        switch self {
        case .string(let value): return value
        case .number(let value): return value.formatted(.number.grouping(.never))
        default: return fallback
        }
    }
    func wNumber(_ fallback: Double = 0) -> Double {
        let value: Double
        switch self {
        case .number(let number): value = number
        case .string(let text): value = Double(text) ?? fallback
        default: value = fallback
        }
        return value.isFinite ? value : fallback
    }
}

enum NativeWorkoutEngine {
    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func date(_ value: JSONValue) -> Date? {
        let text = value.stringValue
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func status(_ set: JSONValue, historical: Bool = false) -> String {
        let value = set.w("status").stringValue
        if ["pending", "completed", "failed", "skipped"].contains(value) { return value }
        if set.w("done") == .bool(true) { return "completed" }
        if set.w("done") == .bool(false) { return "skipped" }
        return historical ? "completed" : "pending"
    }

    static func pending(_ session: JSONValue) -> [(Int, Int)] {
        session.w("exercises").arrayValue.enumerated().flatMap { e, exercise in
            exercise.w("sets").arrayValue.enumerated().compactMap { s, set in
                status(set) == "pending" ? (e, s) : nil
            }
        }
    }

    static func cursor(_ session: JSONValue) -> (exercise: Int, set: Int)? {
        let exercises = session.w("exercises").arrayValue
        let e = Int(min(Double(max(0, exercises.count - 1)), max(0, session.w("cursor").w("exerciseIndex").wNumber())))
        guard exercises.indices.contains(e) else { return nil }
        let sets = exercises[e].w("sets").arrayValue
        let s = Int(min(Double(max(0, sets.count - 1)), max(0, session.w("cursor").w("setIndex").wNumber())))
        if sets.indices.contains(s), status(sets[s]) == "pending" { return (e, s) }
        return pending(session).first.map { ($0.0, $0.1) }
    }

    static func normalized(_ raw: JSONValue) -> JSONValue? {
        guard case .object = raw, !raw.w("id").wText().isEmpty else { return nil }
        var result = raw
        let exercises = raw.w("exercises").arrayValue.map { exercise -> JSONValue in
            guard case .object = exercise else { return exercise }
            let sets = exercise.w("sets").arrayValue.map { set -> JSONValue in
                guard case .object = set else { return set }
                return set.wMerging(["status": .string(status(set))])
            }
            return exercise.wMerging(["sets": .array(sets)])
        }
        result = result.wMerging(["exercises": .array(exercises)])
        let requested = raw.w("status").stringValue
        let validStatus = ["active", "resting", "paused", "summary"].contains(requested) ? requested : "active"
        result = result.wMerging(["status": .string(pending(result).isEmpty && validStatus != "paused" ? "summary" : validStatus)])
        if let current = cursor(result) {
            result = result.wMerging(["cursor": raw.w("cursor").wMerging([
                "exerciseIndex": .number(Double(current.exercise)), "setIndex": .number(Double(current.set))
            ])])
        }
        return result
    }

    static func previousSets(exercise: JSONValue, history: [JSONValue]) -> [JSONValue] {
        func matches(_ item: JSONValue) -> Bool {
            item.w("exerciseId") == exercise.w("id") ||
            (!exercise.w("name").stringValue.isEmpty && item.w("name").stringValue.caseInsensitiveCompare(exercise.w("name").stringValue) == .orderedSame)
        }
        func counted(_ set: JSONValue) -> Bool {
            ["completed", "failed"].contains(status(set, historical: true)) &&
            set.w("setType").stringValue != "warmup" && set.w("done") != .bool(false)
        }
        let sorted = history.enumerated().sorted {
            let a = $0.element.w("date").stringValue, b = $1.element.w("date").stringValue
            return a == b ? $0.offset > $1.offset : a > b
        }
        for item in sorted {
            if let logged = item.element.w("exercises").arrayValue.first(where: { matches($0) && $0.w("sets").arrayValue.contains(where: counted) }) {
                return logged.w("sets").arrayValue.filter(counted)
            }
        }
        return []
    }

    static func newSession(routine: JSONValue, library: [JSONValue], history: [JSONValue], now: Date) -> JSONValue {
        let id = "session-\(UUID().uuidString.lowercased())"
        let exercises = routine.w("exerciseIds").arrayValue.enumerated().map { index, key -> JSONValue in
            let exerciseID = key.wText()
            let exercise = library.first { $0.w("id").wText() == exerciseID } ?? .object(["id": key, "name": .string(exerciseID)])
            let plan = routine.w("plan").w(exerciseID)
            let previous = previousSets(exercise: exercise, history: history)
            // The only domain ceiling: at most 100 newly allocated sets per exercise.
            // Imported active sessions are NOT truncated; original plans and snapshots
            // remain untouched. The planning UI discloses this allocation safeguard.
            let count = Int(min(100, max(1, plan.w("sets").wNumber(3).rounded())))
            let sets: [JSONValue] = (0..<count).map { setIndex in
                let last = previous.indices.contains(setIndex) ? previous[setIndex] : previous.last
                let reps = last?.w("reps").wText() ?? plan.w("reps").wText("8")
                let weight = max(0, last?.w("weight").wNumber() ?? plan.w("weight").wNumber())
                return .object([
                    "id": .string("\(id)-exercise-\(index + 1)-set-\(setIndex + 1)"),
                    "plannedWeight": .number(max(0, plan.w("weight").wNumber(weight))),
                    "plannedReps": .string(plan.w("reps").wText(reps)),
                    "previousWeight": last.map { .number(max(0, $0.w("weight").wNumber())) } ?? .string(""),
                    "previousReps": .string(last?.w("reps").wText() ?? ""),
                    "weight": .number(weight), "reps": .string(reps.isEmpty ? "8" : reps),
                    "rpe": .string(""), "effort": .string(""), "setType": .string("working"),
                    "blockId": .string(""), "round": .string(""), "status": .string("pending"), "completedAt": .string("")
                ])
            }
            let repText = sets.first?.w("reps").stringValue ?? ""
            let duration = repText.range(of: #"^\d+(?:\.\d+)?\s*(?:s|sec|secs|second|seconds|min|mins|minute|minutes)$"#, options: [.regularExpression, .caseInsensitive]) != nil
            return exercise.wMerging([
                "exerciseId": key, "name": .string(exercise.w("name").wText("Exercise")),
                "substitutedForExerciseId": .string(""), "substitutedForName": .string(""),
                "metricKind": .string(duration ? "duration" : "reps"),
                "restSec": .number(max(0, plan.w("rest").wNumber(90).rounded())),
                "notes": .string(""), "sets": .array(sets)
            ])
        }
        return .object([
            "schemaVersion": .number(1), "id": .string(id), "date": .string(dayKey(now)),
            "routineId": routine.w("id"), "routineName": .string(routine.w("name").wText("Workout")),
            "routineSnapshot": routine, "startedAt": .string(timestamp(now)), "lastSavedAt": .string(timestamp(now)),
            "status": .string(exercises.isEmpty ? "summary" : "active"),
            "pauseReturnStatus": .string("active"), "pausedAt": .string(""), "accumulatedPausedMs": .number(0),
            "cursor": .object(["exerciseIndex": .number(0), "setIndex": .number(0)]),
            "exercises": .array(exercises), "notes": .string(""), "rest": .null,
            "summaryAt": .string(exercises.isEmpty ? timestamp(now) : "")
        ])
    }

    static func saved(_ session: JSONValue, _ fields: [String: JSONValue], now: Date) -> JSONValue {
        session.wMerging(fields).wMerging(["lastSavedAt": .string(timestamp(now))])
    }

    static func patchCurrentSet(_ raw: JSONValue, fields: [String: JSONValue], now: Date) -> JSONValue {
        guard let session = normalized(raw), session.w("status").stringValue == "active", let current = cursor(session) else { return raw }
        var exercises = session.w("exercises").arrayValue
        var sets = exercises[current.exercise].w("sets").arrayValue
        sets[current.set] = sets[current.set].wMerging(fields)
        exercises[current.exercise] = exercises[current.exercise].wMerging(["sets": .array(sets)])
        return saved(session, ["exercises": .array(exercises)], now: now)
    }

    static func completeSet(_ raw: JSONValue, outcome: String = "completed", now: Date) -> JSONValue {
        guard let session = normalized(raw), session.w("status").stringValue == "active", let current = cursor(session) else { return raw }
        let exercise = session.w("exercises").arrayValue[current.exercise]
        let set = exercise.w("sets").arrayValue[current.set]
        let outcome = ["failed", "skipped"].contains(outcome) ? outcome : "completed"
        var fields: [String: JSONValue] = ["status": .string(outcome), "completedAt": .string(timestamp(now))]
        if outcome == "failed" { fields["effort"] = .string("failed") }
        // If imported legacy sets include done, update it rather than leaving a contradictory flag.
        if set.objectValue["done"] != nil { fields["done"] = .bool(outcome != "skipped") }
        var next = patchCurrentSet(session, fields: fields, now: now)
        guard let nextCursor = pending(next).first else { return review(next, now: now) }
        next = next.wMerging(["cursor": session.w("cursor").wMerging([
            "exerciseIndex": .number(Double(nextCursor.0)), "setIndex": .number(Double(nextCursor.1))
        ])])
        let configured = max(0, exercise.w("restSec").wNumber(90))
        let seconds = set.w("setType").stringValue == "warmup" ? min(45, configured) : configured
        guard outcome != "skipped", seconds > 0 else { return saved(next, ["status": .string("active"), "rest": .null], now: now) }
        return saved(next, ["status": .string("resting"), "rest": .object([
            "durationSec": .number(seconds), "remainingSec": .number(seconds),
            "endsAt": .string(timestamp(now.addingTimeInterval(seconds))), "paused": .bool(false),
            "fromExerciseName": exercise.w("name"), "fromSetLabel": .string("Set \(current.set + 1)")
        ])], now: now)
    }

    static func restRemaining(_ session: JSONValue, now: Date) -> Double {
        let rest = session.w("rest")
        guard case .object = rest else { return 0 }
        if rest.w("paused") == .bool(true) { return max(0, rest.w("remainingSec").wNumber()) }
        guard let end = date(rest.w("endsAt")) else { return max(0, rest.w("remainingSec").wNumber()) }
        return max(0, ceil(end.timeIntervalSince(now)))
    }

    static func finishRest(_ raw: JSONValue, now: Date) -> JSONValue {
        guard raw.w("status").stringValue == "resting" else { return raw }
        return saved(raw, ["status": .string("active"), "rest": .null], now: now)
    }

    static func expireRest(_ raw: JSONValue, sessionID: String, deadline: String, now: Date) -> JSONValue {
        guard raw.w("id").stringValue == sessionID, raw.w("status").stringValue == "resting",
              raw.w("rest").w("paused") != .bool(true), !deadline.isEmpty,
              raw.w("rest").w("endsAt").stringValue == deadline,
              date(.string(deadline)) != nil, restRemaining(raw, now: now) <= 0 else { return raw }
        return finishRest(raw, now: now)
    }

    static func toggleRest(_ raw: JSONValue, now: Date) -> JSONValue {
        guard raw.w("status").stringValue == "resting", case .object = raw.w("rest") else { return raw }
        let remaining = restRemaining(raw, now: now)
        let wasPaused = raw.w("rest").w("paused") == .bool(true)
        let rest = raw.w("rest").wMerging([
            "remainingSec": .number(remaining), "paused": .bool(!wasPaused),
            "endsAt": .string(wasPaused ? timestamp(now.addingTimeInterval(remaining)) : "")
        ])
        return saved(raw, ["rest": rest], now: now)
    }

    static func pause(_ raw: JSONValue, now: Date) -> JSONValue {
        let state = raw.w("status").stringValue
        guard ["active", "resting"].contains(state) else { return raw }
        let rest = state == "resting" ? raw.w("rest").wMerging([
            "remainingSec": .number(restRemaining(raw, now: now)), "endsAt": .string(""), "paused": .bool(true)
        ]) : raw.w("rest")
        return saved(raw, ["status": .string("paused"), "pauseReturnStatus": .string(state),
                           "pausedAt": .string(timestamp(now)), "rest": rest], now: now)
    }

    static func resume(_ raw: JSONValue, now: Date) -> JSONValue {
        guard raw.w("status").stringValue == "paused" else { return raw }
        let paused = max(0, now.timeIntervalSince(date(raw.w("pausedAt")) ?? now) * 1000)
        let resting = raw.w("pauseReturnStatus").stringValue == "resting" && raw.w("rest") != .null
        let rest = resting ? raw.w("rest").wMerging([
            "paused": .bool(false), "endsAt": .string(timestamp(now.addingTimeInterval(restRemaining(raw, now: now))))
        ]) : .null
        return saved(raw, ["status": .string(resting ? "resting" : (pending(raw).isEmpty ? "summary" : "active")),
                           "rest": rest, "pausedAt": .string(""),
                           "accumulatedPausedMs": .number(raw.w("accumulatedPausedMs").wNumber() + paused)], now: now)
    }

    static func review(_ raw: JSONValue, now: Date) -> JSONValue {
        let paused = raw.w("status").stringValue == "paused" ? max(0, now.timeIntervalSince(date(raw.w("pausedAt")) ?? now) * 1000) : 0
        return saved(raw, ["status": .string("summary"), "rest": .null, "pausedAt": .string(""),
                           "summaryAt": .string(timestamp(now)),
                           "accumulatedPausedMs": .number(raw.w("accumulatedPausedMs").wNumber() + paused)], now: now)
    }

    static func elapsed(_ session: JSONValue, now: Date) -> Double {
        let start = date(session.w("startedAt")) ?? date(session.w("createdAt")) ?? now
        let end = date(session.w("summaryAt")) ?? now
        let livePause = session.w("status").stringValue == "paused" ? max(0, now.timeIntervalSince(date(session.w("pausedAt")) ?? now)) : 0
        return max(0, end.timeIntervalSince(start) - session.w("accumulatedPausedMs").wNumber() / 1000 - livePause)
    }

    // One store.change transaction: history and active-session clearing cannot diverge.
    static func finish(in data: inout [String: JSONValue], sessionID: String, now: Date) {
        let workout = data["workout"] ?? .object([:])
        guard let session = normalized(workout.w("activeSession")), session.w("id").stringValue == sessionID,
              session.w("status").stringValue == "summary" else { return }
        var logs = workout.w("workouts").arrayValue
        if !logs.contains(where: { $0.w("id") == session.w("id") || $0.w("sessionId") == session.w("id") }) {
            let exercises = session.w("exercises").arrayValue.map { exercise in
                exercise.wMerging(["sets": .array(exercise.w("sets").arrayValue.map { set in
                    set.wMerging(["done": .bool(["completed", "failed"].contains(status(set)))])
                })])
            }
            logs.append(session.wMerging([
                "sessionId": session.w("id"), "exercises": .array(exercises),
                "duration": .number(max(1, (elapsed(session, now: now) / 60).rounded())),
                "finishedAt": .string(timestamp(now))
            ]))
        }
        data["workout"] = workout.wMerging(["workouts": .array(logs), "activeSession": .null])
    }
}

// MARK: - Workout planning

struct WorkoutPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var sessionOpen = false
    @State private var routineEditor: WorkoutEditorItem?
    @State private var libraryOpen = false

    private var workout: JSONValue { store.document.data["workout"] ?? .object([:]) }
    private var routines: [JSONValue] { workout.w("routines").arrayValue }
    private var active: JSONValue? { NativeWorkoutEngine.normalized(workout.w("activeSession")) }
    private var hasStoredSession: Bool { workout.w("activeSession") != .null }

    var body: some View {
        ArchivePage(title: "Workout", subtitle: "A little preparation. One set at a time.") {
            VStack(alignment: .leading, spacing: 24) {
                if let active {
                    ArchivePanel(tint: ArchiveTheme.move) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(active.w("routineName").wText("Workout")).font(ArchiveTheme.heading)
                            Text(active.w("status").stringValue == "summary" ? "Ready to review. Nothing is in history until you finish." : "Your progress is saved. Pick up where you left off.")
                                .foregroundStyle(ArchiveTheme.secondary)
                            Button(active.w("status").stringValue == "summary" ? "Review workout" : "Open saved workout") { sessionOpen = true }
                                .buttonStyle(WorkoutPrimaryButton())
                        }
                    }
                } else if hasStoredSession {
                    Text("An imported active session could not be opened. It is retained in your backup. Export it before replacing any data in Settings.")
                        .foregroundStyle(ArchiveTheme.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your routines").font(ArchiveTheme.heading)
                    if routines.isEmpty {
                        Text("Start with your own routine, even if it is just a name for now. No workouts are added for you.")
                            .foregroundStyle(ArchiveTheme.secondary)
                    }
                    ForEach(Array(routines.enumerated()), id: \.offset) { _, routine in
                        ArchivePanel(tint: ArchiveTheme.move.opacity(0.35)) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(routine.w("name").wText("Routine")).font(ArchiveTheme.heading)
                                Text("\(routine.w("exerciseIds").arrayValue.count) exercises").foregroundStyle(ArchiveTheme.secondary)
                                if routine.w("exerciseIds").arrayValue.contains(where: { routine.w("plan").w($0.wText()).w("sets").wNumber(3) > 100 }) {
                                    Text("This plan exceeds the allocation safeguard. Starting it creates at most 100 sets per exercise; your original plan is retained.")
                                        .font(.footnote).foregroundStyle(ArchiveTheme.secondary)
                                }
                                ViewThatFits(in: .horizontal) {
                                    HStack { routineActions(routine) }
                                    VStack(alignment: .leading) { routineActions(routine) }
                                }
                            }
                        }
                    }
                    Button("Create routine", systemImage: "plus") {
                        routineEditor = WorkoutEditorItem(value: .object([
                            "id": .string("routine-\(UUID().uuidString.lowercased())"), "name": .string(""),
                            "notes": .string(""), "exerciseIds": .array([]), "plan": .object([:])
                        ]))
                    }.frame(minHeight: 44)
                }

                DisclosureGroup("Weekly schedule") {
                    VStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            scheduleRow(day)
                        }
                    }.padding(.top, 12)
                }
                Button("Exercise library", systemImage: "list.bullet") { libraryOpen = true }.frame(minHeight: 44)
            }
            .foregroundStyle(ArchiveTheme.ink)
        }
        .sheet(item: $routineEditor) { item in
            WorkoutRoutineEditor(initial: item.value).environmentObject(store)
        }
        .sheet(isPresented: $libraryOpen) { WorkoutLibraryView().environmentObject(store) }
        .fullScreenCover(isPresented: $sessionOpen) { WorkoutSessionView().environmentObject(store) }
    }

    @ViewBuilder private func routineActions(_ routine: JSONValue) -> some View {
        Button("Start workout") { start(routine) }
            .buttonStyle(WorkoutPrimaryButton()).disabled(hasStoredSession || routine.w("exerciseIds").arrayValue.isEmpty)
        Button("Edit routine") { routineEditor = WorkoutEditorItem(value: routine) }.frame(minHeight: 44)
    }

    private func scheduleRow(_ day: Int) -> some View {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let current = workout.w("schedule").arrayValue
        let selected = current.indices.contains(day) ? current[day].wText() : ""
        return Picker(names[day], selection: Binding(get: { selected }, set: { value in
            store.change { data in
                let state = data["workout"] ?? .object([:])
                var schedule = state.w("schedule").arrayValue
                while schedule.count < 7 { schedule.append(.string("")) }
                schedule[day] = .string(value)
                data["workout"] = state.wMerging(["schedule": .array(schedule)])
            }
        })) {
            Text("Rest / unassigned").tag("")
            if !selected.isEmpty && !routines.contains(where: { $0.w("id").wText() == selected }) {
                Text("Unavailable routine (retained)").tag(selected)
            }
            ForEach(Array(routines.enumerated()), id: \.offset) { _, routine in
                Text(routine.w("name").wText("Routine")).tag(routine.w("id").wText())
            }
        }.pickerStyle(.menu).frame(minHeight: 44)
    }

    private func start(_ routine: JSONValue) {
        store.change { data in
            let state = data["workout"] ?? .object([:])
            guard state.w("activeSession") == .null else { return }
            let session = NativeWorkoutEngine.newSession(routine: routine, library: state.w("exercises").arrayValue,
                                                         history: state.w("workouts").arrayValue, now: Date())
            data["workout"] = state.wMerging(["activeSession": session, "selectedRoutineId": routine.w("id")])
        }
        if active != nil { sessionOpen = true }
    }
}

private struct WorkoutEditorItem: Identifiable {
    var id: String { value.w("id").wText() }
    let value: JSONValue
}

private struct WorkoutPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        let alpha = scheme == .dark ? 0.22 : 1.0
        return configuration.label.font(.body.weight(.medium)).foregroundStyle(ArchiveTheme.ink)
            .padding(.horizontal, 18).padding(.vertical, 12).frame(minHeight: 44)
            .background(ArchiveTheme.move.opacity(alpha * (enabled ? (configuration.isPressed ? 0.6 : 1) : 0.3)), in: RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? 1 : 0.5)
    }
}

private struct WorkoutRoutineEditor: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JSONValue
    @State private var deleteConfirmation = false
    @State private var libraryOpen = false
    @State private var saveError: String?
    private let original: JSONValue

    init(initial: JSONValue) {
        original = initial
        _draft = State(initialValue: initial)
    }
    private var ids: [JSONValue] { draft.w("exerciseIds").arrayValue }
    private var library: [JSONValue] { (store.document.data["workout"] ?? .null).w("exercises").arrayValue }
    private var exists: Bool {
        (store.document.data["workout"] ?? .null).w("routines").arrayValue.contains { $0.w("id") == draft.w("id") }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name", text: textBinding("name"))
                    TextField("Notes", text: textBinding("notes"), axis: .vertical)
                }
                if let saveError { Section { Text(saveError).foregroundStyle(ArchiveTheme.secondary) } }
                Section {
                    if ids.isEmpty { Text("No exercises yet. You can save an empty routine.").foregroundStyle(ArchiveTheme.secondary) }
                    ForEach(Array(ids.enumerated()), id: \.offset) { index, id in
                        let key = id.wText()
                        let exercise = library.first { $0.w("id") == id }
                        DisclosureGroup(exercise?.w("name").wText("Exercise") ?? "Unavailable exercise: \(key)") {
                            WorkoutPlanFields(plan: planBinding(key))
                            HStack {
                                Button("Move up") { move(index, by: -1) }.disabled(index == 0)
                                Spacer()
                                Button("Move down") { move(index, by: 1) }.disabled(index == ids.count - 1)
                            }.buttonStyle(.borderless).frame(minHeight: 44)
                            Button("Remove from routine", role: .destructive) { remove(index) }.frame(minHeight: 44)
                        }
                    }
                    Menu("Add exercise") {
                        ForEach(Array(library.filter { !ids.contains($0.w("id")) }.enumerated()), id: \.offset) { _, exercise in
                            Button(exercise.w("name").wText("Exercise")) { add(exercise) }
                        }
                        Button("Create or edit library exercise…") { libraryOpen = true }
                    }.frame(minHeight: 44)
                } header: { Text("Exercises & plan") } footer: {
                    Text("Rep targets may be a range or a duration, such as 8–10 or 45s. Starting a routine allocates at most 100 sets per exercise for safety; imported plans and open sessions stay intact. Library edits never rewrite history.")
                }
                if exists {
                    Section {
                        Button("Delete routine", role: .destructive) { deleteConfirmation = true }
                    } footer: { Text("Finished workouts and any active snapshot are kept. Its scheduled days become unassigned.") }
                }
            }
            .scrollContentBackground(.hidden).background(ArchiveTheme.canvas)
            .navigationTitle(exists ? "Edit routine" : "New routine").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.w("name").stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete this routine?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
                Button("Delete routine", role: .destructive) { delete() }
            }
            .sheet(isPresented: $libraryOpen) { WorkoutLibraryView().environmentObject(store) }
        }.tint(ArchiveTheme.ink)
    }

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(get: { draft.w(key).wText() }, set: { draft = draft.wMerging([key: .string($0)]) })
    }
    private func planBinding(_ id: String) -> Binding<JSONValue> {
        Binding(get: { draft.w("plan").w(id) }, set: { value in
            draft = draft.wMerging(["plan": draft.w("plan").wMerging([id: value])])
        })
    }
    private func add(_ exercise: JSONValue) {
        let id = exercise.w("id")
        guard !ids.contains(id) else { return }
        let state = store.document.data["workout"] ?? .null
        let previous = NativeWorkoutEngine.previousSets(exercise: exercise, history: state.w("workouts").arrayValue)
        let first = previous.first
        let plan: JSONValue = .object(["sets": .number(Double(max(1, previous.isEmpty ? 3 : previous.count))),
                                      "reps": .string(first?.w("reps").wText("8") ?? "8"),
                                      "weight": .number(first?.w("weight").wNumber() ?? 0), "rest": .number(90)])
        draft = draft.wMerging(["exerciseIds": .array(ids + [id]), "plan": draft.w("plan").wMerging([id.wText(): plan])])
    }
    private func remove(_ index: Int) {
        var values = ids
        let id = values.remove(at: index).wText()
        var plans = draft.w("plan").objectValue
        plans.removeValue(forKey: id)
        draft = draft.wMerging(["exerciseIds": .array(values), "plan": .object(plans)])
    }
    private func move(_ index: Int, by delta: Int) {
        var values = ids
        guard values.indices.contains(index + delta) else { return }
        values.swapAt(index, index + delta)
        draft = draft.wMerging(["exerciseIds": .array(values)])
    }
    private func save() {
        var expected: JSONValue?
        store.change { data in
            let state = data["workout"] ?? .object([:])
            var routines = state.w("routines").arrayValue
            var value = draft
            // Merge against the latest object, not a stale whole-document snapshot.
            if let index = routines.firstIndex(where: { $0.w("id") == draft.w("id") }) {
                var changed = draft.objectValue.filter { original.objectValue[$0.key] != $0.value }
                changed["name"] = .string(draft.w("name").stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
                value = routines[index].wMerging(changed)
                routines[index] = value
            } else {
                value = draft.wMerging(["name": .string(draft.w("name").stringValue.trimmingCharacters(in: .whitespacesAndNewlines))])
                routines.append(value)
            }
            expected = value
            data["workout"] = state.wMerging(["routines": .array(routines), "selectedRoutineId": value.w("id")])
        }
        // A failed atomic write leaves the store unchanged; keep the editor open for retry.
        if let expected, (store.document.data["workout"] ?? .null).w("routines").arrayValue.contains(expected) { dismiss() }
        else { saveError = "This routine could not be saved. Your draft is still here; please try again." }
    }
    private func delete() {
        store.change { data in
            let state = data["workout"] ?? .object([:])
            let id = draft.w("id")
            let routines = state.w("routines").arrayValue.filter { $0.w("id") != id }
            let schedule = state.w("schedule").arrayValue.map { $0 == id ? JSONValue.string("") : $0 }
            data["workout"] = state.wMerging([
                "routines": .array(routines), "schedule": .array(schedule),
                "selectedRoutineId": state.w("selectedRoutineId") == id ? (routines.first?.w("id") ?? .string("")) : state.w("selectedRoutineId")
            ])
        }
        if !(store.document.data["workout"] ?? .null).w("routines").arrayValue.contains(where: { $0.w("id") == draft.w("id") }) { dismiss() }
        else { saveError = "This routine could not be deleted. Your saved routine is unchanged." }
    }
}

private struct WorkoutPlanFields: View {
    @Binding var plan: JSONValue
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Sets", text: number("sets", fallback: "3")).keyboardType(.numberPad)
                .accessibilityLabel("Number of sets")
            TextField("Reps or duration", text: Binding(get: { plan.w("reps").wText("8") }, set: { plan = plan.wMerging(["reps": .string($0)]) }))
                .accessibilityLabel("Reps or duration")
            TextField("Weight", text: number("weight", fallback: "0")).keyboardType(.decimalPad).accessibilityLabel("Planned weight")
            TextField("Rest, seconds", text: number("rest", fallback: "90")).keyboardType(.numberPad).accessibilityLabel("Rest in seconds")
        }.padding(.vertical, 8)
    }
    private func number(_ field: String, fallback: String) -> Binding<String> {
        Binding(get: { plan.w(field).wText(fallback) }, set: { text in
            if text.isEmpty { plan = plan.wMerging([field: .string("")]); return }
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            guard let value = Double(normalized), value.isFinite, value >= 0 else { return }
            plan = plan.wMerging([field: .number(value)])
        })
    }
}

// MARK: - Exercise library

private struct WorkoutLibraryView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var editor: WorkoutEditorItem?
    private var exercises: [JSONValue] { (store.document.data["workout"] ?? .null).w("exercises").arrayValue }
    var body: some View {
        NavigationStack {
            List {
                if exercises.isEmpty {
                    Text("Your library is empty. Add an exercise you actually use, then add it to a routine.").foregroundStyle(ArchiveTheme.secondary)
                }
                ForEach(Array(exercises.enumerated()), id: \.offset) { _, exercise in
                    Button { editor = WorkoutEditorItem(value: exercise) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.w("name").wText("Exercise")).foregroundStyle(ArchiveTheme.ink)
                            if !exercise.w("equipment").stringValue.isEmpty {
                                Text(exercise.w("equipment").stringValue).font(.subheadline).foregroundStyle(ArchiveTheme.secondary)
                            }
                        }.frame(minHeight: 44)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ArchiveTheme.canvas)
            .navigationTitle("Exercise library").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add exercise", systemImage: "plus") {
                        editor = WorkoutEditorItem(value: .object([
                            "id": .string("exercise-\(UUID().uuidString.lowercased())"), "name": .string(""),
                            "equipment": .string(""), "movement": .string(""), "instructions": .string(""),
                            "primaryMuscles": .array([]), "secondaryMuscles": .array([])
                        ]))
                    }
                }
            }
            .sheet(item: $editor) { item in WorkoutExerciseEditor(initial: item.value).environmentObject(store) }
        }.tint(ArchiveTheme.ink)
    }
}

private struct WorkoutExerciseEditor: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JSONValue
    @State private var primary: String
    @State private var secondary: String
    @State private var saveError: String?
    private let original: JSONValue
    init(initial: JSONValue) {
        original = initial
        _draft = State(initialValue: initial)
        _primary = State(initialValue: initial.w("primaryMuscles").arrayValue.map { $0.wText() }.joined(separator: ", "))
        _secondary = State(initialValue: initial.w("secondaryMuscles").arrayValue.map { $0.wText() }.joined(separator: ", "))
    }
    var body: some View {
        NavigationStack {
            Form {
                if let saveError { Section { Text(saveError).foregroundStyle(ArchiveTheme.secondary) } }
                Section("Exercise") {
                    TextField("Name", text: text("name"))
                    TextField("Equipment", text: text("equipment"))
                    TextField("Movement", text: text("movement"))
                    TextField("Instructions", text: text("instructions"), axis: .vertical)
                }
                Section {
                    TextField("Primary muscles", text: $primary)
                    TextField("Secondary muscles", text: $secondary)
                } header: { Text("Muscles") } footer: { Text("Separate muscle names with commas. Existing snapshots and finished workouts keep their original details.") }
            }
            .scrollContentBackground(.hidden).background(ArchiveTheme.canvas)
            .navigationTitle("Exercise").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.w("name").stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.tint(ArchiveTheme.ink)
    }
    private func text(_ key: String) -> Binding<String> {
        Binding(get: { draft.w(key).wText() }, set: { draft = draft.wMerging([key: .string($0)]) })
    }
    private func muscles(_ text: String) -> JSONValue {
        .array(text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.map { .string($0) })
    }
    private func save() {
        var expected: JSONValue?
        store.change { data in
            let state = data["workout"] ?? .object([:])
            var exercises = state.w("exercises").arrayValue
            var changes = draft.objectValue.filter { original.objectValue[$0.key] != $0.value }
            changes["name"] = .string(draft.w("name").stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            // Do not normalize untouched imported arrays (including unknown muscle names).
            if primary != original.w("primaryMuscles").arrayValue.map({ $0.wText() }).joined(separator: ", ") { changes["primaryMuscles"] = muscles(primary) }
            if secondary != original.w("secondaryMuscles").arrayValue.map({ $0.wText() }).joined(separator: ", ") { changes["secondaryMuscles"] = muscles(secondary) }
            if let index = exercises.firstIndex(where: { $0.w("id") == draft.w("id") }) {
                exercises[index] = exercises[index].wMerging(changes)
                expected = exercises[index]
            } else {
                let value = draft.wMerging(changes)
                exercises.append(value)
                expected = value
            }
            data["workout"] = state.wMerging(["exercises": .array(exercises)])
        }
        if let expected, (store.document.data["workout"] ?? .null).w("exercises").arrayValue.contains(expected) { dismiss() }
        else { saveError = "This exercise could not be saved. Your draft is still here; please try again." }
    }
}

// MARK: - Focused session

private struct WorkoutRestDeadline: Hashable {
    let sessionID: String
    let deadline: String
    let paused: Bool
}

struct WorkoutSessionView: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var reviewConfirmation = false
    @State private var discardConfirmation = false
    @State private var saveError: String?
    private var raw: JSONValue { (store.document.data["workout"] ?? .null).w("activeSession") }
    private var session: JSONValue? { NativeWorkoutEngine.normalized(raw) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let session {
                        Text(session.w("routineName").wText("Workout")).font(ArchiveTheme.title)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("\(clock(NativeWorkoutEngine.elapsed(session, now: context.date))) · \(completedCount(session)) sets logged")
                                .monospacedDigit().foregroundStyle(ArchiveTheme.secondary)
                        }
                        if session.w("status").stringValue == "summary" {
                            summary(session)
                        } else if session.w("status").stringValue == "paused" {
                            ArchivePanel(tint: ArchiveTheme.move) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Take your time.").font(ArchiveTheme.heading)
                                    Text("Workout paused. Your sets and remaining rest are saved.")
                                    Button("Resume workout") { mutate { NativeWorkoutEngine.resume($0, now: Date()) } }.buttonStyle(WorkoutPrimaryButton())
                                }
                            }
                        } else if session.w("status").stringValue == "resting" {
                            rest(session)
                        } else if let current = NativeWorkoutEngine.cursor(session) {
                            currentSet(session, current: current)
                        }
                        if session.w("status").stringValue != "summary" {
                            Button("Review & finish early") { reviewConfirmation = true }.frame(minHeight: 44)
                        }
                    } else {
                        Text("No open workout. Finished workouts are in Workout History.")
                        Button("Close") { dismiss() }.frame(minHeight: 44)
                    }
                    if let message = store.message { Text(message).foregroundStyle(ArchiveTheme.secondary).accessibilityLabel("Save status: \(message)") }
                    if let saveError { Text(saveError).foregroundStyle(ArchiveTheme.secondary).accessibilityLabel("Save error: \(saveError)") }
                }
                .padding(24).frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(ArchiveTheme.canvas).foregroundStyle(ArchiveTheme.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Save & close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let session, ["active", "resting"].contains(session.w("status").stringValue) {
                        Button("Pause workout") { mutate { NativeWorkoutEngine.pause($0, now: Date()) } }
                    }
                }
            }
            .confirmationDialog("Review this workout now?", isPresented: $reviewConfirmation, titleVisibility: .visible) {
                Button("Review workout") { mutate { NativeWorkoutEngine.review($0, now: Date()) } }
            } message: { Text("Pending sets stay uncompleted. This does not add anything to history.") }
            .confirmationDialog("Discard this saved workout?", isPresented: $discardConfirmation, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { discard() }
            } message: { Text("This removes only the active session. No history entry will be created.") }
        }
        .tint(ArchiveTheme.ink)
        .interactiveDismissDisabled()
    }

    private func currentSet(_ session: JSONValue, current: (exercise: Int, set: Int)) -> some View {
        let exercises = session.w("exercises").arrayValue
        let exercise = exercises[current.exercise]
        let sets = exercise.w("sets").arrayValue
        let set = sets[current.set]
        return VStack(alignment: .leading, spacing: 20) {
            Text("Exercise \(current.exercise + 1) of \(exercises.count) · Set \(current.set + 1) of \(sets.count)").font(.subheadline).foregroundStyle(ArchiveTheme.secondary)
            Text(exercise.w("name").wText("Exercise")).font(ArchiveTheme.heading)
            if set.w("setType").stringValue == "warmup" { Text("Warm-up set").foregroundStyle(ArchiveTheme.secondary) }
            ArchivePanel(tint: ArchiveTheme.move) {
                VStack(alignment: .leading, spacing: 18) {
                    if !set.w("previousReps").wText().isEmpty {
                        Text("Previous: \(set.w("previousWeight").wText("0")) × \(set.w("previousReps").wText())").font(.subheadline).foregroundStyle(ArchiveTheme.secondary)
                    }
                    Stepper(onIncrement: {
                        let weight = max(0, set.w("weight").wNumber()) + 2.5
                        if weight.isFinite { patch(["weight": .number(weight)]) }
                    }, onDecrement: {
                        patch(["weight": .number(max(0, set.w("weight").wNumber() - 2.5))])
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight").font(.subheadline)
                            Text(set.w("weight").wText("0")).font(ArchiveTheme.number).monospacedDigit()
                        }
                    }
                    .accessibilityLabel("Weight, in the same unit as your routine")
                    TextField("Exact weight", text: Binding(get: { set.w("weight").wText("0") }, set: { text in
                        guard let weight = Double(text.replacingOccurrences(of: ",", with: ".")), weight.isFinite, weight >= 0 else { return }
                        patch(["weight": .number(weight)])
                    })).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityLabel("Exact weight")
                    // A text entry preserves imported ranges/durations instead of silently converting 45s to reps.
                    TextField("Reps or duration", text: Binding(get: { set.w("reps").wText("8") }, set: { patch(["reps": .string($0)]) }))
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Actual repetitions or duration")
                    if exercise.w("metricKind").stringValue != "duration", let reps = Double(set.w("reps").wText()), reps.isFinite {
                        Stepper("Repetitions: \(set.w("reps").wText())", onIncrement: {
                            let value = max(0, reps) + 1
                            if value.isFinite { patch(["reps": .string(value.formatted(.number.grouping(.never).precision(.fractionLength(0))))]) }
                        }, onDecrement: {
                            patch(["reps": .string(max(0, reps - 1).formatted(.number.grouping(.never).precision(.fractionLength(0))))])
                        })
                    }
                    Picker("Effort (optional)", selection: Binding(get: { set.w("effort").stringValue }, set: { patch(["effort": .string($0)]) })) {
                        Text("Not recorded").tag("")
                        Text("Easy").tag("easy")
                        Text("As expected").tag("expected")
                        Text("Hard").tag("hard")
                        Text("Failed").tag("failed")
                    }.pickerStyle(.menu).frame(minHeight: 44)
                    Text("Weight uses your routine’s existing unit; this increment does not convert units.").font(.footnote).foregroundStyle(ArchiveTheme.secondary)
                    Button("Complete set") {
                        mutate { NativeWorkoutEngine.completeSet($0, outcome: set.w("effort").stringValue == "failed" ? "failed" : "completed", now: Date()) }
                    }.buttonStyle(WorkoutPrimaryButton()).disabled(set.w("reps").wText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if !exercise.w("notes").stringValue.isEmpty { Text(exercise.w("notes").stringValue).foregroundStyle(ArchiveTheme.secondary) }
            Button("Skip this set") { mutate { NativeWorkoutEngine.completeSet($0, outcome: "skipped", now: Date()) } }.frame(minHeight: 44)
        }
    }

    private func rest(_ session: JSONValue) -> some View {
        let token = WorkoutRestDeadline(sessionID: session.w("id").stringValue,
                                        deadline: session.w("rest").w("endsAt").stringValue,
                                        paused: session.w("rest").w("paused") == .bool(true))
        return TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = NativeWorkoutEngine.restRemaining(session, now: context.date)
            ArchivePanel(tint: ArchiveTheme.move) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(remaining > 0 ? "A moment to recover." : "Ready when you are.").font(ArchiveTheme.heading)
                    Text(clock(remaining)).font(ArchiveTheme.number).monospacedDigit().accessibilityLabel("Rest remaining: \(remaining.formatted(.number.precision(.fractionLength(0)))) seconds")
                    if !session.w("rest").w("fromExerciseName").stringValue.isEmpty {
                        Text("After \(session.w("rest").w("fromExerciseName").stringValue)").foregroundStyle(ArchiveTheme.secondary)
                    }
                    if remaining > 0 {
                        Button(session.w("rest").w("paused") == .bool(true) ? "Resume rest timer" : "Pause rest timer") {
                            mutate { NativeWorkoutEngine.toggleRest($0, now: Date()) }
                        }.frame(minHeight: 44)
                    }
                    Button("Skip rest") {
                        mutate { NativeWorkoutEngine.finishRest($0, now: Date()) }
                    }.buttonStyle(WorkoutPrimaryButton())
                }
            }
        }
        .task(id: token) { await waitForRest(token) }
        // The timeline only displays. A cancellable deadline task advances once;
        // closing/reopening the view restores that task from the saved timestamp.
    }

    @MainActor private func waitForRest(_ token: WorkoutRestDeadline) async {
        guard !token.paused, let end = NativeWorkoutEngine.date(.string(token.deadline)) else { return }
        // Sleep in bounded chunks only for unusually distant imported deadlines.
        // This is not a rest-duration ceiling and does not write or update UI.
        while end.timeIntervalSinceNow > 0 {
            do { try await Task.sleep(for: .seconds(min(end.timeIntervalSinceNow, 86_400))) }
            catch { return }
        }
        guard !Task.isCancelled else { return }
        let now = Date()
        guard NativeWorkoutEngine.expireRest(raw, sessionID: token.sessionID, deadline: token.deadline, now: now) != raw else { return }
        mutate { NativeWorkoutEngine.expireRest($0, sessionID: token.sessionID, deadline: token.deadline, now: now) }
    }

    private func summary(_ session: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your session, saved so far.").font(ArchiveTheme.heading)
            Text("\(completedCount(session)) sets logged · \(NativeWorkoutEngine.pending(session).count) unfinished. Only Finish workout adds this session to history.")
                .foregroundStyle(ArchiveTheme.secondary)
            WorkoutSetDetails(workout: session)
            TextField("Workout notes", text: Binding(get: { session.w("notes").wText() }, set: { value in
                mutate { NativeWorkoutEngine.saved($0, ["notes": .string(value)], now: Date()) }
            }), axis: .vertical).textFieldStyle(.roundedBorder)
            Button("Finish workout") { finish(session) }.buttonStyle(WorkoutPrimaryButton())
            if !NativeWorkoutEngine.pending(session).isEmpty {
                Button("Return to unfinished sets") {
                    mutate { NativeWorkoutEngine.saved($0, ["status": .string("active"), "summaryAt": .string("")], now: Date()) }
                }.frame(minHeight: 44)
            }
            Button("Discard workout", role: .destructive) { discardConfirmation = true }.frame(minHeight: 44)
        }
    }

    private func mutate(_ edit: (JSONValue) -> JSONValue) {
        let expectedID = raw.w("id")
        var expected: JSONValue?
        store.change { data in
            let state = data["workout"] ?? .object([:])
            guard state.w("activeSession").w("id") == expectedID, let current = NativeWorkoutEngine.normalized(state.w("activeSession")) else { return }
            let next = edit(current)
            expected = next
            data["workout"] = state.wMerging(["activeSession": next])
        }
        if let expected, raw == expected { saveError = nil }
        else { saveError = "This change could not be saved. Your last saved set is intact; please try again." }
    }
    private func patch(_ fields: [String: JSONValue]) { mutate { NativeWorkoutEngine.patchCurrentSet($0, fields: fields, now: Date()) } }
    private func finish(_ session: JSONValue) {
        store.change { data in NativeWorkoutEngine.finish(in: &data, sessionID: session.w("id").stringValue, now: Date()) }
        if raw == .null { dismiss() }
        else { saveError = "The workout could not be finished. It is still saved as an active session; please try again." }
    }
    private func discard() {
        let id = raw.w("id")
        store.change { data in
            let state = data["workout"] ?? .object([:])
            guard state.w("activeSession").w("id") == id else { return }
            data["workout"] = state.wMerging(["activeSession": .null])
        }
        if raw == .null { dismiss() }
        else { saveError = "This workout could not be discarded. Your saved session is unchanged." }
    }
    private func completedCount(_ session: JSONValue) -> Int {
        session.w("exercises").arrayValue.flatMap { $0.w("sets").arrayValue }.filter { ["completed", "failed"].contains(NativeWorkoutEngine.status($0)) }.count
    }
    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "—" }
        let safe = max(0, seconds.rounded(.down))
        let minutes = (safe / 60).rounded(.down).formatted(.number.grouping(.never).precision(.fractionLength(0)))
        return "\(minutes):\(String(format: "%02d", Int(safe.truncatingRemainder(dividingBy: 60))))"
    }
}

// MARK: - Date-based, read-only history

struct WorkoutHistoryPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var selectedDate = Date()
    private var dateKey: String { NativeWorkoutEngine.dayKey(selectedDate) }
    private var manual: [JSONValue] {
        (store.document.data["workout"] ?? .null).w("workouts").arrayValue.filter { $0.w("date").stringValue == dateKey }
    }
    private var watch: [JSONValue] {
        (store.document.data["watchData"] ?? .null).w("workouts").arrayValue.filter { item in
            let key = item.w("date").stringValue
            if !key.isEmpty { return key == dateKey }
            return NativeWorkoutEngine.date(item.w("startedAt")).map { NativeWorkoutEngine.dayKey($0) == dateKey } ?? false
        }
    }
    var body: some View {
        ArchivePage(title: "Workout history", subtitle: "Every session has its own place.") {
            VStack(alignment: .leading, spacing: 22) {
                DatePicker("Choose a date", selection: $selectedDate, displayedComponents: .date).datePickerStyle(.compact).frame(minHeight: 44)
                if manual.isEmpty && watch.isEmpty {
                    ArchivePanel(tint: ArchiveTheme.move.opacity(0.4)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("A quiet page.").font(ArchiveTheme.heading)
                            Text("No finished or imported workouts on this date. An open workout appears here only after Finish workout.").foregroundStyle(ArchiveTheme.secondary)
                        }
                    }
                }
                ForEach(Array(manual.enumerated()), id: \.offset) { _, workout in
                    ArchivePanel(tint: ArchiveTheme.move.opacity(0.5)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(workout.w("routineName").wText("Workout")).font(ArchiveTheme.heading)
                            Text("Archive · \(workout.w("duration").wText("—")) min").foregroundStyle(ArchiveTheme.secondary)
                            WorkoutSetDetails(workout: workout, historical: true)
                            if !workout.w("notes").stringValue.isEmpty { Text(workout.w("notes").stringValue) }
                        }
                    }
                }
                ForEach(Array(watch.enumerated()), id: \.offset) { _, workout in
                    ArchivePanel(tint: ArchiveTheme.water.opacity(0.2)) { WorkoutWatchDetails(workout: workout) }
                }
            }.foregroundStyle(ArchiveTheme.ink)
        }.tint(ArchiveTheme.ink)
    }
}

private struct WorkoutSetDetails: View {
    let workout: JSONValue
    var historical = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(workout.w("exercises").arrayValue.enumerated()), id: \.offset) { _, exercise in
                DisclosureGroup(exercise.w("name").wText(exercise.w("exerciseName").wText("Exercise"))) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(exercise.w("sets").arrayValue.enumerated()), id: \.offset) { index, set in
                            let status = NativeWorkoutEngine.status(set, historical: historical)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(set.w("setType").stringValue == "warmup" ? "Warm-up" : "Set \(index + 1)"): \(set.w("weight").wText("0")) × \(set.w("reps").wText("—"))")
                                Text(setDescription(set, status: status)).font(.subheadline).foregroundStyle(ArchiveTheme.secondary)
                            }
                        }
                        if !exercise.w("notes").stringValue.isEmpty { Text(exercise.w("notes").stringValue).font(.subheadline) }
                        if !exercise.w("substitutedForName").stringValue.isEmpty {
                            Text("In place of \(exercise.w("substitutedForName").stringValue)").font(.subheadline)
                        }
                    }.padding(.vertical, 8)
                }.frame(minHeight: 44)
            }
        }
    }
    private func setDescription(_ set: JSONValue, status: String) -> String {
        var parts = [status == "pending" ? "Unfinished" : status.capitalized]
        let effort = set.w("effort").stringValue
        if !effort.isEmpty { parts.append("Effort: \(effort)") }
        if !set.w("rpe").wText().isEmpty { parts.append("RPE \(set.w("rpe").wText())") }
        if !set.w("blockId").wText().isEmpty { parts.append("Block \(set.w("blockId").wText())") }
        if !set.w("round").wText().isEmpty { parts.append("Round \(set.w("round").wText())") }
        return parts.joined(separator: " · ")
    }
}

private struct WorkoutWatchDetails: View {
    let workout: JSONValue
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(ArchiveTheme.heading)
            Text("\(source) · Read-only imported workout").font(.subheadline).foregroundStyle(ArchiveTheme.secondary)
            if let start = NativeWorkoutEngine.date(workout.w("startedAt")) { Text(start, format: .dateTime.hour().minute()) }
            ForEach([("durationMinutes", "Duration (min)"), ("activeDurationSeconds", "Active time (s)"),
                     ("distanceMeters", "Distance (m)"), ("activeCalories", "Active energy (kcal)"),
                     ("averageHeartRate", "Average heart rate (bpm)")], id: \.0) { key, label in
                if workout.w(key) != .null { Text("\(label): \(workout.w(key).wText("Not supplied"))") }
            }
            if !workout.w("notes").stringValue.isEmpty { Text(workout.w("notes").stringValue) }
            let segments = workout.w("segments").arrayValue
            if !segments.isEmpty {
                DisclosureGroup("Segments (\(segments.count))") {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        Text("Segment \(index + 1) · \(segment.w("repetitions").wText("—")) repetitions").padding(.vertical, 4)
                    }
                }
            }
            Text("Provider details remain in your backup. Imported sessions never become an editable active workout.")
                .font(.footnote).foregroundStyle(ArchiveTheme.secondary)
        }
    }
    private var title: String {
        for key in ["title", "name", "activityName", "type"] {
            let value = workout.w(key).stringValue
            if !value.isEmpty { return value }
        }
        return "Watch workout"
    }
    private var source: String {
        for key in ["source", "sourceName", "provider"] {
            let value = workout.w(key).stringValue
            if !value.isEmpty { return value }
        }
        return "Connected health"
    }
}
