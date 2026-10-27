import SwiftUI
import UIKit

enum ArchiveTheme {
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.075, green: 0.071, blue: 0.082, alpha: 1)
        : UIColor(red: 0.992, green: 0.981, blue: 0.965, alpha: 1) })
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let habit = Color(red: 1, green: 0.773, blue: 0.827)
    static let sleep = Color(red: 0.788, green: 0.627, blue: 0.863)
    static let water = Color(red: 0.635, green: 0.749, blue: 0.996)
    static let move = Color(red: 0.898, green: 0.976, blue: 0.894)
    static let title = Font.system(.largeTitle, design: .serif).weight(.regular)
    static let heading = Font.system(.title2, design: .serif).weight(.regular)
    static let number = Font.system(.title, design: .serif).monospacedDigit()
}

struct ArchivePanel<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(scheme == .dark ? 0.15 : 0.24), in: RoundedRectangle(cornerRadius: 26))
    }
}

struct ArchivePage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @EnvironmentObject private var store: ArchiveStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(ArchiveTheme.title).accessibilityAddTraits(.isHeader)
                    if !subtitle.isEmpty { Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }.padding(.vertical, 8)
                content
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await store.refresh() }
        .background(ArchiveTheme.canvas.ignoresSafeArea())
    }
}

struct ArchiveEmpty: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(ArchiveTheme.heading)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
    }
}

extension View {
    @ViewBuilder func archiveGlass() -> some View {
        modifier(ArchiveGlass())
    }
}

private struct ArchiveGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}
