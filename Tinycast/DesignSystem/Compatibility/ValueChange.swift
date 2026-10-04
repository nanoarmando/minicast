import SwiftUI

/// macOS 14's `onChange(of:initial:_:)` shape, built on the macOS 13 single-value form.
private struct ValueChange<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { if initial { action(value, value) } }
            // The capture list keeps the value from the render before the change.
            .onChange(of: value) { [value] newValue in action(value, newValue) }
    }
}

extension View {
    func onValueChange<Value: Equatable>(
        of value: Value, initial: Bool = false, _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        modifier(ValueChange(value: value, initial: initial, action: action))
    }

    func onValueChange<Value: Equatable>(
        of value: Value, initial: Bool = false, _ action: @escaping () -> Void
    ) -> some View {
        modifier(ValueChange(value: value, initial: initial) { _, _ in action() })
    }
}
