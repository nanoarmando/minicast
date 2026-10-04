## 1. Toolchain and project baseline

- [x] 1.1 Install XcodeGen, select the installed Xcode, and confirm it accepts a macOS 13.0 deployment target (stop and revise the design if it does not)
- [x] 1.2 Set the deployment target to 13.0 and release `ARCHS = arm64 x86_64`, `ONLY_ACTIVE_ARCH = NO` in `project.yml` for all targets
- [x] 1.3 Set fork identity in `project.yml` (bundle ids, product names, `DICTATION_EXECUTABLE_NAME` for release and debug) and sync the helper name literal in `DictationWorker`
- [x] 1.4 Add the `swift-perception` package to `project.yml`, link `Perception` to the app, and run `xcodegen generate`
- [x] 1.5 Create the local self-signed identity on the main Mac following `docs/signing.md`
- [x] 1.6 Delete `.github/workflows/`

## 2. Removed features

- [x] 2.1 Remove the Apple Intelligence provider: delete `AppleIntelligenceProvider.swift` and `AppleIntelligence.swift`, and remove the provider, model source, selection and capability cases from AI model, settings, provider panel, model option and chat code
- [x] 2.2 Remove the Translate quick action: delete `TextTranslator.swift`, and remove the `.translate` action, its `CommandID`, catalog and launcher entries, panel and result handling, settings UI and settings search keyword
- [x] 2.3 Move `QuicklinkDestination` and `QuicklinkLauncher` out of Quicklinks under a neutral name and update window layouts (runner and argument picker without the saved-quicklinks section), clipboard drag and "open in browser"
- [x] 2.4 Remove Quicklinks and Snippets: feature folders, palette modes, `AppEntry.Kind` cases, commands, hotkey kinds, fallbacks, settings panes and keys, backup categories and coverage, the snippet arguments dialog, and the snippet-only `TextInjector` paths
- [x] 2.5 Remove Notes: feature folder, `AppCore` wiring and termination flush, commands, settings pane and keys, backup category, the quick action note target, and the in-process editor injection path
- [x] 2.6 Remove Dictation: feature folder, `DictationHelper` target and embed in `project.yml`, hold-to-talk hotkey machinery, settings, microphone permission row, usage string and entitlement, and `Scripts/benchmark-dictation.sh`
- [x] 2.7 Remove Camera (including the Camera files under `Calendar/UI/` and the calendar camera preview toggle), Support, Onboarding, WindowSwitcher and MenuSearch (with the Navigation settings pane), and drop camera usage string, entitlement and permission row
- [x] 2.8 Reword `AIPreamble`, regenerate the project with XcodeGen, and confirm the Debug build compiles past the removals
- [x] 2.9 Verify that persisted, imported or migrated references to removed features are ignored (default model, quick action models and overrides, favorites, aliases, hotkeys, ranking, visibility, fallbacks, settings keys, backup categories) and fix any decode that would trap

## 3. Fork identity and updates

- [x] 3.1 Make the extension OAuth Keychain service bundle-id based
- [x] 3.2 Remove the update feature wiring (scheduled check, "Check for Updates…" menu item, palette command, update settings) and delete the Updates feature code when nothing else depends on it
- [x] 3.3 Confirm that `AppPaths` resolves the fork to `~/.config/tinycast-fork/` and bundle-id folders, and that no code path reads the official app's locations

## 4. Observation migration (swift-perception)

- [x] 4.1 Convert all `@Observable` types to `@Perceptible`, `@ObservationIgnored` to `@PerceptionIgnored`, and imports to `Perception`
- [x] 4.2 Convert the 6 remaining `withObservationTracking` sites to `withPerceptionTracking` (`AppCore.track`/`trackChatRoute`, `AppIndex`, `HyperKeyTap`, `SettingsFileRepository`, AI chat window title)
- [x] 4.3 Convert `@Bindable` declarations and `@Bindable var x = x` patterns to `@Perception.Bindable`
- [x] 4.4 Wrap every view and view modifier body that reads perceptible state in `WithPerceptionTracking`, including lazily built content closures: palette and screens
- [x] 4.5 Same as 4.4 for settings panes and the settings window
- [x] 4.6 Same as 4.4 for AI chat, quick actions, HUDs, window management, extensions, calendar, file search and remaining surfaces
- [x] 4.7 Add the App scene observation bridge for `TinycastApp` (`MenuBarExtra` insertion and calendar menu bar state)

## 5. Other macOS 13 API replacements

- [x] 5.1 Add the fork-local `onChange` modifier with the macOS 14 shape and migrate all two-parameter, zero-parameter and `initial:` call sites
- [x] 5.2 Add the fork-local key press modifier and migrate the palette `onKeyPress` sites in `RootPaletteView`; verify arrows, Return, Tab, Escape and modifier keys
- [x] 5.3 Migrate the remaining `onKeyPress` sites (inline argument fields, launcher items table, extension fields and modifiers)
- [x] 5.4 Replace scroll geometry, phase and visibility modifiers and `defaultScrollAnchor` (thin scrollbar, overflow fade, selection following, edge dissolve, chat transcript, extension fields)
- [x] 5.5 Replace `onGeometryChange` if the toolchain does not back-deploy it
- [x] 5.6 Replace `Mutex` with `OSAllocatedUnfairLock` (`IconCache`, `ExtensionFetcher`, `ExtensionWebSocketBridge`)
- [x] 5.7 Replace macOS 14 activation calls with `activate(ignoringOtherApps:)`/`activate(options:)`, and `AsyncStream.makeStream`
- [x] 5.8 Add the macOS 13 EventKit access branch in `Permissions` and the legacy calendar and reminders usage keys in `Info.plist`
- [x] 5.9 Replace `pointerStyle` with `NSCursor` hover handling, and add the cosmetic no-op modifiers for `focusEffectDisabled`, `symbolEffect` and `contentMargins`
- [x] 5.10 Replace `ContentUnavailableView`, `toolbar(removing:)`, `NSMenuItem.sectionHeader`, `TextSelection`, `writingToolsBehavior`, `.snappy`, `.spring(duration:bounce:)` and static shape members
- [x] 5.11 Resolve `isolated deinit` sites that do not compile for macOS 13 using the fallback in the design
- [x] 5.12 Replace the macOS 15 Vision `RecognizeTextRequest` in `ClipboardTextExtractor` (clipboard text helper) with `VNRecognizeTextRequest`
- [x] 5.13 Replace the macOS 26 Network.framework `NetworkListener`/`NetworkConnection` in `ExtensionWebSocketBridge` and `MCPOAuthListener` with `NWListener`/`NWConnection`
- [x] 5.14 Replace the remaining macOS 14+ APIs reported by the compiler (typed `NotificationCenter` observers, `posix_spawn_file_actions_addchdir`, `searchable` variants, `scrollBounceBehavior`, `KeyEquivalent` conformances, Mutex-based initializers and any other) with macOS 13 equivalents
- [x] 5.15 Replace SF Symbol names that do not exist on macOS 13 (SF Symbols 4) with available equivalents so no icon renders blank
- [x] 5.16 Move the Settings window controls into the content on every macOS version: drop toolbar bridging, leave the titlebar band empty (no header, title or back/forward, at the user's request), a sidebar search field, and ⌘F focusing it

## 6. Liquid Glass replacement

- [x] 6.1 Rewrite `GlassEffectView` as an `NSVisualEffectView` wrapper and `Theme.frosted(in:)` with a SwiftUI material
- [x] 6.2 Replace the remaining `.glassEffect` and `.buttonStyle(.glass)` call sites with the same primitives

## 7. Build, tests and scripts

- [x] 7.1 Fix all remaining compile errors until the Debug and Release builds compile with no new warnings
- [x] 7.2 Update `Scripts/run-tests.sh` to build swift-perception once and pass its module, library and macro plugin flags; delete harnesses and source list entries for removed features
- [x] 7.3 Run `./Scripts/run-tests.sh`, `./Scripts/lint.sh` and the Model import check until clean
- [x] 7.4 Update `Scripts/build-dmg.sh` for the universal fork build (identity check, `lipo` and `minos` assertions, fork names) and `Scripts/verify-signature.sh` for the new names and the single helper
- [x] 7.5 Produce a signed universal release build and verify both slices and macOS 13.0 minimum on all executables

## 8. Migration from the official app

- [x] 8.1 Write `Scripts/migrate-from-official.sh` with precondition checks (apps quit, fork installed, official data present, fork empty unless `--force` with backup)
- [x] 8.2 Copy Application Support, Caches (without the update cache) and `~/.config/tinycast/`, and clone preferences into the fork domain
- [x] 8.3 Copy Keychain secrets for the AI, MCP, installed-AI and extension OAuth services into the fork's service names with the fork app trusted, skipping and reporting denied items
- [x] 8.4 Print the migration summary (migrated, skipped, manual steps)

## 9. Manual verification

- [ ] 9.1 On the main Mac (macOS 27): run the migration script, then smoke test palette, launcher, clipboard, file search, window management and layouts, calendar, extensions, AI chat with migrated keys, settings live updates and menu bar item; confirm the official app's data, preferences and Keychain items are unchanged
- [ ] 9.2 Verify the migration's abort paths (app running, fork not installed, fork already has data) and `--force` backup
- [ ] 9.3 On the 2017 Mac (macOS 13): run the Debug build and fix every Perception untracked-access warning
- [ ] 9.4 On the 2017 Mac: run the release build and verify the platform-compatibility scenarios (keyboard navigation, live settings, window titles, calendar prompt, palette responsiveness, scrolling) and the feature-availability scenarios
- [ ] 9.5 Verify that a rebuilt app keeps preferences and the Accessibility permission, and that Backup import from the official app works

## 10. Documentation

- [x] 10.1 Rewrite the `AGENTS.md` posture and non-negotiables for the fork (macOS 13 floor, Perception, allowed compatibility helpers, scrolling files, no upstream merges, fork identity, migration script)
- [x] 10.2 Update `README.md` with requirements, build and signing steps, data isolation, the migration script and Backup import, removed features and known limitations
