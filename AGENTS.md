# Minicast

Minicast is a private fork of Tinycast, a native macOS menu-bar launcher: fuzzy app launcher, global and
per-app hotkeys, a text/image clipboard history, an inline calculator, file search, window management,
calendar, AI chat, quick actions and an emoji picker. It also **runs Raycast extensions** natively, in
JavaScriptCore. SwiftUI + AppKit, running as an accessory with no Dock icon (`LSUIElement`).

Upstream is not merged. Planning lives in OpenSpec (`openspec/`): current behavior in
`openspec/specs/`, finished work in `openspec/changes/archive/`, open work in `openspec/changes/`.
`docs/` describes Minicast; `website/` is still upstream's and is handled by its own change.

**Internal names stay `Tinycast`.** The source folder `Tinycast/`, `Tinycast.xcodeproj`, the target,
scheme and module, type names (`TinycastApp`, …), the `TINYCAST_BUNDLE_IDENTIFIER` build variable, the
`tinycast.icon` bundle, logging subsystems, queue labels and the `__tinycast*` JS bridge globals keep the
old name until the `rename-internal-identifiers` change. Everything a user or a third party sees says
Minicast.

## Posture: macOS 13 floor, one code path

**Minicast targets macOS 13 Ventura and later, Intel and Apple silicon, from one universal build.** It
is built with the Xcode 27 toolchain in Swift 6 language mode. This overrides upstream's "latest macOS
only" posture.

- **Every API must exist on macOS 13.** The compiler is the inventory: the deployment target is 13.0,
  so anything newer is a build error, never a warning to live with.
- **One code path for every macOS version.** Use `#available` only where the macOS 13 call is wrong on
  newer systems (EventKit full access in `Platform/Permissions.swift`) or for cosmetic modifiers that
  simply do nothing on macOS 13.
- **Compatibility helpers live in `Tinycast/DesignSystem/Compatibility/`** and keep the shape of the
  newer API so call sites stay readable: `onValueChange` (for `onChange`), `onKeyDown` (for
  `onKeyPress`), `onScrollMetricsChange`/`onLiveScrollChange`/`onScrollVisibilityChanged` (for scroll
  geometry), `EmptyStateView` (for `ContentUnavailableView`) and the cosmetic modifiers. Reuse them;
  never call the macOS 14+ originals.
- **Observation is swift-perception.** Models are `@Perceptible` (`@PerceptionIgnored`,
  `withPerceptionTracking`, `@Perception.Bindable`). Every `View` and `ViewModifier` body is wrapped in
  `WithPerceptionTracking`, and so is lazily built content that reads models (`GeometryReader`, lazy
  stacks and grids, `List` content, popovers, sheets, context menus). A missing wrapper only shows on
  macOS 13, where Perception logs an untracked-access warning in Debug builds. On macOS 14+ Perception
  delegates to native Observation.
- **SF Symbols must exist in SF Symbols 4** (macOS 13); newer names render blank.
- **One appearance:** classic blur materials (`GlassEffectView` is an `NSVisualEffectView`,
  `Theme.frosted(in:)` a SwiftUI material). No Liquid Glass.
- The rest of upstream's style stays: prefer Swift Concurrency, `SMAppService`, structured concurrency;
  no migration code inside the app (the one-time `Scripts/migrate-to-minicast.sh` is external).

Carbon is a deliberate capability-gap dependency rather than inertia: nothing modern registers a
system-wide chord, and HIToolbox's TIS APIs remain the public input-source mechanism.

## Identity and removed features

- Release: `com.minicast.app`, "Minicast". Debug: `com.minicast.app.dev`, "Minicast Dev". Every
  persisted path, preference domain and Keychain service derives from the bundle id, so Minicast never
  touches the data of the official Tinycast (`com.tinycast.app`). Keep it that way. `AppPaths` maps `com.minicast.app[.<suffix>]` to
  `~/.config/minicast[-<suffix>]`.
- User-visible text says Minicast (or `Bundle.main.appDisplayName`); the About pane is the only place
  that names Tinycast, as the upstream credit.
- Links: `minicast://`, `raycast://` and `com.raycast://`, never `tinycast://`. Backups export as
  `.minicast` (`com.minicast.backup`) and still import `.tinycast`. Shell commands get `MINICAST=1` and
  `TINYCAST=1`.
- Updates come only from `github.com/nanoarmando/minicast` releases, checked when About opens or on
  request, never in the background; see [updates.md](docs/features/updates.md). The palette's
  "Changelog" opens the commit history on `main`.
- Removed and not to be reintroduced without an OpenSpec change: Apple Intelligence provider, Translate
  quick action, Dictation (and the `DictationHelper` target), Notes, Quicklinks, Camera preview,
  Snippets, Support reminder, Onboarding, WindowSwitcher, MenuSearch (Navigation pane).
- **Few new features; a feature request is answered with a Raycast extension.** The built-in feature
  set is close to final. Before adding a feature, check whether a Raycast extension can do it — if it
  can, the answer is an extension (see README "Philosophy"), and the work on Minicast is at most
  closing a gap in the extension runtime. A genuinely new built-in feature needs an OpenSpec change.
- Link opening shared by window layouts, clipboard drag and "open in browser" lives in
  `Platform/LinkDestination.swift` and `Platform/LinkLauncher.swift`. `TextInjector` only serves quick
  actions (replace and copy selection).

## Where things are

| Folder | Holds |
| --- | --- |
| `Tinycast/App/` | `@main`, `AppDelegate`, `AppCore` — the composition root |
| `Tinycast/DesignSystem/` | shared visual primitives; `Theme.swift` is the only design-token source |
| `Tinycast/Platform/` | system shims: `Permissions`, `AppPaths`, `Signposts`, `NotificationToken`, … |
| `Tinycast/Palette/` | the palette shell: panel, window controller, `RootPaletteView`, `PaletteScreen` |
| `Tinycast/Windows/` | the non-palette AppKit surfaces: `Dialog/`, `HUD/`, `About/`, `AppWindowController` |
| `Tinycast/Features/` | one folder per feature; larger ones split `Model/` `Service/` `UI/` `Settings/` |
| `Tests/` | the standalone harnesses — one Swift file each, no XCTest target |
| `Scripts/` | every executable script: test runner, data generators, packaging, linting, editor setup |

| Read it before you | Doc |
| --- | --- |
| change how anything is wired or owned | [architecture.md](docs/architecture.md) |
| write Swift — naming, style, concurrency, budgets, comments | [standards.md](docs/standards.md) |
| claim a change is done | [testing.md](docs/testing.md) |
| build, run or regenerate data | [development.md](docs/development.md) |
| add or restyle any view | [ui.md](docs/ui.md) |
| touch one feature's internals | [features/](docs/features/) — each opens with its invariants |
| package or ship a build | [release.md](docs/release.md) |

## Non-negotiables

Never break these without an explicit task to do so. Anything feature-specific lives in that
feature's doc, under its own `## Invariants`.

- **`AppCore` is the sole owner.** New long-lived state goes on `AppCore`, wired in `start()` — never a
  competing singleton. Views reach a feature's **coordinator** through `@Environment`, not `AppCore`.
- **A file under `Features/*/Model/` may not import AppKit or SwiftUI**, and takes every environment
  fact — clock, filesystem, home directory, rates — as an injected parameter. The harnesses compile the
  shipped sources, so this is enforced by compilation rather than convention.
- **Swift 6 language mode: data-race violations are hard errors.** `@MainActor` is the default,
  cross-actor model types are `Sendable`, and heavy or IO-bound work goes off-main as `nonisolated`
  functions driven by `Task.detached`. Do not add a second actor.
- **Dark is the baseline, and a colour's dark branch is the literal it always was.** `Theme.Colors`
  resolves per appearance through `ramp`/`adaptive`; every dark value is the `Color.white.opacity(…)`
  the forced-dark build shipped, restated rather than re-derived. Retune a light branch freely — change
  a dark one only when the task is to change Dark. `AppAppearance` drives `NSApp.appearance`, and
  `.system` maps to `nil` so AppKit follows macOS on its own.
- **Minicast presents its own dialogs — never `NSAlert` or a system popover.** A question
  goes through `DialogController`, a report through a HUD via `HUDPresenter`.
- **A networked feature fetches on a private `.ephemeral`, `urlCache = nil` session**, never
  `URLSession.shared`, so its own cache file stays the only copy on disk. `CurrencyRateStore` is the
  reference — copy it rather than inventing a second shape. A flag that grants a capability never
  has a `settings.json` key, and a backup applies one only after the import's consent dialog
  (`SettingsBackupCoverage.capabilities`). Keychain secrets never enter a backup.
- **Extensions stay inside `Features/Extensions/`.** Every view, row, menu, geometry and sizing
  constant an extension needs is written and owned there — never added to `DesignSystem/`, never bolted
  onto `Theme`, and never lifted somewhere another feature can build on it. Another surface may render
  one as an opaque box — `LauncherScreen` does exactly that with `ExtensionArgumentsAccessory` — but it
  never reaches inside one. An extension renders untrusted third-party code whose shape we do not
  control, so it must never be able to force a change on a launcher surface.
  **Duplicating a view or a piece of layout maths to keep it here is the correct trade**, and the one
  place the no-duplication rule yields. What *is* shared: `Theme`'s base tokens (spacing, radius,
  colour), `InterfaceMetrics` as the view over those same base tokens, `PopoverMenuItem` as a data
  shape, and `Platform/`. What is never shared: anything with
  "how an extension looks or moves" in it. `ExtensionActionsPanel` and `ExtensionGridGeometry` exist
  precisely because the palette's own menu and the emoji grid must stay free to change without them.
- **`AppEntry.Kind` is the only thing that says what an entry is.** One case per launcher section and
  per `VisibilityStore` category — never re-derive a category by sniffing an entry ID. Which *pane*
  lists a command is a separate fact, and `SettingsTab.ownedCommands` is the only place that states it.
- **Generated files are never hand-edited.** `EmojiData.generated.swift` and
  `Resources/EmojiKeywords/` come from `node Scripts/gen-emoji.js`, `CurrencyData.generated.swift` from `node Scripts/gen-currencies.js`,
  `CountryZoneData.generated.swift` from `node Scripts/gen-countries.js`, and
  `Resources/RaycastRuntime.generated.js` from `Scripts/raycast-runtime/build.mjs` — the runtime is
  committed so building the app never needs Node.
- **`DesignSystem/Scrolling/EdgeDissolve.swift` and `ThinScrollbar.swift` are tuned by eye** against
  the palette's floating bars. On macOS 13 they read scroll state from the backing `NSScrollView`
  (`onScrollMetricsChange`); change them only for a scroll bug that lives there.

## Conventions worth knowing up front

- **A new preference also gets a `SettingsFileKey`** and its binding in `SettingsFileSchema`, so the
  opt-in `settings.json` mirror carries it; the exhaustive switch fails the build until it is bound.
  See [settings-file.md](docs/features/settings-file.md).
- **A type's suffix says what it *is*** — `Store`, `Coordinator`, `Controller`, `Manager`, `Engine`,
  `Policy` and the rest each name a specific responsibility. **Semantic correctness always wins over
  suffix consistency:** pick the suffix that describes the type honestly, add a new one when none fits,
  and never rename a well-named type just to match the table.
  Full table: [standards.md#naming](docs/standards.md#naming).
- **Comments are rare, one line, and explain the *why*** — the gotcha or invariant, never the what.
  **Never two in a row, never extended into a block**: if one line can't carry it, name a function,
  constant or type instead. Cap 100 characters, delete rather than update, and never comment a change
  you just made. Nothing lints this; get it right the first time.
  Full rules: [standards.md#comments](docs/standards.md#comments).
- **Debug builds are their own channel** — `Minicast Dev.app` / `com.minicast.app.dev` — so a local run
  never shares prefs, caches, TCC grants or the login item with an installed copy. Anything newly
  persisted must stay keyed by `Bundle.main.bundleIdentifier`.
- **XcodeGen owns the project.** `Tinycast.xcodeproj` is committed but generated from `project.yml`;
  after editing it, run `./.tools/xcodegen/bin/xcodegen generate` and commit both. The only Swift
  package is swift-perception; never `Bundle.module`. Command-line builds pass `-skipMacroValidation`.

## Before you finish

Each item is explained in [testing.md](docs/testing.md#definition-of-done).

- `./Scripts/run-tests.sh` passes (it builds swift-perception once into `.build/harness-perception/`).
- The Debug build and the universal Release build (`./Scripts/build-dmg.sh`) compile with **no errors and
  no new warnings** for the 13.0 deployment target.
- `PATH="$PWD/.tools/swiftlint:$PATH" ./Scripts/lint.sh` is clean, with no new warnings. SwiftLint is
  the project-local binary in `.tools/swiftlint/` (not committed); never install it with `brew`.
- `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Tinycast/Features/*/Model/` returns nothing.
- Any doc your change made wrong is fixed in the same commit.

## Shipping a version

**A version bump is not done until its GitHub release exists.** Pushing commits is not a release:
the second Mac installs from GitHub, so a version that only lives in `main` never reaches it. Every
time `MARKETING_VERSION` changes, follow [release.md](docs/release.md#publishing-a-release) to the
end: bump `project.yml` and regenerate, build `./Scripts/build-dmg.sh`, commit and push, then
`gh release create minicast-v<version> build/Minicast-<version>.dmg` on `nanoarmando/minicast`, and
confirm it is listed as **Latest** with the DMG attached.
