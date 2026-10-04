import Foundation

/// `ai/ai.json`. The flags record which ids had a Keychain secret, never the secret itself.
struct BackupAIPayload: Codable, Sendable {
    var settings: AISettingsSnapshot
    var connectionsWithSecrets: [UUID]
    var installedToolsWithSecrets: [InstalledAIKind]
}

/// `ai/mcp.json`. Servers keep their ids, so a secret this Mac already holds still matches.
struct BackupMCPPayload: Codable, Sendable {
    var servers: [MCPServer]
    var serversWithSecrets: [UUID]
}

/// `settings/quick-actions.json`: the custom actions and every quick-action choice.
struct BackupQuickActionsPayload: Codable, Sendable {
    var customActions: [CustomQuickAction]
    var model: AIModelSelection?
    var modelOverrides: [String: AIModelSelection]
    var previewChoices: [String: Bool]
    var instructionOverrides: [String: String]
}

/// An imported AI connection, MCP server or installed tool whose secret this Mac lacks.
struct BackupPendingSecret: Sendable, Hashable, Identifiable {
    enum Kind: Sendable, Hashable {
        case aiConnection
        case mcpServer
        case installedTool
    }

    var kind: Kind
    var name: String

    var id: String { "\(kind)-\(name)" }
}
