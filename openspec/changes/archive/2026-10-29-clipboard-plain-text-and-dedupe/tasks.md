## 1. Default action

- [x] 1.1 Add `ClipboardDefaultAction.defaultChoices` (`.paste`, `.copy`), drive the Default action
  picker from it, and drop the plain-text-default branch in `action(for:on:)`
- [x] 1.2 In `AppSettings`, map `.pastePlainText` to `.paste` on load and in the property's `didSet`
- [x] 1.3 Update `defaultActionChords` in `Tests/clipboard-test.swift` for the two defaults

## 2. Paste as Plain Text command

- [x] 2.1 Add `CommandID.pasteAsPlainText` (name "Paste as Plain Text", `doc.plaintext`) after
  `pasteMarkdownAsRichText`; list it in the clipboard `ownedCommands` and `applyEnabled`, and route
  it in `LauncherCoordinator.runCommand`
- [x] 2.2 In `ClipboardCoordinator`, extract the Markdown command's guard/snapshot/paste/restore body
  into a shared helper with generic flag and delay names, and add `pasteClipboardAsPlainText()` using
  `Paster.pasteStringInPlace`

## 3. History dedupe

- [x] 3.1 Add the `items_kind_text` index and a lookup of the newest row by kind and text
- [x] 3.2 Make `reinsert` update `source_app`; in `addText` and `addFiles`, do nothing on a pinned
  match, reinsert the newest unpinned match with the new time and source, otherwise insert
- [x] 3.3 Add harness cases: non-consecutive text repeat, repeat beyond the resident window, pinned
  match, whitespace difference, source app update, file path repeat

## 4. Quick Look

- [x] 4.1 Rename `PaletteState.fileSearchQuickLook` to `quickLookOpen` across its resets, the
  `onEscape` hook and File Search
- [x] 4.2 Generalise `FileSearchQuickLook` to a name and URL; keep File Search's behavior unchanged
- [x] 4.3 Add `ClipboardItem.offersQuickLook`; in `ClipboardScreen`, handle `.quickLook` in `perform`
  (missing-content HUD), add the "Quick Look ⌘Y" menu row, overlay the card on the selected entry and
  unmount the side preview while it is open
- [x] 4.4 Add a harness case for `offersQuickLook`
- [x] 4.5 Add `ZoomableImageSurface` for image files in the card (pinch, scroll, double-click
  fit/1:1, fitted per entry) and enable pinch on the card's `PDFView`
- [x] 4.6 Route the ⌘+ / ⌘− zoom token to the open card (image or PDF) instead of the emoji grid
- [x] 4.7 ⌘-scroll zoom around the pointer on the image surface and the card's `PDFView`; click-drag
  panning with a hand cursor on zoomed images

## 5. Docs and checks

- [x] 5.1 Update `docs/features/clipboard.md` (Default action, new command, dedupe, Quick Look),
  `docs/features/file-search.md` (shared card), the manual checks in `docs/testing.md`, and the
  command lists in `AGENTS.md` and `README.md`
- [x] 5.2 Run `./Scripts/run-tests.sh`, the Debug build, `./Scripts/build-dmg.sh`, lint and the
  Model-import check
