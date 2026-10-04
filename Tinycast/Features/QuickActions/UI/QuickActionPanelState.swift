import Foundation
import Perception

/// Owned by the controller, not the view, so a reply keeps arriving while SwiftUI re-renders.
@MainActor
@Perceptible
final class QuickActionPanelState {
    enum Phase: Equatable {
        case running
        case finished
        case failed(String)
    }

    let action: QuickAction
    let original: String
    private(set) var output = ""
    private(set) var phase: Phase = .running

    @PerceptionIgnored private var cachedDiff: [TextDiffEngine.Chunk]?

    var diff: [TextDiffEngine.Chunk] {
        guard action.showsDiff, phase == .finished else { return [] }
        if let cachedDiff { return cachedDiff }
        let chunks = TextDiffEngine.diff(original: original, modified: output)
        cachedDiff = chunks
        return chunks
    }

    var isRunning: Bool { phase == .running }

    var canReplace: Bool { phase == .finished && !output.isEmpty }

    init(action: QuickAction, original: String) {
        self.action = action
        self.original = original
    }

    func append(_ delta: String) {
        output += delta
    }

    func finish(_ text: String) {
        output = text
        phase = .finished
    }

    func fail(_ message: String) {
        phase = .failed(message)
    }
}
