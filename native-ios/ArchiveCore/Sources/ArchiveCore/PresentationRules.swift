import Foundation

extension ArchiveDocument {
    public static func moduleSpanDays(_ value: JSONValue) -> Int {
        guard let number = value.finiteNumber else { return 7 }
        return Int(min(365, max(1, number)))
    }

    public mutating func reorderHabits(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let names = habits
        guard destination >= 0, destination <= names.count,
              offsets.allSatisfy({ names.indices.contains($0) }) else { return }
        let moving = offsets.sorted().map { names[$0] }
        var remaining = names.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: insertion)
        let tracked = Set(trackedHabits)
        data["habitNames"] = .array(remaining.map(JSONValue.string))
        data["trackedHabits"] = .array(remaining.filter { tracked.contains($0) }.map(JSONValue.string))
    }
}
