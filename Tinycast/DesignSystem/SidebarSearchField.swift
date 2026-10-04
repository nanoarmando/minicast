import SwiftUI
import Perception

/// The search capsule at the top of a window's sidebar; Settings and AI Chat share it.
struct SidebarSearchField: View {
    @Binding var query: String
    @FocusState.Binding var focused: Bool
    let accessibilityLabel: String

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("", text: $query, prompt: Text("Search"))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .focused($focused)
                    .textCursorOnHover()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(height: Theme.Size.sidebarSearchField)
            .background { Color.clear.frosted(in: Capsule()) }
            .contentShape(.rect)
            .onTapGesture { focused = true }
            .accessibilityLabel(accessibilityLabel)
        }
    }
}
