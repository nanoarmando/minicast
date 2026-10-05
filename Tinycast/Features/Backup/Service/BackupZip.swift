import Foundation
import os

/// The format-2 container, through the system's own `ditto` and `zipinfo`, as extension installs do.
enum BackupZip {
    private static let logger = Logger(subsystem: "com.tinycast", category: "Backup")

    /// No resource forks, extended attributes or ACLs: a bundle carries file contents only.
    nonisolated static func compress(_ directory: URL, into file: URL) throws {
        try run(
            "/usr/bin/ditto",
            ["-c", "-k", "--norsrc", "--noextattr", "--noacl", directory.path, file.path],
            failure: .cannotWrite)
    }

    /// Lists and checks every entry first, so a hostile archive is refused before it is written.
    nonisolated static func extract(_ file: URL, into directory: URL) throws {
        // The open panel's grant covers this process only, never a tool it launches.
        let local = directory.deletingLastPathComponent().appendingPathComponent("incoming.zip")
        do {
            try FileManager.default.copyItem(at: file, to: local)
        } catch {
            logger.error("Couldn't copy the backup into staging: \(error.localizedDescription)")
            throw BackupArchive.ArchiveError.cannotRead
        }
        defer { try? FileManager.default.removeItem(at: local) }
        let entries = try run("/usr/bin/zipinfo", ["-1", local.path])
        let listing = try run("/usr/bin/zipinfo", ["-s", local.path])
        try BackupArchive.validateZip(
            entries: entries.split(separator: "\n").map(String.init), listing: listing)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", "--norsrc", local.path, directory.path])
        guard !BackupArchive.containsSymbolicLink(directory) else {
            throw BackupArchive.ArchiveError.cannotRead
        }
    }

    @discardableResult
    private nonisolated static func run(
        _ tool: String, _ arguments: [String],
        failure: BackupArchive.ArchiveError = .cannotRead
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Read before waiting: a listing larger than the pipe buffer would otherwise deadlock.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // A listing that is not UTF-8 is refused, never validated as empty.
        guard process.terminationStatus == 0, let text = String(bytes: data, encoding: .utf8) else {
            logger.error("\(tool) exited with status \(process.terminationStatus)")
            throw failure
        }
        return text
    }
}
