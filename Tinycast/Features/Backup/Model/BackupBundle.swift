import Foundation

/// The payload a backup carries; pure, so the harness drives the real layout.
struct BackupBundle: Sendable {
    enum LearningPart: String, CaseIterable, Sendable {
        case ranking
        case emoji
        case calculator
    }

    let root: URL
    /// The manifest format this tree is laid out for; format 1 kept settings at the root.
    let format: Int

    init(root: URL, format: Int = BackupManifest.currentFormat) {
        self.root = root
        self.format = format
    }

    // MARK: - Layout

    var manifestURL: URL { root.appendingPathComponent("manifest.json") }

    func directory(for category: BackupCategory) -> URL {
        if category == .configuration, format == BackupManifest.legacyFormat { return root }
        return root.appendingPathComponent(category.descriptor.subpath, isDirectory: true)
    }

    var settingsURL: URL { directory(for: .configuration).appendingPathComponent("settings.json") }
    var quickActionsURL: URL {
        directory(for: .configuration).appendingPathComponent("quick-actions.json")
    }
    var extensionsDirectory: URL { directory(for: .extensions) }
    var aiURL: URL { directory(for: .aiAndMCP).appendingPathComponent("ai.json") }
    var mcpURL: URL { directory(for: .aiAndMCP).appendingPathComponent("mcp.json") }
    var chatDatabaseURL: URL {
        directory(for: .chatHistory).appendingPathComponent("ai-chats.sqlite3")
    }

    var clipboardItemsURL: URL { directory(for: .clipboard).appendingPathComponent("items.jsonl") }
    var clipboardImagesDirectory: URL {
        directory(for: .clipboard).appendingPathComponent("images", isDirectory: true)
    }

    func learningURL(_ part: LearningPart) -> URL {
        directory(for: .learning).appendingPathComponent("\(part.rawValue).json")
    }

    // MARK: - Writing

    /// Called once before composing; the archive carries no directory a category didn't ask for.
    func prepare(_ categories: Set<BackupCategory>) throws {
        try create(root)
        for category in categories { try create(directory(for: category)) }
        if categories.contains(.clipboard) { try create(clipboardImagesDirectory) }
    }

    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func writeManifest(_ manifest: BackupManifest) throws {
        try write(try Self.encoder.encode(manifest), to: manifestURL)
    }

    func encode<Value: Encodable>(_ value: Value, to url: URL) throws {
        try write(try Self.encoder.encode(value), to: url)
    }

    // MARK: - Clipboard, a line at a time

    /// One clip per line; a newline inside a clip is escaped, so `\n` only ever separates.
    struct ClipboardWriter: ~Copyable {
        private let handle: FileHandle
        /// Compact, not pretty-printed: a pretty object spans lines and breaks the separator.
        private let encoder: JSONEncoder

        init(url: URL) throws {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try FileHandle(forWritingTo: url)
            encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
        }

        func write(_ item: BackupClipboardItem) throws {
            var line = try encoder.encode(item)
            line.append(0x0A)
            try handle.write(contentsOf: line)
        }

        deinit { try? handle.close() }
    }

    func clipboardWriter() throws -> ClipboardWriter {
        try ClipboardWriter(url: clipboardItemsURL)
    }

    /// Mapped and decoded lazily, so a gigabyte of history costs one clip of resident memory.
    func clipboardItems() -> some Sequence<BackupClipboardItem> {
        let data = (try? Data(contentsOf: clipboardItemsURL, options: .mappedIfSafe)) ?? Data()
        return data.split(separator: 0x0A, omittingEmptySubsequences: true)
            .lazy
            .compactMap { try? Self.decoder.decode(BackupClipboardItem.self, from: Data($0)) }
    }

    // MARK: - Reading

    func readManifest() throws(BackupFormatError) -> BackupManifest {
        guard let data = try? Data(contentsOf: manifestURL),
            let manifest = try? Self.decoder.decode(BackupManifest.self, from: data)
        else { throw .unreadable }
        guard manifest.format == format else {
            throw .unsupportedFormat(found: manifest.format)
        }
        return manifest
    }

    /// nil rather than a throw: a clip whose image the archive lost is skipped and counted.
    func clipboardImageURL(named name: String) -> URL? {
        guard Self.isSafeName(name) else { return nil }
        let url = clipboardImagesDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func decodeLearning<Value: Decodable>(_ part: LearningPart, as type: Value.Type) -> Value? {
        decode(Value.self, at: learningURL(part))
    }

    func decode<Value: Decodable>(_ type: Value.Type, at url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(Value.self, from: data)
    }

    // MARK: - Coding

    /// ISO-8601 dates, so a backup stays readable by eye and by anything but this decoder.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Names

    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".."
            && name.rangeOfCharacter(from: Self.forbidden) == nil
    }

    private static let forbidden = CharacterSet(charactersIn: "/:\\\0")

    private func create(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
