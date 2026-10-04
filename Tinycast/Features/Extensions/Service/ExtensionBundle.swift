import Foundation

/// The installed set as a backup carries it. Backup only moves the folder; this reads inside it.
enum ExtensionBundle {
    /// One `index.json` row; its folder is `ExtensionCatalog.safeName(name)`.
    struct Entry: Codable, Sendable {
        var name: String
        /// Present only for a store install, so update checks pick it up again after a restore.
        var storeVersion: StoreVersion?
        var appearance: ExtensionAppearance?
    }

    struct StoreVersion: Codable, Sendable {
        var commitSHA: String?
    }

    /// What `ExtensionManager` reads on the main actor; `write` copies the files off it.
    struct Snapshot: Sendable {
        struct Item: Sendable {
            var entry: Entry
            var directory: URL
            var supportDirectory: URL
            var data: Data?
            var commands: Data?
        }

        var items: [Item]
    }

    enum BundleError: LocalizedError {
        case unreadable
        case unsafeName(String)

        var errorDescription: String? {
            switch self {
            case .unreadable: return "The backup's extension list is damaged."
            case .unsafeName(let name): return "The backup names an invalid extension: \(name)."
            }
        }
    }

    // MARK: - Layout

    static func indexURL(in root: URL) -> URL { root.appendingPathComponent("index.json") }

    static func folder(_ name: String, in root: URL) -> URL {
        root.appendingPathComponent(ExtensionCatalog.safeName(name), isDirectory: true)
    }

    static func packageURL(_ name: String, in root: URL) -> URL {
        folder(name, in: root).appendingPathComponent("package", isDirectory: true)
    }

    static func dataURL(_ name: String, in root: URL) -> URL {
        folder(name, in: root).appendingPathComponent("data.json")
    }

    static func commandsURL(_ name: String, in root: URL) -> URL {
        folder(name, in: root).appendingPathComponent("commands.json")
    }

    static func supportURL(_ name: String, in root: URL) -> URL {
        folder(name, in: root).appendingPathComponent("support", isDirectory: true)
    }

    // MARK: - Writing and reading

    /// Copies each extension's folder, data and support files; returns how many it wrote.
    static func write(_ snapshot: Snapshot, into root: URL) throws -> Int {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for item in snapshot.items {
            let name = item.entry.name
            try fm.createDirectory(at: folder(name, in: root), withIntermediateDirectories: true)
            try copyResolvingLinks(item.directory, to: packageURL(name, in: root))
            if let data = item.data { try data.write(to: dataURL(name, in: root)) }
            if let commands = item.commands { try commands.write(to: commandsURL(name, in: root)) }
            if fm.fileExists(atPath: item.supportDirectory.path) {
                try copyResolvingLinks(item.supportDirectory, to: supportURL(name, in: root))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot.items.map(\.entry)).write(to: indexURL(in: root))
        return snapshot.items.count
    }

    /// An import refuses any link, so a link to a file travels as the file and any other is dropped.
    static func copyResolvingLinks(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isDirectoryKey]
        for entry in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: keys) {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            let values = try entry.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                let resolved = entry.resolvingSymlinksInPath()
                let resolvedValues = try? resolved.resourceValues(forKeys: [.isRegularFileKey])
                guard resolvedValues?.isRegularFile == true else { continue }
                try fm.copyItem(at: resolved, to: target)
            } else if values.isDirectory == true {
                try copyResolvingLinks(entry, to: target)
            } else {
                try fm.copyItem(at: entry, to: target)
            }
        }
    }

    /// Run before any data changes: a name that is not one safe folder rejects the whole bundle.
    static func entries(in root: URL) throws -> [Entry] {
        guard let data = try? Data(contentsOf: indexURL(in: root)),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { throw BundleError.unreadable }
        var folders = Set<String>()
        for entry in entries {
            let folder = ExtensionCatalog.safeName(entry.name)
            guard isSafeFolder(folder), folders.insert(folder).inserted else {
                throw BundleError.unsafeName(entry.name)
            }
        }
        return entries
    }

    private static func isSafeFolder(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".."
            && name.rangeOfCharacter(from: CharacterSet(charactersIn: "/:\\\0")) == nil
    }
}
