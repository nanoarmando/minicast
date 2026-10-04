import AppleArchive
import Foundation
import System

/// Recognises a backup's container and checks it; the format-1 AppleArchive reader lives here.
enum BackupArchive {
    static let fileExtension = "minicast"

    enum ArchiveError: LocalizedError, Equatable {
        case cannotWrite
        case cannotRead

        var errorDescription: String? {
            switch self {
            case .cannotWrite: return "Couldn't write the backup file."
            case .cannotRead: return "This file isn't a Minicast backup, or it's damaged."
            }
        }
    }

    // MARK: - Format 2: ZIP

    /// A local-file header opens every ZIP; anything else is read as a format-1 archive.
    static func isZip(_ file: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) == Data([0x50, 0x4B, 0x03, 0x04])
    }

    /// Checked before anything is extracted: an absolute or `..` entry names a place outside.
    static func isContainedEntry(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~") else { return false }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    /// `zipinfo`'s listing spells each entry's mode `ls`-style, so a link starts with `l`.
    static func listsSymbolicLink(_ listing: String) -> Bool {
        listing.split(separator: "\n").contains { line in
            line.count > 10 && line.first == "l"
                && line.dropFirst().prefix(9).allSatisfy { "rwxsStT-".contains($0) }
        }
    }

    /// Both checks a ZIP must pass before `ditto` may write a single byte of it.
    static func validateZip(entries: [String], listing: String) throws {
        guard entries.allSatisfy(isContainedEntry), !listsSymbolicLink(listing) else {
            throw ArchiveError.cannotRead
        }
    }

    // MARK: - Format 1: AppleArchive

    static func open(file: URL, into directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard
            let source = ArchiveByteStream.fileStream(
                path: FilePath(file.path), mode: .readOnly, options: [], permissions: []),
            let decompressor = ArchiveByteStream.decompressionStream(readingFrom: source)
        else { throw ArchiveError.cannotRead }
        defer {
            try? decompressor.close()
            try? source.close()
        }
        guard let decoder = ArchiveStream.decodeStream(readingFrom: decompressor) else {
            throw ArchiveError.cannotRead
        }
        defer { try? decoder.close() }
        do {
            try ArchiveStream.withExtractStream(
                extractingTo: FilePath(directory.path), selectUsing: containedEntry
            ) { extractor in
                _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            }
        } catch {
            throw ArchiveError.cannotRead
        }
        guard !containsSymbolicLink(directory) else { throw ArchiveError.cannotRead }
    }

    /// A link entry passes the path filter, and reading through one would leave the extract.
    static func containsSymbolicLink(_ directory: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey]
        guard
            let entries = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: Array(keys))
        else { return true }
        for case let url as URL in entries
        where (try? url.resourceValues(forKeys: keys))?.isSymbolicLink == true {
            return true
        }
        return false
    }

    /// Skips any entry naming an absolute path or `..`, so a hostile archive cannot escape.
    private static func containedEntry(
        _ message: ArchiveHeader.EntryMessage, _ path: FilePath,
        _ data: ArchiveHeader.EntryFilterData?
    ) -> ArchiveHeader.EntryMessageStatus {
        guard !path.isAbsolute, !path.components.contains(where: { $0.string == ".." }) else {
            return .skip
        }
        return .ok
    }
}
