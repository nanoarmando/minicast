import Foundation
import Security

enum UpdateInstallerError: LocalizedError {
    case mountFailed(String)
    case missingApp
    case notSignedLikeThisCopy
    case wrongVersion(expected: AppVersion, found: String?)
    case stagingFailed(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .mountFailed(let detail):
            "The disk image could not be opened: \(detail)"
        case .missingApp:
            "The disk image does not contain Minicast.app."
        case .notSignedLikeThisCopy:
            "The download is not signed like this copy of Minicast, so it was not installed."
        case .wrongVersion(let expected, let found):
            "The download is version \(found ?? "unknown"), not the announced \(expected)."
        case .stagingFailed(let detail):
            "The new version could not be prepared: \(detail)"
        case .launchFailed(let detail):
            "The installer could not start: \(detail)"
        }
    }
}

/// Turns a downloaded disk image into a verified app outside any mounted volume, then swaps it in.
enum UpdateInstaller {
    static let appName = "Minicast.app"

    private static let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")
    private static let ditto = URL(fileURLWithPath: "/usr/bin/ditto")

    static func stagedApp(in workspace: URL) -> URL {
        workspace.appendingPathComponent("staged", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    /// The restored app reads this after a failed swap; the script writes it.
    static func failureReport(in workspace: URL) -> URL {
        workspace.appendingPathComponent("failure.txt")
    }

    /// Always deletes the disk image; returns the staged app only when both checks passed.
    static func stage(
        diskImage: URL, version: AppVersion, workspace: URL
    ) async throws -> URL {
        defer { try? FileManager.default.removeItem(at: diskImage) }
        let requirement = try runningRequirement()
        let staged = stagedApp(in: workspace)
        try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())

        let mountPoint = try await attach(diskImage, under: workspace)
        do {
            let mounted = mountPoint.appendingPathComponent(appName, isDirectory: true)
            guard FileManager.default.fileExists(atPath: mounted.path) else {
                throw UpdateInstallerError.missingApp
            }
            try verify(mounted, requirement: requirement, version: version)
            try FileManager.default.createDirectory(
                at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
            let copy = try await ToolRunner.run(
                ditto, ["--noextattr", "--noqtn", mounted.path, staged.path])
            guard copy.succeeded else { throw UpdateInstallerError.stagingFailed(copy.tail) }
        } catch {
            await detach(mountPoint)
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            throw error
        }
        await detach(mountPoint)
        do {
            try verify(staged, requirement: requirement, version: version)
        } catch {
            try? FileManager.default.removeItem(at: staged.deletingLastPathComponent())
            throw error
        }
        return staged
    }

    /// Started before quitting; `/bin/sh` is reparented to launchd and outlives Minicast.
    static func launchSwap(staged: URL, target: URL, report: URL, waitingFor pid: Int32) throws {
        let previous = target.deletingLastPathComponent()
            .appendingPathComponent(".Minicast-previous.app", isDirectory: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            swapScript(
                pid: pid, staged: staged.path, target: target.path, previous: previous.path,
                report: report.path)
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UpdateInstallerError.launchFailed(error.localizedDescription)
        }
    }

    static func swapScript(
        pid: Int32, staged: String, target: String, previous: String, report: String
    ) -> String {
        """
        pid=\(pid)
        staged=\(shellQuoted(staged))
        target=\(shellQuoted(target))
        previous=\(shellQuoted(previous))
        report=\(shellQuoted(report))
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        rm -rf "$previous"
        if mv "$target" "$previous" 2>/dev/null; then
            if mv "$staged" "$target" 2>/dev/null; then
                xattr -dr com.apple.quarantine "$target" 2>/dev/null
                open "$target"
                rm -rf "$previous" "$(dirname "$staged")"
                exit 0
            fi
            mv "$previous" "$target"
        fi
        echo "Minicast could not replace its app at $target." > "$report"
        rm -rf "$(dirname "$staged")"
        open "$target"
        """
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Disk image

    private static func attach(_ diskImage: URL, under workspace: URL) async throws -> URL {
        let mounts = workspace.appendingPathComponent("mounts", isDirectory: true)
        try FileManager.default.createDirectory(at: mounts, withIntermediateDirectories: true)
        let result = try await ToolRunner.run(
            hdiutil,
            [
                "attach", "-nobrowse", "-readonly", "-noautoopen", "-mountrandom", mounts.path,
                "-plist", diskImage.path
            ])
        guard result.succeeded else { throw UpdateInstallerError.mountFailed(result.tail) }
        guard let mountPoint = mountPoint(fromPlist: result.output) else {
            throw UpdateInstallerError.mountFailed("hdiutil reported no mount point.")
        }
        return URL(fileURLWithPath: mountPoint, isDirectory: true)
    }

    private static func mountPoint(fromPlist output: String) -> String? {
        // hdiutil may print notices before the plist, so parse from its opening tag.
        guard let start = output.range(of: "<?xml"),
            let data = String(output[start.lowerBound...]).data(using: .utf8),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else { return nil }
        return entities.lazy.compactMap { $0["mount-point"] as? String }.first
    }

    private static func detach(_ mountPoint: URL) async {
        _ = try? await ToolRunner.run(hdiutil, ["detach", mountPoint.path, "-force"])
    }

    // MARK: - Signature

    private static func runningRequirement() throws -> SecRequirement {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
            SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess,
            let requirement
        else { throw UpdateInstallerError.notSignedLikeThisCopy }
        return requirement
    }

    private static func verify(
        _ app: URL, requirement: SecRequirement, version: AppVersion
    ) throws {
        var staticCode: SecStaticCode?
        let flags = SecCSFlags(
            rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode,
            SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
        else { throw UpdateInstallerError.notSignedLikeThisCopy }

        let infoPlist = app.appendingPathComponent("Contents/Info.plist")
        let declared = (try? Data(contentsOf: infoPlist))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) }
            .flatMap { ($0 as? [String: Any])?["CFBundleShortVersionString"] as? String }
        guard declared.flatMap(AppVersion.init) == version else {
            throw UpdateInstallerError.wrongVersion(expected: version, found: declared)
        }
    }
}
