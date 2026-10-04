## Purpose

Gives the fork its own identity so it can replace or coexist with the official Tinycast without sharing
preferences, data, secrets or update channel, and so the official app can be reinstalled at any time.

## ADDED Requirements

### Requirement: Distinct app identity
The release build SHALL use the bundle identifier `com.tinycast.app.fork` and the app name
"Tinycast Fork"; the debug build SHALL use `com.tinycast.app.fork.dev` and "Tinycast Fork Dev".

#### Scenario: Installed side by side
- **WHEN** "Tinycast Fork.app" is copied to `/Applications` where `Tinycast.app` already exists
- **THEN** neither app replaces the other on disk

### Requirement: Isolated persisted data
All data the fork persists (preferences, Application Support and Caches folders, the opt-in
`settings.json` file, Keychain items including extension OAuth tokens, and the login item) SHALL be keyed
to the fork's bundle identifier and SHALL NOT read or write the official app's data.

#### Scenario: Settings file location
- **WHEN** the user enables the settings file in the fork
- **THEN** it is written to `~/.config/tinycast-fork/settings.json` and `~/.config/tinycast/` is untouched

#### Scenario: First launch starts empty
- **WHEN** the fork is launched for the first time, without running the migration, on a Mac where the
  official app has data
- **THEN** the fork starts with default settings and the official app's data, preferences and Keychain
  items remain unchanged

#### Scenario: Official app reinstalled later
- **WHEN** the user reinstalls and opens the official Tinycast after using the fork
- **THEN** the official app finds its own previous configuration, unaffected by the fork

#### Scenario: Data persists across fork rebuilds
- **WHEN** the user installs a newer build of the fork over an older one
- **THEN** preferences, data and AI keys are preserved, and the Accessibility permission is preserved when
  both builds were signed with the same local identity

### Requirement: Importing a setup from a backup file
The fork SHALL accept a backup file exported by the official app through the built-in Backup import,
restoring the categories that the backup format covers.

#### Scenario: Import from the official app
- **WHEN** the user exports a backup from the official app and imports it in the fork
- **THEN** settings, hotkeys, clipboard history and launcher learning are restored (snippet and note
  categories are ignored because those features are removed), and AI
  keys, MCP servers, extensions and feature consent switches must be set again by hand

### Requirement: No self-update
The fork SHALL NOT check for, download, or install updates, and SHALL NOT show a "Check for Updates…"
command or update settings.

#### Scenario: No network update check
- **WHEN** the fork runs for more than a day
- **THEN** it never contacts the GitHub releases API of upstream or any other update source

#### Scenario: No update command
- **WHEN** the user opens the menu bar menu, the palette commands, or the settings
- **THEN** no update check command or update preference is offered

### Requirement: One-time migration from the official app
The repository SHALL provide a migration command that copies the official app's user data into the
fork's locations, so the fork starts with the user's existing setup. It SHALL migrate preferences, the
Application Support data (AI chats, clipboard, extensions and their data, launcher learning, quick
actions, window layouts and rooms), Caches, the `settings.json` file, and Keychain secrets (AI keys, MCP secrets, installed-AI environment,
extension OAuth tokens). It SHALL NOT migrate anything bound to the code signature: privacy permissions
and the login item registration. It SHALL never modify or delete the official app's data.

#### Scenario: Successful migration
- **WHEN** the user runs the migration with both apps quit, the fork installed, and the fork holding no data
- **THEN** all listed data is copied to the fork's locations, the official app's data is unchanged, and
  the command prints what was migrated and what must be done by hand (permissions, login item)

#### Scenario: Keychain authorization
- **WHEN** the migration copies Keychain secrets
- **THEN** macOS asks the user to authorize reading each official secret, and the copied secrets are
  readable by the fork without further prompts

#### Scenario: Keychain access denied
- **WHEN** the user denies access to a secret
- **THEN** that secret is skipped, the rest of the migration completes, and the summary lists it as skipped

#### Scenario: App running
- **WHEN** the official app or the fork is running
- **THEN** the migration aborts before copying anything and asks the user to quit them

#### Scenario: Fork already has data
- **WHEN** the fork already has data and the user runs the migration without `--force`
- **THEN** the migration aborts without changes

#### Scenario: Forced migration
- **WHEN** the fork already has data and the user runs the migration with `--force`
- **THEN** the fork's existing data is first moved to a timestamped backup folder, then the migration runs

#### Scenario: Fork not installed
- **WHEN** "Tinycast Fork.app" is not in `/Applications`
- **THEN** the migration aborts and explains that the fork must be installed first
