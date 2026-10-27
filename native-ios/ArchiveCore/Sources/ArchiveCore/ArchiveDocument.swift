import Foundation

public struct DailyRecord: Equatable, Sendable {
    public var date: String
    public var habits: [String: Bool]
    public var waterML: Double?
    public var sleepHours: Double?
    public var sleepSource: String

    public init(date: String, habits: [String: Bool] = [:], waterML: Double? = nil,
                sleepHours: Double? = nil, sleepSource: String = "manual") {
        self.date = date
        self.habits = habits
        self.waterML = waterML
        self.sleepHours = sleepHours
        self.sleepSource = sleepSource
    }
}

public enum ArchiveBackupError: Error, LocalizedError, Equatable {
    case invalidArchive
    case unsupportedVersion
    case malformedData

    public var errorDescription: String? {
        switch self {
        case .invalidArchive: return "This file is not an Archive backup. Your current data has not changed."
        case .unsupportedVersion: return "This Archive backup version is not supported. Your current data has not changed."
        case .malformedData: return "This Archive backup contains malformed records. Your current data has not changed."
        }
    }
}

/// Value-semantic candidate document. The caller commits/persists it only after
/// successful import/reconciliation; this package performs no I/O or health reads.
public struct ArchiveDocument: Equatable, Sendable {
    // These bounds protect downstream Int/minute display conversions. The raw
    // imported JSON remains intact; bounds apply only to the typed projection.
    static let maximumDisplayWaterML: Double = 1_000_000_000
    public var data: [String: JSONValue]
    private var envelope: [String: JSONValue]

    public init() {
        let habits = ["Read", "Walk", "Workout", "Journal"].map { JSONValue.string($0) }
        data = ["habitNames": .array(habits), "trackedHabits": .array(habits),
                "entries": .array([]), "goals": .object(["waterTarget": .number(2000), "waterUnit": .string("ml")])]
        envelope = [:]
    }

    public init(backup: Data) throws {
        let root: JSONValue
        do { root = try JSONDecoder().decode(JSONValue.self, from: backup) }
        catch { throw ArchiveBackupError.invalidArchive }
        guard case .object(let envelope) = root,
              envelope["app"] == .string("archive-productivity-tracker") else {
            throw ArchiveBackupError.invalidArchive
        }
        guard case .number(let version)? = envelope["version"],
              version >= 1, version <= 4, version.rounded() == version else {
            throw ArchiveBackupError.unsupportedVersion
        }
        guard case .object(let data)? = envelope["data"] else { throw ArchiveBackupError.malformedData }
        try Self.validate(data)
        self.data = data
        self.envelope = envelope
        migrateWater()
        reconcileSleep()
    }

    public func backup() throws -> Data {
        try Self.validate(data)
        var root = envelope
        root["app"] = .string("archive-productivity-tracker")
        root["version"] = .number(4)
        root["exportedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        root["data"] = .object(data)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(JSONValue.object(root))
    }

    public var habits: [String] {
        Self.unique((data["habitNames"]?.arrayValue ?? []).map(\.stringValue)
            + rawEntries.flatMap { $0["habits"].objectValue.keys.sorted() })
    }

    public var trackedHabits: [String] {
        guard let tracked = data["trackedHabits"] else { return habits }
        return Self.unique(tracked.arrayValue.map(\.stringValue)).filter { habits.contains($0) }
    }

    public var entries: [DailyRecord] {
        rawEntries.compactMap { raw in
            let fields = Self.recordedFields(raw)
            guard Self.validDateKey(raw["date"].stringValue), ["habits", "water", "sleep"].contains(where: { fields[$0]?.boolValue == true }) else { return nil }
            let source = raw["sleepSource"].stringValue
            return DailyRecord(date: raw["date"].stringValue,
                habits: fields["habits"]?.boolValue == true ? raw["habits"].objectValue.mapValues(\.boolValue) : [:],
                waterML: fields["water"]?.boolValue == true ? min(Self.maximumDisplayWaterML, max(0, raw["water"].finiteNumber ?? 0)) : nil,
                sleepHours: fields["sleep"]?.boolValue == true ? min(24, max(0, raw["sleep"].finiteNumber ?? 0)) : nil,
                sleepSource: source.isEmpty ? "manual" : source)
        }.sorted { $0.date < $1.date }
    }

    public func entry(on date: String) -> DailyRecord? { entries.first { $0.date == date } }

    public mutating func setHabit(_ habit: String, completed: Bool, on date: String) {
        let name = habit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, Self.validDateKey(date), completed || rawEntries.contains(where: { $0["date"].stringValue == date }) else { return }
        if !habits.contains(name) { addHabit(name) }
        updateEntry(on: date, field: "habits") { raw in
            var values = raw["habits"].objectValue
            values[name] = .bool(completed)
            raw["habits"] = .object(values)
        }
    }

    public mutating func addHabit(_ habit: String) {
        let name = habit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tracked = trackedHabits
        data["habitNames"] = .array(Self.unique(habits + [name]).map { .string($0) })
        data["trackedHabits"] = .array(Self.unique(tracked + [name]).map { .string($0) })
    }

    public mutating func renameHabit(_ habit: String, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, habit != name, habits.contains(habit) else { return }
        let names = Self.unique(habits.map { $0 == habit ? name : $0 })
        let tracked = Set(trackedHabits.map { $0 == habit ? name : $0 })
        data["habitNames"] = .array(names.map { .string($0) })
        data["trackedHabits"] = .array(names.filter { tracked.contains($0) }.map { .string($0) })
        rawEntries = rawEntries.map { raw in
            var raw = raw
            var values = raw["habits"].objectValue
            if let oldValue = values.removeValue(forKey: habit) {
                values[name] = .bool(oldValue.boolValue || (values[name]?.boolValue ?? false))
                raw["habits"] = .object(values)
            }
            return raw
        }
    }

    public mutating func setTracked(_ habit: String, enabled: Bool) {
        guard habits.contains(habit) else { return }
        var tracked = Set(trackedHabits)
        if enabled { tracked.insert(habit) } else { tracked.remove(habit) }
        data["trackedHabits"] = .array(habits.filter { tracked.contains($0) }.map { .string($0) })
    }

    public mutating func addWater(_ millilitres: Double, on date: String) {
        guard millilitres.isFinite, millilitres > 0 else { return }
        let raw = rawEntries.first { $0["date"].stringValue == date }
        let recorded = Self.recordedFields(raw)["water"]?.boolValue == true
        // Never replace a huge imported value with its bounded display value.
        let total = (recorded ? (raw?["water"].finiteNumber ?? 0) : 0) + millilitres
        setWater(total, on: date)
    }

    public mutating func setWater(_ millilitres: Double, on date: String) {
        guard millilitres.isFinite, millilitres >= 0, millilitres <= Self.maximumDisplayWaterML, Self.validDateKey(date) else { return }
        updateEntry(on: date, field: "water") { $0["water"] = .number(millilitres) }
    }

    public mutating func setManualSleep(_ hours: Double, on date: String) {
        guard hours.isFinite, hours >= 0, hours <= 24, Self.validDateKey(date) else { return }
        let sessions = Self.sleepByDate(data["watchData"]?["sleepSessions"].arrayValue ?? [])
        if sessions[date] != nil {
            reconcileSleep()
            var entries = rawEntries
            guard let index = entries.firstIndex(where: { $0["date"].stringValue == date }) else { return }
            var native = entries[index]["nativeIOS"].objectValue
            // Updating a fallback must never displace an authoritative watch value.
            var fallback = native["sleepFallback"]?.objectValue ?? [:]
            for key in Self.sleepMetadataKeys { fallback.removeValue(forKey: key) }
            fallback["recorded"] = .bool(true)
            fallback["sleep"] = .number(hours)
            fallback["sleepSource"] = .string("manual")
            native["sleepFallback"] = .object(fallback)
            entries[index]["nativeIOS"] = .object(native)
            rawEntries = entries
        } else {
            updateEntry(on: date, field: "sleep") { raw in
                raw["sleep"] = .number(hours)
                raw["sleepSource"] = .string("manual")
                for key in Self.sleepMetadataKeys where key != "sleep" && key != "sleepSource" {
                    var object = raw.objectValue
                    object.removeValue(forKey: key)
                    raw = .object(object)
                }
            }
        }
    }

    public static func dateKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var rawEntries: [JSONValue] {
        get { data["entries"]?.arrayValue ?? [] }
        set { data["entries"] = .array(newValue) }
    }

    static func recordedFields(_ raw: JSONValue?) -> [String: JSONValue] {
        guard let raw else { return ["habits": .bool(false), "water": .bool(false), "sleep": .bool(false)] }
        guard case .object(let fields) = raw["recordedFields"] else {
            return ["habits": .bool(true), "water": .bool(true), "sleep": .bool(true)]
        }
        return fields.merging(["habits": .bool(fields["habits"]?.boolValue ?? false),
            "water": .bool(fields["water"]?.boolValue ?? false), "sleep": .bool(fields["sleep"]?.boolValue ?? false)]) { _, new in new }
    }

    mutating func updateEntry(on date: String, field: String, change: (inout JSONValue) -> Void) {
        var entries = rawEntries
        let index = entries.firstIndex { $0["date"].stringValue == date }
        var raw = index.map { entries[$0] } ?? .object(["date": .string(date)])
        var fields = Self.recordedFields(index.map { entries[$0] })
        change(&raw)
        fields[field] = .bool(true)
        raw["recordedFields"] = .object(fields)
        if let index { entries[index] = raw } else { entries.append(raw) }
        rawEntries = entries.sorted { $0["date"].stringValue < $1["date"].stringValue }
    }

    static func validDateKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard key.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), year > 0 else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        return dateKey(date, calendar: calendar) == key
    }

    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private mutating func migrateWater() {
        var goals = data["goals"]?.objectValue ?? [:]
        guard (goals["waterUnit"]?.stringValue ?? "").isEmpty else { return }
        let target = goals["waterTarget"]?.finiteNumber
        let waters = rawEntries.compactMap { $0["water"].finiteNumber }
        let cups = (target.map { $0 <= 30 } ?? false) || (!waters.isEmpty && (waters.max() ?? 0) <= 30)
        if cups {
            rawEntries = rawEntries.map { raw in
                var raw = raw
                if let water = raw["water"].finiteNumber { raw["water"] = .number(water * 250) }
                return raw
            }
            if let target, target <= 30 { goals["waterTarget"] = .number(target * 250) }
        }
        // Mark the unit even on sparse imports so a later roundtrip cannot
        // misinterpret a newly entered small millilitre value as cups.
        goals["waterUnit"] = .string("ml")
        data["goals"] = .object(goals)
    }

    private static func validate(_ data: [String: JSONValue]) throws {
        guard case .array(let entries)? = data["entries"] else { throw ArchiveBackupError.malformedData }
        var dates = Set<String>()
        for entry in entries {
            guard case .object = entry, validDateKey(entry["date"].stringValue),
                  dates.insert(entry["date"].stringValue).inserted else { throw ArchiveBackupError.malformedData }
            if entry.objectValue["habits"] != nil {
                guard case .object(let habits) = entry["habits"], habits.values.allSatisfy({ if case .bool = $0 { return true }; return false }) else {
                    throw ArchiveBackupError.malformedData
                }
            }
            for key in ["water", "sleep"] where entry[key] != .null {
                guard let value = entry[key].finiteNumber, value >= 0 else { throw ArchiveBackupError.malformedData }
            }
            if entry.objectValue["recordedFields"] != nil {
                guard case .object(let fields) = entry["recordedFields"] else { throw ArchiveBackupError.malformedData }
                for key in ["habits", "water", "sleep"] where fields[key] != nil {
                    guard case .bool? = fields[key] else { throw ArchiveBackupError.malformedData }
                }
            }
        }
        for key in ["habitNames", "trackedHabits"] where data[key] != nil {
            guard case .array(let values)? = data[key], values.allSatisfy({ if case .string = $0 { return true }; return false }) else {
                throw ArchiveBackupError.malformedData
            }
        }
        for key in ["goals", "watchData", "nativeIOS", "workout"] where data[key] != nil {
            guard case .object? = data[key] else { throw ArchiveBackupError.malformedData }
        }
        if let watch = data["watchData"] {
            for key in ["dailySummaries", "sleepSessions", "workouts", "quantitySamples"] where watch.objectValue[key] != nil {
                guard case .array(let records) = watch[key], records.allSatisfy({ if case .object = $0 { return true }; return false }) else {
                    throw ArchiveBackupError.malformedData
                }
            }
            if watch.objectValue["samples"] != nil {
                guard case .object = watch["samples"] else { throw ArchiveBackupError.malformedData }
                for key in ["heartRate", "heartRateVariability"] where watch["samples"].objectValue[key] != nil {
                    guard case .array(let records) = watch["samples"][key], records.allSatisfy({ if case .object = $0 { return true }; return false }) else {
                        throw ArchiveBackupError.malformedData
                    }
                }
            }
        }
    }
}
