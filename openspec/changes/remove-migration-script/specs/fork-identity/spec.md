## REMOVED Requirements

### Requirement: One-time migration into Minicast
**Reason**: The backup bundle, the `.tinycast` import, the Raycast import and the settings file cover
bringing a setup into Minicast, and the script duplicated them.
**Migration**: Export a backup from the official Tinycast and import it in Minicast's Import & Export
window, or import a Raycast export. Between Minicast installs, export and import a `.minicast` bundle.

## ADDED Requirements

### Requirement: Bringing an existing setup
Minicast SHALL offer exactly these ways to bring in an existing setup, all from inside the app: importing
a Minicast bundle, importing a `.tinycast` backup from the official app, importing a Raycast export, and
syncing the `~/.config/minicast/settings.json` file. The repository SHALL NOT provide a script that copies
another app's data folders or Keychain items into Minicast.

#### Scenario: Moving from the official Tinycast
- **WHEN** the user exports a backup from the official Tinycast and imports it in Minicast
- **THEN** the categories that the `.tinycast` format carries are restored, and the official app's data is
  unchanged

#### Scenario: No migration script
- **WHEN** the user looks for a way to copy Tinycast's data folders into Minicast
- **THEN** the repository has no migration script, and the README points to the in-app imports

## MODIFIED Requirements

### Requirement: Isolated persisted data
All data Minicast persists (preferences, Application Support and Caches folders, the opt-in
`settings.json` file, Keychain items including extension OAuth tokens, and the login item) SHALL be keyed
to Minicast's bundle identifier and SHALL NOT read or write the data of the official app.

#### Scenario: Settings file location
- **WHEN** the user enables the settings file in Minicast
- **THEN** it is written to `~/.config/minicast/settings.json` (`~/.config/minicast-dev/` for the debug
  build), and `~/.config/tinycast/` is untouched

#### Scenario: First launch starts empty
- **WHEN** Minicast is launched for the first time on a Mac where the official app has data
- **THEN** Minicast starts with default settings and the official app's data, preferences and Keychain items
  remain unchanged

#### Scenario: Official app reinstalled later
- **WHEN** the user reinstalls and opens the official Tinycast after using Minicast
- **THEN** the official app finds its own previous configuration, unaffected by Minicast

#### Scenario: Data persists across rebuilds
- **WHEN** the user installs a newer build of Minicast over an older one
- **THEN** preferences, data and AI keys are preserved, and the Accessibility permission is preserved when
  both builds were signed with the same local identity
