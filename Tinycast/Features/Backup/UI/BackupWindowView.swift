import SwiftUI
import Perception

/// The Import & Export window: one side to write a bundle, one to read one back.
struct BackupWindowView: View {
    static let initialSize = CGSize(width: 560, height: 560)

    @Environment(BackupCoordinator.self) private var backup

    var body: some View {
        WithPerceptionTracking {
            @Perception.Bindable var backup = backup
            VStack(spacing: Theme.Spacing.md) {
                Picker("", selection: $backup.side) {
                    ForEach(BackupCoordinator.Side.allCases) { side in
                        Text(side.title).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .padding(.top, Theme.Spacing.xxxl)

                switch backup.side {
                case .export: BackupExportForm()
                case .import: BackupImportForm()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onDisappear { backup.windowDidClose() }
        }
    }
}

private struct BackupExportForm: View {
    @Environment(BackupCoordinator.self) private var backup

    var body: some View {
        WithPerceptionTracking {
            @Perception.Bindable var backup = backup
            Form {
                Section {
                    BackupCategorySelection(selection: $backup.exportSelection)
                } header: {
                    Text("Include")
                }
                Section {
                    Label {
                        Text(
                            "A backup can hold extension passwords, LocalStorage tokens, clipboard "
                                + "content and chat history in readable form. Treat it as a "
                                + "sensitive file. API keys and other Keychain secrets are never "
                                + "included.")
                    } icon: {
                        Image(systemName: "exclamationmark.shield")
                    }
                    .foregroundStyle(.secondary)
                    LabeledContent {
                        if backup.isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Export…") { backup.export() }
                                .disabled(backup.exportSelection.isEmpty)
                        }
                    } label: {
                        Text("Save as one .minicast file")
                    }
                    if let status = backup.exportStatus { BackupStatusRow(status: status) }
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct BackupImportForm: View {
    @Environment(BackupCoordinator.self) private var backup

    var body: some View {
        WithPerceptionTracking {
            @Perception.Bindable var backup = backup
            Form {
                Section {
                    LabeledContent {
                        if backup.isOpening {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Choose…") { backup.chooseImportFile() }
                                .disabled(backup.isImporting)
                        }
                    } label: {
                        Text("Backup File")
                        Text(fileSubtitle)
                    }
                }
                if let opened = backup.opened {
                    Section {
                        BackupCategorySelection(
                            selection: $backup.importSelection, available: available(opened.manifest))
                        LabeledContent {
                            if backup.isImporting {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Import…") { backup.runImport() }
                                    .disabled(backup.importSelection.isEmpty)
                            }
                        } label: {
                            Text(
                                opened.bundle.format == BackupManifest.currentFormat
                                    ? "Selected categories replace this Mac's."
                                    : "Selected categories are added to this Mac's.")
                        }
                    } header: {
                        Text("Restore")
                    }
                }
                if let status = backup.importStatus {
                    Section { BackupStatusRow(status: status) }
                }
                if !backup.pendingSecrets.isEmpty {
                    Section {
                        ForEach(backup.pendingSecrets) { secret in
                            LabeledContent {
                                Button("Open Settings") { backup.showSettings(for: secret) }
                            } label: {
                                Text(secret.name)
                                Text(kindTitle(secret.kind))
                            }
                        }
                    } header: {
                        Text("Secrets to Enter Again")
                    } footer: {
                        Text("Keychain secrets never travel in a backup.")
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var fileSubtitle: String {
        guard let name = backup.importFile?.lastPathComponent else {
            return "A .minicast or .tinycast file exported from Minicast or Tinycast."
        }
        return name
    }

    private func available(_ manifest: BackupManifest) -> [BackupCategory: Int] {
        Dictionary(
            uniqueKeysWithValues: BackupCategory.ordered(manifest.categories).map {
                ($0, manifest.count($0))
            })
    }

    private func kindTitle(_ kind: BackupPendingSecret.Kind) -> String {
        switch kind {
        case .aiConnection: return "AI connection API key"
        case .mcpServer: return "MCP server secret"
        case .installedTool: return "Installed AI tool variables"
        }
    }
}

private struct BackupStatusRow: View {
    let status: BackupCoordinator.Status

    var body: some View {
        WithPerceptionTracking {
            switch status {
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}
