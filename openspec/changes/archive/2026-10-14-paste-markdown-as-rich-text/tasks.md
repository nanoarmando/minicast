## 1. Dependency

- [x] 1.1 Add swift-markdown to `project.yml` packages and the Tinycast target, regenerate with
  `./.tools/xcodegen/bin/xcodegen generate`, and commit the resolved pin
- [x] 1.2 Extend the harness wrapper package in `Scripts/run-tests.sh` to build swift-markdown at the
  pinned version

## 2. Conversion

- [x] 2.1 Add `Features/Clipboard/Model/MarkdownRichText.swift`: GFM Markdown to an HTML document with
  the minimal stylesheet (Foundation and Markdown imports only)
- [x] 2.2 Add `Tests/markdown-rich-text-test.swift` covering every element in the GFM coverage
  requirement, and register it in `docs/testing.md`

## 3. Paste

- [x] 3.1 In `Paster`, write one item with HTML, RTF (from the HTML, images replaced by links), the
  Markdown as plain text and the internal marker, then paste in place
- [x] 3.2 In `ClipboardCoordinator`, add the command action: no-text message, pasteboard snapshot,
  paste to the target app, restore the snapshot after the settle delay, ignore repeats meanwhile

## 4. Command

- [x] 4.1 Add `CommandID.pasteMarkdownAsRichText` with name and `doc.richtext` symbol after
  `pasteSequentially`
- [x] 4.2 List it in the clipboard `ownedCommands`, in `applyEnabled`'s `setCommandsVisible` set, and
  route it in `LauncherCoordinator.runCommand`

## 5. Docs and checks

- [x] 5.1 Document the command in `docs/features/clipboard.md`, add manual checks to
  `docs/testing.md`, and update `AGENTS.md` and `README.md` for the new command and package
- [x] 5.2 Run `./Scripts/run-tests.sh`, the Debug build, `./Scripts/build-dmg.sh`, lint and the
  Model-import check; paste into Mail, Notes, Slack and a Chromium editor
