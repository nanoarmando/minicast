import SwiftUI
import Perception

struct ApplicationsSettingsView: View {
    var body: some View {
        WithPerceptionTracking {
            Form {
                LauncherCategorySwitchSection(
                    kind: .application, anchor: .applicationsApplications)

                SearchScopesSection()

                LauncherItemsSection(
                    kind: .application,
                    anchor: .applicationsApplications,
                    searchPrompt: "Search applications…")
            }
            .formStyle(.grouped)
            .settingsScrollTarget(.applications)
            .releasesFocusOnOutsideClick()
        }
    }

}
