## MODIFIED Requirements

### Requirement: Persisted references to removed features
Persisted or imported references to removed features (favorites, aliases, hotkeys, launcher ranking,
visibility, fallbacks, settings keys, backup categories and data files) SHALL be ignored without errors.

#### Scenario: Imported backup from the official app
- **WHEN** Minicast imports a `.tinycast` backup from an official app that used snippets, quicklinks,
  notes or dictation
- **THEN** those settings and categories are ignored, and every kept feature works

#### Scenario: Persisted Translate or removed command reference
- **WHEN** persisted favorites, aliases, hotkeys, or rankings reference the Translate command or a command
  of a removed feature
- **THEN** those references are ignored and the app does not crash
