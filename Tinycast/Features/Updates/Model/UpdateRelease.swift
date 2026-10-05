import Foundation

/// The fields Minicast reads from GitHub's "latest release" answer.
struct UpdateRelease: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        let name: String
        let downloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    static let tagPrefix = "minicast-v"

    let tag: String
    let notes: String
    let pageURL: URL
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case notes = "body"
        case pageURL = "html_url"
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tag = try container.decode(String.self, forKey: .tag)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        pageURL = try container.decode(URL.self, forKey: .pageURL)
        assets = try container.decodeIfPresent([Asset].self, forKey: .assets) ?? []
    }

    var version: AppVersion? {
        guard tag.hasPrefix(Self.tagPrefix) else { return nil }
        return AppVersion(String(tag.dropFirst(Self.tagPrefix.count)))
    }

    /// Only the DMG named after the tag's own version; any other asset is not a Minicast build.
    var diskImage: Asset? {
        guard let version else { return nil }
        return assets.first { $0.name == "Minicast-\(version).dmg" }
    }

    func outcome(comparedTo current: AppVersion) -> UpdateCheckOutcome {
        guard let version, let diskImage else { return .unusable }
        guard version > current else { return .upToDate }
        return .available(
            AvailableUpdate(
                version: version, notes: notes, pageURL: pageURL, downloadURL: diskImage.downloadURL))
    }
}

struct AvailableUpdate: Equatable, Sendable {
    let version: AppVersion
    let notes: String
    let pageURL: URL
    let downloadURL: URL
}

enum UpdateCheckOutcome: Equatable, Sendable {
    case available(AvailableUpdate)
    case upToDate
    case unusable
}
