import AppKit
import SwiftUI

/// macOS 13 stand-in for `ScrollGeometry` (macOS 15), read from the backing `NSScrollView`.
struct ScrollMetrics: Equatable {
    /// Rests at `-contentInsets.top`, as SwiftUI's own offset does.
    var contentOffset: CGPoint = .zero
    var contentSize: CGSize = .zero
    var containerSize: CGSize = .zero
    var contentInsets = EdgeInsets()
}

extension View {
    /// Attach to a `ScrollView`: `onScrollGeometryChange` for macOS 13.
    func onScrollMetricsChange<Value: Equatable>(
        for type: Value.Type, of transform: @escaping (ScrollMetrics) -> Value,
        action: @escaping (Value, Value) -> Void
    ) -> some View {
        modifier(ScrollMetricsChange(transform: transform, action: action))
    }

    /// Attach to a `ScrollView`: true while the user scrolls it, false once it settles.
    func onLiveScrollChange(_ action: @escaping (Bool) -> Void) -> some View {
        background(ScrollObserver(target: .sibling, onLiveScroll: action))
    }

    /// Attach inside scroll content: whether at least half of this view shows in its scroll view.
    func onScrollVisibilityChanged(_ action: @escaping (Bool) -> Void) -> some View {
        background(ScrollObserver(target: .enclosing, onVisibility: action))
    }
}

private struct ScrollMetricsChange<Value: Equatable>: ViewModifier {
    let transform: (ScrollMetrics) -> Value
    let action: (Value, Value) -> Void
    @State private var last: Value?

    func body(content: Content) -> some View {
        content.background(
            ScrollObserver(
                target: .sibling,
                onMetrics: { metrics in
                    let value = transform(metrics)
                    guard value != last else { return }
                    let old = last ?? value
                    last = value
                    action(old, value)
                }))
    }
}

private struct ScrollObserver: NSViewRepresentable {
    let target: ScrollObserverView.Target
    var onLiveScroll: ((Bool) -> Void)?
    var onVisibility: ((Bool) -> Void)?
    var onMetrics: ((ScrollMetrics) -> Void)?

    init(
        target: ScrollObserverView.Target, onLiveScroll: ((Bool) -> Void)? = nil,
        onVisibility: ((Bool) -> Void)? = nil, onMetrics: ((ScrollMetrics) -> Void)? = nil
    ) {
        self.target = target
        self.onLiveScroll = onLiveScroll
        self.onVisibility = onVisibility
        self.onMetrics = onMetrics
    }

    func makeNSView(context: Context) -> ScrollObserverView { ScrollObserverView(target: target) }

    func updateNSView(_ view: ScrollObserverView, context: Context) {
        view.onLiveScroll = onLiveScroll
        view.onVisibility = onVisibility
        view.onMetrics = onMetrics
        view.attach()
    }
}

private final class ScrollObserverView: NSView {
    enum Target {
        /// The scroll view this view's frame covers: a background attached to the `ScrollView`.
        case sibling
        /// The scroll view this view scrolls inside of.
        case enclosing
    }

    let target: Target
    var onLiveScroll: ((Bool) -> Void)?
    var onVisibility: ((Bool) -> Void)?
    var onMetrics: ((ScrollMetrics) -> Void)?

    private weak var scrollView: NSScrollView?
    private var observers: [NotificationToken] = []
    private static let retryBudget = 10
    private static let retryDelay: TimeInterval = 0.05
    private var retriesLeft = 0
    private var isRetryPending = false
    private var isReportPending = false
    private var lastMetrics: ScrollMetrics?
    private var lastVisible: Bool?

    init(target: Target) {
        self.target = target
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attach()
    }

    override func layout() {
        super.layout()
        if isAttached { report() } else { attach() }
    }

    private var isAttached: Bool { scrollView?.window != nil && scrollView?.window === window }

    /// Resets the retry budget: every layout, hierarchy or update event is a fresh chance to attach.
    func attach() {
        retriesLeft = Self.retryBudget
        tryAttach()
    }

    private func tryAttach() {
        guard window != nil else { return detach() }
        if scrollView != nil, !isAttached { detach() }
        guard let found = findScrollView() else { return scheduleRetry() }
        guard found !== scrollView else { return report() }
        detach()
        scrollView = found
        let clip = found.contentView
        clip.postsBoundsChangedNotifications = true
        clip.postsFrameChangedNotifications = true
        found.documentView?.postsFrameChangedNotifications = true
        observe(NSView.boundsDidChangeNotification, of: clip) { $0.report() }
        observe(NSView.frameDidChangeNotification, of: clip) { $0.report() }
        if let document = found.documentView {
            observe(NSView.frameDidChangeNotification, of: document) { $0.report() }
        }
        observe(NSScrollView.willStartLiveScrollNotification, of: found) { $0.onLiveScroll?(true) }
        observe(NSScrollView.didEndLiveScrollNotification, of: found) { $0.onLiveScroll?(false) }
        report()
    }

    // SwiftUI splices the scroll view in a later pass, so a same-instant retry sees nothing new.
    private func scheduleRetry() {
        guard retriesLeft > 0, !isRetryPending else { return }
        retriesLeft -= 1
        isRetryPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in
            guard let self else { return }
            isRetryPending = false
            if !isAttached { tryAttach() }
        }
    }

    private func detach() {
        observers = []
        scrollView = nil
        lastMetrics = nil
        lastVisible = nil
    }

    private func observe(
        _ name: Notification.Name, of object: AnyObject,
        _ handler: @escaping @MainActor (ScrollObserverView) -> Void
    ) {
        let center = NotificationCenter.default
        let token = center.addObserver(forName: name, object: object, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                if let self { handler(self) }
            }
        }
        observers.append(NotificationToken(token, center: center))
    }

    // A programmatic scroll posts inside a SwiftUI update, where a state write would be dropped.
    private func report() {
        guard scrollView != nil, !isReportPending else { return }
        isReportPending = true
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isReportPending = false
                self.deliverReport()
            }
        }
    }

    private func deliverReport() {
        guard let scrollView else { return }
        if let onMetrics {
            let metrics = Self.metrics(of: scrollView)
            if metrics != lastMetrics {
                lastMetrics = metrics
                onMetrics(metrics)
            }
        }
        if let onVisibility {
            let visible = isMostlyVisible(in: scrollView)
            if visible != lastVisible {
                lastVisible = visible
                onVisibility(visible)
            }
        }
    }

    private static func metrics(of scrollView: NSScrollView) -> ScrollMetrics {
        let clip = scrollView.contentView
        let insets = scrollView.contentInsets
        let document = scrollView.documentView
        let contentHeight = document?.frame.height ?? 0
        // An unflipped document counts its offset up from the bottom; SwiftUI counts from the top.
        let offsetY =
            document?.isFlipped == false
            ? contentHeight - clip.bounds.maxY : clip.bounds.minY
        return ScrollMetrics(
            contentOffset: CGPoint(x: clip.bounds.minX, y: offsetY),
            contentSize: document?.frame.size ?? .zero,
            containerSize: scrollView.frame.size,
            contentInsets: EdgeInsets(
                top: insets.top, leading: insets.left, bottom: insets.bottom,
                trailing: insets.right))
    }

    private func isMostlyVisible(in scrollView: NSScrollView) -> Bool {
        let clip = scrollView.contentView
        let frame = convert(bounds, to: clip)
        guard frame.height > 0 else { return true }
        return frame.intersection(clip.bounds).height >= frame.height / 2
    }

    private func findScrollView() -> NSScrollView? {
        switch target {
        case .enclosing: return enclosingScrollView
        case .sibling: return coveredScrollView()
        }
    }

    /// The nearest scroll view whose frame best overlaps this one's; SwiftUI keeps them siblings.
    private func coveredScrollView() -> NSScrollView? {
        let own = convert(bounds, to: nil)
        guard own.width > 0, own.height > 0 else { return nil }
        var node = superview
        while let ancestor = node {
            let best = Self.scrollViews(under: ancestor)
                .map { ($0, Self.overlap(own, $0.convert($0.bounds, to: nil))) }
                .filter { $0.1 > 0.5 }
                .max { $0.1 < $1.1 }
            if let best { return best.0 }
            node = ancestor.superview
        }
        return nil
    }

    private static func scrollViews(under view: NSView) -> [NSScrollView] {
        view.subviews.flatMap { sub -> [NSScrollView] in
            if let scroll = sub as? NSScrollView { return [scroll] }
            return scrollViews(under: sub)
        }
    }

    /// Intersection over union, so a nested or neighbouring scroll view never wins by size alone.
    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let shared = intersection.width * intersection.height
        let union = lhs.width * lhs.height + rhs.width * rhs.height - shared
        return union > 0 ? shared / union : 0
    }
}
