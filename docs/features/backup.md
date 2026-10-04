# Backup

Export and import of the complete Minicast setup as a single `.minicast` bundle, plus the entry point
for importing a Raycast export. The feature lives in `Features/Backup/`.

A bundle carries six independently selectable categories, all ticked on export and offered again on
import when present: **Settings & Shortcuts**, **Extensions**, **AI & MCP**, **Clipboard History**,
**AI Chat History** and **Launcher Learning**. Only Keychain secrets never travel.

Export writes `Minicast-<date>.minicast`: a standard ZIP (format 2) with the exported type
`com.minicast.backup`. Renamed to `.zip`, Archive Utility opens it. The open panel also accepts
`.tinycast` (`com.tinycast.backup`, declared as an *imported* type), and older format-1 `.minicast`
files, both AppleArchive. They import as before. Categories Minicast does not have (the official app's
snippets and notes) are ignored.

Both flows run in the **Import & Export** window (`UI/BackupWindowView.swift`, owned by
`BackupCoordinator` on `AppCore`). The launcher's Export and Import commands open it on the matching
side, and **Settings → Backup** opens it too. The pane keeps the Raycast import and the
[settings file](settings-file.md) switch.

## Invariants

- **Keychain material never enters a bundle, and export never reads the Keychain.** AI API keys, MCP
  secrets, installed-AI environment values and extension OAuth tokens stay on the Mac that has them.
  Export records only *which* ids had a secret (`connectionsWithSecrets`, `serversWithSecrets`,
  `installedToolsWithSecrets`) through `KeychainSecretStore.hasSecret`, an attributes-only query that
  materializes no secret bytes and raises no prompt.
- **Extension data outside the Keychain does travel, in plain text.** Password-type preferences,
  LocalStorage and support files are carried as stored. The export side warns that the file is
  sensitive, and the bundle is written with mode `0600`.
- **A capability switch travels but is applied only after consent.** `SettingsBackupCoverage.capabilities`
  names the keys: `extensionsEnabled`, `mcpEnabled`, `aiEnabled`, `quickActionsEnabled`,
  `calendarEnabled`, `autoJoinMeetings` and `clipboardTextSearchEnabled`. Content applies first. Then,
  if any switch would turn **on**, a dialog lists what would become able to run (extensions, MCP stdio
  commands, installed-AI overrides, shell-running custom commands and fallbacks). Declining keeps every
  switch as it was. A switch that only turns off applies without asking. Calendar goes through
  `CalendarCoordinator.enableAfterGrant()`, so macOS still asks for access first.
- **`SettingsBackup`'s mirror is hand-written, and reflection is never the fix.** `AppSettingsKey` owns
  every key `AppSettings` persists. `SettingsBackupCoverage` places each in exactly one bucket, and
  `settings-backup-test` fails when a key is in none. Adding a setting means editing
  `SettingsBackupCoverage` in the same commit.
- **Machine-local keys never travel.** Palette position and expanded displays, the extension package
  manager and custom search paths, the input source to switch to, the meeting browser, the settings-file
  switch and launch at login describe one Mac.
- **Import replaces each selected category, and leaves the rest untouched.** A confirmation names the
  categories and the installed extensions that would be uninstalled. A format-1 file still merges, as it
  always did.
- **No absolute path may enter the Minicast-owned parts of a bundle.** A clip's `imagePath` names a
  file on the Mac that wrote it, so `BackupClipboardItem` carries a bundle-relative `imageName`.
  Extension data is third-party content and is carried as-is.
- **Each reader accepts only its own format.** A `PK` signature routes to the format-2 reader and
  anything else to the format-1 AppleArchive reader. Each compares its version with `==`. This is two
  readers, not a migration. A higher number fails with "made by a newer Minicast".
- **Extraction is checked before anything is written.** See [Inside the file](#inside-the-file).
- **`BackupCategory` names every category, and its `descriptor` switch is exhaustive.** A new case
  fails to build until it names a label, a symbol, a bundle subpath and a count noun.

## Layout

| File | Role |
| --- | --- |
| `Model/BackupCategory.swift` | The categories and the descriptor every one of them must name |
| `Model/BackupManifest.swift` | The table of contents, the format constants and their guard |
| `Model/BackupBundle.swift` | The payload directory's layout (both formats) and part-by-part encode/decode |
| `Model/BackupArchive.swift` | Format detection, ZIP entry validation, and the format-1 AppleArchive reader |
| `Model/BackupPayloads.swift` | The AI, MCP and quick-action parts, and the pending-secret row |
| `Model/BackupClipboardItem.swift` | The portable clip, with no path in it |
| `Model/SettingsBackup.swift` | Settings, capability values, hotkey payloads, and their `Codable` shape |
| `Model/SettingsBackupCoverage.swift` | The coverage declaration the harness checks |
| `Model/RaycastImport.swift` | The importable categories, the `Result` and its per-category trim |
| `Model/RaycastImportError.swift` | The three failures an import reports |
| `Service/BackupZip.swift` | Directory ⇄ ZIP through `ditto` and `zipinfo` |
| `Service/BackupStaging.swift` | One scratch tree, created on init and removed on discard |
| `Service/BackupComposer.swift` | Stores → staging; `plan` on main, `write` off it |
| `Service/BackupApplier.swift` | Staging → stores in dependency order, returning a per-category summary |
| `Service/BackupActions.swift` | Pickers, replace confirmation, capability consent, the settings-file switch |
| `UI/BackupCoordinator.swift` | The window, one export and one import in flight, and their results |
| `UI/BackupWindowView.swift` | The Export and Import sides |
| `Settings/BackupCategorySelection.swift` | The category checkboxes, on both sides |
| `Settings/BackupSettingsView.swift` | The pane: buttons into the window, Raycast import, settings file |
| `Features/Extensions/Service/ExtensionBundle.swift` | An extension's slice of a bundle, owned by Extensions |

## Inside the file

```
manifest.json                 format 2, app version, createdAt, per-category counts
settings/settings.json        SettingsBackup (settings, capabilities, hotkeys, collections)
settings/quick-actions.json   custom quick actions and every quick-action choice
extensions/index.json         [{name, storeVersion?, appearance?}]
extensions/<name>/package/    the installed folder
extensions/<name>/data.json   preferences, LocalStorage, cache, accessory values
extensions/<name>/commands.json   that extension's command state
extensions/<name>/support/    the extension support folder
ai/ai.json                    AI settings, connections, installed tools, secret flags
ai/mcp.json                   MCP servers, secret flags
clipboard/items.jsonl         one clip per line
clipboard/images/<uuid>.png
chats/ai-chats.sqlite3        a consistent copy of the chat database
learning/{ranking,emoji,calculator}.json
```

A category the user didn't tick has no key in `counts` and no files in the bundle, which is how the
import picker greys a row out.

**The container is `ditto`'s ZIP.** Export runs `ditto -c -k --norsrc --noextattr --noacl`, so a
bundle carries file contents only, with no `__MACOSX` folder. Import lists the entries with
`zipinfo -1` and `zipinfo -s` and refuses absolute paths, `..` components and symlink entries before
`ditto -x -k` writes anything. It then re-checks the extracted tree for symbolic links. Extension
folder names must be one safe component each, or the bundle is refused (`ExtensionBundle.entries`).
Exported extension trees resolve a symlinked file into a file and drop any other link, so a bundle
never carries one.

**Clipboard history is JSONL, everything else is JSON.** A single JSON array of 200,000 clips has to be
built in memory to encode and again to decode. A line per clip is one small encode through an open
`FileHandle` on the way out and one mapped read on the way back. Splitting on `\n` is legal because a
newline inside a clip is escaped by the encoder. `backup-archive-test` asserts the line count equals
the clip count.

**Chats are a SQLite backup.** `ChatHistoryStore` snapshots through `sqlite3_backup_*`, which gives a
consistent copy, WAL included, while the live database stays open. A Mac with no chat database exports
an empty one, so importing it still clears the chats.

**Format 1 is AppleArchive, read and never written.** It uses LZFSE with the keyset
`"TYP,PAT,DAT,MOD,MTM"`, so it has no `UID`/`GID` and no `IDX`. `BackupArchive.open` skips any entry
whose path is absolute or contains `..`, then refuses an extract holding a symbolic link.
`settings.json` sits at the root of a format-1 tree, and `BackupBundle(format:)` reads it from there.

**Staging lives in `Caches`, not `temporaryDirectory`.** It sits on the same volume as Application
Support, so a clipboard PNG crosses into the bundle as a hardlink. The ZIP is written inside staging,
set to `0600`, then moved to the chosen location. `BackupStaging` sweeps anything a day old on the next
run, since a run killed mid-flight leaves its tree behind.

## Coverage, and why it is spelled out

`SettingsBackupCoverage` holds five tables:

- `mirrored`: each `SettingsData` field paired with the `AppSettings` key it carries.
- `externallySourced`: fields no `AppSettings` key stands behind. `launchAtLogin` comes from
  `LaunchAtLogin`. It is machine-local, so only a format-1 file still sets it.
- `capabilities`: the `CapabilityData` fields, applied only after consent.
- `carriedElsewhere`: keys a bundle carries in its own part (`ai/ai.json`, `ai/mcp.json`,
  `settings/quick-actions.json`).
- `deliberatelyExcluded`: the machine-local keys, each with its reason.

`settings-backup-test` asserts that every `AppSettingsKey` sits in exactly one table, that no field
claims a key twice, and that every exclusion names a real key with a non-empty reason. The duplication
between `AppSettings` and this file is deliberate: it forces a decision about every new setting.

Beyond `AppSettings`, Settings & Shortcuts also carries:
- every hotkey (fixed actions, apps, panes, custom commands, quick actions, window layouts, rooms and
  sizes, Apple Shortcuts and extension commands);
- custom commands, window layouts, rooms, custom and room-minimum window sizes;
- favorites, hidden launcher items and kinds, aliases, fallback order and enabled state;
- hidden meeting calendars (unknown ids are only ever tested for membership, so they are harmless);
- pinned emoji;
- custom quick actions.

## Importing

`BackupApplier` applies the selected categories in dependency order, each independently, and collects
failures into `Summary.problems` rather than stopping:

1. **AI & MCP** replaces AI settings, connections and MCP servers wholesale. Ids are kept, so a secret
   this Mac already holds under the same id still matches. The Keychain items of entries a replace
   removes are left in place, so a later re-import matches them again.
2. **Extensions** go through `ExtensionManager`. It uninstalls the extensions that are not in the bundle,
   using the same cleanup as a manual uninstall, then installs each bundled extension and restores its
   data, command state, support folder, store version and appearance. One failing extension is reported
   by name and the rest continue.
3. **Settings & Shortcuts** writes every carried key. A key absent from the bundle resets to its
   default. Collections use their stores' `replace`. This runs after Extensions because hotkeys and
   aliases are keyed by `extension:<name>/<command>`.
4. **Clipboard** clears the history, then streams through `ClipboardStore.importStoredItems`, off the
   main actor and on its own connection. An `id` never travels with a clip: `items.id` is `UNIQUE`, so
   minting fresh identities is what keeps a second pass from failing its inserts.
5. **Chats** reset the chat UI, swap the database file and reopen it.
6. **Learning** replaces. Merging two Macs' frecency tables would produce a table describing neither.
7. **Capability consent**, as described in the invariants.

Applying writes through the owning stores and `AppSettings` like any other change, so the launcher
reprojects through normal observation.

The summary reports what was applied. After an AI & MCP import, it also lists each connection, server or
installed tool that had a secret on the source and has none here. Each row opens the AI or MCP settings
where that secret is set. Extensions ask for their OAuth sign-in again on first use.

The old flat `Tinycast-Settings-*.json` export is gone rather than deprecated, and nothing reads it.

Raycast import is documented separately in [raycast-import.md](raycast-import.md).
