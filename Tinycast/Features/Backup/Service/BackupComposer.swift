import Foundation

/// Stores → staged bundle: `plan` reads on the main actor, `write` does every byte of IO off it.
@MainActor
enum BackupComposer {
    /// Everything the writer needs, in `Sendable` form, so the heavy half can leave the actor.
    struct Plan: Sendable {
        var categories: Set<BackupCategory>
        var appVersion: String
        var settings: Data?
        var quickActions: Data?
        var extensions: ExtensionBundle.Snapshot?
        var ai: Data?
        var mcp: Data?
        var aiRecords = 0
        var clipboardDatabase: URL?
        var chatDatabase: URL?
        var learning: [BackupBundle.LearningPart: Data] = [:]
        var learningRecords = 0
    }

    struct Result: Sendable {
        var manifest: BackupManifest
        /// Clips whose image file had already gone; reported rather than silently dropped.
        var missingImages: Int
    }

    static func plan(_ categories: Set<BackupCategory>, from core: AppCore) async -> Plan {
        var plan = Plan(
            categories: categories,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "unknown")
        let encoder = BackupBundle.encoder
        if categories.contains(.configuration) {
            plan.settings = try? SettingsBackup.gather(from: core).encoded()
            plan.quickActions = try? encoder.encode(quickActions(from: core))
        }
        if categories.contains(.extensions) {
            plan.extensions = await core.extensions.bundleSnapshot()
        }
        if categories.contains(.aiAndMCP) {
            let ai = aiPayload(from: core)
            let mcp = mcpPayload(from: core)
            plan.ai = try? encoder.encode(ai)
            plan.mcp = try? encoder.encode(mcp)
            plan.aiRecords = ai.settings.connections.count + mcp.servers.count
        }
        if categories.contains(.clipboard) { plan.clipboardDatabase = core.clipboardStore.dbURL }
        if categories.contains(.chatHistory) { plan.chatDatabase = core.chatHistory.databaseURL }
        if categories.contains(.learning) {
            // From memory, not the files: the ranking store persists asynchronously.
            plan.learning[.ranking] = try? encoder.encode(core.launcherRanking.visits)
            plan.learning[.emoji] = try? encoder.encode(core.frequentEmoji.records)
            plan.learning[.calculator] = try? encoder.encode(core.calcHistory.entries)
            plan.learningRecords =
                core.launcherRanking.visits.count + core.frequentEmoji.records.count
                + core.calcHistory.entries.count
        }
        return plan
    }

    private static func quickActions(from core: AppCore) -> BackupQuickActionsPayload {
        let store = core.quickActionSettings
        return BackupQuickActionsPayload(
            customActions: core.customQuickActions.actions, model: store.model,
            modelOverrides: store.modelOverrides,
            previewChoices: store.settings.storedPreviewChoices,
            instructionOverrides: store.settings.storedInstructionOverrides)
    }

    /// Presence checks only, which read no secret and so raise no Keychain prompt.
    private static func aiPayload(from core: AppCore) -> BackupAIPayload {
        let settings = core.aiSettings.snapshot
        return BackupAIPayload(
            settings: settings,
            connectionsWithSecrets: settings.connections.map(\.id).filter {
                (try? KeychainSecretStore.aiAPIKeys.hasSecret(for: $0)) == true
            },
            installedToolsWithSecrets: InstalledAIKind.allCases.filter(\.hasStoredEnvironment))
    }

    private static func mcpPayload(from core: AppCore) -> BackupMCPPayload {
        let servers = core.mcpSettings.servers
        let secrets = MCPSecretStore()
        return BackupMCPPayload(
            servers: servers, serversWithSecrets: servers.map(\.id).filter(secrets.hasSecrets))
    }

    nonisolated static func write(_ plan: Plan, into bundle: BackupBundle) throws -> Result {
        try bundle.prepare(plan.categories)
        var counts: [String: Int] = [:]
        var missingImages = 0

        if let settings = plan.settings {
            try bundle.write(settings, to: bundle.settingsURL)
            if let quickActions = plan.quickActions {
                try bundle.write(quickActions, to: bundle.quickActionsURL)
            }
            counts[BackupCategory.configuration.rawValue] = 1
        }
        if let extensions = plan.extensions {
            counts[BackupCategory.extensions.rawValue] = try ExtensionBundle.write(
                extensions, into: bundle.extensionsDirectory)
        }
        if let ai = plan.ai, let mcp = plan.mcp {
            try bundle.write(ai, to: bundle.aiURL)
            try bundle.write(mcp, to: bundle.mcpURL)
            counts[BackupCategory.aiAndMCP.rawValue] = plan.aiRecords
        }
        if let database = plan.clipboardDatabase {
            let outcome = try writeClipboard(from: database, into: bundle)
            counts[BackupCategory.clipboard.rawValue] = outcome.written
            missingImages = outcome.missing
        }
        if let database = plan.chatDatabase {
            counts[BackupCategory.chatHistory.rawValue] = try ChatHistoryStore.snapshot(
                databaseAt: database, to: bundle.chatDatabaseURL)
        }
        if !plan.learning.isEmpty {
            for (part, data) in plan.learning { try bundle.write(data, to: bundle.learningURL(part)) }
            counts[BackupCategory.learning.rawValue] = plan.learningRecords
        }

        let manifest = BackupManifest(
            appVersion: plan.appVersion, createdAt: Date(), counts: counts)
        try bundle.writeManifest(manifest)
        return Result(manifest: manifest, missingImages: missingImages)
    }

    // MARK: - Parts

    private nonisolated static func writeClipboard(
        from database: URL, into bundle: BackupBundle
    )
        throws -> (written: Int, missing: Int)
    {
        let writer = try bundle.clipboardWriter()
        var written = 0
        var missing = 0
        var failure: Error?
        ClipboardStore.forEachStoredItem(inDatabaseAt: database) { item in
            guard failure == nil else { return }
            do {
                guard let portable = try portableItem(item, into: bundle) else {
                    missing += 1
                    return
                }
                try writer.write(portable)
                written += 1
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
        return (written, missing)
    }

    /// nil when the image has gone; hardlinked where the volume allows, so PNGs cost inodes.
    private nonisolated static func portableItem(
        _ item: ClipboardItem, into bundle: BackupBundle
    )
        throws -> BackupClipboardItem?
    {
        var imageName: String?
        if item.kind == .image {
            guard let path = item.imagePath,
                FileManager.default.fileExists(atPath: path)
            else { return nil }
            let source = URL(fileURLWithPath: path)
            // The stored blob's own name, so exporting twice names the same clip the same way.
            var name = source.lastPathComponent
            var destination = bundle.clipboardImagesDirectory.appendingPathComponent(name)
            if !BackupBundle.isSafeName(name)
                || FileManager.default.fileExists(atPath: destination.path)
            {
                name = UUID().uuidString + ".png"
                destination = bundle.clipboardImagesDirectory.appendingPathComponent(name)
            }
            if (try? FileManager.default.linkItem(at: source, to: destination)) == nil {
                try FileManager.default.copyItem(at: source, to: destination)
            }
            imageName = name
        }
        // A referenced file is exported as its path; a backup never carries bytes it never held.
        if item.kind == .file, item.filePath.map(FileManager.default.fileExists) != true {
            return nil
        }
        let kind: BackupClipboardItem.Kind
        switch item.kind {
        case .text: kind = .text
        case .image: kind = .image
        case .file: kind = .file
        }
        return BackupClipboardItem(
            kind: kind, text: item.text, imageName: imageName,
            createdAt: item.createdAt, sourceBundleID: item.sourceBundleID,
            pinnedAt: item.pinnedAt)
    }
}
