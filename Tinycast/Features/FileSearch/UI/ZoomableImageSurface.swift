import AppKit
import SwiftUI

/// A ⌘+ / ⌘− press for the Quick Look card; a new token is a new step.
struct QuickLookZoom: Equatable {
    let token: UUID
    let zoomsIn: Bool
}

/// An image the card can pinch, scroll and step: Quick Look's own view has no zoom in this panel.
struct ZoomableImageSurface: NSViewRepresentable {
    let url: URL
    let zoom: QuickLookZoom

    final class Coordinator {
        var zoomToken: UUID?
        var loadTask: Task<Void, Never>?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ZoomableImageScrollView {
        let view = ZoomableImageScrollView()
        context.coordinator.zoomToken = zoom.token
        let url = url
        context.coordinator.loadTask = Task { [weak view] in
            let data = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: url, options: .mappedIfSafe)
            }.value
            guard !Task.isCancelled, let data else { return }
            view?.show(NSImage(data: data))
        }
        return view
    }

    func updateNSView(_ view: ZoomableImageScrollView, context: Context) {
        guard context.coordinator.zoomToken != zoom.token else { return }
        context.coordinator.zoomToken = zoom.token
        view.step(zoomingIn: zoom.zoomsIn)
    }

    static func dismantleNSView(_ view: ZoomableImageScrollView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        view.show(nil)
    }
}

final class ZoomableImageScrollView: NSScrollView, KeyboardFocusRefusing, PaletteCursorOwning {
    private let imageView = PanningImageView()
    /// While fitted, a resize refits; any zoom leaves the user's magnification alone.
    private var isFitted = true
    private static let stepFactor: CGFloat = 1.25
    private static let maxMagnification: CGFloat = 16

    init() {
        super.init(frame: .zero)
        contentView = CenteringClipView()
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        allowsMagnification = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.onMouseDown = { [weak self] event in self?.mouseDownOnImage(event) }
        documentView = imageView
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(_ image: NSImage?) {
        imageView.image = image
        imageView.frame = NSRect(origin: .zero, size: image.map(Self.pixelSize) ?? .zero)
        fit()
    }

    func step(zoomingIn: Bool) {
        guard imageView.image != nil else { return }
        zoom(to: magnification * (zoomingIn ? Self.stepFactor : 1 / Self.stepFactor))
    }

    override func layout() {
        super.layout()
        if isFitted { fit() }
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        isFitted = false
    }

    /// Pinch never reaches a non-activating panel, so ⌘-scroll is the pointer-anchored zoom.
    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command), imageView.image != nil else {
            return super.scrollWheel(with: event)
        }
        zoom(
            to: magnification * scrollZoomFactor(for: event),
            centeredAt: contentView.convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) { updateCursor() }

    override func mouseEntered(with event: NSEvent) { updateCursor() }

    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    private var isPannable: Bool {
        let document = imageView.frame.size
        let visible = contentView.bounds.size
        return document.width > visible.width + 0.5 || document.height > visible.height + 0.5
    }

    private func updateCursor() {
        (isPannable ? NSCursor.openHand : NSCursor.arrow).set()
    }

    private func mouseDownOnImage(_ event: NSEvent) {
        if event.clickCount == 2 { return toggleActualSize() }
        guard isPannable, let window else { return }
        let start = event.locationInWindow
        let origin = contentView.bounds.origin
        NSCursor.closedHand.set()
        // A tracking loop: the panel's cursor policy runs in sendEvent, which this bypasses.
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
            next.type == .leftMouseDragged
        {
            let moved = NSPoint(
                x: origin.x - (next.locationInWindow.x - start.x) / magnification,
                y: origin.y - (next.locationInWindow.y - start.y) / magnification)
            let bounds = NSRect(origin: moved, size: contentView.bounds.size)
            contentView.scroll(to: contentView.constrainBoundsRect(bounds).origin)
            reflectScrolledClipView(contentView)
        }
        updateCursor()
    }

    private func toggleActualSize() {
        if isFitted || magnification != 1 { zoom(to: 1) } else { fit() }
    }

    private func zoom(to target: CGFloat, centeredAt point: NSPoint? = nil) {
        let visible = documentVisibleRect
        setMagnification(
            min(max(target, minMagnification), maxMagnification),
            centeredAt: point ?? NSPoint(x: visible.midX, y: visible.midY))
        isFitted = false
    }

    private func fit() {
        let size = imageView.frame.size
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return }
        let fitted = min(bounds.width / size.width, bounds.height / size.height)
        minMagnification = min(fitted, 1)
        maxMagnification = max(Self.maxMagnification, fitted)
        magnification = fitted
        isFitted = true
    }

    /// 1:1 means one image pixel per point, not the DPI the file declares.
    private static func pixelSize(of image: NSImage) -> NSSize {
        guard let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 else {
            return image.size
        }
        return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}

/// Every click is the scroll view's: a drag pans and a double-click toggles fit and 1:1.
private final class PanningImageView: NSImageView {
    var onMouseDown: ((NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) { onMouseDown?(event) }
}

/// One wheel line counts as ten precise points, so a mouse and a trackpad zoom at a similar pace.
func scrollZoomFactor(for event: NSEvent) -> CGFloat {
    pow(1.01, event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 10))
}

/// A plain clip view pins a smaller document to the bottom-left corner.
private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let document = documentView?.frame else { return rect }
        if rect.width > document.width { rect.origin.x = (document.width - rect.width) / 2 }
        if rect.height > document.height { rect.origin.y = (document.height - rect.height) / 2 }
        return rect
    }
}
