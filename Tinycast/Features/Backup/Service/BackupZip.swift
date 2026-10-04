import Foundation

/// The format-2 container, through the system's own `ditto` and `zipinfo`, as extension installs do.
enum BackupZip {
    /// No resource forks, extended attributes or ACLs: a bundle carries file contents only.
    nonisolated static func compress(_ directory: URL, into file: URL) throws {
        try run(
            "/usr/bin/ditto",
            ["-c", "-k", "--norsrc", "--noextattr", "--noacl", directory.path, file.path],
            failure: .cannotWrite)
    }

    /// Lists and checks every entry first, so a hostile archive is refused before it is written.
    nonisolated static func extract(_ file: URL, into directory: URL) throws {
        let entries = try run("/usr/bin/zipinfo", ["-1", file.path])
        let listing = try run("/usr/bin/zipinfo", ["-s", file.path])
        try BackupArchive.validateZip(
            entries: entries.split(separator: "\n").map(String.init), listing: listing)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", "--norsrc", file.path, directory.path])
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
        guard process.terminationStatus == 0 else { throw failure }
        return String(decoding: data, as: UTF8.self)
    }
}
