import SwiftUI
import Perception

/// An action's own shortcut, matched before the palette's bindings see it.
enum ExtensionShortcutKeys {
    @MainActor
    static func handle(
        _ press: KeyPressEvent, screen: ExtensionCommandScreen?, selection: Int
    ) -> KeyPressEvent.Result {
        guard let screen, !press.modifiers.isEmpty else { return .ignored }
        return screen.dispatchShortcut(
            key: ASCIIKeyboardLayout.keyEquivalent(fallingBackTo: press.key),
            modifiers: press.modifiers,
            at: selection) ? .handled : .ignored
    }
}

struct ExtensionToastSlot: ViewModifier {
    @Environment(\.metrics) private var metrics
    let extensions: ExtensionManager
    let showing: Bool

    func body(content: Content) -> some View {
        WithPerceptionTracking {
            let toast = showing ? extensions.toasts.last : nil
            ZStack(alignment: .leading) {
                content
                    .opacity(toast == nil ? 1 : 0)
                    .allowsHitTesting(toast == nil)
                if let toast {
                    ExtensionToastPill(
                        toast: toast, onAction: { extensions.runToastAction(token: $0) },
                        onDismiss: { extensions.hide(toast: toast.id) }
                    )
                    .padding(.trailing, metrics.spacing.md)
                    .id(toast.id)
                    .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toast?.id)
        }
    }
}

struct ExtensionFormKeys: ViewModifier {
    let field: ExtensionFormField
    let isFocused: Bool
    let onActivate: () -> Void
    let onSubmit: () -> Void
    @Environment(PaletteState.self) private var palette

    func body(content: Content) -> some View {
        WithPerceptionTracking {
            content.onKeyDown(keys: ExtensionFormKey.enterKeys + [.space], isEnabled: isFocused) {
                press in
                switch ExtensionFormKey.resolve(
                    field: field, key: press.key, modifiers: press.modifiers,
                    repeating: press.phase == .repeat, menuOpen: palette.menuOpen,
                    composing: palette.isComposing)
                {
                case .activate: onActivate()
                case .submit: onSubmit()
                case .consume: break
                case .ignored: return .ignored
                }
                return .handled
            }
        }
    }
}
