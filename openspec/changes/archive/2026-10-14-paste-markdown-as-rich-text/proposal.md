## Why

Markdown copied from AI chats, READMEs or editors pastes as raw syntax (`**bold**`, `| a | b |`) into
apps that expect formatted text, such as mail, documents and chat. Minicast already pastes from the
clipboard with a hotkey (Paste Sequentially), so one more clipboard command can paste that Markdown as
formatted text without an external converter.

## What Changes

- A new built-in command, **Paste Markdown as Rich Text**, owned by the Clipboard pane. It reads the
  text currently on the clipboard, converts it from GitHub Flavored Markdown to rich text and pastes
  it into the frontmost app.
- After the paste, the clipboard holds the original Markdown again, and the converted content is
  never recorded in the clipboard history.
- The command gets the same treatment as the other clipboard commands: a shortcut recorder, an alias
  field and a launcher-visibility checkbox in the Clipboard pane. It is hidden, and its shortcut stops
  working, while Enable Clipboard History is off.
- Apple's swift-markdown package becomes the app's second Swift package dependency.
- Out of scope: a "Paste as Plain Text" command, a shortcut for the Default action setting, and
  converting entries from inside the Clipboard History palette.

## Capabilities

### New Capabilities
- `clipboard-markdown-paste`: the Paste Markdown as Rich Text command, covering what it converts, how
  it pastes, what the clipboard holds afterwards, its availability and its failure cases.

### Modified Capabilities
None.

## Impact

- Code: `Features/Launcher/Model/CommandID.swift`, `CommandCatalog.swift` (`SettingsTab.ownedCommands`),
  `Features/Launcher/UI/LauncherCoordinator.swift` (`runCommand`),
  `Features/Clipboard/UI/ClipboardCoordinator.swift`, `Features/Clipboard/Service/Paster.swift`, and a
  new Markdown converter under `Features/Clipboard/`.
- Dependencies: `project.yml` gains swift-markdown; the Xcode project is regenerated with XcodeGen.
- Tests: `Scripts/run-tests.sh` builds swift-markdown for the harnesses; a new harness covers the
  conversion.
- Docs: `docs/features/clipboard.md`, `docs/testing.md`, `AGENTS.md` (the only-package rule) and
  `README.md` where commands or dependencies are listed.
- No new preference, no `settings.json` key and no backup change.
