import Foundation
import Perception
import UniformTypeIdentifiers

/// Owns the Import & Export window: one export and one import in flight, and their results.
@MainActor
@Perceptible
final class BackupCoordinator {
    enum Side: String, CaseIterable, Identifiable {
        case export
        case `import`

        var id: Self { self }
        var title: String { self == .export ? "Export" : "Import" }
    }

    enum Status {
        case success(String)
        case failure(String)
    }

    var side: Side = .export
    var exportSelection = BackupCategory.all
    private(set) var isExporting = false
    private(set) var exportStatus: Status?

    private(set) var importFile: URL?
    /// Held between opening the file and applying it, so the extracted tree survives the picker.
    private(set) var opened: BackupActions.OpenedBackup?
    var importSelection: Set<BackupCategory> = []
    private(set) var isOpening = false
    private(set) var isImporting = false
    private(set) var importStatus: Status?
    private(set) var pendingSecrets: [BackupPendingSecret] = []

    @PerceptionIgnored private unowned let core: AppCore
    @PerceptionIgnored private let window: AppWindowController

    init(core: AppCore) {
        self.core = core
        window = AppWindowController(
            title: "Import & Export", contentSize: BackupWindowView.initialSize,
            activation: core.activationPolicy, closesOnEscape: true)
    }

    /// An open window comes forward on `side`; export always starts with every category ticked.
    func show(_ side: Side) {
        self.side = side
        if side == .export, !isExporting {
            exportSelection = BackupCategory.all
            exportStatus = nil
        }
        window.show { BackupWindowView().environment(core).environment(self) }
    }

    // MARK: - Export

    func export() {
        guard !isExporting, !exportSelection.isEmpty,
            let destination = BackupActions.chooseSaveLocation(
                named: "Minicast", type: .minicastBackup)
        else { return }
        isExporting = true
        exportStatus = nil
        let categories = exportSelection
        Task {
            defer { isExporting = false }
            do {
                let result = try await BackupActions.exportBackup(
                    core: core, categories: categories, to: destination)
                exportStatus = .success(BackupActions.exportText(result))
            } catch {
                exportStatus = .failure(error.localizedDescription)
            }
        }
    }

    // MARK: - Import

    func chooseImportFile() {
        guard !isImporting, let url = BackupActions.chooseBackupFile() else { return }
        discardOpened()
        importFile = url
        importStatus = nil
        pendingSecrets = []
        isOpening = true
        Task {
            defer { isOpening = false }
            do {
                let opened = try await BackupActions.openBackup(at: url)
                self.opened = opened
                importSelection = opened.manifest.categories
            } catch {
                importStatus = .failure(error.localizedDescription)
            }
        }
    }

    func runImport() {
        guard let opened, !isImporting, !importSelection.isEmpty else { return }
        isImporting = true
        let categories = importSelection
        Task {
            defer { isImporting = false }
            guard let summary = await BackupActions.applyBackup(categories, from: opened, to: core)
            else { return }
            // Staged files are adopted by the stores during apply, so the tree goes either way.
            discardOpened()
            importFile = nil
            pendingSecrets = summary.pendingSecrets
            importStatus =
                summary.problems.isEmpty
                ? .success(BackupActions.summaryText(summary))
                : .failure(BackupActions.summaryText(summary))
        }
    }

    func showSettings(for secret: BackupPendingSecret) {
        let anchor: SettingsAnchor = secret.kind == .mcpServer ? .aiMCPServers : .aiProviders
        core.settingsCoordinator.showSettings(tab: .ai, revealing: .section(anchor))
    }

    /// The extracted tree can run to gigabytes, so closing the window must not strand it.
    func windowDidClose() {
        guard !isImporting else { return }
        discardOpened()
        importFile = nil
    }

    private func discardOpened() {
        opened?.staging.discard()
        opened = nil
    }
}
