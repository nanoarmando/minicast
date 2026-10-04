import AppKit
import Carbon.HIToolbox
import SwiftUI

/// macOS 13 stand-in for SwiftUI's `KeyPress` (macOS 14), read from the AppKit event.
struct KeyPressEvent {
    enum Result {
        case handled
        case ignored
    }

    struct Phases: OptionSet {
        let rawValue: Int
        static let down = Phases(rawValue: 1 << 0)
        static let `repeat` = Phases(rawValue: 1 << 1)
    }

    let key: KeyEquivalent
    let characters: String
    let modifiers: SwiftUI.EventModifiers
    let phase: Phases

    init(_ event: NSEvent) {
        // ⇧⇥ arrives as backtab; SwiftUI names it ⇥ with ⇧ held.
        let base =
            Int(event.keyCode) == kVK_Tab ? "\t" : (event.charactersIgnoringModifiers ?? "")
        key = KeyEquivalent(base.first ?? "\0")
        characters = event.characters ?? ""
        phase = event.isARepeat ? .repeat : .down
        let flags = event.modifierFlags
        var modifiers: SwiftUI.EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.capsLock) { modifiers.insert(.capsLock) }
        self.modifiers = modifiers
    }
}

extension KeyEquivalent {
    /// `KeyEquivalent` is only `Equatable` from macOS 14, so keys compare by their character.
    func isSameKey(as other: KeyEquivalent) -> Bool { character == other.character }

    static func ~= (pattern: KeyEquivalent, value: KeyEquivalent) -> Bool {
        value.isSameKey(as: pattern)
    }
}

/// A window that routes keys itself from `sendEvent`, after its own AppKit key rules.
@MainActor
protocol KeyPressRoutingWindow: NSWindow {}

/// Hands key-downs to the `onKeyDown` handlers of the key window, innermost first.
@MainActor
enum KeyPressRouter {
    private struct WeakAnchor {
        weak var view: KeyPressAnchorView?
    }

    private static var anchors: [WeakAnchor] = []
    private static var monitor: Any?

    /// True when a handler consumed the event.
    static func dispatch(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let window = event.window, window.isKeyWindow else {
            return false
        }
        let press = KeyPressEvent(event)
        // The smaller frame is the inner view, which SwiftUI would have asked first.
        let candidates = anchors.compactMap(\.view)
            .filter { $0.window === window }
            .enumerated()
            .sorted { lhs, rhs in
                let (left, right) = (lhs.element.area, rhs.element.area)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
        return candidates.contains { $0.element.handle(press) == .handled }
    }

    fileprivate static func register(_ anchor: KeyPressAnchorView) {
        anchors.removeAll { $0.view == nil || $0.view === anchor }
        anchors.append(WeakAnchor(view: anchor))
        installMonitor()
    }

    fileprivate static func unregister(_ anchor: KeyPressAnchorView) {
        anchors.removeAll { $0.view == nil || $0.view === anchor }
    }

    private static func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.window is KeyPressRoutingWindow { return event }
            return dispatch(event) ? nil : event
        }
    }
}

private final class KeyPressAnchorView: NSView {
    var keys: [KeyEquivalent]?
    var phases: KeyPressEvent.Phases = [.down, .repeat]
    var isEnabled = true
    var action: (KeyPressEvent) -> KeyPressEvent.Result = { _ in .ignored }

    var area: CGFloat { bounds.width * bounds.height }

    func handle(_ press: KeyPressEvent) -> KeyPressEvent.Result {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, phases.contains(press.phase) else {
            return .ignored
        }
        if let keys, !keys.contains(where: { $0.isSameKey(as: press.key) }) { return .ignored }
        return action(press)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            KeyPressRouter.unregister(self)
        } else {
            KeyPressRouter.register(self)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct KeyPressAnchor: NSViewRepresentable {
    let keys: [KeyEquivalent]?
    let phases: KeyPressEvent.Phases
    let isEnabled: Bool
    let action: (KeyPressEvent) -> KeyPressEvent.Result

    func makeNSView(context: Context) -> KeyPressAnchorView { KeyPressAnchorView() }

    func updateNSView(_ view: KeyPressAnchorView, context: Context) {
        view.keys = keys
        view.phases = phases
        view.isEnabled = isEnabled
        view.action = action
    }
}

extension View {
    /// macOS 13 `onKeyPress`: blind to focus, so a field passes its own focus as `isEnabled`.
    func onKeyDown(
        keys: [KeyEquivalent]? = nil,
        phases: KeyPressEvent.Phases = [.down, .repeat],
        isEnabled: Bool = true,
        action: @escaping (KeyPressEvent) -> KeyPressEvent.Result
    ) -> some View {
        background(
            KeyPressAnchor(keys: keys, phases: phases, isEnabled: isEnabled, action: action)
        )
    }
}
