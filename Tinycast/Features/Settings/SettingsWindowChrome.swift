import AppKit

/// An empty unified toolbar only sizes the titlebar band; the controls live in the content beneath it.
@MainActor
final class SettingsWindowChrome: WindowChrome {
    func install(in window: NSWindow) {
        // Without a toolbar the band is 28pt and the traffic lights sit too high for the header row.
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        // Hidden, not cleared: Mission Control and the Window menu still name the window.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // A drag on a `Form` shouldn't move the window; the header band drags it through AppKit.
        window.isMovableByWindowBackground = false
    }
}
