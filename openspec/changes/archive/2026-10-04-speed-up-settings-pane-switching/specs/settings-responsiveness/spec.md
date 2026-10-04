## Purpose

Keeps the Settings window responsive on slower Macs (Intel, macOS 13) when the user switches sections,
without changing how Settings looks or navigates.

## ADDED Requirements

### Requirement: Immediate section selection
When the user selects a section in the Settings sidebar, the sidebar highlight SHALL update in the next
frame, before the new pane finishes building, and the selected pane SHALL then appear without further user
action.

#### Scenario: Clicking a long section
- **WHEN** the user clicks a section with many rows (for example System Actions) on the 2017 Intel Mac
- **THEN** the sidebar highlight moves immediately and the pane appears right after, with no frozen frame
  on the previous pane

#### Scenario: Moving with the keyboard
- **WHEN** the user moves through sidebar sections with the arrow keys
- **THEN** the highlight follows each key press without waiting for each pane to build, and the pane shown
  matches the final selection

### Requirement: Navigation behavior preserved
Search results, deep links and section reveal SHALL keep working exactly as before: selecting a search result
or opening Settings at a specific section SHALL show that pane, scroll to the matched setting and pulse it.

#### Scenario: Search result reveal
- **WHEN** the user searches for a setting and selects a row result in another section
- **THEN** that section opens, the setting scrolls into view and its title pulses once

#### Scenario: Opening Settings at a section
- **WHEN** Settings is opened from the palette or the menu bar at a specific section
- **THEN** that section is shown

### Requirement: No blocking work when a pane appears
Panes SHALL NOT block the main thread with system queries when they appear. The Calendar pane SHALL load
the list of installed browsers in the background, and the General pane SHALL load keyboard input sources
without delaying its first frame.

#### Scenario: Opening the Calendar pane
- **WHEN** the user opens the Calendar section
- **THEN** the pane appears without a pause, and the "Open Meeting Links In" list contains the installed
  browsers once they are loaded, keeping the saved choice selected

#### Scenario: Opening the General pane
- **WHEN** the user opens the General section
- **THEN** the pane appears without a pause and the input source options are available once loaded
