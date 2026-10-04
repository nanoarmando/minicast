import AppKit
import SwiftUI
import Perception

struct BackupSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(BackupCoordinator.self) private var backup
    private var runningApps: RunningAppsMonitor { core.runningApps }
    @State private var raycastFile: URL?
    @State private var passphrase = ""
    @State private var importing = false
    @State private var status: Status?
    @State private var selection: RaycastImportOptions = .all
    @State private var isRaycastExport = false

    private enum Status {
        case success(String)
        case failure(String)
    }

    private var raycastRunning: Bool {
        runningApps.runningBundleIDs.contains(where: BackupActions.isRaycastBundleID)
    }

    /// Turning it on may ask first, so the switch follows the setting rather than the click.
    private var settingsFileSync: Binding<Bool> {
        Binding(
            get: { core.settings.settingsFileEnabled },
            set: { enabled in Task { await BackupActions.setSettingsFileEnabled(enabled, core: core) } })
    }

    private var raycastFileSubtitle: String {
        guard let name = raycastFile?.lastPathComponent else {
            return "A .rayconfig file from Raycast 2.0 or later."
        }
        return "\(name) — \(isRaycastExport ? "Raycast export" : "not a Raycast export")"
    }

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    LabeledContent {
                        Button("Export…") { backup.show(.export) }
                    } label: {
                        SettingsRowTitle(.backupExport, "Export Backup")
                        Text("Settings, extensions, AI and history, as one .minicast file.")
                    }
                } header: {
                    SettingsSectionHeader(.backupExport)
                }

                Section {
                    LabeledContent {
                        Button("Import…") { backup.show(.import) }
                    } label: {
                        SettingsRowTitle(.backupImport, "Import Backup")
                        Text("A .minicast or .tinycast file exported from Minicast or Tinycast.")
                    }
                } header: {
                    SettingsSectionHeader(.backupImport)
                }

                Section {
                    LabeledContent {
                        Button("Choose…") { chooseRaycastFile() }
                    } label: {
                        SettingsRowTitle(.backupImportFromRaycast, "Raycast Export")
                        Text(raycastFileSubtitle)
                    }
                    LabeledContent {
                        RevealableSecureField(
                            title: "Passphrase", text: $passphrase, prompt: Text("Export password")
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        // LabeledContent right-aligns its value text, caret and all; a field reads left.
                        .multilineTextAlignment(.leading)
                        .frame(width: 160)
                        .onSubmit(runRaycastImport)
                    } label: {
                        Text("Passphrase")
                    }
                    RaycastImportSelection(selection: $selection)
                    conflictNotice
                    LabeledContent {
                        if importing {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Import") { runRaycastImport() }
                                .disabled(!isRaycastExport || passphrase.isEmpty || selection.isEmpty)
                        }
                    } label: {
                        Text("Import")
                    }
                    if let status { statusRow(status) }
                } header: {
                    SettingsSectionHeader(.backupImportFromRaycast)
                }

                Section {
                    Toggle(isOn: settingsFileSync) {
                        SettingsRowTitle(.backupSettingsFile, "Sync settings file")
                        Text(BackupActions.settingsFilePath)
                    }
                    if core.settings.settingsFileEnabled {
                        LabeledContent {
                            Button("Show in Finder", action: BackupActions.revealSettingsFile)
                        } label: {
                            Text("Settings changed here are written to the file, and edits to it apply here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    SettingsSectionHeader(.backupSettingsFile)
                }
            }
            .formStyle(.grouped)
            .settingsScrollTarget(.backup)
        }
    }

    @ViewBuilder
    private var conflictNotice: some View {
        if raycastRunning {
            LabeledContent {
                Button("Quit Raycast") { BackupActions.quitRaycast() }
            } label: {
                Label(
                    "Raycast is running — quit it to avoid hotkey conflicts.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
        } else {
            Label(
                "Unset matching Raycast shortcuts to avoid conflicts.",
                systemImage: "info.circle"
            )
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusRow(_ status: Status) -> some View {
        switch status {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func chooseRaycastFile() {
        guard let url = BackupActions.pickRaycastFile() else { return }
        raycastFile = url
        isRaycastExport = BackupActions.isRaycastExport(url)
        status = nil
    }

    private func runRaycastImport() {
        guard let file = raycastFile, isRaycastExport, !passphrase.isEmpty, !selection.isEmpty,
            !importing
        else { return }
        importing = true
        status = nil
        Task {
            defer { importing = false }
            do {
                let outcome = try await BackupActions.importRaycast(
                    core: core, file: file, passphrase: passphrase, options: selection)
                status = .success(BackupActions.raycastText(outcome))
                passphrase = ""
            } catch {
                status = .failure(error.localizedDescription)
            }
        }
    }
}
