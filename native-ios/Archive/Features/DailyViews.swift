import ArchiveCore
import SwiftUI
import UIKit

struct HomePage: View {
    let navigate: (ArchiveDestination) -> Void
    @EnvironmentObject private var store: ArchiveStore
    private var pendingHabit: String? { store.document.trackedHabits.first { store.document.entry(on: store.today)?.habits[$0] != true } }
    private var sleep: DailyRecord? { store.document.entries.last { $0.sleepHours != nil } }

    var body: some View {
        ArchivePage(title: "A little care,\none step at a time.", subtitle: "Your day, at your pace.") {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day()).font(.subheadline).foregroundStyle(.secondary)
            if store.document.data["workout"]?["activeSession"] != nil,
               store.document.data["workout"]?["activeSession"] != .null {
                Button { navigate(.workout) } label: {
                    ArchivePanel(tint: ArchiveTheme.move) {
                        Label("Your workout is saved", systemImage: "dumbbell")
                        Text("Continue where you paused").font(ArchiveTheme.heading)
                    }
                }.buttonStyle(.plain)
            }
            Button { navigate(.sleep) } label: {
                ArchivePanel(tint: ArchiveTheme.sleep) {
                    Text(sleep?.sleepSource == "manual" ? "Your latest night" : "From your watch").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .center, spacing: 18) {
                        Image(systemName: "moon.fill").font(.title).foregroundStyle(.purple.opacity(0.6)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Sleep")
                            Text(sleep?.sleepHours.map(hoursText) ?? "When you're ready").font(ArchiveTheme.number)
                            if let sleep { Text("\(sleep.date) · \(sleepOrigin(sleep, in: store.document))").font(.caption).foregroundStyle(.secondary) }
                            else { Text("Connect Apple Health or record a night.").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }.buttonStyle(.plain)

            if let habit = pendingHabit {
                ArchivePanel(tint: ArchiveTheme.habit) {
                    Label("One thing for you", systemImage: "book").font(.subheadline).foregroundStyle(.secondary)
                    Text(habit).font(ArchiveTheme.heading).padding(.vertical, 6)
                    Text("A moment to pause.").font(.subheadline).foregroundStyle(.secondary)
                    HoldToComplete(title: "Hold to complete", accessibilityTitle: "Complete \(habit)") {
                        store.setHabit(habit, completed: true, on: store.today)
                    }.padding(.top, 12)
                }
            } else {
                ArchivePanel(tint: ArchiveTheme.habit) {
                    Label(store.document.trackedHabits.isEmpty ? "Make room for what matters" : "A little care, already here", systemImage: "checkmark.circle")
                    Text(store.document.trackedHabits.isEmpty ? "Choose your habits" : "Nothing else to tick off.").font(ArchiveTheme.heading)
                    Button("View habits") { navigate(.habit) }.padding(.top, 6)
                }
            }
            ArchivePanel(tint: ArchiveTheme.water) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Water", systemImage: "waterbottle")
                        Text(store.document.entry(on: store.today)?.waterML.map { "\(integerText($0)) mL" } ?? "A fresh start").font(ArchiveTheme.number)
                    }
                    Spacer()
                    Button("+250 mL") { store.addWater(250, on: store.today) }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
                }
            }
            Button { navigate(.workout) } label: {
                ArchivePanel(tint: ArchiveTheme.move) {
                    Label("Movement, when you're ready", systemImage: "figure.walk")
                }
            }.buttonStyle(.plain)
            NativeModulesView(page: "home", metric: "water")
        }
    }
}

struct HoldToComplete: View {
    let title: String
    let accessibilityTitle: String
    let complete: () -> Bool
    @State private var pressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 58)
            .background(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(ArchiveTheme.habit.opacity(0.75))
                        .frame(width: pressing ? geometry.size.width : 0)
                }.clipShape(Capsule())
            }
            .background(ArchiveTheme.habit.opacity(0.35), in: Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: 0.7, maximumDistance: 18) {
                if complete(), !reduceMotion { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
            } onPressingChanged: { value in
                withAnimation(reduceMotion ? nil : .linear(duration: value ? 0.7 : 0.12)) { pressing = value }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityHint("Double tap to complete. Touch and hold when using the screen directly.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { _ = complete() }
    }
}

struct HabitPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var date = Date()
    @State private var managing = false
    private var key: String { ArchiveStore.dateKey(date) }
    var body: some View {
        ArchivePage(title: "A little, often.", subtitle: "Pick up wherever you are.") {
            DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
            HStack {
                Text("Your habits").font(ArchiveTheme.heading)
                Spacer()
                Button("Manage", systemImage: "slider.horizontal.3") { managing = true }.labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
            ForEach(store.document.trackedHabits, id: \.self) { habit in
                let done = store.document.entry(on: key)?.habits[habit] == true
                ArchivePanel(tint: ArchiveTheme.habit) {
                    HStack {
                        Text(habit).font(ArchiveTheme.heading)
                        Spacer()
                        if done { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Completed") }
                    }
                    if done {
                        Button("Mark incomplete") { store.setHabit(habit, completed: false, on: key) }
                            .font(.subheadline).frame(minHeight: 44)
                    } else {
                        HoldToComplete(title: "Hold to complete", accessibilityTitle: "Complete \(habit)") {
                            store.setHabit(habit, completed: true, on: key)
                        }
                    }
                }
            }
            if store.document.trackedHabits.isEmpty { ArchiveEmpty(title: "Your own rhythm", detail: "Add a habit that you would like to make room for.", icon: "leaf") }
            NativeModulesView(page: "habit", metric: "habit")
        }.sheet(isPresented: $managing) { HabitManager() }
    }
}

private struct HabitManager: View {
    @EnvironmentObject private var store: ArchiveStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rename: String?
    @State private var replacement = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Add a habit") {
                    TextField("Habit name", text: $name)
                    Button("Add habit") {
                        if store.commit({ $0.addHabit(name) }) { name = "" }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Tracking") {
                    ForEach(store.document.habits, id: \.self) { habit in
                        HStack {
                            Button(habit) { rename = habit; replacement = habit }
                            Toggle("Track \(habit)", isOn: Binding(
                                get: { store.document.trackedHabits.contains(habit) },
                                set: { enabled in store.commit { $0.setTracked(habit, enabled: enabled) } }
                            )).labelsHidden()
                        }
                    }.onMove { from, to in
                        store.commit { $0.reorderHabits(fromOffsets: from, toOffset: to) }
                    }
                }
                Text("Turning tracking off keeps every historical record.").font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Your habits").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .topBarLeading) { EditButton() } }
            .alert("Rename habit", isPresented: Binding(get: { rename != nil }, set: { if !$0 { rename = nil } })) {
                TextField("Name", text: $replacement)
                Button("Save") { if let original = rename { store.commit { $0.renameHabit(original, to: replacement) } }; rename = nil }
                Button("Cancel", role: .cancel) { rename = nil }
            }
        }
    }
}

struct WaterPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var date = Date()
    @State private var editing = false
    @State private var amount = 0.0
    private var key: String { ArchiveStore.dateKey(date) }
    var body: some View {
        ArchivePage(title: "A little refresh.", subtitle: "Every sip belongs here.") {
            DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
            ArchivePanel(tint: ArchiveTheme.water) {
                Text(store.document.entry(on: key)?.waterML.map { "\(integerText($0)) mL" } ?? "Nothing recorded yet").font(ArchiveTheme.number)
                HStack {
                    Button("+250 mL") { store.addWater(250, on: key) }
                    Button("+500 mL") { store.addWater(500, on: key) }
                }.buttonStyle(.bordered).controlSize(.large).padding(.vertical, 8)
                Button("Adjust total") { amount = store.document.entry(on: key)?.waterML ?? 0; editing = true }.frame(minHeight: 44)
            }
            MetricTrend(metric: "water")
            NativeModulesView(page: "water", metric: "water")
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form { TextField("Water in mL", value: $amount, format: .number).keyboardType(.decimalPad) }
                    .navigationTitle("Water total").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.commit({ $0.setWater(amount, on: key) }) { editing = false } }.disabled(!amount.isFinite || amount < 0) }
                    }
            }.presentationDetents([.medium])
        }
    }
}

struct SleepPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var manual = false
    @State private var hours = 8.0
    private var key: String { ArchiveStore.dateKey(date) }
    private var entry: DailyRecord? { store.document.entry(on: key) }
    var body: some View {
        ArchivePage(title: "Room to rest.", subtitle: "Sleep belongs to the day before you wake.") {
            DatePicker("Night belonging to", selection: $date, in: ...Date(), displayedComponents: .date)
            ArchivePanel(tint: ArchiveTheme.sleep) {
                Label(entry?.sleepSource == "manual" ? "Recorded by you" : "From your watch", systemImage: "moon")
                Text(entry?.sleepHours.map(hoursText) ?? "Your night will appear here").font(ArchiveTheme.number)
                Text(entry?.sleepHours == nil ? "Enable Apple Health in Settings, then pull down to refresh. Manual entry is always available when your watch missed a night." : "Source: \(entry.map { sleepOrigin($0, in: store.document) } ?? "Manual")")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
                Button("Record manually") { hours = entry?.sleepHours ?? 8; manual = true }.frame(minHeight: 44)
                if entry?.sleepSource != "manual", entry?.sleepHours != nil {
                    Text("Watch sleep takes priority. A manual entry is kept as a fallback.").font(.caption).foregroundStyle(.secondary)
                }
            }
            MetricTrend(metric: "sleep")
            NativeModulesView(page: "sleep", metric: "sleep")
        }
        .sheet(isPresented: $manual) {
            NavigationStack {
                Form {
                    TextField("Hours slept", value: $hours, format: .number.precision(.fractionLength(0...2))).keyboardType(.decimalPad)
                    Text("This night is filed under \(key). Watch data takes priority if it arrives later.").font(.footnote)
                }.navigationTitle("Manual sleep").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { manual = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Save") { if store.commit({ $0.setManualSleep(hours, on: key) }) { manual = false } }.disabled(!hours.isFinite || hours < 0 || hours > 24) }
                    }
            }.presentationDetents([.medium])
        }
    }
}

func hoursText(_ hours: Double) -> String {
    guard hours.isFinite, hours >= 0, hours < Double(Int.max / 60) else { return "Unavailable" }
    let minutes = max(0, Int((hours * 60).rounded()))
    return "\(minutes / 60)h \(minutes % 60)m"
}

func integerText(_ value: Double) -> String {
    guard value.isFinite else { return "Unavailable" }
    return value.formatted(.number.precision(.fractionLength(0)))
}

func sleepOrigin(_ record: DailyRecord, in document: ArchiveDocument) -> String {
    if record.sleepSource == "manual" { return "Manual" }
    let origin = document.data["entries"]?.arrayValue.first { $0["date"].stringValue == record.date }?["sleepOrigin"].stringValue ?? ""
    return origin.isEmpty ? "Synced watch" : origin
}
