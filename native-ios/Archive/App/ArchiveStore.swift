import ArchiveCore
import Combine
import Foundation

@MainActor
final class ArchiveStore: ObservableObject {
    @Published private(set) var document = ArchiveDocument()
    @Published var message: String?
    @Published var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLaunching = true
    @Published private(set) var undoLabel: String?
    private var undoAction: (() -> Void)?
    private let health = HealthKitService()
    private let fileURL: URL
    private var writeBlocked = false
    private var launched = false
    private var healthEpoch = UUID()

    init(directory: URL? = nil) {
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Archive", isDirectory: true)
        fileURL = folder.appendingPathComponent("records.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                document = try ArchiveDocument(backup: Data(contentsOf: fileURL))
            }
        } catch {
            writeBlocked = true
            errorMessage = "Your saved records could not be opened. They have been kept untouched. Import a valid backup to recover them. \(error.localizedDescription)"
        }
    }

    static func dateKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    var today: String { Self.dateKey(Date()) }
    var yesterday: String { Self.dateKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) }
    var nativeSettings: JSONValue { .object(document.data["nativeIOS"]?.objectValue ?? [:]) }
    var healthEnabled: Bool { nativeSettings["healthKitEnabled"].boolValue }
    var lastSync: String { nativeSettings["lastHealthSync"].stringValue }

    @discardableResult
    func commit(_ edit: (inout ArchiveDocument) -> Void) -> Bool {
        guard !writeBlocked else {
            errorMessage = "Saved records need recovery before new changes can be saved. Import a valid Archive backup in Settings."
            return false
        }
        var next = document
        edit(&next)
        do {
            try persist(next)
            document = next
            return true
        } catch {
            errorMessage = "This change could not be saved. Your previous records are intact. \(error.localizedDescription)"
            return false
        }
    }

    func change(_ edit: (inout [String: JSONValue]) -> Void) { commit { edit(&$0.data) } }

    private func persist(_ next: ArchiveDocument) throws {
        let bytes = try next.backup()
        try bytes.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func importBackup(_ bytes: Data) {
        do {
            var next = try ArchiveDocument(backup: bytes)
            // Query cursors and authorization belong to this installation's
            // HealthKit store, not to a portable backup from another phone.
            var native = next.data["nativeIOS"]?.objectValue ?? [:]
            native["healthKitAnchors"] = .object([:])
            native["healthKitEnabled"] = .bool(false)
            native["lastHealthSync"] = .string("")
            next.data["nativeIOS"] = .object(native)
            // Keep the exact old file, including a corrupt file, before replacement.
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let recovery = fileURL.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
                try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: fileURL, to: recovery.appendingPathComponent("before-import-\(UUID().uuidString).json"))
            }
            try persist(next)
            healthEpoch = UUID()
            document = next
            writeBlocked = false
            errorMessage = nil
            undoAction = nil
            undoLabel = nil
            message = "Your records are here. A copy of the previous file was kept on this iPhone."
        } catch { errorMessage = "The backup could not be imported. Your current records were not changed. \(error.localizedDescription)" }
    }

    @discardableResult
    func setHabit(_ habit: String, completed: Bool, on date: String) -> Bool {
        let old = rawEntry(on: date)
        guard commit({ $0.setHabit(habit, completed: completed, on: date) }) else { return false }
        registerUndo("Habit updated") { [weak self] in self?.restoreHabit(habit, from: old, on: date) }
        return true
    }

    func addWater(_ ml: Double, on date: String) {
        let old = rawEntry(on: date)
        guard commit({ $0.addWater(ml, on: date) }) else { return }
        registerUndo("Water recorded") { [weak self] in self?.restoreField("water", from: old, on: date) }
    }

    private func rawEntry(on date: String) -> JSONValue? {
        document.data["entries"]?.arrayValue.first { $0["date"].stringValue == date }
    }

    private func restoreField(_ field: String, from old: JSONValue?, on date: String) {
        change { data in
            var entries = data["entries"]?.arrayValue ?? []
            guard let index = entries.firstIndex(where: { $0["date"].stringValue == date }) else { return }
            var entry = entries[index]
            entry[field] = old?[field] ?? (field == "habits" ? .object([:]) : .number(0))
            var recorded = entry["recordedFields"].objectValue
            recorded[field] = old.map { oldEntry in
                oldEntry["recordedFields"] == .null ? .bool(true) : oldEntry["recordedFields"][field]
            } ?? .bool(false)
            entry["recordedFields"] = .object(recorded)
            if recorded.values.contains(where: { $0.boolValue }) || Self.hasUnknownFields(entry) || !entry["habits"].objectValue.isEmpty { entries[index] = entry }
            else { entries.remove(at: index) }
            data["entries"] = .array(entries)
        }
    }

    private func restoreHabit(_ habit: String, from old: JSONValue?, on date: String) {
        guard document.habits.contains(habit) else { message = "This habit has changed since it was recorded."; return }
        change { data in
            var entries = data["entries"]?.arrayValue ?? []
            guard let index = entries.firstIndex(where: { $0["date"].stringValue == date }) else { return }
            var entry = entries[index]
            var habits = entry["habits"].objectValue
            if let previous = old?["habits"].objectValue[habit] { habits[habit] = previous }
            else { habits.removeValue(forKey: habit) }
            entry["habits"] = .object(habits)
            var fields = entry["recordedFields"].objectValue
            let previouslyRecorded = old.map { $0["recordedFields"] == .null || $0["recordedFields"]["habits"].boolValue } ?? false
            var previousOtherHabits = old?["habits"].objectValue ?? [:]
            previousOtherHabits.removeValue(forKey: habit)
            var currentOtherHabits = habits
            currentOtherHabits.removeValue(forKey: habit)
            fields["habits"] = .bool(previouslyRecorded || previousOtherHabits != currentOtherHabits)
            entry["recordedFields"] = .object(fields)
            if fields.values.contains(where: { $0.boolValue }) || Self.hasUnknownFields(entry) || !habits.isEmpty { entries[index] = entry }
            else { entries.remove(at: index) }
            data["entries"] = .array(entries)
        }
    }

    private static func hasUnknownFields(_ entry: JSONValue) -> Bool {
        let known: Set<String> = ["date", "habits", "water", "sleep", "recordedFields"]
        let knownPresence: Set<String> = ["habits", "water", "sleep"]
        return !Set(entry.objectValue.keys).isSubset(of: known)
            || !Set(entry["recordedFields"].objectValue.keys).isSubset(of: knownPresence)
    }

    func registerUndo(_ label: String, action: @escaping () -> Void) {
        undoLabel = label; undoAction = action
    }
    func undo() { let action = undoAction; undoAction = nil; undoLabel = nil; action?() }
    func dismissUndo() { undoAction = nil; undoLabel = nil }

    func launch() async {
        guard !launched else { return }
        launched = true
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(9))
            guard !Task.isCancelled, let self, self.isLaunching else { return }
            self.isLaunching = false
            self.message = "Your saved records are ready. Apple Health is still responding."
        }
        if healthEnabled { await refresh() }
        timeout.cancel()
        isLaunching = false
    }

    func reviewHealthAccess() async {
        guard HealthKitService.available else { message = "Apple Health is unavailable on this device."; return }
        do {
            try await health.requestAccess()
            // Completion is not proof of individual read grants. No query here.
            change { data in
                var native = data["nativeIOS"]?.objectValue ?? [:]
                native["healthKitEnabled"] = .bool(true)
                data["nativeIOS"] = .object(native)
            }
            message = "Access review completed. Pull down to import the data Apple Health makes available. You can change your choices in Health."
        } catch { errorMessage = "Apple Health access could not be reviewed. \(error.localizedDescription)" }
    }

    func refresh() async {
        guard healthEnabled, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let anchors = nativeSettings["healthKitAnchors"].objectValue.mapValues(\.stringValue)
        let epoch = healthEpoch
        do {
            let batch = try await health.read(anchors: anchors)
            guard epoch == healthEpoch, healthEnabled else { return }
            commit { next in
                next.applyHealthKit(batch)
                var native = next.data["nativeIOS"]?.objectValue ?? [:]
                native["healthKitAnchors"] = .object(batch.anchors.mapValues(JSONValue.string))
                native["lastHealthSync"] = .string(ISO8601DateFormatter().string(from: batch.syncedAt))
                next.data["nativeIOS"] = .object(native)
            }
        } catch { message = "Your saved records are still here. Apple Health could not refresh: \(error.localizedDescription)" }
    }
}
