## Purpose

Defines which macOS versions and Mac architectures the fork runs on, and guarantees that every feature
kept in the fork behaves and looks the same on macOS 13 Ventura and on newer systems.

## ADDED Requirements

### Requirement: Minimum supported system
The app and its bundled helper SHALL launch and run on macOS 13.0 or later, and the bundle SHALL declare
13.0 as its minimum system version.

#### Scenario: Launch on macOS 13 Ventura
- **WHEN** the user opens the app on an Intel Mac running macOS 13
- **THEN** the app launches, shows its menu bar item, and opens the palette with the configured hotkey

#### Scenario: Launch on a newer macOS
- **WHEN** the user opens the same build on an Apple silicon Mac running macOS 27
- **THEN** the app launches and every kept feature works as on macOS 13

#### Scenario: Older system is refused by macOS
- **WHEN** the user tries to open the app on macOS 12 or earlier
- **THEN** macOS refuses to open it because the minimum system version is not met

### Requirement: Universal binary
Every executable in the release build (the app and the clipboard text helper) SHALL
contain both arm64 and x86_64 slices.

#### Scenario: Architecture check
- **WHEN** the release build is inspected with `lipo -archs` on each executable
- **THEN** each one reports both `x86_64` and `arm64`

### Requirement: Kept features work on macOS 13
Every feature not removed by the `feature-availability` capability SHALL remain available on macOS 13,
including palette keyboard navigation, launcher, clipboard history, file search, calculator, window
management (moving and resizing windows, layouts, rooms, custom sizes, window commands and their hotkeys),
quick actions other than Translate, AI chat with external providers, MCP,
Raycast extensions, calendar, emoji picker, dictionary, uninstall, custom commands, Apple Shortcuts, system
actions, fallbacks, and backup.

#### Scenario: Palette keyboard navigation
- **WHEN** the palette is open on macOS 13 and the user types a query and presses arrow keys, Return, Tab
  and Escape
- **THEN** the selection moves, the selected item runs, and the palette closes exactly as on macOS 27

#### Scenario: Settings changes apply live
- **WHEN** the user changes a setting (for example "show in menu bar" or the interface size) on macOS 13
- **THEN** the change is reflected immediately in the menu bar, palette and settings window without
  relaunching

#### Scenario: Window title follows content
- **WHEN** the user renames the active AI chat
- **THEN** the AI chat window title updates immediately

#### Scenario: Calendar permission on macOS 13
- **WHEN** the user enables the calendar feature on macOS 13 for the first time
- **THEN** macOS shows the calendar permission prompt and, once granted, events load

### Requirement: Responsive palette on older hardware
Typing in the palette or moving the selection SHALL update only the views whose data changed, so that
interaction stays responsive on a 2017 Intel MacBook Pro.

#### Scenario: Typing a query
- **WHEN** the user types a query of several characters in the palette on the 2017 Intel Mac
- **THEN** results update for each keystroke without visible lag or dropped characters

### Requirement: Single classic appearance
The app SHALL use classic macOS blur materials instead of Liquid Glass on every macOS version, so the
appearance is the same on macOS 13 and newer systems. Scroll edge fades and the thin scrollbar are allowed
to be simplified, but content SHALL remain fully scrollable and readable.

#### Scenario: Same look on both Macs
- **WHEN** the palette, settings, HUDs, quick action results and AI chat are opened on macOS 13 and on macOS 27
- **THEN** both show blurred translucent backgrounds without Liquid Glass effects

#### Scenario: Long lists remain usable
- **WHEN** a list longer than its container is shown (for example clipboard history)
- **THEN** the list scrolls, the selected row stays visible during keyboard navigation, and no row is
  clipped permanently
