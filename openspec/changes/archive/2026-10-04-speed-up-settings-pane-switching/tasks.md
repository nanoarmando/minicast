## 1. Implementation

- [x] 1.1 Render a `displayedTab` in `SettingsDetailView`, updated from `.task(id: navigation.tab)` after `Task.yield()`, keeping `WithPerceptionTracking` and the recorder popover host
- [x] 1.2 Write `flashing = nil` in `SettingsNavigationState.select` only when it is not already nil
- [x] 1.3 Load installed browsers in `CalendarSettingsView` through a background task (`Browser` made `Sendable`)
- [x] 1.4 Load input sources in `GeneralSettingsView` from a task after the first frame instead of `onAppear`

## 2. Verification

- [x] 2.1 Debug and universal Release builds compile with no errors and no new warnings; `./Scripts/run-tests.sh` passes
- [x] 2.2 On the main Mac: sidebar clicks and arrow keys, search result reveal into another pane, opening Settings at a section from the palette, Calendar browser picker keeps the saved choice
- [x] 2.3 On the 2017 Mac: switching sections, especially long ones, feels immediate; Calendar and General open without a pause
