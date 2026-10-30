# clipboard-plain-text-paste Specification

## Purpose

Lets the user paste the text on the clipboard without its formatting into the frontmost app, with
one command that can be bound to a global shortcut.

## Requirements

### Requirement: Paste as Plain Text command
The system SHALL provide a built-in command named "Paste as Plain Text" that pastes the plain-text
representation of the text currently on the clipboard, without any formatting, into the app that was
frontmost when the command ran.

#### Scenario: Run from a shortcut
- **WHEN** the clipboard holds formatted text copied from a web page and the user presses the
  command's shortcut in another app
- **THEN** the same text is pasted into that app at its cursor with no fonts, colours, links or styles

#### Scenario: Run from the launcher
- **WHEN** the user runs the command from the launcher palette
- **THEN** the palette closes and the plain text is pasted into the app that was frontmost before the
  palette opened

#### Scenario: Text is pasted as is
- **WHEN** the clipboard text has leading or trailing spaces or line breaks
- **THEN** the pasted text keeps them unchanged

### Requirement: Clipboard is restored after the plain-text paste
After the paste, the clipboard SHALL hold the content it held before the command ran, including its
formatting, and neither the pasted plain text nor the restored content SHALL be added to the
clipboard history.

#### Scenario: Clipboard after the paste
- **WHEN** the command has pasted the plain text
- **THEN** a normal ⌘V pastes the original formatted content again
- **AND** the clipboard history gains no new entry and no entry changes position

#### Scenario: Repeated shortcut
- **WHEN** the shortcut is pressed again before the previous paste has restored the clipboard
- **THEN** the repeat is ignored and the original clipboard is still restored

### Requirement: No text on the clipboard for the plain-text paste
When the clipboard holds no text, such as an image or nothing, the command SHALL paste nothing,
leave the clipboard unchanged and show a message saying there is no text on the clipboard.

#### Scenario: Image on the clipboard
- **WHEN** the clipboard holds only an image and the user runs the command
- **THEN** nothing is pasted, the clipboard still holds the image, and a "No text on the clipboard"
  message is shown

### Requirement: Same availability as the other clipboard commands for the plain-text paste
The command SHALL be listed in the Clipboard settings pane with an alias field, a shortcut recorder
with no default shortcut, and a launcher-visibility checkbox, and SHALL be hidden from the launcher,
with its shortcut inactive, while clipboard history is disabled.

#### Scenario: Assign a shortcut
- **WHEN** the user records a shortcut for Paste as Plain Text in the Clipboard pane
- **THEN** pressing it in any app runs the command

#### Scenario: Clipboard history disabled
- **WHEN** Enable Clipboard History is off
- **THEN** the command is not listed in the launcher and its shortcut does nothing

