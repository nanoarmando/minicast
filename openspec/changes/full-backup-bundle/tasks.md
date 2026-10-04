## 1. Container and format

- [x] 1.1 Add ZIP entry validation (absolute paths, `..`, symlink entries, unsafe extension names) to
  `Backup/Model/BackupArchive.swift` and a `Service/` wrapper running `ditto -c -k`, `zipinfo -1` and
  `ditto -x -k` (D1)
- [x] 1.2 Detect the format by magic bytes; keep the format-1 AppleArchive reader for old `.minicast`
  and `.tinycast` files; manifest format 2 with a newer-format error (D2)
- [x] 1.3 Add `extensions`, `aiAndMCP` and `chatHistory` to `BackupCategory` with descriptors and the
  D3 layout in `BackupBundle`

## 2. Settings & Shortcuts coverage

- [x] 2.1 Rework `SettingsBackupCoverage` so only machine-local keys stay excluded and capability keys
  sit in their own declared list (D4)
- [x] 2.2 Extend `SettingsBackup` with the full hotkey payload (quick actions, Apple Shortcuts, extension
  commands), fallbacks, hidden meeting calendars, room minimum sizes and capability values
- [x] 2.3 Carry custom quick actions and quick-action settings
- [x] 2.4 Switch settings apply to replace semantics (absent key resets to default) (D6)

## 3. Extensions

- [x] 3.1 Add `ExtensionStorage.flush()` use before export and `replaceAll(name:with:)` for restore
- [x] 3.2 Add `ExtensionManager.exportBundle(into:)` (files, data, command slice, support folder, store
  version, appearance)
- [x] 3.3 Add `ExtensionManager.restoreBundle(from:)`: uninstall the extensions that are not in the
  bundle, install the bundled ones, then restore data, metadata, version and appearance, reporting
  per-extension failures

## 4. AI, MCP and chats

- [x] 4.1 Export and replace AI connections, AI settings, installed-tool settings and MCP servers,
  keeping UUIDs
- [x] 4.2 Record `hasSecret` flags with an attributes-only Keychain query (D7)
- [x] 4.3 Add the `ChatHistoryStore` SQLite backup snapshot and the replace-on-import path (D8)
- [x] 4.4 Clear-then-import for clipboard history

## 5. Apply flow and consent

- [x] 5.1 Order the applier as in D6 and collect per-category failures in the summary
- [x] 5.2 Build the replace confirmation (categories plus extensions to uninstall)
- [x] 5.3 Replace `confirmExecutableImport` with the capability consent step that lists extensions,
  MCP commands, AI overrides and shell-running commands and fallbacks (D5)
- [x] 5.4 Build the pending-secrets list with deep links to the AI and MCP settings anchors

## 6. Window

- [x] 6.1 Add `BackupCoordinator` on `AppCore` owning the Import/Export `AppWindowController` (D9)
- [x] 6.2 Build the export side (categories, sensitivity warning, save) and the import side (open,
  categories present in the bundle, summary)
- [x] 6.3 Route the launcher Export and Import commands and the Backup pane button to the window; keep
  the Raycast import and the `settings.json` switch in the pane

## 7. Tests and docs

- [x] 7.1 Extend `backup-archive-test`: format-2 round trip, format-1 still read, hostile ZIP cases, no
  Keychain values, no `/Users` in Minicast-owned parts
- [x] 7.2 Extend `settings-backup-test` for the new coverage buckets
- [x] 7.3 Rewrite the invariants in `docs/features/backup.md`; update `extensions.md` (including the
  stale appearance line), `ai.md`, `mcp.md`, `docs/testing.md`, `README.md` and `AGENTS.md`
- [ ] 7.4 Run the Definition of Done: harnesses, Debug and universal Release builds, lint, Model import
  grep, and a manual export from one channel imported into a wiped Dev channel
