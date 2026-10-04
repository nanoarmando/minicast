import Combine
import Perception
import SwiftUI

@main
struct TinycastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // Channel-aware: "Tinycast", "Tinycast Dev", or "Tinycast Beta".
    private let appName = Bundle.main.appDisplayName

    @StateObject private var sceneState = MenuBarSceneState()

    /// Two independent items: one preference each, no state either can read off the other.
    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertion) {
            MenuBarMenu(appName: appName)
        } label: {
            MenuBarLabel(appName: appName)
        }
        .commands { menuBarCommands }

        MenuBarExtra(isInserted: calendarMenuBarInsertion) {
            CalendarMenuBarMenu()
        } label: {
            CalendarMenuBarLabel(appName: appName)
        }
    }

    /// Read in `body` through `sceneState`; SwiftUI echoes the binding back, so only a change writes.
    private var menuBarInsertion: Binding<Bool> {
        let settings = AppCore.shared.settings
        let isInserted = sceneState.showInMenuBar
        return Binding(
            get: { isInserted },
            set: { inserted in
                guard inserted != settings.showInMenuBar else { return }
                settings.showInMenuBar = inserted
            })
    }

    /// Writes through `AppSettings`: dragging the item out must stop the clock and move the picker.
    private var calendarMenuBarInsertion: Binding<Bool> {
        let settings = AppCore.shared.settings
        let isInserted = sceneState.isCalendarMenuBarEnabled && !isCalendarMenuBarHiddenWhenEmpty
        return Binding(
            get: { isInserted },
            set: { inserted in
                if inserted {
                    guard settings.calendarMenuBarDisplay == .disabled else { return }
                    settings.calendarMenuBarDisplay = .meetingIcon
                } else {
                    // SwiftUI echoes our own removal back here; only a drag-out means "turn it off".
                    guard !isCalendarMenuBarHiddenWhenEmpty, settings.calendarMenuBarDisplay != .disabled
                    else { return }
                    settings.calendarMenuBarDisplay = .disabled
                }
            })
    }

    private var isCalendarMenuBarHiddenWhenEmpty: Bool {
        sceneState.isCalendarMenuBarHiddenWhenEmpty
    }

    /// Declared, not assigned to `NSApp.mainMenu`: SwiftUI rebuilds the menu on any scene change.
    @CommandsBuilder
    private var menuBarCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(appName)") { AppCore.shared.settingsCoordinator.showAbout() }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { AppCore.shared.settingsCoordinator.showSettings() }
                .keyboardShortcut(",")
        }
        CommandGroup(replacing: .appTermination) {
            Button("Close Window") {
                // The chat window closes itself when it is in front; otherwise ⌘Q is Settings'.
                guard !AppCore.shared.aiChatCoordinator.closeWindowIfKey() else { return }
                AppCore.shared.settingsCoordinator.closeSettings()
            }
            .keyboardShortcut("q")
        }
    }
}

/// Scene bodies can't use `WithPerceptionTracking`, so this republishes their reads for SwiftUI.
@MainActor
private final class MenuBarSceneState: ObservableObject {
    @Published private(set) var showInMenuBar = false
    @Published private(set) var isCalendarMenuBarEnabled = false
    @Published private(set) var isCalendarMenuBarHiddenWhenEmpty = false

    init() {
        track()
    }

    /// Fires before the write lands, so the hop to main re-arms and reads the new values.
    private func track() {
        withPerceptionTracking {
            let core = AppCore.shared
            let settings = core.settings
            let showInMenuBar = settings.showInMenuBar
            let isCalendarMenuBarEnabled = settings.calendarMenuBarDisplay != .disabled
            let isHiddenWhenEmpty =
                settings.calendarMenuBarHidesWhenEmpty && !core.calendarCoordinator.hasMenuBarEvent
            if self.showInMenuBar != showInMenuBar { self.showInMenuBar = showInMenuBar }
            if self.isCalendarMenuBarEnabled != isCalendarMenuBarEnabled {
                self.isCalendarMenuBarEnabled = isCalendarMenuBarEnabled
            }
            if isCalendarMenuBarHiddenWhenEmpty != isHiddenWhenEmpty {
                isCalendarMenuBarHiddenWhenEmpty = isHiddenWhenEmpty
            }
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
    }
}
