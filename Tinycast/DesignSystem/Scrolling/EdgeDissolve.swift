import SwiftUI
import Perception

/// Scroll-driven edge mask for a list underlapping the palette's floating bars. See `docs/ui.md`.
struct EdgeDissolveMask: ViewModifier {
    /// Band lengths: the bar's height plus its overshoot into the list — 32px top, 28px bottom.
    private var topFade: CGFloat {
        metrics.size.headerHeight + metrics.size.headerPadding + metrics.scaled(32)
    }
    private var bottomFade: CGFloat { metrics.size.bottomBarHeight + metrics.scaled(28) }
    private static let topMinAlpha: CGFloat = 0.15
    private static let bottomMinAlpha: CGFloat = 0.25
    @Environment(\.metrics) private var metrics

    /// Nil until measured, so rows never sit opaque under the bars while the probe attaches.
    @State private var scroll: ScrollState?

    private struct ScrollState: Equatable {
        var top: CGFloat
        var bottom: CGFloat
        var canScroll: Bool
    }

    func body(content: Content) -> some View {
        WithPerceptionTracking {
            content
                .onScrollMetricsChange(for: ScrollState.self) { geo in
                    let visible =
                        geo.containerSize.height - geo.contentInsets.top
                        - geo.contentInsets.bottom
                    return ScrollState(
                        top: geo.contentOffset.y + geo.contentInsets.top,
                        bottom: geo.contentSize.height + geo.contentInsets.bottom
                            - geo.containerSize.height - geo.contentOffset.y,
                        canScroll: geo.contentSize.height > visible
                    )
                } action: { _, new in
                    scroll = ScrollState(
                        top: max(0, new.top), bottom: max(0, new.bottom), canScroll: new.canScroll)
                }
                .mask(
                    // Must span the scroll view's *full* frame — the bars' safe-area insets would otherwise shift the gradient inward, clipping the underlap regions to black.
                    GeometryReader { geo in
                        WithPerceptionTracking {
                            LinearGradient(
                                stops: stops(height: geo.size.height),
                                startPoint: .top, endPoint: .bottom
                            )
                        }
                    }
                    .ignoresSafeArea()
                )
        }
    }

    private func stops(height: CGFloat) -> [Gradient.Stop] {
        let state = scroll ?? ScrollState(top: topFade, bottom: bottomFade, canScroll: true)
        guard state.canScroll, height > 0 else { return [.init(color: .black, location: 0)] }
        // Midpoint alpha eases from 1 toward the floor as a full band of content scrolls past.
        let topAlpha = 1 - (1 - Self.topMinAlpha) * min(state.top / topFade, 1)
        let bottomAlpha = 1 - (1 - Self.bottomMinAlpha) * min(state.bottom / bottomFade, 1)
        return [
            .init(color: .black.opacity(0), location: 0),
            .init(color: .black.opacity(topAlpha), location: topFade / 2 / height),
            .init(color: .black, location: topFade / height),
            .init(color: .black, location: 1 - bottomFade / height),
            .init(color: .black.opacity(bottomAlpha), location: 1 - bottomFade / 2 / height),
            .init(color: .black.opacity(0), location: 1)
        ]
    }
}

extension View {
    /// Attach to a `ScrollView` that underlaps the palette's floating bars (before `thinScrollbar`, so the scrollbar overlay stays unmasked).
    func edgeDissolve() -> some View {
        modifier(EdgeDissolveMask())
    }
}
