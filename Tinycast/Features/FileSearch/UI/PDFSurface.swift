import PDFKit
import SwiftUI

/// A PDF drawn in process, where the wheel reaches it the way it reaches QuickLook's text view.
struct PDFSurface: NSViewRepresentable {
    let url: URL
    var zoom: QuickLookZoom?

    final class Coordinator {
        var zoomToken: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PreviewPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        context.coordinator.zoomToken = zoom?.token
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if let zoom, context.coordinator.zoomToken != zoom.token {
            context.coordinator.zoomToken = zoom.token
            if zoom.zoomsIn { view.zoomIn(nil) } else { view.zoomOut(nil) }
        }
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
        view.autoScales = true
    }

    static func dismantleNSView(_ view: PDFView, coordinator: Coordinator) {
        view.document = nil
    }
}

/// Clicking a page must not move the keyboard off the search field.
private final class PreviewPDFView: PDFView, KeyboardFocusRefusing {
    /// ⌘-scroll zooms around the pointer, the way it does on the card's images.
    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command), let document = documentView,
            let clip = document.enclosingScrollView?.contentView, document.frame.width > 0,
            document.frame.height > 0
        else { return super.scrollWheel(with: event) }
        let pointer = document.convert(event.locationInWindow, from: nil)
        let fraction = NSPoint(
            x: pointer.x / document.frame.width, y: pointer.y / document.frame.height)
        let offset = NSPoint(x: pointer.x - clip.bounds.minX, y: pointer.y - clip.bounds.minY)
        autoScales = false
        scaleFactor = min(
            max(scaleFactor * scrollZoomFactor(for: event), minScaleFactor), maxScaleFactor)
        layoutDocumentView()
        let anchored = NSPoint(
            x: fraction.x * document.frame.width - offset.x,
            y: fraction.y * document.frame.height - offset.y)
        clip.scroll(to: clip.constrainBoundsRect(NSRect(origin: anchored, size: clip.bounds.size)).origin)
        document.enclosingScrollView?.reflectScrolledClipView(clip)
    }
}
