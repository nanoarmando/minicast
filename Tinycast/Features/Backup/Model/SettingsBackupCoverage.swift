import Foundation

/// What `SettingsBackup.SettingsData` carries, written out so a new setting has to be considered.
enum SettingsBackupCoverage {
    /// Each `SettingsData` field paired with the `AppSettings` key it mirrors.
    static let mirrored: [String: AppSettingsKey] = [
        "clipboardEnabled": .clipboardEnabled,
        "clipboardRetentionDays": .clipboardRetention,
        "clipboardDefaultAction": .clipboardDefaultAction,
        "clipboardDisabledApps": .clipboardDisabledApps,
        "hyperKey": .hyperKey,
        "hyperKeyIncludesShift": .hyperKeyIncludesShift,
        "hyperKeyQuickPress": .hyperKeyQuickPress,
        "showInMenuBar": .showInMenuBar,
        "emojiSkinTone": .emojiSkinTone,
        "emojiGridColumns": .emojiGridColumns,
        "popToRootSeconds": .popToRootTimeout,
        "escapeKeyBehavior": .escapeKeyBehavior,
        "appearance": .appearance,
        "calcNumberStyle": .calcNumberStyle,
        "interfaceSize": .interfaceSize,
        "compactMode": .compactMode,
        "showFavoritesInCompactMode": .showFavoritesInCompactMode,
        "searchScopes": .searchScopes,
        "launcherShowsSuggestions": .launcherShowsSuggestions,
        "rootSearchSensitivity": .rootSearchSensitivity,
        "openOnCursorScreen": .openOnCursorScreen,
        "paletteDraggable": .paletteDraggable,
        "fileSearchEnabled": .fileSearchEnabled,
        "fileSearchScopes": .fileSearchScopes,
        "fileSearchIgnorePatterns": .fileSearchIgnorePatterns,
        "customCommandsEnabled": .customCommandsEnabled,
        "customCommandsShowInLauncher": .customCommandsShowInLauncher,
        "windowManagementEnabled": .windowManagementEnabled,
        "windowManagementShowInLauncher": .windowManagementShowInLauncher,
        "windowGap": .windowGap,
        "windowCycle": .windowCycle,
        "windowLayoutsShowInLauncher": .windowLayoutsShowInLauncher,
        "windowRoomsShowInLauncher": .windowRoomsShowInLauncher,
        "appleShortcutsEnabled": .appleShortcutsEnabled,
        "extensionsShowInLauncher": .extensionsShowInLauncher,
        "calendarShowInLauncher": .calendarShowInLauncher,
        "calendarLauncherLimit": .calendarLauncherLimit,
        "calendarSpan": .calendarSpan,
        "joinWindowMinutes": .joinWindowMinutes,
        "autoJoinConfirms": .autoJoinConfirms,
        "menuBarEvents": .menuBarEvents,
        "calendarMenuBarDisplay": .calendarMenuBarDisplay,
        "menuBarLinkedEventsOnly": .menuBarLinkedEventsOnly,
        "calendarMenuBarHidesWhenEmpty": .calendarMenuBarHidesWhenEmpty,
        "hideCurrentEvent": .hideCurrentEvent
    ]

    /// The `SettingsData` fields no `AppSettings` key stands behind, and what they read instead.
    static let externallySourced: [String: String] = [
        "launchAtLogin":
            "Read from LaunchAtLogin, which owns the login item; machine-local, so an export leaves "
            + "it out and only a format-1 file still sets it."
    ]

    /// `CapabilityData` fields: carried, but applied only after the import's consent dialog.
    static let capabilities: [String: AppSettingsKey] = [
        "extensionsEnabled": .extensionsEnabled,
        "mcpEnabled": .mcpEnabled,
        "aiEnabled": .aiEnabled,
        "quickActionsEnabled": .quickActionsEnabled,
        "calendarEnabled": .calendarEnabled,
        "autoJoinMeetings": .autoJoinMeetings,
        "clipboardTextSearchEnabled": .clipboardTextSearchEnabled
    ]

    /// Keys a bundle carries in a part of its own rather than `settings.json`, by that part.
    static let carriedElsewhere: [String: String] = [
        AppSettingsKey.aiInstalledProviders.rawValue: aiPart,
        AppSettingsKey.aiConnections.rawValue: aiPart,
        AppSettingsKey.aiDefaultModel.rawValue: aiPart,
        AppSettingsKey.aiWebSearch.rawValue: aiPart,
        AppSettingsKey.aiSystemPrompt.rawValue: aiPart,
        AppSettingsKey.aiSystemPromptEnabled.rawValue: aiPart,
        AppSettingsKey.aiRetention.rawValue: aiPart,
        AppSettingsKey.aiOpensTo.rawValue: aiPart,
        AppSettingsKey.aiNewChatAfter.rawValue: aiPart,
        AppSettingsKey.aiToolRounds.rawValue: aiPart,
        AppSettingsKey.aiShownModels.rawValue: aiPart,
        AppSettingsKey.aiDisabledRoutes.rawValue: aiPart,
        AppSettingsKey.aiInstalledOverrides.rawValue: aiPart,
        AppSettingsKey.mcpServers.rawValue: "ai/mcp.json",
        AppSettingsKey.quickActionModel.rawValue: quickActionsPart,
        AppSettingsKey.quickActionModelOverrides.rawValue: quickActionsPart,
        AppSettingsKey.quickActionPreviews.rawValue: quickActionsPart,
        AppSettingsKey.quickActionInstructions.rawValue: quickActionsPart
    ]

    private static let aiPart = "ai/ai.json"
    private static let quickActionsPart = "settings/quick-actions.json"

    /// Machine-local keys, kept out of a bundle because they describe this Mac and no other.
    static let deliberatelyExcluded: [String: String] = [
        AppSettingsKey.extensionPackageManager.rawValue:
            "Names a tool on this Mac; the machine a backup lands on may not have it.",
        AppSettingsKey.extensionCustomSearchPaths.rawValue:
            "Machine-local toolchain paths; the Mac a backup lands on may not have them, or may have "
            + "something else there.",
        AppSettingsKey.palettePosition.rawValue:
            "Machine-local geometry: every entry names a display this Mac has, and no other one.",
        AppSettingsKey.paletteExpandedCenterDisplays.rawValue:
            "Machine-local geometry: every entry names a display this Mac has, and no other one.",
        AppSettingsKey.autoSwitchInputSource.rawValue:
            "Names a keyboard input source installed on this Mac; another Mac may not have it.",
        AppSettingsKey.meetingBrowser.rawValue:
            "Names a browser installed on this Mac; another Mac may not have it.",
        AppSettingsKey.settingsFileEnabled.rawValue:
            "Lets a file on this Mac change its settings; an import must not hand that to another."
    ]
}
