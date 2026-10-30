## Context

`ClipboardDefaultAction` (`paste`, `copy`, `pastePlainText`) is both the Default action setting and
the action vocabulary for the ↵, ⌘↵ and ⌃⌘↵ chords and the ⌘K menu; `action(for:on:)` maps chords to
actions. The settings picker lists `allCases`. `AppSettings` loads the stored raw value with a
`.paste` fallback, and `settings.json` and backup restore assign the same property.

Paste Markdown as Rich Text (`ClipboardCoordinator.pasteMarkdownAsRichText`) is the model for a
no-view command that pastes the live clipboard: a repeat guard, `prepareForTinycastPasteboardMutation`,
`Paster.snapshot`, a marker-stamped write pasted in place, and `Paster.restore` after a settle delay.

`ClipboardStore.addText` and `addFiles` skip only a repeat of the newest row. `promote`/`reinsert`
already move a row to the top under the same id (keeping FTS and recognized-text rows) but do not
update `source_app`. The resident `items` window holds 1000 rows plus pins; older rows exist only in
SQLite, and `text` has no index.

File Search already has ⌘Y Quick Look as an overlay card inside the palette
(`FileSearchQuickLook` over `FileSearchSurface`, which routes to `QLPreviewView`, PDFKit, AVKit or
plain text). `QLPreviewPanel` is avoided on purpose: the palette is non-activating and hides on
`windowDidResignKey`, so a system panel would take key and close the palette. `PaletteShortcut`
already resolves ⌘Y to `.quickLook` on every screen; `ClipboardScreen.perform` ignores it today.
State lives in `PaletteState.fileSearchQuickLook`, reset on hide, screen change and mode change, and
`PalettePanel.onEscape` closes it before SwiftUI sees Esc.

## Goals / Non-Goals

**Goals:**
- Reuse the command, hotkey, visibility and paste plumbing with no new mechanism.
- Keep ⌃⌘↵ and the ⌘K plain-text row unchanged.
- Dedupe across the whole history at insert cost close to today's.

**Non-Goals:**
- Image dedupe, cleanup of stored duplicates, normalised or case-insensitive matching.

## Decisions

- **Keep the enum, narrow the choices.** `ClipboardDefaultAction` keeps all three cases because the
  chords and the menu need `.pastePlainText`. A static `defaultChoices: [.paste, .copy]` drives the
  picker. `AppSettings.clipboardDefaultAction`'s `didSet` turns `.pastePlainText` into `.paste`, and
  the initial load does the same, so `settings.json`, backup restore and old preferences all pass
  through one rule. Alternative: a separate setting enum — cleaner types, but it splits one concept
  across two enums and rewrites `action(for:on:)` and its tests for no behavioral gain.
- **Chords with a narrowed default.** With `.pastePlainText` never the default, `action(for:on:)`
  always maps ⌃⌘↵ to `.pastePlainText`; the unused branch for a plain-text default is removed.
- **Command wiring.** A `pasteAsPlainText` `CommandID` after `pasteMarkdownAsRichText` (name "Paste
  as Plain Text", symbol `doc.plaintext`, in SF Symbols 4), added to the clipboard `ownedCommands`, to
  `applyEnabled`'s `setCommandsVisible` set and to `runCommand`. It gets its hotkey slot from
  `CommandID.hotKeyAction` with no default binding.
- **One live-clipboard paste routine.** The Markdown method's guard/snapshot/paste/restore body
  becomes a private helper that takes the content writer; Markdown passes its HTML/RTF writer and the
  new `pasteClipboardAsPlainText()` passes `Paster.pasteStringInPlace`. The repeat flag and settle
  delay are renamed generically (`isPastingClipboard`, `clipboardRestoreDelay`) and shared, so the two
  commands also guard each other. The plain text is `NSPasteboard.general.string(forType: .string)`,
  unchanged.
- **Dedupe lookup in SQLite.** `addText`/`addFiles` look up the newest row with the same `kind` and
  `text` via `SELECT … WHERE kind = ? AND text = ? ORDER BY rowid DESC`, so rows beyond the resident
  window are found. A new `CREATE INDEX IF NOT EXISTS items_kind_text ON items(kind, text)` makes it an
  index seek; being `IF NOT EXISTS`, it needs no migration. If any match is pinned, nothing happens;
  otherwise the newest match is reinserted with the new time and source app. Alternative: search only
  the resident window — simpler, but misses older duplicates, which the user ruled out.
- **`reinsert` carries the source app.** The UPDATE also sets `source_app`, and the item copy takes
  the new `sourceBundleID`. `promote` and `unpin` pass the item's own value, so their behavior is
  unchanged.
- **Multi-file copies.** Each path in the batch is deduped on its own; the batch prunes once as today.
- **Quick Look reuses File Search's in-palette card.** `FileSearchQuickLook` is generalised to take a
  name and a URL, and the clipboard screen overlays it on its non-empty list, fed by the selected
  entry's `clipURL`. The palette keeps the keyboard, so ⌘Y, arrows and Esc work with no new
  responder. Alternative: `QLPreviewPanel` — rejected for the reason above, and it would steal the
  arrows and need an activation that breaks the paste target.
- **One shared flag.** `PaletteState.fileSearchQuickLook` becomes `quickLookOpen`, used by both
  screens, so the existing resets and the `onEscape` hook cover the clipboard with no second copy.
- **Availability on the model.** `ClipboardItem.offersQuickLook` (image with a stored path, or any
  file, folders included) drives both the ⌘K row and the ⌘Y chord, like `offersTextExtraction`.
  Existence is checked in the coordinator before opening; a missing file uses the existing
  `reportUnavailable` HUD and a missing image blob gets "That image is no longer available."
- **Zoom by rendering images in process.** `QLPreviewView` offers no zoom inside a non-activating
  panel, so the card (not the side pane) draws image files with a new `ZoomableImageSurface`: an
  `NSImageView` in an `NSScrollView` with `allowsMagnification`, plus double-click to toggle fit and
  1:1. PDFs already use `PDFView`; it gets the same steps through `zoomIn`/`zoomOut`. Being the shared
  card, File Search's ⌘Y gains zoom too. A new view per URL resets zoom on every selection.
- **⌘-scroll zooms, not pinch.** The palette never activates the app, and macOS does not deliver
  magnify gestures to an inactive app, so pinch cannot be relied on. Both surfaces override
  `scrollWheel` and, with ⌘ held, set the magnification around the pointer from the scroll delta;
  without ⌘ they scroll as before. The built-in pinch handling stays for when it is delivered.
- **Drag to pan images.** The image view tracks a click-drag to move the clip view's origin, with an
  open/closed hand cursor while the image exceeds the card. PDFs keep drag for text selection.
- **⌘+ / ⌘− reuse the emoji zoom chords.** `PaletteWindowController.emojiGridZoom` already decodes
  them into `PaletteState`'s zoom token; while `quickLookOpen` is true the token is routed to the card
  instead of the emoji grid. ⌘0 is not used for the card: on the clipboard screen it is the tenth pin.
- **One player at a time.** While the card is open, the clipboard's side preview is not mounted, the
  same rule File Search follows, so a video never plays twice.

## Risks / Trade-offs

- [The index stores each text again, up to 32,000 characters] → history text is small next to image
  blobs; accepted for a constant-time lookup.
- [A row beyond the window moves into it] → `reinsert` already inserts at the head and trims the
  window, the same path `promote` uses for search results.
- [A stored plain-text default changes ↵'s behavior silently] → this is the requested outcome; the
  picker then shows Paste.

## Migration Plan

None in the app. The index is created on open; old preferences fall back through the setter.
Rollback is reverting the change; the extra index is harmless.
