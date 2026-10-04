import SwiftUI
import Perception

struct SettingsSidebarView: View {
    @Environment(SettingsNavigationState.self) private var navigation
    @Environment(\.appearsActive) private var appearsActive
    @State private var query = ""
    @State private var highlighted: SettingsSearchEntry.ID?
    @FocusState private var searchFocused: Bool

    private var results: [SettingsSearchEntry] { SettingsSearchCatalog.results(for: query) }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                SidebarSearchField(
                    query: $query, focused: $searchFocused, accessibilityLabel: "Search settings")
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
                    .onKeyDown(keys: [.upArrow, .downArrow, .return], isEnabled: searchFocused) {
                        stepResults($0.key)
                    }
                if query.isEmpty {
                    browse
                } else {
                    found
                }
            }
            .onExitCommand {
                query = ""
                searchFocused = false
            }
            .background(focusShortcut)
        }
    }

    private var browse: some View {
        List(selection: selection) {
            WithPerceptionTracking {
                ForEach(SettingsSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.tabs) { tab in
                            Label {
                                Text(tab.title)
                            } icon: {
                                SettingsTabIcon(
                                    systemImage: tab.systemImage,
                                    tint: appearsActive
                                        ? (navigation.tab == tab ? Color.primary : Color.accentColor)
                                        : Color.secondary)
                            }
                            .tag(tab)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        // Pin the style before mounting; the implicit sidebar style paints icons a frame late.
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder private var found: some View {
        if results.isEmpty {
            // Greedy: a finite max height here becomes a constraint that shrinks the whole window.
            EmptyStateView.search(text: query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // A second `List`, so result IDs and `SettingsTab` never share a selection namespace.
            List(selection: $highlighted) {
                WithPerceptionTracking {
                    Section("Results") {
                        ForEach(results) { entry in
                            SettingsSearchResultRow(entry: entry).tag(entry.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            // Arrowing through results moves the pane with the selection, as System Settings does.
            .onValueChange(of: highlighted) { _, id in
                guard let entry = results.first(where: { $0.id == id }) else { return }
                navigation.select(entry.tab, revealing: entry.target)
            }
        }
    }

    /// ⌘F with no menu item to hang it on; zero-sized so it only ever contributes the shortcut.
    private var focusShortcut: some View {
        Button("Search Settings") { searchFocused = true }
            .keyboardShortcut("f", modifiers: .command)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }

    /// From the field, the arrows walk the results and Return opens the first, as `.searchable` did.
    private func stepResults(_ key: KeyEquivalent) -> KeyPressEvent.Result {
        let results = results
        guard !results.isEmpty else { return .ignored }
        let index = results.firstIndex { $0.id == highlighted }
        switch key {
        case .downArrow:
            highlighted = results[min((index ?? -1) + 1, results.count - 1)].id
        case .upArrow:
            highlighted = results[max((index ?? results.count) - 1, 0)].id
        default:
            guard index == nil else { return .ignored }
            highlighted = results[0].id
        }
        return .handled
    }

    /// `List` hands back an optional selection; routing it through `select` records history.
    private var selection: Binding<SettingsTab?> {
        Binding(
            get: { navigation.tab },
            set: { if let tab = $0 { navigation.select(tab) } }
        )
    }
}

private struct SettingsSearchResultRow: View {
    let entry: SettingsSearchEntry

    var body: some View {
        WithPerceptionTracking {
            Label {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(entry.title).lineLimit(1)
                    Text(entry.breadcrumb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                SettingsTabIcon(systemImage: entry.tab.systemImage, tint: .accentColor)
            }
            // Centred, not first-baseline: the tile sits against a two-line title and breadcrumb.
            .labelStyle(CenteredLabelStyle())
        }
    }
}

private struct CenteredLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            configuration.icon
            configuration.title
        }
    }
}
