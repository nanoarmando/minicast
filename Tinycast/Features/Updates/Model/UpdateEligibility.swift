import Foundation

/// Whether this copy of Minicast may replace itself, decided from facts its caller gathers.
enum UpdateEligibility: Equatable, Sendable {
    case eligible
    case developmentBuild
    case notInApplications
    case readOnlyLocation

    static let releaseBundleIdentifier = "com.minicast.app"

    static func evaluate(
        bundleIdentifier: String?, bundlePath: String, isParentWritable: Bool
    ) -> UpdateEligibility {
        guard bundleIdentifier == releaseBundleIdentifier else { return .developmentBuild }
        if bundlePath.hasPrefix("/Volumes/") || bundlePath.contains("/AppTranslocation/") {
            return .notInApplications
        }
        return isParentWritable ? .eligible : .readOnlyLocation
    }

    var refusal: String? {
        switch self {
        case .eligible:
            nil
        case .developmentBuild:
            "Updates are only available in the release build."
        case .notInApplications:
            "Move Minicast to the Applications folder to update it."
        case .readOnlyLocation:
            "Minicast can't update itself because its folder isn't writable."
        }
    }
}
