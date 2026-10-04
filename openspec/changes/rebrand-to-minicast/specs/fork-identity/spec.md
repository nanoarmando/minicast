## RENAMED Requirements

- FROM: `### Requirement: One-time migration from the official app`
- TO: `### Requirement: One-time migration into Minicast`

## MODIFIED Requirements

### Requirement: Distinct app identity
The release build SHALL use the bundle identifier `com.minicast.app` and the app name "Minicast"; the
debug build SHALL use `com.minicast.app.dev` and "Minicast Dev".

#### Scenario: Installed side by side
- **WHEN** "Minicast.app" is copied to `/Applications` where `Tinycast.app` already exists
- **THEN** no app replaces another on disk

#### Scenario: Not suggested to itself
- **WHEN** the launcher shows app suggestions
- **THEN** neither Minicast nor the official Tinycast is suggested

### Requirement: Isolated persisted data
All data Minicast persists (preferences, Application Support and Caches folders, the opt-in
`settings.json` file, Keychain items including extension OAuth tokens, and the login item) SHALL be keyed
to Minicast's bundle identifier and SHALL NOT read or write the data of the official app.

#### Scenario: Settings file location
- **WHEN** the user enables the settings file in Minicast
- **THEN** it is written to `~/.config/minicast/settings.json` (`~/.config/minicast-dev/` for the debug
  build), and `~/.config/tinycast/` is untouched

#### Scenario: First launch starts empty
- **WHEN** Minicast is launched for the first time, without running the migration, on a Mac where the
  official app has data
- **THEN** Minicast starts with default settings and the official app's data, preferences and Keychain items
  remain unchanged

#### Scenario: Official app reinstalled later
- **WHEN** the user reinstalls and opens the official Tinycast after using Minicast
- **THEN** the official app finds its own previous configuration, unaffected by Minicast

#### Scenario: Data persists across rebuilds
- **WHEN** the user installs a newer build of Minicast over an older one
- **THEN** preferences, data and AI keys are preserved, and the Accessibility permission is preserved when
  both builds were signed with the same local identity

### Requirement: Importing a setup from a backup file
Minicast SHALL accept a backup file exported by the official app or by Minicast through
the built-in Backup import, restoring the categories that the backup format covers.

#### Scenario: Import from the official app
- **WHEN** the user exports a backup from the official app and imports it in Minicast
- **THEN** settings, hotkeys, clipboard history and launcher learning are restored (snippet and note
  categories are ignored because those features are removed), and AI
  keys, MCP servers, extensions and feature consent switches must be set again by hand

### Requirement: One-time migration into Minicast
The repository SHALL provide a migration command that copies the official Tinycast's
(`com.tinycast.app`) user data into Minicast's locations, so Minicast starts with the user's existing
setup. It SHALL migrate preferences,
the Application Support data (AI chats, clipboard, extensions and their data, launcher learning, quick
actions, window layouts and rooms), Caches, the `settings.json` file, and Keychain secrets (AI keys, MCP
secrets, installed-AI environment, extension OAuth tokens). It SHALL NOT migrate anything bound to the
code signature: privacy permissions and the login item registration. It SHALL leave out settings of
features Minicast removed, and SHALL never modify or delete the official app's data.

#### Scenario: Successful migration
- **WHEN** the user runs the migration with both apps quit, Minicast installed, and Minicast holding no
  data
- **THEN** all listed data is copied from the official Tinycast to Minicast's locations, excluding
  settings of removed features, Tinycast's data is unchanged, and the command prints what was migrated
  and what must be done by hand (permissions, login item, removing Tinycast)

#### Scenario: Keychain authorization
- **WHEN** the migration copies Keychain secrets
- **THEN** macOS asks the user to authorize reading each source secret, and the copied secrets are
  readable by Minicast without further prompts

#### Scenario: Keychain access denied
- **WHEN** the user denies access to a secret
- **THEN** that secret is skipped, the rest of the migration completes, and the summary lists it as skipped

#### Scenario: App running
- **WHEN** Tinycast or Minicast is running
- **THEN** the migration aborts before copying anything and asks the user to quit them

#### Scenario: Minicast already has data
- **WHEN** Minicast already has data and the user runs the migration without `--force`
- **THEN** the migration aborts without changes

#### Scenario: Forced migration
- **WHEN** Minicast already has data and the user runs the migration with `--force`
- **THEN** Minicast's existing data is first moved to a timestamped backup folder, then the migration runs

#### Scenario: Minicast not installed
- **WHEN** "Minicast.app" is not in `/Applications`
- **THEN** the migration aborts and explains that Minicast must be installed first
