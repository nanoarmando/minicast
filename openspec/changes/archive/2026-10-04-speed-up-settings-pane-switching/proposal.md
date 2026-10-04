## Why

On the Intel MacBook Pro (2017) running macOS 13, switching sections in the Settings sidebar shows a small
but noticeable delay. Each switch builds the whole new pane synchronously on the main thread (every pane is
a grouped `Form` that realizes all its rows on macOS 13), Perception adds manual tracking per view on macOS
13, and two panes do blocking work when they appear. The user wants switching to feel immediate without
changing how Settings looks.

## What Changes

- The sidebar selection updates immediately; the new pane is mounted right after that first frame, so the
  click never waits for the pane to be built.
- The Calendar pane enumerates installed browsers off the main thread instead of blocking when it appears.
- The General pane reads keyboard input sources without blocking the pane's first frame.
- Navigation stops invalidating the outgoing pane with a redundant state write.
- Out of scope (deferred): replacing the eager `Form` rows of the System Settings, System Actions and
  Commands panes with the recycled launcher items table.

## Capabilities

### New Capabilities

- `settings-responsiveness`: how quickly the Settings window responds to section changes and pane
  appearance, while keeping navigation, search reveal and deep links unchanged.

### Modified Capabilities

None.

## Impact

- **Code**: `Tinycast/Features/Settings/SettingsDetailView.swift`, `SettingsNavigationState.swift`,
  `Features/Calendar/Settings/CalendarSettingsView.swift`, `Features/Calendar/Service/MeetingLauncher.swift`,
  `Features/Settings/Panes/GeneralSettingsView.swift` (and the input source helper it calls).
- **Behavior**: identical look; a pane may appear one frame after the sidebar highlight.
- **Dependencies, data, project settings**: none.
