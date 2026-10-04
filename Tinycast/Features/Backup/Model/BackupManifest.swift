import Foundation

/// The bundle's table of contents: what a reader must agree with before it touches anything else.
struct BackupManifest: Codable, Sendable, Equatable {
    /// The ZIP bundle this build writes. Not a migration point — see docs/features/backup.md.
    static let currentFormat = 2
    /// The AppleArchive file older builds and the official Tinycast wrote; read, never written.
    static let legacyFormat = 1

    var format = Self.currentFormat
    /// Carried so a person reading a report can place the file; never branched on.
    var appVersion: String
    var createdAt: Date
    /// Keyed by `BackupCategory.rawValue`; a missing key is how the picker greys a row out.
    var counts: [String: Int]

    var categories: Set<BackupCategory> {
        Set(BackupCategory.allCases.filter { counts[$0.rawValue] != nil })
    }

    func count(_ category: BackupCategory) -> Int { counts[category.rawValue] ?? 0 }
}

enum BackupFormatError: LocalizedError, Equatable {
    case unreadable
    case unsupportedFormat(found: Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "This file isn't a Minicast backup, or it's damaged."
        case .unsupportedFormat(let found) where found > BackupManifest.currentFormat:
            return
                "This backup was made by a newer Minicast (format \(found)). Update Minicast on "
                + "this Mac, then import it again."
        case .unsupportedFormat(let found):
            return
                "This backup was made by a different version of Minicast (format \(found), "
                + "expected \(BackupManifest.currentFormat)). Export again from the Mac that has "
                + "your setup."
        }
    }
}
