import SwiftUI

/// macOS 13 stand-in for `ContentUnavailableView`: a centred symbol, title and explanation.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xs)
            Text(title)
                .font(.title3.weight(.semibold))
            if let description {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func search(text: String) -> EmptyStateView {
        EmptyStateView(
            title: "No Results for “\(text)”", systemImage: "magnifyingglass",
            description: "Check the spelling or try a new search.")
    }
}
