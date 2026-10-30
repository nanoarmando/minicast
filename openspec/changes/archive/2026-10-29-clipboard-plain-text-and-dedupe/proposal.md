## Why

Pasting without formatting needs a shortcut that works in any app, but today it exists only as a
Clipboard History action and as a Default action choice, so it can't be bound to a hotkey. The
history also fills with repeats: copying the same text again a few copies later adds a second row
instead of bringing the first one back to the top. And a copied image, PDF or video can't be viewed
at full size without leaving the palette, though File Search already previews files in place.

## What Changes

- A new built-in command, **Paste as Plain Text**, owned by the Clipboard pane. It pastes the text
  currently on the clipboard, without its formatting, into the frontmost app and then restores the
  original clipboard, exactly like Paste Markdown as Rich Text. It gets an alias field, a shortcut
  recorder and a launcher-visibility checkbox.
- The Clipboard pane's **Default action** picker offers only Paste and Copy to Clipboard. A stored
  "Paste as Plain Text" default is treated as Paste. ⌃⌘↵ and the ⌘K row keep pasting a history entry
  as plain text.
- **Clipboard history no longer keeps duplicates of text or files.** Copying text, or a file path,
  that is already in the history moves the existing row to the top with the new time and source app,
  instead of adding a row. A pinned duplicate stays where it is. Images are unchanged.
- **Quick Look in Clipboard History.** Image and file entries (images, PDFs, videos, any file) get a
  Quick Look action on ⌘Y and in the ⌘K menu, shown inside the palette in the same card File Search
  uses, so the palette stays open and the preview follows the selection.
- Out of scope: Quick Look for text entries, deduplicating images, cleaning up duplicates already stored, and fuzzy matching
  (case or whitespace differences are different entries).

## Capabilities

### New Capabilities
- `clipboard-plain-text-paste`: the Paste as Plain Text command, covering what it pastes, what the
  clipboard holds afterwards, its availability and its failure cases.
- `clipboard-history`: the Default action choices and how a repeated copy updates the history.
- `clipboard-quick-look`: previewing image and file entries from the Clipboard History palette.

### Modified Capabilities
None.

## Impact

- Code: `Features/Launcher/Model/CommandID.swift`, `CommandCatalog.swift` (`SettingsTab.ownedCommands`),
  `Features/Launcher/UI/LauncherCoordinator.swift` (`runCommand`),
  `Features/Clipboard/UI/ClipboardCoordinator.swift`, `Features/Clipboard/Model/ClipboardStore.swift`
  (default-action choices, dedupe, an index on stored text),
  `Features/Clipboard/Settings/ClipboardSettingsView.swift`, `Features/Settings/AppSettings.swift`,
  `Features/Clipboard/UI/ClipboardScreen.swift`, `Features/FileSearch/UI/FileSearchQuickLook.swift`
  (generalised card), `Palette/PaletteState.swift`, `Palette/RootPaletteView.swift`,
  `Palette/PaletteWindowController.swift` (shared Quick Look flag and Esc).
- Tests: `Tests/clipboard-test.swift` (default-action chords, dedupe, Quick Look availability).
- Docs: `docs/features/clipboard.md`, `docs/features/file-search.md`, `docs/testing.md`, `AGENTS.md` and `README.md` where clipboard
  commands are listed.
- No new preference, no `settings.json` key and no backup change. The SQLite schema gains one index,
  created with `IF NOT EXISTS`.
