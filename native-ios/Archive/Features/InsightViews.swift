import ArchiveCore
import Charts
import SwiftUI

struct MetricPoint: Identifiable {
    var id: String { date }
    let date: String
    let value: Double
}

struct MetricTrend: View {
    var metric: String
    var days = 7
    var line = false
    @EnvironmentObject private var store: ArchiveStore
    private var points: [MetricPoint] {
        let start = ArchiveStore.dateKey(Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date())
        return store.document.entries.filter { $0.date >= start }.compactMap { entry in
            let value: Double?
            switch metric {
            case "sleep": value = entry.sleepHours
            case "habit":
                let tracked = store.document.trackedHabits
                value = entry.habits.isEmpty || tracked.isEmpty ? nil : Double(tracked.filter { entry.habits[$0] == true }.count) / Double(tracked.count) * 100
            default: value = entry.waterML
            }
            return value.map { MetricPoint(date: entry.date, value: $0) }
        }
    }
    private var tint: Color { metric == "sleep" ? ArchiveTheme.sleep : metric == "habit" ? ArchiveTheme.habit : ArchiveTheme.water }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The last \(days) days").font(ArchiveTheme.heading)
            if points.isEmpty {
                Text("A pattern will grow as your records arrive.").foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    if line {
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value)).foregroundStyle(tint)
                        PointMark(x: .value("Date", point.date), y: .value("Value", point.value)).foregroundStyle(tint)
                    } else {
                        BarMark(x: .value("Date", point.date), y: .value("Value", point.value))
                            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.45), tint], startPoint: .bottom, endPoint: .top)).cornerRadius(5)
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: min(7, points.count))) }
                .frame(height: 160)
                .accessibilityLabel("\(metric) across recorded days. Unrecorded days are omitted.")
                Text("Only recorded days are included.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8)
    }
}

struct StatsPage: View {
    @EnvironmentObject private var store: ArchiveStore
    var body: some View {
        ArchivePage(title: "Your own rhythm.", subtitle: "Patterns to understand, at your pace.") {
            if store.document.entries.isEmpty {
                ArchiveEmpty(title: "A little history, in time", detail: "Your real records will become trends here. There is nothing to catch up on.", icon: "chart.xyaxis.line")
            }
            MetricTrend(metric: "habit")
            MetricTrend(metric: "water")
            MetricTrend(metric: "sleep")
            let summaries = store.document.data["watchData"]?["dailySummaries"].arrayValue ?? []
            if let latest = summaries.sorted(by: { $0["date"].stringValue < $1["date"].stringValue }).last {
                ArchivePanel(tint: ArchiveTheme.move) {
                    Text("Latest movement").font(ArchiveTheme.heading)
                    Text(latest["date"].stringValue).font(.caption).foregroundStyle(.secondary)
                    if latest["steps"] != .null { LabeledContent("Steps", value: integerText(latest["steps"].doubleValue)) }
                    if latest["distanceMeters"] != .null { LabeledContent("Distance", value: String(format: "%.1f km", latest["distanceMeters"].doubleValue / 1000)) }
                    Text(latest["source"].stringValue).font(.caption).foregroundStyle(.secondary)
                }
            }
            NativeModulesView(page: "stats", metric: "water")
        }
    }
}

struct NativeModulesView: View {
    let page: String
    let metric: String
    @EnvironmentObject private var store: ArchiveStore
    @State private var managing = false
    private var modules: [JSONValue] { store.document.data["pageModules"]?[page].arrayValue ?? [] }
    private let available = [("daily-histogram", "Daily bars"), ("area-line", "Trend line")]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(modules.enumerated()), id: \.offset) { _, module in
                let name = module["moduleId"].stringValue
                if name == "daily-histogram" || name == "area-line" {
                    MetricTrend(metric: metric, days: max(1, min(365, Int(module["settings"]["days"].doubleValue == 0 ? 7 : module["settings"]["days"].doubleValue))), line: name == "area-line")
                }
            }
            Button("Your panels", systemImage: "slider.horizontal.3") { managing = true }.font(.subheadline).frame(minHeight: 44)
        }
        .sheet(isPresented: $managing) {
            NavigationStack {
                List {
                    Section("On this page") {
                        ForEach(Array(modules.enumerated()), id: \.offset) { _, module in
                            VStack(alignment: .leading) {
                                Text(module["moduleId"].stringValue)
                                if !available.contains(where: { $0.0 == module["moduleId"].stringValue }) {
                                    Text("Configuration retained; this panel is available in the web app.").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in update { $0.remove(atOffsets: offsets) } }
                        .onMove { offsets, destination in update { $0.move(fromOffsets: offsets, toOffset: destination) } }
                    }
                    Section("Add") {
                        ForEach(available, id: \.0) { kind, label in
                            Button(label) {
                                update { $0.append(.object(["id": .string(UUID().uuidString), "moduleId": .string(kind), "settings": .object(["days": .number(7)])])) }
                            }
                        }
                    }
                }.navigationTitle("Your panels").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { EditButton() }; ToolbarItem(placement: .confirmationAction) { Button("Done") { managing = false } } }
            }
        }
    }
    private func update(_ edit: (inout [JSONValue]) -> Void) {
        store.change { data in
            var pages = data["pageModules"]?.objectValue ?? [:]
            var values = pages[page]?.arrayValue ?? []
            edit(&values)
            pages[page] = .array(values)
            data["pageModules"] = .object(pages)
        }
    }
}
