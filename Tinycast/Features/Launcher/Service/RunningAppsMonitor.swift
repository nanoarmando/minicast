import AppKit
import Perception

/// Tracks running apps for the launcher's indicator, live from NSWorkspace.
@MainActor
@Perceptible
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    @PerceptionIgnored private var observers: [NotificationToken] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append(NotificationToken(token, center: center))
        }
    }

    /// True while the entry's bundle runs; drives the running dot and the Quit action.
    func isRunning(_ app: AppEntry) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return runningBundleIDs.contains(bundleID)
    }

    /// Helpers and agents fire these too, so republish only on a real change.
    private func refresh() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        guard next != runningBundleIDs else { return }
        runningBundleIDs = next
    }
}
