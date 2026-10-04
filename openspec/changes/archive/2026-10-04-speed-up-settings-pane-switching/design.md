## Context

See `proposal.md`. Relevant current behavior (read-only analysis of the fork):

- `SettingsDetailView` switches on `navigation.tab` and builds the selected pane synchronously. Every pane
  is a `Form(.grouped)`; on macOS 13 it realizes all rows at once, and long panes (System Settings, System
  Actions, Commands, Extensions) have dozens of heavy rows (alias field backed by `NSTextView`, shortcut
  recorder, icon task, toggle).
- `SettingsNavigationState.select` always writes `flashing = nil`; on macOS 13 a Perceptible setter does not
  skip equal values, so every `SearchPill` of the outgoing pane is invalidated on each switch.
- `CalendarSettingsView` calls `MeetingLauncher.installedBrowsers()` (LaunchServices query plus a `Bundle`
  per app) in `onAppear` on the main thread.
- `GeneralSettingsView` calls `core.inputSourceSwitcher.options(...)` (Text Input Sources API) in `onAppear`.
- Search reveal: `SettingsScrollTarget` handles `scrollRequest` with a `.task(id:)` that yields once and
  assumes the pane has just mounted.

## Goals / Non-Goals

**Goals:** the sidebar responds in the next frame; no blocking system queries on pane appearance; identical
look and navigation.

**Non-Goals:** replacing eager `Form` rows with the recycled `LauncherItemsTable` (deferred; larger and with
visual risk); icon prewarming; changes outside Settings.

## Decisions

### 1. Mount the pane one turn after the selection
`SettingsDetailView` keeps a local `displayedTab` (`@State`), initialized from `navigation.tab`, and
updates it from `.task(id: navigation.tab)` after `await Task.yield()`. The `switch` renders
`displayedTab`, so the sidebar highlight (which reads `navigation.tab`) paints before the heavy pane is
built. No placeholder: the previous pane stays visible for that turn, which avoids a blank flash.
- Search reveal keeps working because `scrollRequest` is handled inside the mounted pane, which appears
  after `displayedTab` changes; `SettingsScrollTarget` already yields before scrolling. Verify that a search
  result into another pane still scrolls and pulses; if the request arrives before the pane mounts, re-key
  the pane's reveal task on `displayedTab`.
- Rapid arrow-key navigation coalesces naturally: each new `navigation.tab` cancels the previous task, so
  only the final selection is built.
- Alternative: show a lightweight placeholder pane during the turn. Rejected: visible flash on fast Macs.

### 2. Skip redundant navigation writes
`SettingsNavigationState.select` writes `flashing = nil` only when `flashing != nil`.

### 3. Browsers off the main thread
`CalendarSettingsView` replaces `.onAppear { browsers = ... }` with a `.task` that runs
`MeetingLauncher.installedBrowsers()` in `Task.detached` and assigns the result on the main actor.
`Browser` must be `Sendable` (it holds two strings). The picker already maps an unknown saved id to
"Default Browser", so the saved choice shows correctly once the list arrives.

### 4. Input sources after the first frame
Text Input Sources APIs belong on the main thread, so they are not moved to a background thread. The General
pane loads them from a `.task` after `await Task.yield()` instead of `onAppear`, so the pane draws first.
The distributed-notification refresh stays as is.

## Risks / Trade-offs

- [The pane appears one frame later on fast Macs] → Imperceptible; on slow Macs the click feels faster.
- [A search result navigates before the pane mounts and the reveal is lost] → Verified explicitly; re-key
  the reveal task if needed (Decision 1).
- [Long panes still take time to build on Intel] → Accepted for now; the recycled-table change is deferred.

## Migration Plan

Code-only change; rebuild and install. Rollback: revert the commit.
