import Foundation

/// Every AI setting a backup carries, as `AISettingsStore` persists it; secrets stay in the Keychain.
struct AISettingsSnapshot: Codable, Equatable, Sendable {
    var connections: [AIConnection]
    var defaultModel: AIModelSelection?
    var webSearchEnabled: Bool
    var systemPrompt: String
    var systemPromptEnabled: Bool
    /// Raw values, as `UserDefaults` holds them, so an unknown one falls back like a stored one.
    var retention: Int
    var opensTo: Int
    var newChatAfter: Int
    var toolRounds: Int
    var shownModels: [String: [String]]
    var disabledRoutes: [String]
    var enabledInstalledProviders: [InstalledAIKind]
    /// Keyed by `InstalledAIKind.rawValue`; each names variables, never their values.
    var installedOverrides: [String: InstalledAIOverride]
}
