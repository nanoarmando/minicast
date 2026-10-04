# scroll-edge-effects Specification

## Purpose
Keeps scrolled content legible under the palette's floating bars and keeps scroll-driven effects working on
macOS 13 and newer, matching upstream Tinycast behavior.
## Requirements
### Requirement: Content dissolves under the floating bars
In every palette list, rows that scroll under the top search bar or the bottom action bar SHALL fade out as
they approach the bar, so the bar's text and controls stay readable, on macOS 13 and macOS 27.

#### Scenario: Scrolling the launcher
- **WHEN** the launcher list is longer than the palette and the user scrolls it
- **THEN** rows fade near the search bar and near the action bar, and no row text overlaps the bars'
  text at full opacity

#### Scenario: Other palette screens
- **WHEN** the user scrolls clipboard history, file search, emoji, chat history or an extension list
- **THEN** the same fading applies near both bars

#### Scenario: Short list
- **WHEN** a list fits entirely in the palette
- **THEN** no row is faded

#### Scenario: Before scroll measurements are available
- **WHEN** a list has just appeared and its scroll measurements are not available yet
- **THEN** the bands near the bars are already faded, never fully opaque

### Requirement: Scroll-driven effects follow the scroll position
The thin scrollbar, overflow fades, keyboard selection following and the AI transcript's follow-the-latest
behavior SHALL receive scroll measurements on every surface that uses them.

#### Scenario: Thin scrollbar
- **WHEN** the user scrolls a long palette list
- **THEN** the thin scrollbar thumb appears and tracks the position

#### Scenario: Keyboard navigation beyond the visible rows
- **WHEN** the user presses the down arrow past the last visible row
- **THEN** the list scrolls so the selected row stays visible

#### Scenario: Streaming AI reply
- **WHEN** an AI reply streams while the transcript is scrolled to the end
- **THEN** the transcript keeps following the newest text

#### Scenario: Settings and popup overflow
- **WHEN** a Settings list or popup menu has more content than fits
- **THEN** the overflowing edge fades as in upstream

