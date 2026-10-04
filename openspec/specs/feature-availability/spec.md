# feature-availability Specification

## Purpose
Lists the features the fork removes, either because they depend on frameworks unavailable on macOS 13 or
because the user does not need them, and defines how kept features and persisted references behave after
the removal.
## Requirements
### Requirement: Apple Intelligence provider removed
The fork SHALL NOT offer Apple Intelligence (the on-device Apple model) as an AI provider or model, in AI
settings, model pickers, quick action model choices, or chat.

#### Scenario: Provider list
- **WHEN** the user opens the AI providers settings
- **THEN** Apple Intelligence is not listed and external providers are listed as before

#### Scenario: Persisted Apple Intelligence selection
- **WHEN** imported, migrated or persisted settings reference Apple Intelligence as the default or quick
  action model
- **THEN** the fork ignores that reference, falls back to the first available configured provider (or no
  model), and does not crash

### Requirement: Translate quick action removed
The fork SHALL NOT offer the Translate quick action in the launcher, command list, quick action settings,
hotkey assignment, or settings search.

#### Scenario: Quick action list
- **WHEN** the user opens quick actions in the launcher or settings
- **THEN** Translate is not listed and the remaining quick actions work as before

### Requirement: Unneeded features removed
The fork SHALL NOT contain Dictation, Notes, Quicklinks, Camera preview, Snippets, the Support reminder,
Onboarding, the window switcher, or menu bar search. None of them SHALL appear in settings (including the
Snippets, Quicklinks, Navigation and Notes panes), settings search, the launcher, palette screens, the menu
bar menu, hotkey assignment, or backups, and the app SHALL NOT request microphone or camera access.

#### Scenario: Settings sidebar
- **WHEN** the user opens settings
- **THEN** the sidebar shows no Quicklinks, Snippets, Navigation or Notes panes, and every remaining pane
  works as before

#### Scenario: Launcher and palette
- **WHEN** the user searches the launcher for "note", "snippet", "quicklink", "dictation", "camera",
  "switch windows", "menu" or "support"
- **THEN** no command of a removed feature is offered

#### Scenario: Calendar without camera preview
- **WHEN** a meeting is auto-joined and confirmation is enabled
- **THEN** the plain confirmation dialog is shown instead of a camera preview, and the meeting joins after
  confirming

#### Scenario: First launch without onboarding
- **WHEN** the fork is launched for the first time with no data
- **THEN** no onboarding window is shown, the menu bar item is visible, and the palette hotkey, launch at
  login, Accessibility and Raycast import remain available in settings

### Requirement: Window management preserved
Window management SHALL keep all its behavior: window commands and their hotkeys, layouts, rooms and
custom window sizes. A layout placement whose argument is a URL or file SHALL still open it.

#### Scenario: Window command hotkey
- **WHEN** the user presses the hotkey assigned to "left half"
- **THEN** the focused window moves to the left half of the screen

#### Scenario: Layout with a URL argument
- **WHEN** the user runs a layout whose placement opens a URL in a browser
- **THEN** the URL opens and the window is placed as configured

### Requirement: Persisted references to removed features
Persisted, imported or migrated references to removed features (favorites, aliases, hotkeys, launcher
ranking, visibility, fallbacks, settings keys, backup categories and data files) SHALL be ignored without
errors.

#### Scenario: Migrated data from the official app
- **WHEN** the fork starts with preferences and data migrated from an official app that used snippets,
  quicklinks, notes or dictation
- **THEN** those settings and files are ignored, and every kept feature works

#### Scenario: Persisted Translate or removed command reference
- **WHEN** persisted favorites, aliases, hotkeys, or rankings reference the Translate command or a command
  of a removed feature
- **THEN** those references are ignored and the app does not crash

