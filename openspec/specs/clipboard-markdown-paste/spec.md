# clipboard-markdown-paste Specification

## Purpose

Lets the user paste Markdown that is on the clipboard as formatted rich text into the frontmost app,
with one command that can be bound to a global shortcut.

## Requirements

### Requirement: Paste Markdown as Rich Text command
The system SHALL provide a built-in command named "Paste Markdown as Rich Text" that converts the
text currently on the clipboard from GitHub Flavored Markdown to rich text and pastes the result
into the app that was frontmost when the command ran.

#### Scenario: Run from a shortcut
- **WHEN** the clipboard holds Markdown text and the user presses the command's shortcut in another app
- **THEN** the converted rich text is pasted into that app at its cursor

#### Scenario: Run from the launcher
- **WHEN** the user runs the command from the launcher palette
- **THEN** the palette closes and the converted rich text is pasted into the app that was frontmost
  before the palette opened

### Requirement: GitHub Flavored Markdown coverage
The conversion SHALL render the GitHub Flavored Markdown syntax: headings, paragraphs and line
breaks, bold, italic, strikethrough, inline code, fenced and indented code blocks, links and
autolinks, images, ordered, unordered and nested lists, task-list items, block quotes, thematic
breaks, tables with column alignment, and inline HTML.

#### Scenario: Table
- **WHEN** the clipboard holds a GFM table with a header row and aligned columns
- **THEN** the pasted content is a table with that header row and those alignments

#### Scenario: Task list
- **WHEN** the clipboard holds `- [x] done` and `- [ ] todo`
- **THEN** the pasted content is a list showing one checked and one unchecked item

#### Scenario: Text with no Markdown syntax
- **WHEN** the clipboard holds plain prose with no Markdown syntax
- **THEN** the prose is pasted as rich-text paragraphs with its words unchanged

### Requirement: Rich text with a plain-text fallback
The pasted content SHALL be offered as HTML and as RTF, with the original Markdown as the plain-text
representation, so each target app picks the richest format it accepts.

#### Scenario: Target accepts only plain text
- **WHEN** the target app accepts only plain text
- **THEN** the original Markdown text is pasted

### Requirement: Clipboard is restored after the paste
After the paste, the clipboard SHALL hold the content it held before the command ran, and neither
the converted content nor the restored content SHALL be added to the clipboard history.

#### Scenario: Clipboard after the paste
- **WHEN** the command has pasted the converted content
- **THEN** a normal ⌘V pastes the original Markdown again
- **AND** the clipboard history gains no new entry from the command

### Requirement: No text on the clipboard
When the clipboard holds no text, such as an image, a file or nothing, the command SHALL paste
nothing, leave the clipboard unchanged and show a message saying there is no text to convert.

#### Scenario: Image on the clipboard
- **WHEN** the clipboard holds only an image and the user runs the command
- **THEN** nothing is pasted, the clipboard still holds the image, and a message reports that there
  is no text to convert

### Requirement: Same availability as the other clipboard commands
The command SHALL be listed in the Clipboard settings pane with an alias field, a shortcut recorder
and a launcher-visibility checkbox, and SHALL follow the Enable Clipboard History switch the same
way as Clipboard History and Paste Sequentially. It SHALL have no default shortcut.

#### Scenario: Clipboard history disabled
- **WHEN** Enable Clipboard History is off
- **THEN** the command is not listed in the launcher and its shortcut does nothing

#### Scenario: Hidden from the launcher only
- **WHEN** the command's launcher-visibility checkbox is unchecked and Enable Clipboard History is on
- **THEN** the command does not appear in launcher search, and its shortcut still pastes
