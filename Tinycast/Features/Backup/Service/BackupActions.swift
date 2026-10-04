import AppKit
import UniformTypeIdentifiers

extension UTType {
    /// Not per-channel: a UTI names an interchange format, so Dev must read stable's exports.
    static let minicastBackup = UTType(exportedAs: "com.minicast.backup")
    static let tinycastBackup = UTType(importedAs: "com.tinycast.backup")
}

/// The backup flows' entry points, shared by the Settings pane and the commands.
@MainActor
enum BackupActions {
    struct RaycastOutcome {
        var summary: SettingsBackup.ApplySummary
        var clipboardImported: Int
        var missingImages: Int
    }

    // MARK: - File panels (dialogs come from `AppCore`)

    /// The shared save panel; an accessory app must activate first or it opens behind.
    static func chooseSaveLocation(named base: String, type: UTType = .json) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        let ext = type.preferredFilenameExtension ?? "json"
        panel.nameFieldStringValue = "\(base)-\(dateStamp()).\(ext)"
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func chooseBackupFile() -> URL? { chooseFile(ofTypes: [.minicastBackup, .tinycastBackup]) }

    private static func chooseFile(ofTypes types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    // MARK: - Minicast backups

    /// An extracted bundle, held between choosing the file and applying it.
    struct OpenedBackup: Sendable {
        let staging: BackupStaging
        let bundle: BackupBundle
        let manifest: BackupManifest
    }

    /// Composed off-main, zipped beside it, then moved into place already `0600`.
    static func exportBackup(
        core: AppCore, categories: Set<BackupCategory>, to destination: URL
    ) async throws -> BackupComposer.Result {
        let plan = await BackupComposer.plan(categories, from: core)
        return try await Task.detached(priority: .userInitiated) {
            let staging = try BackupStaging()
            defer { staging.discard() }
            let bundle = staging.bundle()
            let result = try BackupComposer.write(plan, into: bundle)
            let sealed = staging.root.appendingPathComponent("bundle.zip")
            try BackupZip.compress(bundle.root, into: sealed)
            let fm = FileManager.default
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sealed.path)
            try? fm.removeItem(at: destination)
            try fm.moveItem(at: sealed, to: destination)
            return result
        }.value
    }

    /// Every check runs here, before the caller can apply anything: container, manifest, names.
    static func openBackup(at file: URL) async throws -> OpenedBackup {
        try await Task.detached(priority: .userInitiated) {
            let staging = try BackupStaging()
            do {
                let bundle: BackupBundle
                if BackupArchive.isZip(file) {
                    try BackupZip.extract(file, into: staging.payload)
                    bundle = staging.bundle()
                } else {
                    try BackupArchive.open(file: file, into: staging.payload)
                    bundle = staging.bundle(format: BackupManifest.legacyFormat)
                }
                let manifest = try bundle.readManifest()
                if manifest.categories.contains(.extensions) {
                    _ = try ExtensionBundle.entries(in: bundle.extensionsDirectory)
                }
                return OpenedBackup(staging: staging, bundle: bundle, manifest: manifest)
            } catch {
                staging.discard()
                throw error
            }
        }.value
    }

    /// Confirms, applies, then asks separately before any capability switch is turned on.
    static func applyBackup(
        _ categories: Set<BackupCategory>, from opened: OpenedBackup, to core: AppCore
    ) async -> BackupApplier.Summary? {
        let bundle = opened.bundle
        let staged =
            categories.contains(.configuration) ? BackupApplier.settingsBackup(in: bundle) : nil
        guard await confirmImport(categories, of: bundle, settings: staged, core: core) else {
            return nil
        }
        let summary = await BackupApplier.apply(categories, from: bundle, to: core)
        if let capabilities = staged?.capabilities {
            await offerCapabilities(capabilities, core: core)
        }
        return summary
    }

    /// Names every category it replaces and every extension it removes, before anything moves.
    private static func confirmImport(
        _ categories: Set<BackupCategory>, of bundle: BackupBundle, settings: SettingsBackup?,
        core: AppCore
    ) async -> Bool {
        let replacing = bundle.format == BackupManifest.currentFormat
        let labels = BackupCategory.ordered(categories).map(\.descriptor.label)
        var message =
            replacing
            ? "Replaces \(list(labels)) on this Mac with the backup's. Anything you didn't select "
                + "stays as it is."
            : "Adds the backup's \(list(labels)) to this Mac."
        if categories.contains(.extensions),
            let bundled = try? ExtensionBundle.entries(in: bundle.extensionsDirectory)
        {
            let kept = Set(bundled.map(\.name))
            let removed = await core.extensions.installedOnDisk()
                .filter { !kept.contains($0.manifest.name) }.map(\.title)
            if !removed.isEmpty { message += " These extensions will be uninstalled: \(list(removed))." }
        }
        let commands = settings?.customCommands?.count ?? 0
        if commands > 0 {
            message +=
                " It contains \(count(commands, "custom command")), which can run shell code. "
                + "Only import files you trust."
        }
        return await core.confirm(
            title: replacing ? "Replace with this backup?" : "Import this backup?",
            message: message, symbol: importSymbol,
            confirmTitle: replacing ? "Replace" : "Import",
            confirmRole: replacing ? .destructive : .standard)
    }

    // MARK: - Capability consent

    /// Turning a switch off grants nothing, so only a switch that would turn on needs the answer.
    private static func offerCapabilities(
        _ wanted: SettingsBackup.CapabilityData, core: AppCore
    ) async {
        let enabling = BackupCapability.allCases.filter {
            $0.value(in: wanted) == true && !$0.value(in: core.settings)
        }
        guard !enabling.isEmpty else { return await applyCapabilities(wanted, core: core) }
        let message = await consentMessage(enabling: enabling, core: core)
        guard
            await core.confirm(
                title: "Turn on what this backup had on?", message: message,
                symbol: importSymbol, confirmTitle: "Turn On", tone: .neutral,
                confirmRole: .standard, dismissTitle: "Keep Off")
        else { return }
        await applyCapabilities(wanted, core: core)
    }

    /// What would become able to run, read from this Mac after the import, not from the file.
    private static func consentMessage(
        enabling: [BackupCapability], core: AppCore
    ) async -> String {
        var parts = ["Turns on \(list(enabling.map(\.title)))."]
        if enabling.contains(.extensions) {
            let names = await core.extensions.installedOnDisk().map(\.title)
            if !names.isEmpty { parts.append("Extensions that would run: \(list(names)).") }
        }
        if enabling.contains(.mcp) || enabling.contains(.ai) {
            let commands = core.mcpSettings.enabledServers.compactMap { server -> String? in
                guard case .stdio(let command, _, _) = server.transport else { return nil }
                return "\(server.title) (\(command))"
            }
            if !commands.isEmpty { parts.append("Local MCP servers: \(list(commands)).") }
        }
        if enabling.contains(.ai) {
            let overrides = InstalledAIKind.allCases.compactMap { kind -> String? in
                let path = core.aiSettings.override(for: kind).commandPath
                return path.isEmpty ? nil : "\(kind.title) (\(path))"
            }
            if !overrides.isEmpty { parts.append("AI tools run as: \(list(overrides)).") }
        }
        let shell = core.customCommands.commands.filter(\.isEnabled).map(\.name)
        if !shell.isEmpty { parts.append("Custom commands that run shell code: \(list(shell)).") }
        if core.fallbacks.isEnabled(.builtin(.runShellCommand)) {
            parts.append("The Run Shell Command fallback is on.")
        }
        parts.append("macOS still asks for Calendar or Accessibility access when it's first needed.")
        return parts.joined(separator: " ")
    }

    /// Through the same paths the switches use, so each feature starts or stops as it would.
    private static func applyCapabilities(
        _ wanted: SettingsBackup.CapabilityData, core: AppCore
    ) async {
        let settings = core.settings
        if let value = wanted.aiEnabled { settings.aiEnabled = value }
        if let value = wanted.mcpEnabled { settings.mcpEnabled = value }
        if let value = wanted.quickActionsEnabled { settings.quickActionsEnabled = value }
        if let value = wanted.clipboardTextSearchEnabled {
            settings.clipboardTextSearchEnabled = value
        }
        if let value = wanted.autoJoinMeetings { settings.autoJoinMeetings = value }
        if let value = wanted.extensionsEnabled, value != settings.extensionsEnabled {
            settings.extensionsEnabled = value
            core.extensionCoordinator.applyEnabled()
        }
        if let value = wanted.calendarEnabled, value != settings.calendarEnabled {
            if value {
                await core.calendarCoordinator.enableAfterGrant()
            } else {
                core.calendarCoordinator.setCalendarEnabled(false)
            }
        }
    }

    // MARK: - Raycast (the pane owns the passphrase field + inline status)

    static func importRaycast(
        core: AppCore, file: URL, passphrase: String, options: RaycastImportOptions = .all
    ) async throws -> RaycastOutcome {
        // Off-main in an autoreleasepool, so the large JSON tree drains at once.
        let result = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                try RaycastImportReader.read(file: file, passphrase: passphrase).selecting(options)
            }
        }.value
        let summary = result.backup.apply(to: core)
        let imported =
            result.clipboard.isEmpty
            ? 0 : core.clipboardStore.importEntries(result.clipboard)
        return RaycastOutcome(
            summary: summary,
            clipboardImported: imported,
            missingImages: result.missingImages)
    }

    /// Every Raycast channel (stable, beta, alpha, internal) shares this bundle-id prefix.
    static let raycastBundleIDPrefix = "com.raycast"

    static func isRaycastBundleID(_ id: String) -> Bool { id.hasPrefix(raycastBundleIDPrefix) }

    /// Quit any running Raycast so its hotkeys stop clashing; background helpers stay.
    static func quitRaycast() {
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier.map(isRaycastBundleID) == true
            && app.activationPolicy != .prohibited
        {
            app.terminate()
        }
    }

    /// The `.rayconfig` file picker used by the Backup pane.
    static func pickRaycastFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Reads only the leading bytes, mapped, so a file is labelled before a passphrase is typed.
    static func isRaycastExport(_ file: URL) -> Bool {
        guard let raw = try? Data(contentsOf: file, options: .mappedIfSafe) else { return false }
        return RaycastDecoder.isExport(raw)
    }

    // MARK: - Helpers

    /// One sentence per category that actually moved, so an import is never silent.
    static func summaryText(_ summary: BackupApplier.Summary) -> String {
        var parts: [String] = []
        if let settings = summary.settings, let applied = appliedText(settings) {
            parts.append(applied)
        }
        var imported: [String] = []
        if summary.quickActions > 0 { imported.append(count(summary.quickActions, "quick action")) }
        if let restored = summary.extensions?.restored.count, restored > 0 {
            imported.append(count(restored, "extension"))
        }
        if summary.aiConnections > 0 {
            imported.append(count(summary.aiConnections, "AI connection"))
        }
        if summary.mcpServers > 0 { imported.append(count(summary.mcpServers, "MCP server")) }
        if summary.clipboard > 0 { imported.append("\(summary.clipboard) clips") }
        if summary.chats > 0 { imported.append(count(summary.chats, "conversation")) }
        if summary.learning > 0 { imported.append("\(summary.learning) learning records") }
        if !imported.isEmpty {
            parts.append("Imported " + imported.joined(separator: ", ") + ".")
        }
        if let removed = summary.extensions?.removed, !removed.isEmpty {
            parts.append("Uninstalled \(list(removed)).")
        }
        parts.append(contentsOf: summary.problems)
        return parts.isEmpty ? nothingImportedText : parts.joined(separator: " ")
    }

    static func exportText(_ result: BackupComposer.Result) -> String {
        let categories = BackupCategory.ordered(result.manifest.categories)
        var text =
            categories.isEmpty
            ? "Nothing was selected."
            : "Saved "
                + categories.map(\.descriptor.label)
                .joined(separator: ", ") + "."
        if result.missingImages > 0 {
            text += " \(result.missingImages) images were unavailable and skipped."
        }
        return text
    }

    static let nothingImportedText = "Nothing to import from this file."

    /// Not everything an import applies settles in the running app, so say to relaunch.
    private static let restartAfterImportText = "Quit and reopen Minicast to finish."

    /// One sentence per Raycast category that actually moved, shown by the pane.
    static func raycastText(_ outcome: RaycastOutcome) -> String {
        var parts: [String] = []
        if let applied = appliedText(outcome.summary) { parts.append(applied) }
        if outcome.clipboardImported > 0 {
            parts.append("Imported \(outcome.clipboardImported) clipboard entries.")
        }
        var message = parts.isEmpty ? nothingImportedText : parts.joined(separator: " ")
        if outcome.missingImages > 0 {
            message += " \(outcome.missingImages) images were unavailable and skipped."
        }
        if !parts.isEmpty { message += " \(restartAfterImportText)" }
        return message
    }

    /// nil when no settings applied, so a caller can compose one combined sentence.
    static func appliedText(_ s: SettingsBackup.ApplySummary) -> String? {
        var parts: [String] = []
        if s.settingsFields > 0 { parts.append("\(s.settingsFields) settings") }
        if s.hotkeys > 0 { parts.append("\(s.hotkeys) shortcuts") }
        if s.favorites > 0 { parts.append("\(s.favorites) favorites") }
        if s.hiddenItems > 0 { parts.append("\(s.hiddenItems) hidden items") }
        if s.aliases > 0 { parts.append("\(s.aliases) aliases") }
        if s.pinnedEmoji > 0 { parts.append("\(s.pinnedEmoji) pinned emoji and symbols") }
        if s.customCommands > 0 { parts.append("\(s.customCommands) custom commands") }
        if s.windowLayouts > 0 { parts.append("\(s.windowLayouts) window layouts") }
        if s.windowRooms > 0 { parts.append("\(s.windowRooms) rooms") }
        if s.customWindowSizes > 0 {
            parts.append("\(s.customWindowSizes) custom window sizes")
        }
        guard !parts.isEmpty else { return nil }
        return "Applied " + parts.joined(separator: ", ") + "."
    }

    // MARK: - Settings file

    /// Where settings.json lives for this channel, as the pane and its dialog spell it.
    static var settingsFilePath: String {
        (AppPaths.settingsFile().path as NSString).abbreviatingWithTildeInPath
    }

    /// Turning the mirror on over a file that already exists asks which side wins.
    static func setSettingsFileEnabled(_ enabled: Bool, core: AppCore) async {
        guard enabled else { return core.stopSettingsFile() }
        guard FileManager.default.fileExists(atPath: AppPaths.settingsFile().path) else {
            return core.startSettingsFile(importing: false)
        }
        let choice = await core.choose(
            title: "Import the existing settings file?",
            message:
                "\(settingsFilePath) already exists. Import applies its settings here; Replace "
                + "overwrites it with the current ones.",
            symbol: importSymbol,
            options: [
                DialogAction(title: "Import"),
                DialogAction(title: "Replace", role: .destructive),
                DialogAction(title: "Cancel", role: .cancel)
            ],
            defaultIndex: 0)
        switch choice {
        case 0: core.startSettingsFile(importing: true)
        case 1: core.startSettingsFile(importing: false)
        default: break
        }
    }

    static func revealSettingsFile() {
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.settingsFile()])
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Every import dialog carries the same glyph, so the flow reads as one thing.
    private static let importSymbol = "square.and.arrow.down"

    /// At most a handful of names: a dialog that lists forty extensions is read by nobody.
    private static func list(_ names: [String], limit: Int = 6) -> String {
        guard names.count > limit else { return names.joined(separator: ", ") }
        return names.prefix(limit).joined(separator: ", ") + " and \(names.count - limit) more"
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        value == 1 ? "1 \(noun)" : "\(value) \(noun)s"
    }
}

/// The switches a bundle carries but only the consent step writes.
enum BackupCapability: CaseIterable {
    case extensions
    case mcp
    case ai
    case quickActions
    case calendar
    case autoJoin
    case clipboardTextSearch

    var title: String {
        switch self {
        case .extensions: return "Extensions"
        case .mcp: return "MCP"
        case .ai: return "AI"
        case .quickActions: return "Quick Actions"
        case .calendar: return "Calendar"
        case .autoJoin: return "auto-join meetings"
        case .clipboardTextSearch: return "clipboard text recognition"
        }
    }

    func value(in data: SettingsBackup.CapabilityData) -> Bool? {
        switch self {
        case .extensions: return data.extensionsEnabled
        case .mcp: return data.mcpEnabled
        case .ai: return data.aiEnabled
        case .quickActions: return data.quickActionsEnabled
        case .calendar: return data.calendarEnabled
        case .autoJoin: return data.autoJoinMeetings
        case .clipboardTextSearch: return data.clipboardTextSearchEnabled
        }
    }

    @MainActor
    func value(in settings: AppSettings) -> Bool {
        switch self {
        case .extensions: return settings.extensionsEnabled
        case .mcp: return settings.mcpEnabled
        case .ai: return settings.aiEnabled
        case .quickActions: return settings.quickActionsEnabled
        case .calendar: return settings.calendarEnabled
        case .autoJoin: return settings.autoJoinMeetings
        case .clipboardTextSearch: return settings.clipboardTextSearchEnabled
        }
    }
}
