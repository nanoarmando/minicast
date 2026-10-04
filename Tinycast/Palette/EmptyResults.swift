import SwiftUI
import Perception

struct EmptyResults: View {
    let text: String
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.largeTitle)
                    .symbolRenderingMode(.hierarchical).foregroundStyle(.tertiary)
                Text(text).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
