## Why

Moving Minicast to another Mac (for example the 2017 MacBook Pro) restores only settings, clipboard
history and launcher learning today. Extensions, their preferences, AI connections, MCP servers, AI chat
history, quick actions and the capability switches all have to be set up again by hand, so a "backup" is
not a real setup transfer. The user wants one file that carries the whole setup, so a second Mac ends up
in the same state after one import.

## What Changes

- **BREAKING (file format):** export writes a ZIP bundle (still named `*.minicast`, format 2) instead of
  an AppleArchive. Older Minicast builds cannot read the new file. New builds still import format-1
  `.minicast` and `.tinycast` files.
- The bundle carries everything Minicast stores **except Keychain secrets**: all settings, including the
  AI, MCP and quick-action settings that are excluded today; every hotkey, including the quick-action,
  Apple Shortcut and extension-command ones; custom quick actions; fallbacks; hidden meeting calendars;
  room minimum sizes; installed extensions (their files, preferences including password-type values,
  LocalStorage, cache, command state, support folder, store version and appearance); AI connections;
  MCP servers; AI chat history; clipboard history; and launcher learning.
- The capability switches (extensions, MCP, AI, quick actions, calendar, auto-join meetings, clipboard
  text recognition) travel in the bundle. On import they are applied only after a confirmation that
  lists what would become able to run. If the user declines, the content is still imported and the
  switches stay as they are.
- Export offers six categories, all ticked by default: Settings & Shortcuts, Extensions, AI & MCP,
  Clipboard History, AI Chat History, Launcher Learning.
- Import **replaces** each selected category with the bundle's content, after a confirmation. Categories
  that are not selected are left untouched.
- After an import, a summary lists the AI connections, MCP servers and installed AI tools whose Keychain
  secrets must be entered again, and links to where each one is set.
- A new Import/Export window hosts both flows. The launcher's Export and Import commands open it, and
  Settings → Backup links to it. The Backup pane keeps the Raycast import and the `settings.json` switch.
- The documented backup invariants are revised to match: capability switches and extensions now travel,
  and Keychain material is the line that is never crossed.

## Capabilities

### New Capabilities
- `backup-bundle`: export and import of the complete Minicast setup as a single ZIP bundle, excluding
  Keychain secrets, with per-category selection, replace-on-import, consent for capability switches and
  a report of the secrets that need to be entered again.

### Modified Capabilities
None. `fork-identity`'s "Importing a setup from a backup file" still holds: a `.tinycast` file restores
the categories its format carries.

## Impact

- Code: `Tinycast/Features/Backup/` (archive container, manifest format, categories, composer, applier,
  actions, new window UI). `Features/Extensions/` gains export and restore entry points for an
  extension's files and data. The AI chat history store, quick-action store, hotkey payload, fallback,
  calendar and window stores gain bundle coverage. `Info.plist` keeps `com.minicast.backup`.
- Settings coverage: `SettingsBackupCoverage` moves most AI, MCP, quick-action and capability keys from
  `deliberatelyExcluded` to carried. Only machine-local keys stay excluded.
- Tests: `backup-archive-test` and `settings-backup-test` are extended. A hostile-ZIP case is added.
- Docs: `docs/features/backup.md`, `extensions.md`, `ai.md`, `mcp.md`, `docs/testing.md`, `README.md`,
  `AGENTS.md`.
- Out of scope: automatic sync through `~/.config/minicast/settings.json` (a later change), Keychain
  secrets in any form, re-downloading extensions from the store at import, and encryption of the bundle.
