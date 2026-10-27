import ArchiveCore
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var bytes: Data
    init(bytes: Data = Data()) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.bytes = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}

struct SettingsPage: View {
    @EnvironmentObject private var store: ArchiveStore
    @State private var importing = false
    @State private var exporting = false
    @State private var backupFile = ArchiveBackupFile()
    @State private var reviewing = false
    @State private var confirmImport = false
    @State private var importBytes: Data?
    private var goals: JSONValue { store.document.data["goals"] ?? .object([:]) }

    var body: some View {
        ArchivePage(title: "Make it yours.", subtitle: "Your data, your pace, your choices.") {
            ArchivePanel(tint: ArchiveTheme.sleep) {
                Label("Apple Health", systemImage: "heart.text.clipboard").font(ArchiveTheme.heading)
                Text(store.healthEnabled ? "Access reviewed" : "Connect when you're ready").font(.headline).padding(.top, 8)
                Text("Garmin Connect can share sleep, steps, heart rate and workouts with Apple Health. Archive reads the records you choose to share.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(reviewing ? "Opening Apple Health…" : "Review health access") {
                    reviewing = true
                    Task { await store.reviewHealthAccess(); reviewing = false }
                }.buttonStyle(.bordered).controlSize(.large).disabled(reviewing || !HealthKitService.available)
                Toggle("Import on launch and pull to refresh", isOn: Binding(
                    get: { store.healthEnabled },
                    set: { enabled in
                        store.change { data in
                            var native = data["nativeIOS"]?.objectValue ?? [:]
                            native["healthKitEnabled"] = .bool(enabled)
                            data["nativeIOS"] = .object(native)
                        }
                    }
                )).font(.subheadline)
                if !store.lastSync.isEmpty { Text("Last refresh: \(store.lastSync)").font(.caption).foregroundStyle(.secondary) }
                Text("An access review does not reveal which read categories you allowed. Manage your choices in the Health app. Empty results can mean no shared data or restricted access.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily intentions").font(ArchiveTheme.heading)
                Stepper(value: goal("waterTarget", fallback: 2000), in: 250...20000, step: 250) {
                    LabeledContent("Water", value: "\(integerText(goals["waterTarget"].doubleValue == 0 ? 2000 : goals["waterTarget"].doubleValue)) mL")
                }
                Stepper(value: goal("sleepTarget", fallback: 8), in: 1...24, step: 0.25) {
                    LabeledContent("Sleep", value: hoursText(goals["sleepTarget"].doubleValue == 0 ? 8 : goals["sleepTarget"].doubleValue))
                }
            }.padding(.vertical, 8)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Your records").font(ArchiveTheme.heading)
                Button("Export complete backup", systemImage: "square.and.arrow.up") {
                    do { backupFile = ArchiveBackupFile(bytes: try store.document.backup()); exporting = true }
                    catch { store.errorMessage = error.localizedDescription }
                }.frame(minHeight: 44)
                Button("Import Archive backup", systemImage: "square.and.arrow.down") { importing = true }.frame(minHeight: 44)
                Text("Records from Android or the web app move through JSON backup. Import replaces this iPhone's current document after keeping a recovery copy. Your other installations are unchanged.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Divider()
            Text("Archive · Native preview\nYour records stay on this iPhone. This candidate has not yet completed full feature and device validation.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let bytes = try Data(contentsOf: url)
                _ = try ArchiveDocument(backup: bytes)
                importBytes = bytes
                confirmImport = true
            } catch { store.errorMessage = "This backup could not be opened. \(error.localizedDescription)" }
        }
        .confirmationDialog("Replace this iPhone's records with the selected backup?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Import backup") { if let bytes = importBytes { store.importBackup(bytes) }; importBytes = nil }
            Button("Cancel", role: .cancel) { importBytes = nil }
        } message: { Text("A recovery copy of the current file will be kept before anything is replaced.") }
        .fileExporter(isPresented: $exporting, document: backupFile, contentType: .json, defaultFilename: "archive-backup-\(store.today)") { result in
            if case .failure(let error) = result { store.errorMessage = "The backup could not be exported. \(error.localizedDescription)" }
        }
    }

    private func goal(_ key: String, fallback: Double) -> Binding<Double> {
        Binding(get: { goals[key] == .null ? fallback : goals[key].doubleValue }, set: { value in
            store.change { data in
                var values = data["goals"]?.objectValue ?? [:]
                values[key] = .number(value)
                data["goals"] = .object(values)
            }
        })
    }
}

struct CoachPage: View {
    @EnvironmentObject private var store: ArchiveStore
    var body: some View {
        ArchivePage(title: "A little perspective.", subtitle: "A place to reflect.") {
            ArchiveEmpty(title: "Your conversations are kept", detail: "Saved conversations are available below. Sending messages and reviewing proposed changes are still being brought to the native app; those features remain available in the existing Archive app.", icon: "bubble.left.and.bubble.right")
            ForEach(Array((store.document.data["coachMessages"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, message in
                VStack(alignment: .leading, spacing: 8) {
                    Text(message["role"].stringValue == "user" ? "You" : "Archive").font(.caption).foregroundStyle(.secondary)
                    Text(message["text"].stringValue).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }
        }
    }
}
