## Context

See proposal.md for motivation. Today `Features/Backup/` exports format 1: an AppleArchive (LZFSE)
written by `BackupArchive`, holding `manifest.json`, `settings.json`, `clipboard/` and `learning/`.
`BackupComposer.plan` reads stores on main, `write` runs off-main into `BackupStaging`, and
`BackupApplier` merges settings, streams clipboard rows and replaces learning. `SettingsBackupCoverage`
gives every `AppSettingsKey` a declared status, and `settings-backup-test` enforces it.

Constraints that shape the approach:
- `Features/*/Model/` cannot import AppKit or SwiftUI, and gets paths and clock injected.
- Extension code stays in `Features/Extensions/`. Backup calls an opaque export and restore API.
- `ExtensionStorage` caches in memory and flushes after 250 ms, so its files cannot be copied or written
  behind its back.
- Keychain items are addressed by the UUIDs of AI connections and MCP servers that live in
  `UserDefaults`.
- The app is not sandboxed, and `ExtensionInstaller` already runs `/usr/bin/ditto` through `Process`.

## Goals / Non-Goals

**Goals:**
- One ZIP container, one staging layout and one composer/applier pipeline for all six categories.
- Restore through each owner's API so in-memory stores, launcher rows and hotkeys stay consistent.

**Non-Goals:**
- Encryption, store re-download, sync through `settings.json`, merge mode, partial extension selection.

## Decisions

### D1. ZIP through `ditto`, with a pre-extraction entry check
Export runs `ditto -c -k --sequesterRsrc --norsrc <staging> <file>`. Import first lists entries with
`/usr/bin/zipinfo -1` and rejects absolute paths, `..` components and symlink entries. Only then does it
run `ditto -x -k` into a fresh staging folder, and it re-checks the tree for symlinks (reusing the
existing `containsSymbolicLink` rule). The pure path checks live in `Model/BackupArchive.swift`. The
`Process` calls live in a `Service/` file.
- *Alternative:* a pure-Swift ZIP writer. More code to own, and the repo has no dependency for it.
- *Alternative:* keep AppleArchive. Rejected by the user: the file must open as a ZIP.

### D2. Format detection by magic bytes, version `2`
A file starting with `PK\x03\x04` is read as a format-2 bundle. Anything else goes through the existing
format-1 AppleArchive reader unchanged. `BackupManifest` accepts the set `{1, 2}`. Each reader still
checks its own version with `==`, so this adds a second reader and no migration. A format above 2 fails
with the existing "made by a newer Minicast" error.

### D3. Bundle layout
```
manifest.json
settings/settings.json        Settings & Shortcuts (extended SettingsBackup)
settings/quick-actions.json
extensions/index.json         [{name, storeVersion?, appearance?}]
extensions/<name>/package/    the installed folder, as on disk
extensions/<name>/data.json   ExtensionStorage file (prefs, LocalStorage, cache, accessory values)
extensions/<name>/commands.json   that extension's slice of extension-commands.json
extensions/<name>/support/    the extension support folder
ai/ai.json                    AI connections + AI settings + installed-tool settings + secret flags
ai/mcp.json                   MCP servers + secret flags
clipboard/...                 unchanged from format 1
chats/ai-chats.sqlite3        consistent copy of the chat database
learning/...                  unchanged from format 1
```
`BackupCategory` gains `extensions`, `aiAndMCP` and `chatHistory`, each with its descriptor. Extension
folder names must pass `ExtensionCatalog.safeName` equality, or the bundle is rejected (spec: Safe
bundle extraction).

### D4. Settings coverage becomes "carried unless machine-local"
`SettingsBackupCoverage.deliberatelyExcluded` shrinks to the machine-local keys named in the spec, plus
`launchAtLogin` (externally sourced). The AI, MCP and quick-action keys move to the AI & MCP and
Settings payloads. Capability keys move to a new `SettingsBackupCoverage.capabilities` list, so the
harness still forces each key into exactly one declared bucket. The hotkey payload gains quick-action,
Apple Shortcut and extension-command bindings. The settings payload gains `fallbackOrder`,
`disabledFallbacks`, `hiddenMeetingCalendars`, `roomMinimumWindowSizes` and the custom quick actions.

### D5. Capability consent is a separate apply step
`BackupApplier` applies every selected category with the capability keys held back. `BackupActions` then
shows `DialogController.confirm` with a list built from the staged content: extension names, MCP stdio
commands, installed-AI overrides, and shell-running custom commands and fallbacks. Only on accept does
it write the capability values through the same setters the UI uses (for example
`ExtensionCoordinator.applyEnabled`). This replaces today's `confirmExecutableImport`, which covers a
subset of the same question.

### D6. Replace semantics per category
- **Settings:** every carried key is written. A key absent from the bundle resets to its default.
  Collections (layouts, rooms, aliases, favorites and the rest) use the stores' existing `replace`.
- **Extensions:** `ExtensionManager` gains `exportBundle(into:)` and `restoreBundle(from:)`.
  - Export calls `ExtensionStorage.flush()` before copying.
  - Restore uninstalls the extensions that are not in the bundle through the existing uninstall path.
    For each bundled extension it runs `ExtensionCatalog.install(from:)`, which restores executable
    bits. It then calls a new `ExtensionStorage.replaceAll(name:with:)`, writes the command metadata
    slice and the support folder, and records the store version and appearance.
  - Launcher rows refresh only when extensions are enabled. `refresh()` already returns early otherwise.
- **AI & MCP:** connection and server lists are replaced wholesale. UUIDs are kept, so a secret already
  in this Mac's Keychain under the same UUID still matches (spec: Secrets already present).
- **Clipboard:** existing items are cleared, then the existing streaming import runs.
- **Chats:** the database is closed, the file is replaced and the database is reopened through
  `ChatHistoryStore`.
- **Learning:** replaces, unchanged from today.

Ordering: AI & MCP, then Extensions, then Settings & Shortcuts (whose hotkeys and aliases key on
extension entry IDs), then Clipboard, Chats and Learning, then the consent step.

### D7. Secret flags without reading secrets
Export records `hasSecret: Bool` per connection, server and installed tool, using an attributes-only
Keychain query (`kSecReturnAttributes`, no `kSecReturnData`). That query does not return the secret and
does not show a prompt. Import lists an entry as pending when the flag is true and
`KeychainSecretStore.hasSecret` is false on the destination. Each pending row deep-links to the AI or
MCP settings anchor.

### D8. Chat history snapshot
`ChatHistoryStore` gains a `nonisolated` snapshot that uses `sqlite3_backup_*` into the staging file.
This gives a consistent copy, including WAL contents, without closing the live database.

### D9. Window
`ImportExportWindow` is an `AppWindowController` instance owned by a `BackupCoordinator` on `AppCore`.
Its SwiftUI content has two sides (Export and Import) and reuses `BackupCategorySelection`. The launcher
`exportSettings` and `importSettings` commands and the Backup pane button call `show(side:)`. The
existing summary moves into the window and gains the pending-secrets list.

## Risks / Trade-offs

- [Plaintext secrets outside the Keychain travel: extension passwords and LocalStorage tokens] → Export
  warning (spec). Bundles are written with mode `0600`.
- [Absolute paths inside extension data, such as application-type preferences] → They are carried as-is,
  since this is third-party data that cannot be rewritten. The "no `/Users` in the file" assertion is
  limited to Minicast-owned parts of the bundle.
- [Large clipboard or chat data makes a big ZIP and a slow export] → Categories can be deselected. Work
  runs off-main with the existing progress state.
- [Older Minicast builds cannot read format 2] → Accepted. The single user updates both Macs.
- [Replace uninstalls extensions the user forgot were missing from the bundle] → The confirmation names
  the extensions that will be removed.
- [Calendar IDs in `hiddenMeetingCalendars` may not exist on the destination] → Unknown IDs are already
  ignored by `CalendarStore`. This must be verified while implementing, and filtered if it is not true.

## Migration Plan

No data migration. The app writes format 2 from the first build and reads formats 1 and 2. Rollback
means reverting the change, after which format-2 files are unreadable by that build.
