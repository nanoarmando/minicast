import AppKit
import Perception

/// Checks Minicast's own releases when About asks, and installs one on confirmation.
@MainActor
@Perceptible
final class UpdateCoordinator {
    enum State: Equatable {
        case idle
        case unavailable(String)
        case checking
        case upToDate
        case available(AvailableUpdate)
        case downloading(AvailableUpdate)
        case failed(String)
    }

    private(set) var state: State = .idle

    var isBusy: Bool {
        switch state {
        case .checking, .downloading: true
        default: false
        }
    }

    @PerceptionIgnored private unowned let core: AppCore
    @PerceptionIgnored private let client = UpdateClient()
    @PerceptionIgnored private var work: Task<Void, Never>?
    @PerceptionIgnored private var shownPercent = -1

    private var workspace: URL { AppPaths.caches().appendingPathComponent("updates", isDirectory: true) }

    init(core: AppCore) {
        self.core = core
    }

    /// A swap that failed after the last quit left a report beside the staged app.
    func reportFailedSwap() {
        let report = UpdateInstaller.failureReport(in: workspace)
        guard let message = try? String(contentsOf: report, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: report)
        Task {
            await core.showNotice(
                title: "Update Failed", message: message, symbol: "exclamationmark.triangle",
                tone: .danger)
        }
    }

    func check() {
        guard !isBusy else { return }
        if let refusal = Self.eligibility.refusal {
            state = .unavailable(refusal)
            return
        }
        guard let current = Self.runningVersion else {
            state = .unavailable("This copy of Minicast has no readable version.")
            return
        }
        state = .checking
        work = Task { [client] in
            do {
                let release = try await client.latestRelease()
                switch release.outcome(comparedTo: current) {
                case .available(let update): state = .available(update)
                case .upToDate: state = .upToDate
                case .unusable: state = .failed("The latest release could not be used.")
                }
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func install(_ update: AvailableUpdate) {
        guard case .available = state else { return }
        state = .downloading(update)
        shownPercent = -1
        showDownloadProgress(update, fraction: 0)
        work = Task { [client, workspace] in
            let diskImage = workspace.appendingPathComponent("Minicast-\(update.version).dmg")
            do {
                try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
                try await client.download(update.downloadURL, to: diskImage) { fraction in
                    Task { @MainActor in self.showDownloadProgress(update, fraction: fraction) }
                }
                try Task.checkCancellation()
                core.showProgress("Verifying Minicast \(update.version)…")
                let staged = try await UpdateInstaller.stage(
                    diskImage: diskImage, version: update.version, workspace: workspace)
                core.hideProgress()
                await confirmInstall(update, staged: staged)
            } catch {
                core.hideProgress()
                try? FileManager.default.removeItem(at: diskImage)
                state = .available(update)
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                await core.showNotice(
                    title: "Update Failed", message: error.localizedDescription,
                    symbol: "exclamationmark.triangle", tone: .danger)
            }
        }
    }

    private func cancelDownload() {
        work?.cancel()
    }

    private func showDownloadProgress(_ update: AvailableUpdate, fraction: Double) {
        guard state == .downloading(update) else { return }
        let percent = Int(fraction * 100)
        guard percent != shownPercent else { return }
        shownPercent = percent
        core.showProgress(
            "Downloading Minicast \(update.version)… \(percent)%",
            onCancel: { [weak self] in self?.cancelDownload() })
    }

    private func confirmInstall(_ update: AvailableUpdate, staged: URL) async {
        let confirmed = await core.confirm(
            title: "Install Minicast \(update.version)?",
            message: "Minicast will quit, replace itself with the new version and reopen.",
            symbol: "arrow.down.circle", confirmTitle: "Install and Reopen", tone: .neutral,
            confirmRole: .standard, dismissTitle: "Not Now")
        guard confirmed else {
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            state = .available(update)
            return
        }
        do {
            try UpdateInstaller.launchSwap(
                staged: staged, target: Bundle.main.bundleURL,
                report: UpdateInstaller.failureReport(in: workspace),
                waitingFor: ProcessInfo.processInfo.processIdentifier)
        } catch {
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            state = .available(update)
            await core.showNotice(
                title: "Update Failed", message: error.localizedDescription,
                symbol: "exclamationmark.triangle", tone: .danger)
            return
        }
        NSApp.terminate(nil)
    }

    private static var runningVersion: AppVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    }

    private static var eligibility: UpdateEligibility {
        let bundle = Bundle.main.bundleURL
        return UpdateEligibility.evaluate(
            bundleIdentifier: Bundle.main.bundleIdentifier, bundlePath: bundle.path,
            isParentWritable: FileManager.default.isWritableFile(
                atPath: bundle.deletingLastPathComponent().path))
    }
}
