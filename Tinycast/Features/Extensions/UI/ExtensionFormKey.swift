import SwiftUI

enum ExtensionFormKey {
    static let enterKeys: [KeyEquivalent] = [.return, KeyEquivalent("\u{3}")]

    static func isEnter(_ key: KeyEquivalent) -> Bool {
        enterKeys.contains { $0.isSameKey(as: key) }
    }

    enum Action: Equatable {
        case activate, submit, consume, ignored
    }

    static func resolve(
        field: ExtensionFormField, key: KeyEquivalent, modifiers: EventModifiers,
        repeating: Bool = false, menuOpen: Bool = false, composing: Bool = false
    ) -> Action {
        guard !menuOpen, !composing, field.isFocusable else { return .ignored }
        let modifiers = modifiers.intersection([.command, .control, .option, .shift])
        if isEnter(key) {
            if modifiers == .command { return repeating ? .consume : .submit }
            guard modifiers.isEmpty else { return .ignored }
            if field == .textArea { return .ignored }
            if field == .text || repeating { return .consume }
            return .activate
        }
        if key.isSameKey(as: .space), modifiers.isEmpty, field == .checkbox || field == .filePicker {
            return repeating ? .consume : .activate
        }
        return .ignored
    }
}
