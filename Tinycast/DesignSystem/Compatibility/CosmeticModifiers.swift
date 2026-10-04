import AppKit
import SwiftUI

/// macOS 14+ polish applied where the system has it; macOS 13 keeps the plain look.
extension View {
    /// The chrome draws the focused edge, so the system ring would be a second one.
    @ViewBuilder
    func focusRingHidden() -> some View {
        if #available(macOS 14, *) { focusEffectDisabled() } else { self }
    }

    /// The pulsing progress glyph; static on macOS 13.
    @ViewBuilder
    func progressSymbolPulse() -> some View {
        if #available(macOS 14, *) {
            symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing)
        } else {
            self
        }
    }

    /// A symbol swap that morphs; a plain cut on macOS 13.
    @ViewBuilder
    func symbolReplaceTransition() -> some View {
        if #available(macOS 14, *) { contentTransition(.symbolEffect(.replace)) } else { self }
    }

    /// Vertical breathing room inside a scroll view, kept scrollable past it.
    @ViewBuilder
    func verticalScrollContentMargins(_ length: CGFloat) -> some View {
        if #available(macOS 14, *) {
            contentMargins(.vertical, length, for: .scrollContent)
        } else {
            safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: length) }
                .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: length) }
        }
    }

    /// Bounces only when the content overflows, unless `always`; system default before 13.3.
    @ViewBuilder
    func scrollBounce(always: Bool = false) -> some View {
        if #available(macOS 13.3, *) {
            scrollBounceBehavior(always ? .always : .basedOnSize)
        } else {
            self
        }
    }

    @ViewBuilder
    func secondaryTextScale() -> some View {
        if #available(macOS 14, *) { textScale(.secondary) } else { self }
    }

    /// A revealed secret is no draft to rewrite; macOS 13 has no Writing Tools to refuse.
    @ViewBuilder
    func writingToolsDisabled() -> some View {
        if #available(macOS 15, *) { writingToolsBehavior(.disabled) } else { self }
    }

    /// The I-beam over a plain text field, whose own cursor rect misses its padding.
    func textCursorOnHover() -> some View {
        modifier(TextCursorOnHover())
    }
}

private struct TextCursorOnHover: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                guard inside != pushed else { return }
                pushed = inside
                if inside { NSCursor.iBeam.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                if pushed { NSCursor.pop() }
                pushed = false
            }
    }
}
