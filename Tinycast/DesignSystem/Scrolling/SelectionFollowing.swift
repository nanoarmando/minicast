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

    @Environment(\.metrics) private var metrics
    @State private var position = Position(insetTop: 0, offset: 0)
    /// Both in window space: `frame(in: .scrollView)` is macOS 14, so the row is placed by hand.
    @State private var selection: CGRect?
    /// The full frame under the bars, the same one `edgeDissolve` masks.
    @State private var viewport: CGRect = .zero
    /// Where the selection is still owed a place; nil once it has one, and the pointer owns it.
    @State private var target: Target?
    /// Offsets scrolled from for this target: returning to an older one means the landing bounces.
    @State private var triedOffsets: [CGFloat] = []

    /// The inset whose settling moves the resting offset, and the offset itself.
    private struct Position: Equatable {
        var insetTop: CGFloat
        var offset: CGFloat
    }

    private enum Target {
        /// Anywhere inside the clear band, by the least movement.
        case band
        /// The band's middle, which needs the row's measured frame to land exactly.
        case middle
    }

    func body(content: Content) -> some View {
        WithPerceptionTracking {
            content
                .onScrollMetricsChange(for: Position.self) {
                    Position(insetTop: $0.contentInsets.top, offset: $0.contentOffset.y)
                } action: { old, new in
                    position = new
                    // The inset settles after mount and moves the resting offset: restate a landing.
                    if old.insetTop != new.insetTop, scroll.kind != .follow {
                        return begin(scroll.kind)
                    }
                    align()
                }
                .background {
                    Color.clear
                        .ignoresSafeArea()
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                            viewport = $0
                        }
                }
                .onPreferenceChange(SelectionFrameKey.self) { frame in
                    selection = frame
                    align()
                }
                .onValueChange(of: scroll) { _, scroll in begin(scroll.kind) }
        }
    }

    private func begin(_ kind: ScrollIntent.Kind) {
        triedOffsets = []
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
        let height = viewport.height
        let bands = metrics.dissolveBands
        guard height > 0,
            let edge = SelectionReveal.edge(
                rowTop: selection.minY - viewport.minY, rowBottom: selection.maxY - viewport.minY,
                top: bands.top, bottom: height - bands.bottom),
            !triedOffsets.dropLast().contains(position.offset)
        else {
            self.target = nil
            return
        }
        if triedOffsets.last != position.offset { triedOffsets.append(position.offset) }
        let limit = edge == .top ? bands.top : height - bands.bottom
        proxy.scrollTo(row, anchor: UnitPoint(x: 0.5, y: limit / height))
    }
}
