import SwiftUI
import Perception

/// A SwiftUI split, not `NSSplitViewController`: its sidebar keeps the system's source-list material.
struct SettingsRootView: View {
    var body: some View {
        WithPerceptionTracking {
            NavigationSplitView {
                SettingsSidebarView()
                    .navigationSplitViewColumnWidth(
                        min: Theme.Size.settingsSidebar, ideal: Theme.Size.settingsSidebar,
                        max: Theme.Size.settingsSidebar)
            } detail: {
                SettingsDetailView()
                    .frame(minWidth: Theme.Size.settingsDetailMinimum)
            }
        }
    }
}
