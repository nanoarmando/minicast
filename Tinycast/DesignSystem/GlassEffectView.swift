import SwiftUI

/// Behind-window blur for Tinycast's borderless panels; the caller clips it to the panel's shape.
struct GlassEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // A non-activating panel never makes the app active, so the blur must not wait for it.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

extension View {
    /// A panel that is its own window: the desktop blurred behind it, inside `shape`.
    func glassSurface(in shape: some Shape) -> some View {
        background(GlassEffectView().clipShape(shape))
    }
}
