import SwiftUI

@main
struct ArchiveApp: App {
    @StateObject private var store = ArchiveStore()
    var body: some Scene {
        WindowGroup {
            ArchiveShell().environmentObject(store).tint(.primary)
        }
    }
}
