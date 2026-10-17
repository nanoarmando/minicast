import Foundation

/// All the classifier may know about one path, injected so it stays pure.
struct PathFacts: Hashable, Sendable {
    let path: String
    var exists = true
    /// Never followed: sizing through one could walk the whole disk.
    var isSymbolicLink = false
    var volumeIsReadOnly = false
    /// `SF_RESTRICTED` / `SF_IMMUTABLE` — SIP.
    var isSystemRestricted = false
    /// `UF_IMMUTABLE` — Finder's "Locked" checkbox, which the user can clear themselves.
    var isUserImmutable = false
    /// Only decides anything under a sticky parent — see `classify`.
    var isOwnedByCurrentUser = true
    var parentIsWritable = true
    /// `S_ISVTX` on the parent: the `/tmp` rule, where only an owner may unlink an item.
    var parentIsSticky = false
    var isDirectory = false
    /// Moving a directory to another parent rewrites its `..`, so its own write bit matters too.
    var isWritable = true
}

/// Process-wide facts, probed once per scan rather than once per candidate.
struct UninstallEnvironment: Hashable, Sendable {
    let home: String
    let hasFullDiskAccess: Bool
}

/// Why a candidate can or can't be trashed. Advisory: TCC is evaluated at the syscall.
enum UninstallProtection: String, Hashable, Sendable, CaseIterable {
    case removable
    case systemProtected
    case userLocked
    case notOwned
    case needsFullDiskAccess
    case parentNotWritable
    case notWritable
    /// The app bundle only: Finder moves it after its own administrator prompt.
    case needsAdministrator
    case missing

    var isRemovable: Bool { self == .removable || self == .needsAdministrator }

    var note: String? { self == .needsAdministrator ? "asks for your administrator password" : nil }

    /// Nil exactly when removable; the row's lock icon keys off it.
    var lockReason: String? {
        switch self {
        case .removable, .needsAdministrator:
            return nil
        case .systemProtected:
            return "Part of macOS and protected by the system."
        case .userLocked:
            return "Locked in Finder. Unlock it in Get Info, then try again."
        case .notOwned:
            return "Owned by another user, in a folder that only lets owners remove things."
        case .needsFullDiskAccess:
            return "Needs Full Disk Access, which Minicast doesn’t request. "
                + "Grant it in System Settings › Privacy & Security to include this item."
        case .parentNotWritable:
            return "Its enclosing folder isn’t writable by you, and Minicast never asks for an "
                + "administrator password."
        case .notWritable:
            return "A folder you can’t write to, so it can’t move without an administrator "
                + "password, which Minicast only asks Finder for on the app itself."
        case .missing:
            return "No longer on disk."
        }
    }
}

enum UninstallProtectionRules {
    /// Precedence is asserted; a SIP file is also root-owned, and "part of macOS" reads best.
    static func classify(
        _ facts: PathFacts, isBundle: Bool = false, environment: UninstallEnvironment
    ) -> UninstallProtection {
        guard facts.exists else { return .missing }
        if facts.isSystemRestricted || facts.volumeIsReadOnly { return .systemProtected }
        if facts.isUserImmutable { return .userLocked }
        if !environment.hasFullDiskAccess,
            isTCCProtected(path: facts.path, home: environment.home)
        {
            return .needsFullDiskAccess
        }
        let permission = permissionLock(facts)
        // Only the bundle falls back to Finder, whose own prompt can lift a permission lock.
        if isBundle, permission != nil { return .needsAdministrator }
        return permission ?? .removable
    }

    private static func permissionLock(_ facts: PathFacts) -> UninstallProtection? {
        // Trashing renames out of the parent, so its write bit decides, not the item's owner.
        if !facts.parentIsWritable { return .parentNotWritable }
        // The one case where ownership does decide: a sticky parent lets only an owner unlink.
        if facts.parentIsSticky, !facts.isOwnedByCurrentUser { return .notOwned }
        if facts.isDirectory, !facts.isSymbolicLink, !facts.isWritable { return .notWritable }
        return nil
    }

    /// Wider than the current roots, so adding one can't silently attempt a denied read.
    static func isTCCProtected(path: String, home: String) -> Bool {
        let relative = tccRelativePrefixes.contains { path.hasPrefix(home + "/" + $0) }
        return relative || path.hasPrefix("/Library/Application Support/com.apple.TCC")
    }

    /// Measured, never assumed: listing is not the test. See docs/features/uninstall.md.
    static let tccRelativePrefixes: [String] = [
        "Library/Containers/",
        "Library/Group Containers/",
        "Library/Cookies/",
        "Library/Safari",
        "Library/Mail",
        "Library/Messages",
        "Library/Calendars",
        "Library/Suggestions",
        "Library/HomeKit",
        "Library/IdentityServices",
        "Library/Sharing",
        "Library/Biome",
        "Library/Trial",
        "Library/Metadata/CoreSpotlight",
        "Library/Application Support/AddressBook",
        "Library/Application Support/CallHistoryDB",
        "Library/Application Support/com.apple.TCC",
        "Library/Application Support/MobileSync"
    ]
}

/// Why a move failed, read from the error's codes rather than its localized text.
enum UninstallFailureReason: Hashable, Sendable {
    case noPermission
    case inUse
    case locked
    case notFound
    case automationDenied
    case cancelled
    case other(String)

    static let cocoaDomain = "NSCocoaErrorDomain"
    static let posixDomain = "NSPOSIXErrorDomain"
    static let appleScriptDomain = "NSAppleScriptErrorDomain"

    /// `isUserImmutable` is probed after the failure: `UF_IMMUTABLE` surfaces as a plain `EPERM`.
    static func classify(
        domain: String, code: Int, underlyingPOSIXCode: Int32? = nil,
        isUserImmutable: Bool = false, message: String
    ) -> UninstallFailureReason {
        if isUserImmutable { return .locked }
        switch (domain, code) {
        case (appleScriptDomain, -1743): return .automationDenied
        case (appleScriptDomain, -128): return .cancelled
        case (appleScriptDomain, -5000), (appleScriptDomain, -10004): return .noPermission
        case (appleScriptDomain, -47): return .inUse
        case (appleScriptDomain, -43): return .notFound
        case (cocoaDomain, 4), (cocoaDomain, 260): return .notFound
        case (cocoaDomain, 255): return .inUse
        case (posixDomain, _): return posix(Int32(code)) ?? .other(message)
        default: break
        }
        if let underlying = underlyingPOSIXCode, let reason = posix(underlying) { return reason }
        if domain == cocoaDomain, code == 257 || code == 513 { return .noPermission }
        return .other(message)
    }

    private static func posix(_ code: Int32) -> UninstallFailureReason? {
        switch code {
        case EACCES, EPERM: return .noPermission
        case EBUSY, ETXTBSY: return .inUse
        case ENOENT: return .notFound
        default: return nil
        }
    }

    var isPermission: Bool { self == .noPermission }

    /// Full Disk Access is only worth naming for a leftover; Finder already tried the bundle.
    func explanation(isBundle: Bool) -> String {
        switch self {
        case .noPermission:
            return isBundle
                ? "macOS refused to move it, even with an administrator password."
                : "You don’t have permission to move it. Granting Minicast Full Disk Access in "
                    + "System Settings › Privacy & Security may help."
        case .inUse:
            return "It’s in use by another process. Quit whatever is using it, then try again."
        case .locked:
            return "It’s locked in Finder. Unlock it in Get Info, then try again."
        case .notFound:
            return "It’s no longer on disk."
        case .automationDenied:
            return "Minicast isn’t allowed to control Finder, which asks for your administrator "
                + "password."
        case .cancelled:
            return "The administrator password prompt was cancelled."
        case .other(let message):
            return message
        }
    }
}
