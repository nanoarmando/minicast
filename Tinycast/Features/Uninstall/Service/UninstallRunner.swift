import Foundation

struct UninstallFailedItem: Hashable, Sendable {
    let name: String
    let reason: UninstallFailureReason
    let isBundle: Bool

    var explanation: String { reason.explanation(isBundle: isBundle) }
}

struct UninstallReport: Sendable {
    let trashed: [UninstallCandidate]
    let failed: [UninstallFailedItem]
    /// Leftovers left untouched because the bundle stayed installed.
    var skippedCount = 0

    var trashedCount: Int { trashed.count }
    var freedBytes: Int64 { trashed.reduce(0) { $0 + ($1.size?.bytes ?? 0) } }
    var hasFailures: Bool { !failed.isEmpty }
    /// Gates the reference cleanup: a leftovers-only run leaves the app installed.
    var removedBundle: Bool { trashed.contains { $0.evidence == .bundle } }
}

/// Only ever moves to the Trash — `trashItem`, or Finder's own move for a bundle — never deletes.
enum UninstallRunner {
    static func moveToTrash(_ candidates: [UninstallCandidate]) async -> UninstallReport {
        // A locked candidate should never have been checked; skip rather than attempt.
        let removable = candidates.filter { !$0.isLocked }
        let bundle = removable.first { $0.evidence == .bundle }
        let leftovers = removable.filter { $0.evidence != .bundle }

        return await Task.detached(priority: .userInitiated) {
            var trashed: [UninstallCandidate] = []
            var failed: [UninstallFailedItem] = []
            // Bundle first: a leftover is only worth removing once the app is really gone.
            if let bundle {
                if let reason = trashBundle(bundle) {
                    failed.append(UninstallFailedItem(name: bundle.name, reason: reason, isBundle: true))
                    return UninstallReport(trashed: [], failed: failed, skippedCount: leftovers.count)
                }
                trashed.append(bundle)
            }
            for candidate in leftovers {
                if let reason = trash(candidate.url) {
                    failed.append(
                        UninstallFailedItem(name: candidate.name, reason: reason, isBundle: false))
                } else {
                    trashed.append(candidate)
                }
            }
            return UninstallReport(trashed: trashed, failed: failed)
        }.value
    }

    /// Finder has App Management and its own password prompt; Minicast never sees the password.
    nonisolated private static func trashBundle(_ bundle: UninstallCandidate) -> UninstallFailureReason? {
        let reason = trash(bundle.url)
        return reason?.isPermission == true ? trashWithFinder(bundle.url) : reason
    }

    nonisolated private static func trash(_ url: URL) -> UninstallFailureReason? {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return nil
        } catch {
            let error = error as NSError
            let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
            let immutable = (try? url.resourceValues(forKeys: [.isUserImmutableKey]))?.isUserImmutable
            return UninstallFailureReason.classify(
                domain: error.domain, code: error.code,
                underlyingPOSIXCode: underlying?.domain == NSPOSIXErrorDomain
                    ? Int32(underlying?.code ?? 0) : nil,
                isUserImmutable: immutable ?? false, message: error.localizedDescription)
        }
    }

    /// Ten minutes, because the user is typing a password; AppleScript's default is two.
    nonisolated private static func trashWithFinder(_ url: URL) -> UninstallFailureReason? {
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
            with timeout of 600 seconds
                tell application "Finder" to delete (POSIX file "\(path)" as alias)
            end timeout
            """
        guard let script = NSAppleScript(source: source) else { return .other("Finder is unavailable.") }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return nil }
        return UninstallFailureReason.classify(
            domain: UninstallFailureReason.appleScriptDomain,
            code: (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0,
            message: (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Finder couldn’t move it.")
    }
}
