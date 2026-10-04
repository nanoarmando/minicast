import Foundation

/// Owns the launcher's fallback section: what it offers for a query, and where running one goes.
@MainActor
final class FallbackCoordinator {
    private let store: FallbackStore
    private let settings: AppSettings
    private let visibility: VisibilityStore
    /// The destinations a fallback hands its query to; nothing here is this type's own state.
    private unowned let core: AppCore

    init(
        store: FallbackStore, settings: AppSettings,
        visibility: VisibilityStore, core: AppCore
    ) {
        self.store = store
        self.settings = settings
        self.visibility = visibility
        self.core = core
    }

    /// Everything this Mac can offer today, in the reader's order — Settings lists exactly this.
    var available: [Fallback] { store.ordered(candidates) }

    /// The launcher's rows. An empty query is nobody's input, so it earns no section at all.
    func entries(for query: String) -> [(fallback: Fallback, entry: AppEntry)] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return available.filter(store.isEnabled).compactMap { fallback in
            entry(for: fallback).map { (fallback, $0) }
        }
    }

    func entry(for fallback: Fallback) -> AppEntry? {
        switch fallback {
        case .builtin(let builtin): return CommandCatalog.makeEntry(builtin.command)
        }
    }

    /// The one funnel; each destination takes the query as the input it was already asking for.
    func run(_ fallback: Fallback, query: String) {
        switch fallback {
        case .builtin(.quickAI): core.quickAICoordinator.ask(query)
        case .builtin(.searchFiles): core.fileSearchCoordinator.show(query: query)
        case .builtin(.runShellCommand): core.customCommandCoordinator.runShellCommand(query)
        case .builtin(.define): core.dictionaryCoordinator.show(term: query)
        }
    }

    /// The section's gear and the row's own action; the palette closes behind the pane.
    func showSettings() {
        core.paletteCoordinator.hidePalette(restoreFocus: false)
        core.settingsCoordinator.showSettings(tab: .fallbacks)
    }

    /// A fallback whose feature is switched off is offered nowhere, Settings included.
    private var candidates: [Fallback] {
        Fallback.Builtin.allCases.filter(isAvailable).map(Fallback.builtin)
    }

    private func isAvailable(_ builtin: Fallback.Builtin) -> Bool {
        switch builtin {
        case .quickAI: return settings.aiEnabled
        case .searchFiles: return settings.fileSearchEnabled
        // Its own capability: this shell is not the custom-command library's switch to hold.
        case .runShellCommand: return true
        // Settings › Commands is Define's only switch, so hiding the command there hides this too.
        case .define: return visibility.isVisible(CommandCatalog.makeEntry(.define))
        }
    }
}
