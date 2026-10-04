import Foundation

/// Built-in launcher actions, surfaced alongside the user-authored ones.
enum CommandID: String, CaseIterable, Sendable {
    /// The palette's chat keeps the id it shipped with, so its hotkeys and fallback still reach it.
    case quickAI = "command:ai-chat"
    case aiChat = "command:ai-chat-window"
    case fixGrammar = "command:fix-grammar"
    case rewrite = "command:rewrite"
    case summarize = "command:summarize"
    case calculatorHistory = "command:calculator-history"
    case clipboardHistory = "command:clipboard-history"
    case pasteSequentially = "command:paste-sequentially"
    case searchEmoji = "command:search-emoji"
    case searchFiles = "command:search-files"
    case openInBrowser = "command:open-in-browser"
    case runShellCommand = "command:run-shell-command"
    case define = "command:define"
    case joinNextMeeting = "command:join-next-meeting"
    case mySchedule = "command:my-schedule"
    case createEvent = "command:create-event"
    case copyMeetingLink = "command:copy-meeting-link"
    case openInCalendar = "command:open-in-calendar"
    case createWindowLayout = "command:create-window-layout"
    case captureWindowLayout = "command:capture-window-layout"
    case switchRoom = "command:switch-room"
    case createRoom = "command:create-room"
    case exportSettings = "command:export-settings"
    case importSettings = "command:import-settings"
    case importFromRaycast = "command:import-from-raycast"
    case settings = "command:settings"
    case about = "command:about"
    case quit = "command:quit"

    var name: String {
        switch self {
        case .quickAI: return "Quick AI"
        case .aiChat: return "AI Chat"
        case .fixGrammar: return BuiltInQuickAction.fixGrammar.title
        case .rewrite: return BuiltInQuickAction.rewrite.title
        case .summarize: return BuiltInQuickAction.summarize.title
        case .calculatorHistory: return "Calculator History"
        case .clipboardHistory: return "Clipboard History"
        case .pasteSequentially: return "Paste Sequentially"
        case .searchEmoji: return "Search Emoji & Symbols"
        case .searchFiles: return "Search Files"
        case .openInBrowser: return "Open in Browser"
        case .runShellCommand: return "Run Shell Command"
        case .define: return "Define Word"
        case .joinNextMeeting: return "Join Next Meeting"
        case .mySchedule: return "My Schedule"
        case .createEvent: return "Create Event"
        case .copyMeetingLink: return "Copy Meeting Link"
        case .openInCalendar: return "Open in Calendar"
        case .createWindowLayout: return "Create Window Layout"
        case .captureWindowLayout: return "Create Layout from Current Windows"
        case .switchRoom: return "Switch Room"
        case .createRoom: return "Create Room"
        case .exportSettings: return "Export Backup"
        case .importSettings: return "Import Backup"
        case .importFromRaycast: return "Import from Raycast"
        case .settings: return "Tinycast Settings"
        case .about: return "About Tinycast"
        case .quit: return "Quit Tinycast"
        }
    }

    var sfSymbol: String {
        switch self {
        case .quickAI: return "sparkles"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .fixGrammar: return BuiltInQuickAction.fixGrammar.symbol
        case .rewrite: return BuiltInQuickAction.rewrite.symbol
        case .summarize: return BuiltInQuickAction.summarize.symbol
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .clipboardHistory: return "doc.on.clipboard"
        case .pasteSequentially: return "list.bullet.clipboard"
        case .searchEmoji: return "face.smiling"
        case .searchFiles: return "doc.text.magnifyingglass"
        case .openInBrowser: return "globe"
        case .runShellCommand: return "terminal"
        case .define: return "book.closed"
        case .joinNextMeeting: return "video.fill"
        case .mySchedule: return "calendar"
        case .createEvent: return "calendar.badge.plus"
        case .copyMeetingLink: return "link"
        case .openInCalendar: return "calendar.badge.clock"
        case .createWindowLayout: return "plus.rectangle.on.rectangle"
        case .captureWindowLayout: return "macwindow.badge.plus"
        case .switchRoom: return "door.left.hand.open"
        case .createRoom: return "rectangle.stack.badge.plus"
        case .exportSettings: return "square.and.arrow.up"
        case .importSettings: return "square.and.arrow.down"
        case .importFromRaycast: return "arrow.down.doc"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .quit: return "power"
        }
    }

    /// Exhaustive, so a new shipped action cannot reach the launcher without a row here.
    init(_ action: BuiltInQuickAction) {
        switch action {
        case .fixGrammar: self = .fixGrammar
        case .rewrite: self = .rewrite
        case .summarize: self = .summarize
        }
    }

    var builtInQuickAction: BuiltInQuickAction? {
        switch self {
        case .fixGrammar: return .fixGrammar
        case .rewrite: return .rewrite
        case .summarize: return .summarize
        default: return nil
        }
    }

    /// Queries this command wins until the user opens a rival more.
    var boostedTerms: Set<String> {
        switch self {
        case .quickAI: ["ai"]
        case .aiChat: ["chat"]
        default: []
        }
    }

    /// Suggested, highest first, until the user's own habits fill the section.
    var suggestionPriority: Int? {
        switch self {
        case .clipboardHistory: 80
        case .searchFiles: 70
        case .mySchedule: 60
        case .searchEmoji: 50
        default: nil
        }
    }

    /// Query-driven: the typed text is their input, so they are built where offered, never listed.
    var isQueryDriven: Bool {
        self == .openInBrowser || self == .runShellCommand
    }

    /// A chord carries no query, and none should be able to terminate the app outright.
    var hotKeyAction: HotKeyAction? {
        isQueryDriven || self == .quit ? nil : .command(self)
    }
}
