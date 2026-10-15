## Context

Clipboard commands are `CommandID` cases. `SettingsTab.ownedCommands` places them in the Clipboard
pane, where `FeatureCommandRow` gives every bindable command an alias, a shortcut recorder and a
launcher checkbox. Hotkeys and launcher rows both end in `LauncherCoordinator.runCommand`.
`ClipboardCoordinator.applyEnabled` hides the pane's commands while clipboard history is off, and
`AppCore`'s `allowsAction` then refuses their shortcuts. Paste Sequentially
(`ClipboardCoordinator.pasteNextInSequence`) is the model for pasting into the target app:
`prepareForTinycastPasteboardMutation`, a pasteboard write marked with `ClipboardManager.internalType`,
then `Paster.pasteInPlace`, which posts ⌘V to the target pid. Nothing in the app converts Markdown to
HTML today, and swift-perception is the only Swift package.

## Goals / Non-Goals

**Goals:**
- Output that matches how GitHub renders the same Markdown.
- Reuse the existing command, hotkey, visibility and paste plumbing with no new mechanism.

**Non-Goals:**
- Styling the output beyond a minimal stylesheet (no themes, colours or syntax highlighting).
- Converting from a clipboard-history row, or any other source than the live clipboard.

## Decisions

- **swift-markdown for parsing and HTML.** Apple's package wraps cmark-gfm, the engine GitHub uses,
  and its `HTMLFormatter` turns a parsed `Document` into HTML. It runs on macOS 13. Alternatives: a
  hand-written parser (large, fragile, drifts from GitHub), or `AttributedString(markdown:)` (no
  tables, and headings carry no visual style).
- **Pure converter in `Features/Clipboard/Model/`.** A `MarkdownRichText` type takes a Markdown
  string and returns an HTML document string: the formatter output wrapped in a small `<style>`
  block (system font, collapsed table borders, and fixed sizes chosen by the user: body 14, h1 16,
  h2 15, h3–h6 14 bold, code 13 in Menlo). AppKit's RTF import keeps px as pt, so both flavours
  match. It imports only Foundation and
  Markdown, so the Model rule holds and a harness can compile it.
- **A rewriter fills `HTMLFormatter`'s gaps (swift-markdown 0.9.0).** It escapes text, code and
  URLs, which the formatter writes verbatim, and links bare URLs with `NSDataDetector`, because the
  autolink extension is off. Parsing uses `.disableSmartOpts` to match GitHub. Known differences that
  remain: headings keep only plain text, and images have no `alt` text.
- **RTF derived from the HTML in `Paster`.** AppKit's `NSAttributedString` HTML import builds the RTF
  on the main thread. Before that import, `<img>` tags are replaced with links to their source, so
  the importer never fetches remote images synchronously. The HTML flavour keeps the images.
- **Pasteboard contents.** One item carrying `public.html`, `public.rtf`, `public.utf8-plain-text`
  (the original Markdown) and the `internalType` marker, so the history poller skips it.
- **Restore by snapshot.** Before writing, the coordinator copies every type and its data from the
  current pasteboard items. After ⌘V is posted and a short settle delay passes, it writes the snapshot
  back with the `internalType` marker. Restoring the source item keeps a ⌘V after the command equal
  to the Markdown, and the marker keeps history unchanged.
- **Command wiring.** A `pasteMarkdownAsRichText` case after `pasteSequentially` (name "Paste
  Markdown as Rich Text", symbol `doc.richtext`, present in SF Symbols 4), added to the clipboard
  `ownedCommands` list, to the `setCommandsVisible` set in `applyEnabled`, and to `runCommand`. Being
  a regular command, it gets its hotkey slot from `CommandID.hotKeyAction` with no default binding.
- **No-text case.** When the pasteboard has no string, the coordinator reports through
  `core.showMessage` and writes nothing.
- **Harness.** `Scripts/run-tests.sh` already builds a wrapper package for swift-perception. The
  wrapper gains swift-markdown at the version pinned in `Package.resolved`, and a new
  `Tests/markdown-rich-text-test.swift` checks the HTML for each GFM element in the spec.

## Risks / Trade-offs

- [A target reads the pasteboard lazily, after the restore] → the restore waits a settle delay after
  ⌘V, the same order of magnitude as the paste delays `Paster` already uses, and the manual test pass
  covers Mail, Notes, Slack and a Chromium editor.
- [Some editors ignore `<style>` blocks, so tables lose borders] → the content and structure still
  paste; the RTF flavour carries the borders for native apps.
- [Inline HTML passes through to the target] → the target editor's own paste sanitiser applies, as
  with any HTML copied from a browser. Remote images load only in the HTML flavour, never during RTF
  conversion.
- [A held shortcut repeats the command] → a repeat that arrives before the restore finishes is
  ignored.
- [Second package dependency] → an Apple-maintained package; the AGENTS.md rule that names the only
  package is updated in the same change.

## Migration Plan

None. The command is new, has no default shortcut and adds no stored setting. Rollback is removing
the case and the package.
