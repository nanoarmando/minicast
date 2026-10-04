## Context

See `proposal.md` for motivation. Current state that shapes the approach:

- `project.yml` (XcodeGen) is the project source of truth: deployment target 26.0, Swift 6 language mode,
  `SWIFT_STRICT_CONCURRENCY = complete`, no `ARCHS` override, no Swift packages. Targets: `Tinycast`,
  `ClipboardTextHelper`, `DictationHelper` (the last one is removed with Dictation).
- 75 `@Observable` types (about 60 after the feature removals), all `@MainActor final class` except `VolumeState`. `AppCore` is the composition
  root and injects stores through `.environment(obj)` in `PaletteEnvironment.swift` and
  `SettingsEditorPresenter.swift`, plus smaller injection sites in feature window controllers.
- Non-view observation: 7 `withObservationTracking` sites (`AppCore.track`/`trackChatRoute`, `AppIndex`,
  `HyperKeyTap`, `SettingsFileRepository.renderObserved`, two window title observers); the Notes one goes
  away with Notes.
- Window management depends on two Quicklinks files: `WindowLayoutRunner` opens layout arguments through
  `QuicklinkLauncher`, and `WindowLayoutArgumentField` uses `QuicklinkDestination` and offers saved
  quicklinks as argument sources. `TextInjector` is shared by quick actions and contains snippet-only and
  Notes-only paths.
- The Dictation helper (`QwenRecognizer`) uses stateful Core ML APIs that exist only on macOS 15+.
- `TinycastApp` reads `AppCore.shared.settings` inside the `App` body to drive `MenuBarExtra(isInserted:)`.
- `AGENTS.md` declares a "latest macOS only" posture, "no SwiftPM", and marks
  `DesignSystem/Scrolling/EdgeDissolve.swift` and `ThinScrollbar.swift` as off-limits. This change
  explicitly overrides those three rules for the fork.
- Persisted paths derive from `Bundle.main.bundleIdentifier` (`AppPaths`); `com.tinycast.app.<x>` maps the
  settings file folder to `tinycast-<x>`. `ReleaseChannel` treats any id other than `com.tinycast.app` and
  `.beta` as `.development`.
- `Scripts/run-tests.sh` compiles each harness with plain `swiftc` against shipped sources.

## Goals / Non-Goals

**Goals:**
- One code path for macOS 13 and newer, with `#available` used only where a macOS 13 replacement would
  be worse on newer systems (EventKit access) or for cosmetic no-ops (see Decision 6).
- Keep per-property view invalidation on macOS 13 for palette responsiveness.
- Keep diffs mechanical and local so the port stays reviewable.

**Non-Goals:**
- Supporting macOS 12 or earlier.
- Merging future upstream changes.
- Publishing releases or an update feed for the fork.
- Pixel parity with Liquid Glass or the tuned scroll effects.
- Migration code inside the app (migration is an external one-time script, Decision 10).
- Migrating privacy permissions or the login item.

## Decisions

### 1. Observation → swift-perception
Add `pointfreeco/swift-perception` as a Swift package in `project.yml`. Mechanical mapping:
`@Observable` → `@Perceptible`, `@ObservationIgnored` → `@PerceptionIgnored`, `withObservationTracking` →
`withPerceptionTracking`, `@Bindable` → `@Perception.Bindable`, `import Observation` → `import Perception`.
`@Environment(T.self)` and `.environment(obj)` keep their spelling through Perception's overloads.
Files under `Features/*/Model/` import `Perception` (the `@Perceptible` macro lives there, not in
`PerceptionCore`) and still never import SwiftUI or AppKit, so the Model import rule holds.

Every view body (and `ViewModifier` body, and lazily built closures such as `ForEach`, `List`,
`GeometryReader` or `Menu` content) that reads perceptible state is wrapped in `WithPerceptionTracking`.
Rule of thumb: any `View` that declares `@Environment` of a model type, holds a model property, or
receives one as a parameter.

- Alternative: Combine `ObservableObject`. Rejected: whole-object invalidation on every `@Published`
  change (about 93 settings and about 29 palette properties) risks lag on the 2017 Intel Mac, and needs
  a larger rewrite (`@EnvironmentObject`, Combine pipelines for all tracking sites).
- On macOS 14+ Perception delegates to native Observation, so the main Mac keeps today's behavior.

### 2. App scene observation bridge
`App`/`Scene` bodies cannot use `WithPerceptionTracking`. Add one small `@MainActor` `ObservableObject`
owned by `TinycastApp` (`@StateObject`) that mirrors the few values the scene reads (`showInMenuBar`,
calendar menu bar state, and any other scene-level reads) and refreshes them with a re-arming
`withPerceptionTracking` loop. `MenuBarExtra(isInserted:)` binds to it.

### 3. Other unavailable APIs
- `onChange(of:initial:_:)` with old/new values or zero parameters: one fork-local modifier with the same
  shape as the macOS 14 API, implemented with the macOS 13 `onChange(of:perform:)` plus `onAppear` for
  `initial: true` and a stored previous value. Call sites change only the method name.
- `onKeyPress`: one fork-local modifier backed by an `NSEvent` local key-down monitor that is active while
  the view is on screen and its window is key, returning `.handled`/`.ignored` semantics. Focus-dependent
  sites check focus state before handling. The palette's sites (`RootPaletteView`) are migrated first and
  verified for arrow keys, Return, Tab, Escape and modifier combinations.
- `onScrollGeometryChange`, `onScrollPhaseChange`, `onScrollVisibilityChange`, `defaultScrollAnchor`:
  replaced with geometry preference keys inside the scroll content, or `ScrollViewReader` for anchoring.
  `ThinScrollbar` falls back to the system overlay scroller and `EdgeDissolve` to a static gradient mask
  where needed (functional-first fidelity).
- `onGeometryChange`: keep if the toolchain back-deploys it to macOS 13; otherwise a `GeometryReader`
  background with a preference key.
- `Mutex` → `OSAllocatedUnfairLock` (same `withLock` shape).
- Vision `RecognizeTextRequest` (macOS 15) in the clipboard text helper → `VNRecognizeTextRequest`.
- Network.framework `NetworkListener`/`NetworkConnection` (macOS 26) → `NWListener`/`NWConnection`; typed
  `NotificationCenter` observers (macOS 26) → selector/closure observers; any other compiler-reported API
  gets its macOS 13 equivalent.
- SF Symbols newer than SF Symbols 4 render blank on macOS 13 and are replaced with available names.
- `NSApp.activate()` / `NSRunningApplication.activate()` → `activate(ignoringOtherApps:)` /
  `activate(options:)`. With a 13.0 deployment target these are not deprecation warnings.
- `AsyncStream.makeStream(of:)` → continuation captured from the `AsyncStream` initializer.
- `ContentUnavailableView` → a small fork-local empty-state view.
- `toolbar(removing: .sidebarToggle)`, `NSMenuItem.sectionHeader`, `TextSelection`,
  `writingToolsBehavior`, `.snappy`, `.spring(duration:bounce:)`, static shape members: replaced by their
  macOS 13 equivalents (disabled header item, plain selection handling, explicit animations, shape
  initializers).
- `isolated deinit` (13 sites after the removals): keep if it compiles for macOS 13; otherwise move cleanup into a
  `nonisolated deinit` that only releases thread-safe handles, or into existing explicit `stop()` paths.

### 3b. Settings window controls
The Settings toolbar (back/forward, pane title, sidebar search) is declared in SwiftUI and reaches the
AppKit window only through `sceneBridgingOptions` (macOS 14+). The fork drops the window toolbar and puts
the controls inside the content on every macOS version: no header (the user dropped the back/forward buttons and
the pane title; the titlebar band stays empty), and a plain search field at the top of the sidebar; ⌘F focuses it through `FocusState`. One look
on both Macs, no `#available` branch.
- Alternatives: an AppKit `NSToolbar` only on macOS 13 (native look, two code paths), or a SwiftUI
  `Window` scene (larger refactor of `SettingsCoordinator`). Rejected by the user in favour of one look.

### 4. Liquid Glass → classic materials
Replace the two choke points first: `DesignSystem/GlassEffectView.swift` becomes an
`NSVisualEffectView` wrapper and `Theme.frosted(in:)` uses a SwiftUI material. The remaining direct
`.glassEffect` and `.buttonStyle(.glass)` sites use the same primitives. No `#available` branch: one look on
every macOS version.

### 5. EventKit permissions
`Permissions` uses `requestFullAccessToEvents`/`requestFullAccessToReminders` on macOS 14+ and
`requestAccess(to:)` on macOS 13. `Info.plist` carries both the full-access and the legacy usage
description keys. This is the one behavioral `#available` branch, because the legacy API is not the right
call on macOS 14+.

### 6. Cosmetic-only modifiers
`focusEffectDisabled`, `symbolEffect`, `contentMargins` and `pointerStyle` have no behavioral role.
`pointerStyle` is replaced by `NSCursor` push/pop on hover. The others go through tiny fork-local modifiers
that apply on macOS 14+ and do nothing on macOS 13. The visible difference on macOS 13 is limited to focus
rings and symbol animations.

### 7. Removed features
Removals happen before the Observation migration so the port only touches code that stays.
- Apple Intelligence and Translate: delete `AppleIntelligenceProvider`, `AppleIntelligence` and
  `TextTranslator`, and remove the `.appleIntelligence` provider, model source and selection cases, the
  `.translate` quick action, its `CommandID`, catalog entries, settings UI and settings search keywords.
- Dictation, Notes, Quicklinks, Camera, Snippets, Support, Onboarding, WindowSwitcher and MenuSearch: delete
  each feature folder (plus `Platform/CameraAccess.swift` and the Camera files under `Calendar/UI/`), the
  `DictationHelper` target and its embed in `project.yml`, and every outside reference: `AppCore` wiring
  and `track` registrations, environment injections, `PaletteMode` cases (`.menuSearch`, `.switchWindows`,
  `.quicklinks`, `.snippets`), `AppEntry.Kind` (`.snippet`, `.quicklink`), `CommandID`s, `HotKeyAction`
  cases and `HotKeyManager` hold-to-talk machinery, settings panes and tabs (Quicklinks, Snippets,
  Navigation, Notes), `AppSettings`/`AppSettingsKey`/`SettingsFileKey`/`SettingsFileSchema` keys, backup
  coverage and the Notes and Snippets backup categories, menu bar and palette menu items, the snippet
  arguments dialog, microphone and camera permission rows, usage strings and entitlements.
- Shared code kept: the link-opening utility (`QuicklinkDestination`, `QuicklinkLauncher`) moves out of
  the Quicklinks folder under a neutral name for window layouts, clipboard drag and "open in browser";
  the layout argument picker drops its saved-quicklinks section. `TextInjector` stays for quick actions,
  without its snippet expansion and Notes in-process editor paths; quick actions keep only the external
  target. Calendar auto-join uses the existing plain confirmation instead of the camera preview.
- Onboarding is not replaced: the menu bar item is visible by default, and the palette hotkey, launch at
  login, Accessibility and Raycast import already live in settings. The `AIPreamble` text stops naming
  removed features.
- Persisted references decode through existing `try?` paths (unknown selection → `nil` → first available
  provider). Verify that stores keyed by command id (favorites, aliases, hotkeys, ranking, visibility,
  fallbacks) and backups skip unknown ids, keys and categories rather than trapping, and fix any
  exhaustive decode that would trap.

### 8. Fork identity and isolation
- `project.yml`: release bundle id `com.tinycast.app.fork`, product name "Tinycast Fork"; debug
  `com.tinycast.app.fork.dev`, "Tinycast Fork Dev". The dictation helper naming goes away with the
  `DictationHelper` target.
- `AppPaths` already maps the new id to `~/.config/tinycast-fork/` and bundle-id folders; no change needed.
- `ExtensionOAuthKeychain` service becomes bundle-id based (`<bundleID>.extensions-oauth`).
- `ReleaseChannel` already resolves the fork to `.development` (`updatesItself == false`). In addition,
  remove the update feature's wiring: no scheduled check, no "Check for Updates…" menu item, palette
  command or update settings. Delete the Updates feature code and its harness when nothing else depends
  on it.
- URL schemes (`tinycast`, `raycast`, `com.raycast`), the backup UTI and the pasteboard type stay as-is;
  conflicts only arise when both apps are installed, and are documented.

### 9. Build, signing and tests
- `project.yml`: deployment target 13.0; release builds set `ARCHS = arm64 x86_64` and
  `ONLY_ACTIVE_ARCH = NO`. Regenerate with `xcodegen generate` and commit both files.
- `Scripts/build-dmg.sh`: universal release build (`xcodebuild -skipMacroValidation`, required for the
  Perception macro outside the Xcode UI), identity presence check, `lipo` assertion for the app and the
  clipboard helper, `minos` 13.0 assertion, DMG output named for the fork.
  `Scripts/verify-signature.sh` is updated for the new names.
- Signing reuses the documented self-signed flow (`docs/signing.md`), created once on the main Mac. The
  2017 Mac receives the already signed app.
- `Scripts/run-tests.sh`: build swift-perception once (`swift build` into a cached directory) and pass its
  module, library and macro plugin flags (`-I`, `-L`, `-l`, `-load-plugin-executable`) to each harness
  that compiles perceptible sources. Delete harnesses for removed features and fix source lists of kept
  harnesses that reference removed files. `Scripts/benchmark-dictation.sh` is deleted.
- Delete `.github/workflows/`.

### 10. One-time migration script
`Scripts/migrate-from-official.sh` (zsh, no dependencies beyond macOS tools) copies official data into the
fork. The app keeps no migration code.
- Preconditions, checked before any copy: neither app running, `/Applications/Tinycast Fork.app` exists,
  official data exists. If the fork already has data (Application Support folder, preferences domain or
  `~/.config/tinycast-fork/`), abort unless `--force`, which first moves the fork's data to
  `~/Documents/Backups/Tinycast-Fork-<timestamp>/`.
- Files: `cp -Rp` of `Application Support/com.tinycast.app` and `Caches/com.tinycast.app` (excluding
  `update-check.json`) to the `.fork` folders; `~/.config/tinycast/` to `~/.config/tinycast-fork/`.
  SQLite `-wal`/`-shm` files are copied with their databases, which is safe because both apps are quit.
- Preferences: `defaults export com.tinycast.app - | defaults import com.tinycast.app.fork -`.
- Keychain (file-based login keychain, generic passwords): enumerate accounts for the services
  `com.tinycast.app.{ai-api-keys,mcp-secrets,installed-ai-environment}` and
  `com.tinycast.extensions.oauth`; read each secret with `security find-generic-password -w` (macOS asks
  the user to authorize), and add it under `com.tinycast.app.fork.<scope>` /
  `com.tinycast.app.fork.extensions-oauth` with `security add-generic-password -U -T "<fork app path>"`
  so the fork reads it without prompts. Denied items are skipped and reported.
- Not migrated: TCC privacy permissions and the `SMAppService` login item (both bound to the signature).
- Output: a summary of migrated, skipped and manual items.
- The official app's files, preferences and Keychain items are only read.

### 11. Documentation
Rewrite the posture section of `AGENTS.md` for the fork (macOS 13 floor, Perception, allowed
compatibility helpers, the two scrolling files no longer off-limits, upstream not merged). Update
`README.md` with install, build, signing, data isolation, migration, Backup import and removed
features. Upstream docs
under `docs/` and `website/` that describe removed features are not rewritten (out of scope).

## Risks / Trade-offs

- [Missed `WithPerceptionTracking` wrappers only show on macOS 13 as views that do not refresh] →
  Apply the wrapping rule systematically, then run the Debug build on the 2017 Mac: Perception logs a
  runtime warning for every untracked read; fix each one.
- [Installed Xcode might not support a macOS 13 deployment target] → First task verifies it; if
  unsupported, stop and revise this plan (for example, install an older Xcode side by side).
- [`isolated deinit` may not back-deploy] → Fallback described in Decision 3.
- [Custom `onKeyPress` replacement can conflict with text field editing or the panel's existing AppKit
  key handling] → Migrate the palette first and verify every key path before the remaining sites.
- [Removing features breaks a kept feature through hidden coupling] → Couplings were mapped before
  planning (Decision 7); the build and harness suite catch the rest.
- [Simplified scroll effects look different from upstream] → Accepted (functional-first decision).
- [Swift package adds `swift-syntax` and slows clean builds] → Accepted; incremental builds are unaffected.
- [`AppIndex` hides every `com.tinycast.*` bundle from the launcher, so the official app is hidden while
  the fork runs] → Accepted; documented.
- [Secrets pass briefly through `security` command arguments during migration, visible to local
  processes] → Accepted for a single-user Mac and a one-time run; values are never written to disk or
  logged.
- [Copied preferences may describe state the fork does not have yet, such as launch at login enabled] →
  The fork reads the real login item status; the summary tells the user to re-enable it.
- [Both apps installed at once claim the same URL schemes and may register the same hotkeys] → Documented;
  run only one at a time.

## Migration Plan

1. Build and sign on the main Mac; quit the official app; install "Tinycast Fork.app" without opening it;
   run `Scripts/migrate-from-official.sh`; open the fork; grant privacy permissions and re-enable launch at
   login. (Alternative: skip the script and import a Backup file, re-entering what it does not cover.)
2. Copy the same app to the 2017 Mac and grant permissions there.
3. Rollback: quit the fork and open the official app; its data is untouched. A manual copy of the official
   configuration exists at `~/Documents/Backups/Tinycast-2026-10-03`.

## Open Questions

- Does the installed Xcode back-deploy `onGeometryChange` and `isolated deinit` to macOS 13? Answered by the
  first compile; the fallbacks are already defined.
