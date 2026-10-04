import SwiftUI
import Perception

extension View {
    /// Publishes the selected row's frame for `scrollFollowsSelection`; only that row measures.
    func selectionFrame(_ selected: Bool) -> some View {
        overlay {
            if selected {
                GeometryReader { geometry in
                    WithPerceptionTracking {
                        Color.clear
                            .preference(
                                key: SelectionFrameKey.self, value: geometry.frame(in: .global))
                    }
                }
            }
        }
    }

    /// Keeps the keyboard selection in the band between the bars; needs `selectionFrame` on rows.
    func scrollFollowsSelection(
        _ scroll: ScrollIntent, row: String?, atOrigin: Bool, proxy: ScrollViewProxy
    ) -> some View {
        modifier(SelectionFollowing(scroll: scroll, row: row, atOrigin: atOrigin, proxy: proxy))
    }
}

private struct SelectionFrameKey: PreferenceKey {
    static var defaultValue: CGRect? { nil }

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

private struct SelectionFollowing: ViewModifier {
    let scroll: ScrollIntent
    let row: String?
    let atOrigin: Bool
    let proxy: ScrollViewProxy

    @State private var band = Band(insetTop: 0, height: 0)
    /// Both in window space: `frame(in: .scrollView)` is macOS 14, so the row is placed by hand.
    @State private var selection: CGRect?
    @State private var viewport: CGRect = .zero
    /// Where the selection is still owed a place; nil once it has one, and the pointer owns it.
    @State private var target: Target?

    /// The geometry the rule reads: the band's height, and the inset whose settling moves the rest.
    private struct Band: Equatable {
        var insetTop: CGFloat
        var height: CGFloat
    }

    private enum Target {
        /// Anywhere inside the band, by the least movement.
        case band
        /// The band's middle, which needs the row's measured frame to land exactly.
        case middle
    }

    func body(content: Content) -> some View {
        WithPerceptionTracking {
            content
                .onScrollMetricsChange(for: Band.self) {
                    Band(insetTop: $0.contentInsets.top, height: $0.containerSize.height)
                } action: { old, new in
                    band = new
                    // The inset settles after mount and moves the resting offset: restate a landing.
                    if old.insetTop != new.insetTop, scroll.kind != .follow {
                        return begin(scroll.kind)
                    }
                    align()
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewport = $0 }
                .onPreferenceChange(SelectionFrameKey.self) { frame in
                    selection = frame
                    align()
                }
                .onValueChange(of: scroll) { _, scroll in begin(scroll.kind) }
        }
    }

    private func begin(_ kind: ScrollIntent.Kind) {
        switch kind {
        case .top:
            target = nil
            proxy.scrollToOrigin()
        case .follow:
            target = .band
            align()
        case .center:
            target = .middle
            align()
        }
    }

    private func align() {
        guard let target, let row else { return }
        // Origin, not the row's top, so the first row's section header stays on screen.
        if atOrigin {
            self.target = nil
            return proxy.scrollToOrigin()
        }
        // The lazy stack dropped the selected row: bring it back by id, then re-check its frame.
        guard let selection else {
            return proxy.scrollTo(row, anchor: target == .middle ? .center : nil)
        }
        // A measured row centres exactly, so there is nothing left to watch for.
        if target == .middle {
            self.target = nil
            return proxy.scrollTo(row, anchor: .center)
        }
        guard
            let edge = SelectionReveal.edge(
                rowTop: selection.minY - viewport.minY, rowBottom: selection.maxY - viewport.minY,
                band: band.height)
        else {
            self.target = nil
            return
        }
        proxy.scrollTo(row, anchor: edge == .top ? .top : .bottom)
    }
}
