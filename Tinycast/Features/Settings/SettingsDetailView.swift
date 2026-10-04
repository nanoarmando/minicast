import SwiftUI
import Perception

/// The pane column: whichever pane the history currently points at.
struct SettingsDetailView: View {
    @Environment(SettingsNavigationState.self) private var navigation
    /// Nil until the first switch, so the opening pane is whatever Settings was opened at.
    @State private var displayedTab: SettingsTab?

    var body: some View {
        WithPerceptionTracking {
            // Not a `TabView`: `NSTabView` re-hosts on selection and breaks the recorder.
            Group {
                switch displayedTab ?? navigation.tab {
                case .general: GeneralSettingsView()
                case .applications: ApplicationsSettingsView()
                case .systemSettings: SystemSettingsSettingsView()
                case .systemActions: SystemActionsSettingsView()
                case .commands: CommandsSettingsView()
                case .appleShortcuts: AppleShortcutsSettingsView()
                case .fallbacks: FallbacksSettingsView()
                case .ai: AISettingsView()
                case .quickActions: QuickActionsSettingsView()
                case .fileSearch: FileSearchSettingsView()
                case .windowManagement: WindowManagementSettingsView()
                case .clipboard: ClipboardSettingsView()
                case .emoji: EmojiSettingsView()
                case .calendar: CalendarSettingsView()
                case .extensions: ExtensionsSettingsView()
                case .permissions: PermissionsSettingsView()
                case .backup: BackupSettingsView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // One host for every pane, above their scroll views so a callout is never clipped.
            .shortcutRecorderPopoverHost()
            // One frame late, so the sidebar highlight paints before the heavy pane builds.
            .task(id: navigation.tab) {
                await Task.yield()
                guard !Task.isCancelled else { return }
                displayedTab = navigation.tab
            }
        }
    }
}
