import AppKit
import SwiftUI
import Perception

/// About's Updates card: the result of the last check, and the button that runs the next one.
struct AboutUpdatesSection: View {
    @Environment(UpdateCoordinator.self) private var updates

    private static let notesMaxHeight: CGFloat = 160

    var body: some View {
        WithPerceptionTracking {
            Section {
                status
                if case .available(let update) = updates.state {
                    notes(update)
                }
                LabeledContent {
                    actions
                } label: {
                    EmptyView()
                }
            } header: {
                SettingsSectionHeader(.aboutUpdates)
            }
            .settingsAnchor(.aboutUpdates)
        }
    }

    @ViewBuilder private var status: some View {
        switch updates.state {
        case .idle, .checking:
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…").foregroundStyle(.secondary)
            }
        case .unavailable(let reason):
            Text(reason).foregroundStyle(.secondary)
        case .upToDate:
            Label("Minicast is up to date.", systemImage: "checkmark.circle")
        case .available(let update):
            Label("\(update.version.description) available", systemImage: "arrow.down.circle")
        case .downloading(let update):
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Downloading \(update.version.description)…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label("Couldn't check for updates: \(message)", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private func notes(_ update: AvailableUpdate) -> some View {
        ScrollView {
            Text(Self.markdown(update.notes))
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxHeight: Self.notesMaxHeight)
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if case .available(let update) = updates.state {
                Button("View on GitHub") { NSWorkspace.shared.open(update.pageURL) }
                Button("Update") { updates.install(update) }
                    .keyboardShortcut(.defaultAction)
            }
            if case .unavailable = updates.state {
                EmptyView()
            } else {
                Button("Check for Updates") { updates.check() }
                    .disabled(updates.isBusy)
            }
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
