# Architecture

How Minicast is wired together. Per-feature internals live in [features/](README.md#features);
conventions for writing new code live in [standards.md](standards.md).

## The layering

Independently of the folder tree, every mature subsystem has converged on the same four layers, and the
`Tests/` harnesses are what hold them apart. Each layer is consumed by the one below it.

| Layer | Rule | Members (representative) |
| --- | --- | --- |
| **Pure** | Foundation only. No AppKit, no clock, no network, no filesystem; every environment fact is an injected parameter. Compiled verbatim by a harness, so it cannot drift. | `SearchRelevance`, `LauncherMatch`, `EntryNaming`, `ScriptRomanization`, `LauncherOrder`, `LauncherSuggestions`, `LauncherRankingStore`, `SearchScopes`, `FileSearch{Query,Result,Scope}`, `Calculator/*`, `EmojiCatalog`, `EmojiGridGeometry`, `SystemAction`, `VolumeLevel`, `WindowCommand`, `WindowPlacementEngine`, `WindowActionMemory`, `WindowLayout/*`, `CustomWindowSize{,Store}`, `Room/*`, `PaletteRowIndex`, `Uninstall{Target,SearchRoot,Rules,Protection,Plan}`, `AppleShortcut`, `ShellCommandRunner`, `DoubleTap{Modifier,Detector}`, `ClipboardStore`, `RaycastDecoder`, `AppSettingsKey`, `SettingsBackupCoverage`, `SettingsFile{JSON,Key,Value,Format,Binding,Issue,Identity}`, `HotKeySpelling`, `WindowManagementFileFormat`, `MeetingLink`, `MeetingEvent`, `UpcomingWindow`, `MeetingDay`, `MenuBarSummary`, `AutoJoinPolicy`, `EventDraft` |
| **Effect** | All platform I/O, one folder per feature. | `AppIndex`, `FileSearchService`, `SettingsPaneScanner`, `AXWindowAccess`, `AXScreens`, `WindowInventory`, `WindowLayoutRunner`, `RoomWindowSweep`, `RoomRunner`, `IconCache`, `WindowMover`, `UninstallScanner`, `UninstallRunner`, `SystemActionRunner`, `LinkLauncher`, `TextInjector`, `CurrencyRateStore`, `Paster`, `Scrypt`, `HotKeyCenter`, `HyperKeyTap`, `ModifierTapMonitor`, `RunningAppsMonitor`, `CalendarStore`, `MeetingLauncher`, `MeetingClock`, `AppleShortcutRunner`, `SettingsFileRepository`, `SettingsFileMonitor`, `WindowManagementSettingsFile` |
| **Perceptible state** | `@MainActor @Perceptible` stores, sessions, indices and state types, published to views. | `AppCore`, `AppSettings`, `PaletteState`, the stores and sessions below |
| **View** | SwiftUI screens, views and each feature's coordinator — declarative, thin. | every `UI/` and `Settings/` folder |


In the folder tree those become `Model/`, `Service/`, and `UI/` plus `Settings/` — perceptible state lives
in whichever of the two owns it.

- **`Model/` — pure.** Foundation only, plus SQLite3 or CoreGraphics where the data demands it.
  Everything from the environment is **injected**: `CalcEngine` takes `now` / `calendar` / `rates`,
  `LauncherRankingStore` takes `now` and its file URL, `WindowActionMemory` takes `now` as a parameter,
  and `UninstallRules` is handed directory *names* rather than URLs. This is the layer that **decides** things.
- **`Service/` — effects.** Stores, monitors, runners, scanners and AppKit glue. Every `AXUIElement`
  call, `CGEventTap`, `NSWorkspace.open`, `URLSession` request, `FileManager` walk and CoreAudio read
  lives here. This is the layer that **does** things.
- **`UI/` and `Settings/` — views**, plus the feature's coordinator. Declarative, thin, holding no policy.

The rule is checkable, which is the point: **a file under `Model/` may not import AppKit or SwiftUI**,
because the harnesses compile the shipped sources rather than a copy. A harness that stops compiling is
the signal that a decision leaked into the effect layer, or an effect into the decision layer.

The boundary keeps effects out of decisions: `CalcEngine.evaluate` is handed a finished
`CurrencyRates?` rather than reaching for one, which is what keeps it Foundation-only and testable.
Confirmation gates live in the coordinator, never in the runner — which is why `ShellCommandRunner`
and `SystemActionRunner` stay harness-compilable while the "are you sure?" step still cannot be bypassed.

Two things sit deliberately outside a feature folder: `Features/PaletteRowIndex.swift`, because the
palette rather than any one feature owns the flat selection index, and `DesignSystem/` + `Platform/`,
the shared primitives and system shims every feature draws on. Neither may depend on a feature.

## Single-owner core

`AppCore.shared` (`App/AppCore.swift`) is a `@MainActor @Perceptible` singleton owning every long-lived
thing in the app: the stores (`AppIndex`, `ClipboardStore`, `CustomCommandStore`, `WindowLayoutStore`,
`RoomStore`, `FavoritesStore`, `VisibilityStore`, `AliasStore`, `FallbackStore`, `LauncherRankingStore`,
`CalculatorHistoryStore`, `CurrencyRateStore`, `FrequentEmojiStore`, `PinnedEmojiStore`, `CalendarStore`,
`ChatHistoryStore`, `CustomQuickActionStore`), the managers, monitors and clocks (`ClipboardManager`,
the opt-in `ClipboardTextIndexer`, the opt-in `SettingsFileRepository`, `HotKeyManager`, `HyperKeyTap`,
`RunningAppsMonitor`, `ExtensionManager`, `MCPServerManager`, `InstalledAIManager`, `MeetingClock`), the
shared state (`AppSettings`, `PaletteState`, `FileSearchSession`, `DictionarySession`,
`UninstallSession`, `RoomSession`, `AIChatSurfacesState`), and the twenty-four feature coordinators.

`AppDelegate.applicationDidFinishLaunching` calls `AppCore.shared.start()` and nothing else. That is the
one wiring point, and `start()` reads as the app's whole boot sequence in one screen.

**Feature actions live on that feature's coordinator, and a view must never reach past a coordinator
into a store to mutate it.** That is the rule; `AppCore` holds only the closure wiring that connects a
hotkey to a coordinator. Views inject `AppCore` through `@Environment` and use it as the *locator* for
those coordinators — `core.customCommandCoordinator.…` is the shape, and the alternative
is injecting fifteen coordinators separately for no gain. Reading a store off `AppCore` to render it is
fine too; deciding something with one is what the rule forbids. `showNotice`, `confirm`,
`reportFailure`, `showMessage` and `pickVolume` are forwarders on `AppCore` itself, so
`DialogController` and `MessageHUDController` stay single-owned.

New long-lived state belongs on `AppCore`, wired in `start()`. Do not create a competing singleton: this is a singleton, not a container.

Clipboard text recognition runs outside the process. `AppCore` owns the indexer;
the stateless `ClipboardTextWorker` runs one bundled `ClipboardTextHelper` per item, from
`Contents/Helpers`, and reaps it before returning. Vision's and PDFKit's allocations therefore belong
to a process that exits, and the helper — which has no database, clipboard or settings access — is
handed an input path and answers with bounded text down a pipe.

## Entry points and windows

`TinycastApp` (`@main`) declares only two `MenuBarExtra` scenes — Minicast's own item and the
calendar's, each inserted by one preference and independent of the other; everything else visible is
driven imperatively from AppKit. Extension menu extras are dynamic `NSStatusItem`s owned entirely by
`Features/Extensions/`, through `ExtensionManager`, with no scene or lifecycle wiring in the core.

- **Command palette** — a borderless floating `NSPanel` (`Palette/PalettePanel.swift`) hosting SwiftUI
  via `NSHostingView`, managed by `PaletteWindowController`. It toggles between a compact bar and the
  full launcher by resizing the window. The controller **solely** owns the frame, resolved once per show
  to a top-left anchor so it grows downward, and the hosting view sets `sizingOptions = []` so SwiftUI
  never drives the window size — without that the hosting view resizes the panel to fit content and the
  top edge drifts on the compact↔expanded swap. The panel auto-dismisses on `windowDidResignKey`,
  unless a modal panel holds key.
  See [features/palette.md](features/palette.md).
- **Settings** — a titled `NSWindow` through `Windows/AppWindowController.swift`, owned by
  `SettingsCoordinator`. SwiftUI `Settings` and `Window` scenes are unreliable for accessory apps, so
  this is deliberate. Its lifecycle is independent of the palette's in both directions. About is a
  Settings pane (`Windows/About/AboutView.swift`), not a window of its own.
- **AI Chat** — a titled `AppWindowController` window owned by `AIChatCoordinator`: an
  `NSSplitViewController` with a collapsible sidebar of saved chats beside the open conversation, as
  Settings is built. The conversation lives on `AppCore.aiChats`, not the window, so closing it cancels
  nothing. Quick AI is the same feature's palette screen. See [features/ai.md](features/ai.md).
- **The main menu** — shaped by `TinycastApp`'s `.commands`, which rebinds ⌘Q to Close Window: the AI
  Chat window when it is key, otherwise Settings. It is only ever on screen while a titled window is
  open, so it is those windows' menu bar. It must stay declarative.
- **Dialogs** — borderless `DialogPanel`s driven by `DialogController`, the app's only presenter for
  confirmations, failure reports and value prompts. Presentation is `async`, so nothing blocks the main
  actor, and the presenter refuses a second dialog while one is up — that, not a flag, is what stops a
  held hotkey stacking dialogs.
- **HUDs** are separate, because a dialog asks and a HUD reports: `MessageHUDController` (the pill) and
  `VolumeHUDController` (the level box), both over a shared `HUDPresenter` that owns the
  one-at-a-time, auto-dismiss and fade policy. See [ui.md](ui.md#dialogs--hud).

`NSAlert` is never used, and that is load-bearing. Appearance is a setting: `AppCore.applyAppearance()`
assigns `NSApp.appearance` from `AppSettings.appearance`, and `.system` assigns `nil` so AppKit follows
macOS by itself. Nothing else in the app sets an appearance.

## Perception

Observation is [swift-perception](https://github.com/pointfreeco/swift-perception), the back-port of
Observation that runs on macOS 13 and delegates to native Observation on macOS 14 and later. 63 types are
`@MainActor @Perceptible`, and views read them through `@Environment` rather than `@EnvironmentObject`.
The one `ObservableObject` is `MenuBarSceneState` in `App/TinycastApp.swift`, because a scene body cannot
use `WithPerceptionTracking`; it republishes the few reads the menu bar scenes need.

Four things about this model are easy to get wrong:

- **Every `View` and `ViewModifier` body is wrapped in `WithPerceptionTracking`**, and so is lazily built
  content that reads a model (`GeometryReader`, lazy stacks and grids, `List` content, popovers, sheets,
  context menus). A missing wrapper works on macOS 14 and later and silently stops updating on macOS 13,
  where Perception logs an untracked-access warning in Debug builds.
- **`@PerceptionIgnored` on memo caches** and lazily-built collaborators. Without it, reading a memo
  registers a dependency and the view re-renders on its own cache fill. `AppCore`'s coordinators are all
  `@PerceptionIgnored private(set) lazy` for this reason.
- **Never annotate `@Environment` with a type** for a `@Perceptible` value. The keyless overload is
  resolved by type, and an explicit annotation changes which overload is chosen.
- **The compiler cannot see a missed injection site.** A view reading `@Environment(AppSettings.self)`
  from a hierarchy nobody injected into compiles fine and traps at runtime, so check the injection when
  adding a hosting view.

`AppCore.track` is the pattern for reacting to a settings change outside a view.
`withPerceptionTracking`'s `onChange` is a **willSet** hook — it fires before the write lands and is
one-shot — so the closure defers the re-read into a `Task` and re-arms the tracking there. Both halves
are required; removing the `Task` reads the old value.

## Concurrency

The target builds in **Swift 6 language mode**, so data-race violations are hard errors. Almost
everything is `@MainActor`; cross-actor model types are `Sendable`. Heavy and IO-bound work — the app
scan, image decode, the settings-pane scan, shell execution, the FX rate fetch — is pushed off-main as
`nonisolated static` functions driven by `Task.detached`. There is exactly one actor, deliberately.

House idioms for the sharp edges:

- Block-observer lifetimes go through the RAII `NotificationToken` (`Platform/NotificationToken.swift`)
  rather than removal in a `deinit`.
- `ClipboardStore` uses `isolated deinit` for its SQLite teardown.
- Raw Carbon and C pointers are decoded to plain values before crossing into actor code (see
  `hotKeyCarbonEventHandler`).
- `HealthTicker` (`Platform/HealthTicker.swift`) is the one shared timer for periodic health checks, so
  the event taps do not each own one.

## The tree

The folder layout is the layering above, made navigable — one folder per feature, each holding
everything that feature owns. The top folder keeps its internal name, `Tinycast/`.

```
Tinycast/
  App/              @main (TinycastApp), AppDelegate, AppCore — the composition root
  DesignSystem/     Theme (the token source), InterfaceMetrics, KeyCapChip, Tooltip, SymbolImage,
                    GlassEffectView, PopoverMenu, SettingsComponents, Compatibility/, Scrolling/,
                    Interaction/
  Platform/         system shims: Permissions, LaunchAtLogin, InputSourceSwitcher, ScreenTarget,
                    AppDisplayName, AppPaths, KeychainSecretStore, LinkDestination, LinkLauncher,
                    NotificationToken, Signposts, HealthTicker, Memo, ActivationPolicy,
                    Images/, Compression/
  Resources/        RaycastRuntime.generated.js, the embedded extension runtime
  Palette/          the palette shell: PalettePanel, PaletteWindowController, RootPaletteView,
                    the PaletteScreen protocol, PaletteCoordinator, PaletteState, PaletteMode
  Windows/          the non-palette AppKit surfaces: AppWindowController, Dialog/, HUD/, About/
  Assets.xcassets/  the menu bar icon and the bundled image sets some catalog symbols resolve to
  tinycast.icon     the Icon Composer app icon (the Minicast M monogram)
  Features/
    PaletteRowIndex.swift   the flat selection index — palette-owned, so it sits at the top
    Launcher/ Clipboard/ Calculator/ Calendar/ Emoji/ Dictionary/ FileSearch/ AppleShortcuts/
    Uninstall/ SystemActions/ CustomCommands/ HotKeys/ Backup/ WindowManagement/ AI/ MCP/
    QuickActions/ TextInjection/ Settings/
    Extensions/
        Model/      pure — the harness inputs
        Service/    effects — stores, monitors, runners, AppKit glue
        UI/         screens, views, and the feature's coordinator
        Settings/   the feature's own panes
    Settings/       the Settings shell only: SettingsCoordinator, the root/sidebar/detail views, the chrome,
                    navigation types, SettingsTab, AppSettings, AppSettingsKey, the settings file
                    (Model/, Service/, SettingsFileSchema), and Panes/ for the two panes no feature
                    owns
Tests/              the standalone harnesses, one Swift file each
Scripts/            run-tests.sh, the data generators, the extension runtime build, build-dmg.sh,
                    migrate-to-minicast.sh, formatting, linting, editor setup
```

A larger feature splits into all four sub-folders; a smaller one keeps only what it needs, as
`TextInjection/` (only `Service/`) does. `HotKeys/` has no `Settings/` because its Shortcuts pane is
part of the Settings shell rather than the feature.

Every `SettingsTab` maps to one `…SettingsView`, and each is a stock `Form` with
`.formStyle(.grouped)` — see [ui.md](ui.md#settings). A pane lives with its feature; only a pane no
feature owns (General, Permissions) lives in `Settings/Panes/`. The four launcher-category panes —
Applications, System Settings, System Actions, Commands — are thin wrappers over the shared
`LauncherItemsSection`; Apple Shortcuts pairs its feature switch with the same `LauncherItemsList`.

`SettingsTab` and `SettingsSection` both identify by the case itself, never by an index. A selectable
`List` flattens section and row IDs into one namespace, so overlapping `Int` IDs make SwiftUI drop
whole sidebar groups; `Tests/settings-history-test.swift` pins the two namespaces apart.
