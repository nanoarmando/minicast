import Foundation

/// Staged bundle → live stores. A format-2 bundle replaces each category; format 1 merges as it
/// always did, except Launcher Learning, which replaces.
@MainActor
enum BackupApplier {
    struct Summary: Sendable {
        var settings: SettingsBackup.ApplySummary?
        var quickActions = 0
        var extensions: ExtensionManager.RestoreReport?
        var aiConnections = 0
        var mcpServers = 0
        var clipboard = 0
        var chats = 0
        var learning = 0
        var pendingSecrets: [BackupPendingSecret] = []
        /// Reported rather than thrown: a failure here must not abort the categories after it.
        var problems: [String] = []
    }

    /// In dependency order: hotkeys and aliases name extension entries, so Extensions go first.
    static func apply(
        _ categories: Set<BackupCategory>, from bundle: BackupBundle, to core: AppCore
    ) async -> Summary {
        var summary = Summary()
        let replacing = bundle.format == BackupManifest.currentFormat
        if categories.contains(.aiAndMCP) { applyAI(bundle, to: core, into: &summary) }
        if categories.contains(.extensions) {
            let report = await core.extensions.restoreBundle(from: bundle.extensionsDirectory)
            summary.extensions = report
            summary.problems += report.failures.map { "\($0.name) wasn't restored: \($0.reason)" }
        }
        if categories.contains(.configuration) {
            applyConfiguration(bundle, replacing: replacing, to: core, into: &summary)
        }
        if categories.contains(.clipboard) {
            if replacing { core.clipboardCoordinator.clearHistory(includingPinned: true) }
            summary.clipboard = await importClipboard(bundle, into: core.clipboardStore)
            if summary.clipboard > 0 || replacing { core.clipboardStore.load() }
        }
        if categories.contains(.chatHistory) {
            do {
                core.aiChats.reset()
                try await core.chatHistory.replaceDatabase(with: bundle.chatDatabaseURL)
                summary.chats = core.chatHistory.conversations.count
            } catch {
                summary.problems.append(problem(.chatHistory, error))
            }
        }
        if categories.contains(.learning) {
            summary.learning = applyLearning(bundle, to: core)
        }
        return summary
    }

    /// Read from the staged file, so the consent step can ask about what the bundle carries.
    static func settingsBackup(in bundle: BackupBundle) -> SettingsBackup? {
        guard let data = try? Data(contentsOf: bundle.settingsURL) else { return nil }
        return try? SettingsBackup(json: data)
    }

    // MARK: - Categories

    private static func applyAI(_ bundle: BackupBundle, to core: AppCore, into summary: inout Summary) {
        guard let ai = bundle.decode(BackupAIPayload.self, at: bundle.aiURL),
            let mcp = bundle.decode(BackupMCPPayload.self, at: bundle.mcpURL)
        else {
            summary.problems.append(problem(.aiAndMCP, BackupFormatError.unreadable))
            return
        }
        core.aiSettings.replace(with: ai.settings)
        core.mcpCoordinator.replaceServers(mcp.servers)
        summary.aiConnections = ai.settings.connections.count
        summary.mcpServers = mcp.servers.count

        let flagged = Set(ai.connectionsWithSecrets)
        for connection in core.aiSettings.connections where flagged.contains(connection.id) {
            guard (try? KeychainSecretStore.aiAPIKeys.hasSecret(for: connection.id)) != true
            else { continue }
            summary.pendingSecrets.append(.init(kind: .aiConnection, name: connection.name))
        }
        for kind in ai.installedToolsWithSecrets where !kind.hasStoredEnvironment {
            summary.pendingSecrets.append(.init(kind: .installedTool, name: kind.title))
        }
        let secrets = MCPSecretStore()
        let flaggedServers = Set(mcp.serversWithSecrets)
        for server in core.mcpSettings.servers
        where flaggedServers.contains(server.id) && !secrets.hasSecrets(for: server.id) {
            summary.pendingSecrets.append(.init(kind: .mcpServer, name: server.title))
        }
    }

    /// Quick actions first: the settings file's hotkeys can only bind an action that exists.
    private static func applyConfiguration(
        _ bundle: BackupBundle, replacing: Bool, to core: AppCore, into summary: inout Summary
    ) {
        guard let backup = settingsBackup(in: bundle) else {
            summary.problems.append(problem(.configuration, BackupFormatError.unreadable))
            return
        }
        if let quickActions = bundle.decode(
            BackupQuickActionsPayload.self, at: bundle.quickActionsURL)
        {
            do {
                try core.customQuickActions.replaceAll(quickActions.customActions)
                summary.quickActions = core.customQuickActions.actions.count
            } catch {
                summary.problems.append(problem(.configuration, error))
            }
            var settings = QuickActionSettings()
            settings.storedPreviewChoices = quickActions.previewChoices
            settings.storedInstructionOverrides = quickActions.instructionOverrides
            core.quickActionSettings.replace(
                model: quickActions.model, modelOverrides: quickActions.modelOverrides,
                settings: settings)
        }
        summary.settings = backup.apply(to: core, replacing: replacing)
    }

    private static func problem(_ category: BackupCategory, _ error: Error) -> String {
        "\(category.descriptor.label): \(error.localizedDescription)"
    }

    // MARK: - Parts

    /// Off-main and streamed: a restored history runs to hundreds of thousands of clips.
    private nonisolated static func importClipboard(
        _ bundle: BackupBundle, into store: ClipboardStore
    ) async -> Int {
        ClipboardStore.importStoredItems(
            inDatabaseAt: store.dbURL, adoptingImagesInto: store.imagesDir,
            bundle.clipboardItems().lazy.compactMap { staged($0, in: bundle) })
    }

    /// The row still points into staging; the store adopts the blob once it accepts the clip.
    private nonisolated static func staged(
        _ item: BackupClipboardItem, in bundle: BackupBundle
    ) -> ClipboardItem? {
        switch item.kind {
        case .text:
            guard let text = item.text else { return nil }
            return ClipboardItem(
                id: UUID(), kind: .text, text: text, imagePath: nil, createdAt: item.createdAt,
                sourceBundleID: item.sourceBundleID, pinnedAt: item.pinnedAt)
        case .image:
            guard let name = item.imageName, let url = bundle.clipboardImageURL(named: name) else {
                return nil
            }
            return ClipboardItem(
                id: UUID(), kind: .image, text: nil, imagePath: url.path,
                createdAt: item.createdAt, sourceBundleID: item.sourceBundleID,
                pinnedAt: item.pinnedAt)
        case .file:
            // A path from another Mac names nothing here, so the row is dropped rather than dead.
            guard let path = item.text, FileManager.default.fileExists(atPath: path) else {
                return nil
            }
            return ClipboardItem(
                id: UUID(), kind: .file, text: path, imagePath: nil, createdAt: item.createdAt,
                sourceBundleID: item.sourceBundleID, pinnedAt: item.pinnedAt)
        }
    }

    private static func applyLearning(_ bundle: BackupBundle, to core: AppCore) -> Int {
        var applied = 0
        if let visits = bundle.decodeLearning(.ranking, as: [String: LauncherVisit].self) {
            core.launcherRanking.replace(visits)
            applied += visits.count
        }
        if let records = bundle.decodeLearning(.emoji, as: [FrequentEmoji].self) {
            core.frequentEmoji.replace(records)
            applied += records.count
        }
        if let entries = bundle.decodeLearning(.calculator, as: [CalcHistoryEntry].self) {
            core.calcHistory.replace(entries)
            applied += entries.count
        }
        return applied
    }
}
