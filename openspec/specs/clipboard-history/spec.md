# clipboard-history Specification

## Purpose

Defines what the Default action setting offers in the Clipboard History palette and how a repeated
copy updates the history instead of duplicating an entry.

## Requirements

### Requirement: Default action choices
The Clipboard pane's Default action setting SHALL offer only Paste and Copy to Clipboard. A stored
Paste as Plain Text default, from earlier versions, a `settings.json` file or a backup, SHALL behave
as Paste.

#### Scenario: Picker options
- **WHEN** the user opens the Default action picker
- **THEN** it lists Paste and Copy to Clipboard, and no Paste as Plain Text

#### Scenario: Previously chosen plain-text default
- **WHEN** the stored Default action is Paste as Plain Text
- **THEN** the picker shows Paste and ↵ on a history entry pastes it with its formatting

### Requirement: Plain-text paste of a history entry stays available
Pasting a history entry as plain text SHALL remain available on ⌃⌘↵ and in the ⌘K actions menu of
the Clipboard History palette, whichever Default action is chosen, for entries that have text.

#### Scenario: Plain text with Copy as the default
- **WHEN** the Default action is Copy to Clipboard and the user presses ⌃⌘↵ on a text entry
- **THEN** the entry's text is pasted without formatting into the target app

#### Scenario: Image entry
- **WHEN** the selected entry is an image
- **THEN** ⌃⌘↵ does nothing and the ⌘K menu offers no Paste as Plain Text row

### Requirement: Repeated copies do not duplicate entries
When a copied text, or a copied file path, is identical character for character to an unpinned entry
of the same kind anywhere in the history, the system SHALL move that entry to the top of the recent
entries, set its time to the copy time and its source app to the app of the new copy, and SHALL NOT
add a new entry. Text that differs in case or whitespace SHALL be a separate entry. Images SHALL
always add a new entry.

#### Scenario: Same text copied twice with another copy in between
- **WHEN** the user copies "pepito", then "x", then "pepito" again
- **THEN** the history shows "pepito" once, above "x"

#### Scenario: Duplicate older than the loaded history
- **WHEN** the copied text matches an entry older than the entries currently shown in memory
- **THEN** that entry moves to the top and no new entry is added

#### Scenario: Different whitespace
- **WHEN** the user copies "pepito" and later "pepito " with a trailing space
- **THEN** the history shows two separate entries

#### Scenario: Source app updated
- **WHEN** "pepito" was first copied in Notes and is copied again in Safari
- **THEN** the single "pepito" entry is at the top and shows Safari as its source

#### Scenario: File copied again
- **WHEN** the user copies a file in Finder, copies other content, and copies the same file again
- **THEN** the history shows that file once, at the top, and text recognized in it stays searchable

### Requirement: A pinned duplicate holds its place
When a copied text or file path matches a pinned entry, the system SHALL add no entry and SHALL leave
the pinned entry where it is, even when an unpinned copy of the same text also exists.

#### Scenario: Copying a pinned text
- **WHEN** "pepito" is pinned and the user copies "pepito" again
- **THEN** no new entry appears in the recent entries and the pinned "pepito" keeps its place

### Requirement: Existing duplicates are left as they are
The system SHALL NOT remove duplicate entries already stored before this behavior shipped. A new copy
that matches several stored duplicates SHALL move only the most recent unpinned one.

#### Scenario: Old duplicates
- **WHEN** the history already holds two "pepito" entries and the user copies "pepito"
- **THEN** the newer of the two moves to the top and the older one stays where it was

