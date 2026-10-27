import SwiftUI

enum ArchiveDestination: String, CaseIterable, Identifiable {
    case workout, workoutHistory, habit, coach, home, water, sleep, stats, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .workout: "Workout"
        case .workoutHistory: "Workout history"
        case .habit: "Habit"
        case .coach: "AI Coach"
        case .home: "Home"
        case .water: "Water"
        case .sleep: "Sleep"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .workout: "dumbbell"
        case .workoutHistory: "calendar"
        case .habit: "checkmark.circle"
        case .coach: "bubble.left.and.bubble.right"
        case .home: "house"
        case .water: "drop"
        case .sleep: "moon"
        case .stats: "chart.xyaxis.line"
        case .settings: "slider.horizontal.3"
        }
    }
    var tint: Color {
        switch self {
        case .habit, .home: ArchiveTheme.habit
        case .water: ArchiveTheme.water
        case .sleep: ArchiveTheme.sleep
        default: ArchiveTheme.move
        }
    }
}

struct ArchiveShell: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var destination: ArchiveDestination = .home
    @State private var group: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            ArchiveTheme.canvas.ignoresSafeArea()
            NavigationStack {
                page
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Text("Archive").font(ArchiveTheme.heading)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Settings", systemImage: "person.crop.circle") { destination = .settings }
                                .labelStyle(.iconOnly)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
            }
            .opacity(store.isLaunching ? 0 : 1)
            .allowsHitTesting(!store.isLaunching)
            .accessibilityHidden(store.isLaunching)
            if store.isLaunching { launchView }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.isLaunching)
        .task { await store.launch() }
        .alert("Unable to save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    @ViewBuilder private var page: some View {
        switch destination {
        case .home: HomePage(navigate: navigate)
        case .habit: HabitPage()
        case .water: WaterPage()
        case .sleep: SleepPage()
        case .stats: StatsPage()
        case .settings: SettingsPage()
        case .workout: WorkoutPage()
        case .workoutHistory: WorkoutHistoryPage()
        case .coach: CoachPage()
        }
    }

    private func navigate(_ next: ArchiveDestination) {
        destination = next
        // Keep the chosen category open until Home or its category button is tapped.
    }

    private var bottomChrome: some View {
        VStack(spacing: 8) {
            if let message = store.message {
                HStack {
                    Text(message).font(.footnote)
                    Spacer(minLength: 8)
                    Button("Dismiss", systemImage: "xmark") { store.message = nil }.labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.leading, 16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityElement(children: .contain)
            }
            if let label = store.undoLabel {
                HStack {
                    Text(label).font(.subheadline)
                    Spacer()
                    Button("Undo") { store.undo() }.frame(minHeight: 44)
                    Button("Dismiss", systemImage: "xmark") { store.dismissUndo() }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.padding(.leading, 16).background(.regularMaterial, in: Capsule())
            }
            if let group {
                let destinations: [ArchiveDestination] = group == "productivity" ? [.workout, .workoutHistory, .habit, .coach] : [.water, .sleep, .stats, .settings]
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 2) { ForEach(destinations) { item in destinationButton(item) } }
                    VStack(spacing: 2) { ForEach(destinations) { item in destinationButton(item) } }
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            HStack(spacing: 10) {
                categoryButton("Productivity", symbol: "list.bullet", key: "productivity")
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { destination = .home; group = nil }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: destination == .home ? "house.fill" : "house").font(.title3)
                        Text("Home").font(.caption)
                    }
                    .frame(minWidth: 68, minHeight: 58)
                    .background(destination == .home ? ArchiveTheme.habit.opacity(0.35) : .clear, in: Circle())
                }
                .accessibilityAddTraits(destination == .home ? [.isSelected] : [])
                categoryButton("Health", symbol: "heart", key: "health")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: 440)
            .archiveGlass()
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
    }

    private func categoryButton(_ title: String, symbol: String, key: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { group = group == key ? nil : key }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption)
            }.frame(maxWidth: .infinity, minHeight: 56)
        }
        .accessibilityLabel("\(title), \(group == key ? "collapse" : "expand") destinations")
        .accessibilityAddTraits(group == key ? [.isSelected] : [])
    }

    private func destinationButton(_ item: ArchiveDestination) -> some View {
        Button { navigate(item) } label: {
            VStack(spacing: 6) {
                Image(systemName: item.icon).font(.title3)
                Text(item.title).font(.caption2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 5)
            .background(destination == item ? item.tint.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityAddTraits(destination == item ? [.isSelected] : [])
    }

    private var launchView: some View {
        VStack(spacing: 18) {
            Text("A").font(.system(size: 76, weight: .regular, design: .serif))
                .foregroundStyle(LinearGradient(colors: [ArchiveTheme.habit, ArchiveTheme.sleep, ArchiveTheme.water], startPoint: .leading, endPoint: .trailing))
                .accessibilityHidden(true)
            ProgressView().accessibilityLabel("Opening your saved records")
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(ArchiveTheme.canvas)
    }
}
