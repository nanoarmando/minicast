## MODIFIED Requirements

### Requirement: Scroll-driven effects follow the scroll position
The thin scrollbar, overflow fades, keyboard selection following and the AI transcript's follow-the-latest
behavior SHALL receive scroll measurements on every surface that uses them. Keyboard selection following
SHALL leave the selected row fully opaque: entirely clear of the top search bar, the bottom action bar and
the faded bands that extend past each bar into the list.

#### Scenario: Thin scrollbar
- **WHEN** the user scrolls a long palette list
- **THEN** the thin scrollbar thumb appears and tracks the position

#### Scenario: Keyboard navigation beyond the visible rows
- **WHEN** the user presses the down arrow past the last fully opaque row
- **THEN** the list scrolls so the selected row sits entirely above the bottom action bar's faded band,
  fully opaque

#### Scenario: Keyboard navigation upward
- **WHEN** the user presses the up arrow past the first fully opaque row
- **THEN** the list scrolls so the selected row sits entirely below the search bar's faded band, fully
  opaque

#### Scenario: Selected row already clear
- **WHEN** the selection moves to a row that is already fully opaque and clear of both bars
- **THEN** the list does not scroll

#### Scenario: Row taller than the clear area
- **WHEN** the selected row (such as a tall grid tile or a form field) is taller than the area between
  the two faded bands
- **THEN** the list shows the row's top edge clear of the search bar's faded band

#### Scenario: Every list and grid
- **WHEN** the user navigates with the keyboard in the launcher, clipboard history, calculator history,
  file search, emoji, calendar schedule, rooms, room picker, uninstall, chat history, or an extension
  list, grid or form
- **THEN** the same clearance applies

#### Scenario: Streaming AI reply
- **WHEN** an AI reply streams while the transcript is scrolled to the end
- **THEN** the transcript keeps following the newest text

#### Scenario: Settings and popup overflow
- **WHEN** a Settings list or popup menu has more content than fits
- **THEN** the overflowing edge fades as in upstream

## ADDED Requirements

### Requirement: List ends leave room for the bars
Every palette list that dissolves under the floating bars SHALL leave enough room before its first row
and after its last row that either row, when selected, can be fully opaque and clear of both bars.

#### Scenario: Selecting the last row
- **WHEN** the user moves the selection to the last row of a list longer than the palette
- **THEN** the list scrolls to its end and the last row sits fully opaque above the bottom action bar's
  faded band

#### Scenario: Returning to the first row
- **WHEN** the user moves the selection back to the first row of a scrolled list
- **THEN** the list returns to its start, the first section header is visible, and the first row is
  fully opaque below the search bar's faded band

#### Scenario: Interface size
- **WHEN** the user changes the interface size in Settings
- **THEN** the room at the list ends and the selection clearance scale with the bars, and the first and
  last rows still reach the clear area
