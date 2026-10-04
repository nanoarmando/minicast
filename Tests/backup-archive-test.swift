import AppleArchive
import Foundation
import System

/// Compiles the shipped bundle, ZIP and archive layers, so a backup can't quietly change shape.
@main
@MainActor
struct BackupArchiveTest {
    static var failures = 0

    static func check(_ description: String, _ condition: @autoclosure () -> Bool) {
        if condition() {
            print("PASS  \(description)")
        } else {
            print("FAIL  \(description)")
            failures += 1
        }
    }

    /// UUID-suffixed, per docs/testing.md: harnesses run in parallel against the real system.
    static func scratch() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-archive-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func main() {
        let root = scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        roundTrip(in: root)
        legacyRoundTrip(in: root)
        clipboardLines(in: root)
        noAbsolutePathsEscape(in: root)
        noSecretsTravel(in: root)
        formatGuard(in: root)
        rejectsGarbage(in: root)
        refusesTraversal(in: root)
        refusesSymbolicLinks(in: root)
        refusesHostileZips(in: root)
        refusesUnsafeExtensionNames(in: root)
        categoriesAreComplete()
        staging()

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Round trip

    /// Format 2: a real ZIP, through the same `ditto` and `zipinfo` calls an import makes.
    static func roundTrip(in root: URL) {
        let source = root.appendingPathComponent("seal")
        let bundle = BackupBundle(root: source)
        try? bundle.prepare(BackupCategory.all)

        // A binary blob, so a wrong mode or a text-only path shows up as corruption.
        let png = Data((0..<200_000).map { UInt8($0 % 251) })
        try? bundle.write(png, to: bundle.clipboardImagesDirectory.appendingPathComponent("a.png"))
        try? bundle.write(Data("héllo\nwörld".utf8), to: bundle.learningURL(.ranking))
        try? bundle.write(Data(), to: bundle.learningURL(.emoji))
        try? bundle.write(Data("{}".utf8), to: bundle.settingsURL)

        let installed = root.appendingPathComponent("installed/demo")
        let support = root.appendingPathComponent("support/demo")
        try? FileManager.default.createDirectory(
            at: installed.appendingPathComponent("assets"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? Data("{\"name\":\"demo\"}".utf8).write(
            to: installed.appendingPathComponent("package.json"))
        try? Data("module.exports = 1".utf8).write(to: installed.appendingPathComponent("main.js"))
        try? Data("cache".utf8).write(to: support.appendingPathComponent("state.txt"))
        // A file link, a directory link and a dangling link: none may make the bundle unimportable.
        let fm = FileManager.default
        try? fm.createSymbolicLink(
            at: installed.appendingPathComponent("assets/linked.js"),
            withDestinationURL: installed.appendingPathComponent("main.js"))
        try? fm.createSymbolicLink(
            at: installed.appendingPathComponent("assets/loop"), withDestinationURL: installed)
        try? fm.createSymbolicLink(
            at: support.appendingPathComponent("gone"),
            withDestinationURL: support.appendingPathComponent("missing"))
        let snapshot = ExtensionBundle.Snapshot(items: [
            .init(
                entry: .init(
                    name: "@owner/demo", storeVersion: .init(commitSHA: "abc"),
                    appearance: .init(symbol: "star", tint: .blue)),
                directory: installed, supportDirectory: support,
                data: Data("{\"preferences\":{\"token\":{\"string\":{\"_0\":\"p\"}}}}".utf8),
                commands: Data("{}".utf8))
        ])
        let extensionCount = try? ExtensionBundle.write(snapshot, into: bundle.extensionsDirectory)
        check("the extension writer counts what it wrote", extensionCount == 1)

        let manifest = BackupManifest(
            appVersion: "1.2.3", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            counts: ["configuration": 1, "extensions": 1, "clipboard": 1, "learning": 2])
        try? bundle.writeManifest(manifest)

        let archive = root.appendingPathComponent("out.minicast")
        let opened = root.appendingPathComponent("open")
        do {
            try BackupZip.compress(source, into: archive)
            try BackupZip.extract(archive, into: opened)
        } catch {
            check("compress and extract succeed (\(error))", false)
            return
        }
        check("the file is a ZIP", BackupArchive.isZip(archive))
        check(
            "the manifest sits at the archive's root",
            FileManager.default.fileExists(atPath: opened.appendingPathComponent("manifest.json").path))

        let reopened = BackupBundle(root: opened)
        check(
            "a binary blob survives the round trip",
            (try? Data(
                contentsOf: reopened.clipboardImagesDirectory.appendingPathComponent("a.png")))
                == png)
        check(
            "non-ASCII text survives",
            (try? Data(contentsOf: reopened.learningURL(.ranking))) == Data("héllo\nwörld".utf8))
        check(
            "a zero-byte file survives",
            (try? Data(contentsOf: reopened.learningURL(.emoji))) == Data())
        check(
            "settings live in their own folder",
            reopened.settingsURL.path.hasSuffix("settings/settings.json")
                && FileManager.default.fileExists(atPath: reopened.settingsURL.path))
        let decoded = try? reopened.readManifest()
        check("the manifest round trips", decoded == manifest)
        check(
            "an absent category reads as absent",
            decoded?.categories == [.configuration, .extensions, .clipboard, .learning])
        check("a present category keeps its count", decoded?.count(.clipboard) == 1)
        check("an absent category counts zero", decoded?.count(.chatHistory) == 0)

        let entries = try? ExtensionBundle.entries(in: reopened.extensionsDirectory)
        check("the extension index round trips", entries?.map(\.name) == ["@owner/demo"])
        check("the store version travels", entries?.first?.storeVersion?.commitSHA == "abc")
        check(
            "the extension's own files travel",
            FileManager.default.fileExists(
                atPath: ExtensionBundle.packageURL("@owner/demo", in: reopened.extensionsDirectory)
                    .appendingPathComponent("main.js").path))
        let assets = ExtensionBundle.packageURL("@owner/demo", in: reopened.extensionsDirectory)
            .appendingPathComponent("assets")
        check(
            "a linked file travels as a regular file",
            (try? Data(contentsOf: assets.appendingPathComponent("linked.js")))
                == Data("module.exports = 1".utf8)
                && (try? fm.destinationOfSymbolicLink(
                    atPath: assets.appendingPathComponent("linked.js").path)) == nil)
        check(
            "a directory link and a dangling link are dropped",
            !fm.fileExists(atPath: assets.appendingPathComponent("loop").path)
                && !fm.fileExists(
                    atPath: ExtensionBundle.supportURL("@owner/demo", in: reopened.extensionsDirectory)
                        .appendingPathComponent("gone").path))
        check(
            "the extension's support folder travels",
            FileManager.default.fileExists(
                atPath: ExtensionBundle.supportURL("@owner/demo", in: reopened.extensionsDirectory)
                    .appendingPathComponent("state.txt").path))
        check(
            "the extension's data travels, password values included",
            (try? Data(
                contentsOf: ExtensionBundle.dataURL("@owner/demo", in: reopened.extensionsDirectory)))
                .map { String(decoding: $0, as: UTF8.self).contains("token") } == true)

        let attributes = try? FileManager.default.attributesOfItem(
            atPath: reopened.clipboardImagesDirectory.appendingPathComponent("a.png").path)
        check(
            "the extracted file is owned by the current user",
            (attributes?[.ownerAccountID] as? NSNumber)?.uint32Value == getuid())
    }

    /// Format 1 is still read: settings at the root, the AppleArchive container, its own guard.
    static func legacyRoundTrip(in root: URL) {
        let source = root.appendingPathComponent("legacy")
        let bundle = BackupBundle(root: source, format: BackupManifest.legacyFormat)
        try? bundle.prepare([.configuration, .learning])
        try? bundle.write(Data("{}".utf8), to: bundle.settingsURL)
        var manifest = BackupManifest(
            appVersion: "0.9", createdAt: Date(timeIntervalSince1970: 1_600_000_000),
            counts: ["configuration": 1])
        manifest.format = BackupManifest.legacyFormat
        try? bundle.writeManifest(manifest)

        let archive = root.appendingPathComponent("old.tinycast")
        let opened = root.appendingPathComponent("legacy-open")
        do {
            try sealLegacy(directory: source, into: archive)
            try BackupArchive.open(file: archive, into: opened)
        } catch {
            check("a format-1 file still opens (\(error))", false)
            return
        }
        check("a format-1 file is not mistaken for a ZIP", !BackupArchive.isZip(archive))
        let reopened = BackupBundle(root: opened, format: BackupManifest.legacyFormat)
        check("format 1 keeps settings at the root", reopened.settingsURL.deletingLastPathComponent()
            .standardizedFileURL == opened.standardizedFileURL)
        check("a format-1 manifest reads under its own format", (try? reopened.readManifest()) == manifest)
        do {
            _ = try BackupBundle(root: opened).readManifest()
            check("a format-1 manifest is refused as format 2", false)
        } catch {
            check("a format-1 manifest is refused as format 2", error == .unsupportedFormat(found: 1))
        }
    }

    /// The writer format-1 builds used; kept here only to produce fixtures the reader must open.
    static func sealLegacy(directory: URL, into file: URL) throws {
        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,DAT,MOD,MTM"),
            let destination = ArchiveByteStream.fileStream(
                path: FilePath(file.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)),
            let compressor = ArchiveByteStream.compressionStream(
                using: .lzfse, writingTo: destination)
        else { throw BackupArchive.ArchiveError.cannotWrite }
        try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(directory.path), keySet: keySet)
        }
        try compressor.close()
        try destination.close()
    }

    // MARK: - Clipboard

    static func clipboardLines(in root: URL) {
        let bundle = BackupBundle(root: root.appendingPathComponent("clips"))
        try? bundle.prepare([.clipboard])
        let items = [
            BackupClipboardItem(
                kind: .text, text: "one\ntwo\nthree", imageName: nil,
                createdAt: Date(timeIntervalSince1970: 10), sourceBundleID: "com.apple.Safari",
                pinnedAt: nil),
            BackupClipboardItem(
                kind: .text, text: "carriage\r\nreturn", imageName: nil,
                createdAt: Date(timeIntervalSince1970: 20), sourceBundleID: nil,
                pinnedAt: Date(timeIntervalSince1970: 25)),
            BackupClipboardItem(
                kind: .image, text: nil, imageName: "b.png",
                createdAt: Date(timeIntervalSince1970: 30), sourceBundleID: nil, pinnedAt: nil)
        ]
        if let writer = try? bundle.clipboardWriter() {
            for item in items { try? writer.write(item) }
        }

        check("every clip round trips through JSONL", Array(bundle.clipboardItems()) == items)

        // The invariant the line splitting rests on: a newline in a clip is escaped, never raw.
        let raw = (try? Data(contentsOf: bundle.clipboardItemsURL)) ?? Data()
        check(
            "one line per clip, whatever the clip contains",
            raw.split(separator: 0x0A, omittingEmptySubsequences: true).count == items.count)
    }

    /// The analogue of settings-backup-test's privacy checks: this file leaves the Mac.
    static func noAbsolutePathsEscape(in root: URL) {
        let bundle = BackupBundle(root: root.appendingPathComponent("paths"))
        try? bundle.prepare([.clipboard])
        let item = BackupClipboardItem(
            kind: .image, text: nil, imageName: "c.png", createdAt: Date(), sourceBundleID: nil,
            pinnedAt: nil)
        if let writer = try? bundle.clipboardWriter() { try? writer.write(item) }
        let raw = (try? Data(contentsOf: bundle.clipboardItemsURL)) ?? Data()
        let text = String(bytes: raw, encoding: .utf8) ?? ""
        check("no home directory leaks into the file", !text.contains("/Users"))
        check("no image path leaks into the file", !text.contains("/Library"))
    }

    /// Secrets live only in the Keychain; the payloads carry ids and names, never the values.
    static func noSecretsTravel(in root: URL) {
        let marker = "sk-secret-\(UUID().uuidString)"
        // What the Keychain would hold for this connection; nothing in the payload can carry it.
        let keychain = [UUID(): marker]
        let connection = AIConnection(
            id: keychain.keys.first ?? UUID(), name: "OpenAI", provider: .openAI,
            baseURL: "https://api.openai.com/v1", models: ["gpt"])
        let server = MCPServer(
            name: "Files",
            transport: .stdio(command: "npx", arguments: ["server"], environmentKeys: ["TOKEN"]))
        let ai = BackupAIPayload(
            settings: AISettingsSnapshot(
                connections: [connection], defaultModel: nil, webSearchEnabled: false,
                systemPrompt: "", systemPromptEnabled: true, retention: 0, opensTo: 0,
                newChatAfter: 0, toolRounds: 0, shownModels: [:], disabledRoutes: [],
                enabledInstalledProviders: [.claude],
                installedOverrides: ["claude": InstalledAIOverride()]),
            connectionsWithSecrets: [connection.id], installedToolsWithSecrets: [.claude])
        let mcp = BackupMCPPayload(servers: [server], serversWithSecrets: [server.id])

        let bundle = BackupBundle(root: root.appendingPathComponent("secrets"))
        try? bundle.prepare([.aiAndMCP])
        try? bundle.encode(ai, to: bundle.aiURL)
        try? bundle.encode(mcp, to: bundle.mcpURL)
        try? bundle.writeManifest(
            BackupManifest(appVersion: "1", createdAt: Date(), counts: ["aiAndMCP": 2]))
        let archive = root.appendingPathComponent("secrets.minicast")
        let opened = root.appendingPathComponent("secrets-open")
        try? BackupZip.compress(bundle.root, into: archive)
        try? BackupZip.extract(archive, into: opened)

        let text = allText(in: opened)
        check("the AI and MCP parts were written", text.contains("OpenAI") && text.contains("npx"))
        check("no Keychain value appears anywhere in the bundle", !text.contains(marker))
        check("a secret is recorded only as a flag", text.contains(connection.id.uuidString))
        check("no home directory leaks into Minicast-owned parts", !text.contains("/Users"))
        let reread = BackupBundle(root: opened).decode(BackupAIPayload.self, at: BackupBundle(
            root: opened).aiURL)
        check("the AI part round trips", reread?.settings.connections == [connection])
    }

    static func allText(in directory: URL) -> String {
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        var text = ""
        while let url = files?.nextObject() as? URL {
            if let data = try? Data(contentsOf: url) { text += String(decoding: data, as: UTF8.self) }
        }
        return text
    }

    /// Every hostile entry is refused before extraction: nothing lands outside the destination.
    static func refusesHostileZips(in root: URL) {
        let escapeName = "escape-\(UUID().uuidString).txt"
        let absolute = FileManager.default.temporaryDirectory.appendingPathComponent(
            "absolute-\(UUID().uuidString).txt")
        let cases: [(String, [ZipEntry])] = [
            ("a `..` entry", [ZipEntry(name: "../../\(escapeName)", data: Data("x".utf8))]),
            ("an absolute entry", [ZipEntry(name: absolute.path, data: Data("x".utf8))]),
            ("a symbolic link entry", [ZipEntry(name: "link", data: Data(root.path.utf8), link: true)])
        ]
        for (label, entries) in cases {
            let file = root.appendingPathComponent("hostile-\(UUID().uuidString).minicast")
            try? makeZip(entries).write(to: file)
            check("the \(label) fixture reads as a ZIP", BackupArchive.isZip(file))
            let into = root.appendingPathComponent("hostile-out/\(UUID().uuidString)")
            do {
                try BackupZip.extract(file, into: into)
                check("\(label) is refused", false)
            } catch {
                check("\(label) is refused", error as? BackupArchive.ArchiveError == .cannotRead)
            }
            check(
                "\(label) writes nothing",
                !FileManager.default.fileExists(atPath: into.path))
        }
        check(
            "nothing escaped the extraction folder",
            !FileManager.default.fileExists(atPath: root.deletingLastPathComponent()
                .appendingPathComponent(escapeName).path)
                && !FileManager.default.fileExists(atPath: absolute.path))
        check("a plain relative entry is contained", BackupArchive.isContainedEntry("a/b.json"))
        check("a `..` entry is not", !BackupArchive.isContainedEntry("a/../../b"))
        check("an absolute entry is not", !BackupArchive.isContainedEntry("/etc/hosts"))
    }

    static func refusesUnsafeExtensionNames(in root: URL) {
        for name in ["..", "", "."] {
            let directory = root.appendingPathComponent("unsafe-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data("[{\"name\":\"\(name)\"}]".utf8).write(
                to: ExtensionBundle.indexURL(in: directory))
            do {
                _ = try ExtensionBundle.entries(in: directory)
                check("the extension name \"\(name)\" is refused", false)
            } catch {
                check("the extension name \"\(name)\" is refused", true)
            }
        }
    }

    // MARK: - A stored ZIP, by hand: no tool will write the entries these cases need

    struct ZipEntry {
        var name: String
        var data: Data
        var link = false
    }

    static func makeZip(_ entries: [ZipEntry]) -> Data {
        var local = Data()
        var central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let offset = UInt32(local.count)
            local.append(le32(0x0403_4B50))
            local.append(le16(20)); local.append(le16(0)); local.append(le16(0))
            local.append(le16(0)); local.append(le16(0))
            local.append(le32(crc)); local.append(le32(UInt32(entry.data.count)))
            local.append(le32(UInt32(entry.data.count)))
            local.append(le16(UInt16(name.count))); local.append(le16(0))
            local.append(name); local.append(entry.data)

            let mode: UInt32 = entry.link ? 0o120777 : 0o100644
            central.append(le32(0x0201_4B50))
            central.append(le16(0x0314)); central.append(le16(20)); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le16(0))
            central.append(le32(crc)); central.append(le32(UInt32(entry.data.count)))
            central.append(le32(UInt32(entry.data.count)))
            central.append(le16(UInt16(name.count))); central.append(le16(0)); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le32(mode << 16))
            central.append(le32(offset)); central.append(name)
        }
        var zip = local
        zip.append(central)
        zip.append(le32(0x0605_4B50)); zip.append(le16(0)); zip.append(le16(0))
        zip.append(le16(UInt16(entries.count))); zip.append(le16(UInt16(entries.count)))
        zip.append(le32(UInt32(central.count))); zip.append(le32(UInt32(local.count)))
        zip.append(le16(0))
        return zip
    }

    static func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    static func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return ~crc
    }

    // MARK: - Guards

    static func formatGuard(in root: URL) {
        for offset in [-1, 1] {
            let bundle = BackupBundle(root: root.appendingPathComponent("format\(offset)"))
            try? bundle.prepare([])
            var manifest = BackupManifest(appVersion: "1", createdAt: Date(), counts: [:])
            manifest.format = BackupManifest.currentFormat + offset
            try? bundle.writeManifest(manifest)
            do {
                _ = try bundle.readManifest()
                check("a format of \(manifest.format) is refused", false)
            } catch {
                check(
                    "a format of \(manifest.format) is refused by the same error",
                    error == .unsupportedFormat(found: manifest.format))
                check(
                    "the refusal names the format it found",
                    error.errorDescription?.contains("\(manifest.format)") == true)
            }
        }
    }

    static func rejectsGarbage(in root: URL) {
        let file = root.appendingPathComponent("garbage.minicast")
        try? Data("not an archive".utf8).write(to: file)
        let into = root.appendingPathComponent("garbage-out")
        do {
            try BackupArchive.open(file: file, into: into)
            check("a non-archive is refused", false)
        } catch {
            check("a non-archive is refused", true)
        }

        let empty = BackupBundle(root: root.appendingPathComponent("empty"))
        try? empty.prepare([])
        do {
            _ = try empty.readManifest()
            check("a bundle with no manifest is refused", false)
        } catch {
            check("a bundle with no manifest is refused", error == .unreadable)
        }
    }

    /// A hostile archive must not write outside the directory the caller chose.
    static func refusesTraversal(in root: URL) {
        // Header-by-header: `writeDirectoryContents` refuses to emit the `..` path we need here.
        let archive = root.appendingPathComponent("evil.tinycast")
        let payload = Data("escaped".utf8)
        guard
            let destination = ArchiveByteStream.fileStream(
                path: FilePath(archive.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)),
            let compressor = ArchiveByteStream.compressionStream(
                using: .lzfse, writingTo: destination)
        else {
            check("the traversal fixture can be built", false)
            return
        }
        do {
            try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
                let header = ArchiveHeader()
                header.append(
                    .uint(
                        key: ArchiveHeader.FieldKey("TYP"),
                        value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
                header.append(
                    .string(key: ArchiveHeader.FieldKey("PAT"), value: "../escape.txt"))
                header.append(.uint(key: ArchiveHeader.FieldKey("MOD"), value: 0o644))
                header.append(
                    .blob(key: ArchiveHeader.FieldKey("DAT"), size: UInt64(payload.count)))
                try encoder.writeHeader(header)
                try payload.withUnsafeBytes { buffer in
                    try encoder.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: buffer)
                }
            }
            try compressor.close()
            try destination.close()
        } catch {
            check("the traversal fixture can be built (\(error))", false)
            return
        }

        let into = root.appendingPathComponent("evil-out", isDirectory: true)
        try? BackupArchive.open(file: archive, into: into)
        let escaped = root.appendingPathComponent("escape.txt")
        check(
            "an entry naming `..` never lands outside the destination",
            !FileManager.default.fileExists(atPath: escaped.path))
    }

    /// A link entry names no `..` at all, and reading through it would leave the extract.
    static func refusesSymbolicLinks(in root: URL) {
        let archive = root.appendingPathComponent("linked.tinycast")
        guard
            let destination = ArchiveByteStream.fileStream(
                path: FilePath(archive.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)),
            let compressor = ArchiveByteStream.compressionStream(
                using: .lzfse, writingTo: destination)
        else {
            check("the symlink fixture can be built", false)
            return
        }
        do {
            try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
                let header = ArchiveHeader()
                // 76 is `L`; the Swift overlay names no symbolic-link case to spell it with.
                header.append(.uint(key: ArchiveHeader.FieldKey("TYP"), value: 76))
                header.append(.string(key: ArchiveHeader.FieldKey("PAT"), value: "notes"))
                header.append(
                    .string(key: ArchiveHeader.FieldKey("LNK"), value: root.path))
                header.append(.uint(key: ArchiveHeader.FieldKey("MOD"), value: 0o777))
                try encoder.writeHeader(header)
            }
            try compressor.close()
            try destination.close()
        } catch {
            check("the symlink fixture can be built (\(error))", false)
            return
        }

        let into = root.appendingPathComponent("linked-out", isDirectory: true)
        do {
            try BackupArchive.open(file: archive, into: into)
            check("an archive carrying a symlink is refused", false)
        } catch {
            check(
                "an archive carrying a symlink is refused",
                error as? BackupArchive.ArchiveError == .cannotRead)
        }
    }

    // MARK: - Declarations

    /// The tripwire for adding a case and forgetting the layout or the picker.
    static func categoriesAreComplete() {
        var subpaths: Set<String> = []
        for category in BackupCategory.allCases {
            let descriptor = category.descriptor
            check("\(category.rawValue) has a label", !descriptor.label.isEmpty)
            check("\(category.rawValue) has a symbol", !descriptor.symbol.isEmpty)
            if !descriptor.subpath.isEmpty {
                check(
                    "\(category.rawValue)'s subpath is its own",
                    subpaths.insert(descriptor.subpath)
                        .inserted)
            }
        }
        check("every case is offered", BackupCategory.all.count == BackupCategory.allCases.count)
        check(
            "ordering follows declaration order",
            BackupCategory.ordered(BackupCategory.all) == BackupCategory.allCases)
    }

    static func staging() {
        let base = scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        guard let staging = try? BackupStaging(base: base) else {
            check("staging is created on init", false)
            return
        }
        check(
            "staging is created on init",
            FileManager.default.fileExists(atPath: staging.root.path))
        staging.discard()
        check(
            "discard removes the tree",
            !FileManager.default.fileExists(atPath: staging.root.path))
        staging.discard()
        check("discard is idempotent", true)
    }
}
