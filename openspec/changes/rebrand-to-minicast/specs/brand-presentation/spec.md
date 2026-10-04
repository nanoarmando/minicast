## ADDED Requirements

### Requirement: Minicast name in the interface
Every place where the app names itself to the user (menus, palette commands, About window, Settings,
permission prompts, dialogs, HUDs, error messages and notifications) SHALL say "Minicast" ("Minicast Dev"
where the running build's name is shown in a debug build). Credits to the original Tinycast project are
the only exception.

#### Scenario: Palette commands
- **WHEN** the user searches the palette for "settings", "about" or "quit"
- **THEN** the commands read "Minicast Settings", "About Minicast" and "Quit Minicast"

#### Scenario: Permission prompt
- **WHEN** macOS asks for Calendar, Reminders, Automation or Bluetooth access
- **THEN** the explanation names Minicast

#### Scenario: No leftover name
- **WHEN** the user goes through every Settings pane and the menu bar menu
- **THEN** no text names "Tinycast" except the upstream credit in About

### Requirement: Minicast icons
The app SHALL use the Minicast "M" monogram icon (an orange-to-pink gradient M on a dark rounded square)
in Finder, the Dock, app switchers and the About window, on macOS 13 and later, and a monochrome "M"
template icon in the menu bar that adapts to light and dark menu bars.

#### Scenario: Icon on macOS 13
- **WHEN** Minicast is installed on the macOS 13 Mac
- **THEN** Finder and the About window show the M monogram, not a generic app icon

#### Scenario: Menu bar
- **WHEN** the menu bar is light or dark
- **THEN** the M menu bar icon is drawn in the menu bar's text color

### Requirement: About Minicast
The About window SHALL present Minicast: its name, icon and version, a short statement of what Minicast is
and why it exists, and a link to the Minicast repository `github.com/nanoarmando/minicast`. It SHALL
credit Tinycast by Abue Ammar under AGPL-3.0 with a link to the upstream repository, and SHALL NOT present
upstream's community, website or contact links as Minicast's own. The palette's Changelog command SHALL
open the commit history of the Minicast repository.

The statement SHALL convey: "Minicast is Tinycast for every Mac: a small, native launcher that runs from
macOS 13 on Intel and Apple silicon. It started as a personal fork to keep older Macs useful without
giving up great tools."

#### Scenario: About window
- **WHEN** the user opens About Minicast
- **THEN** it shows the Minicast name, icon, version and statement, a link to the Minicast repository,
  and the credit to Tinycast with its license and a link to the upstream repository

#### Scenario: Changelog
- **WHEN** the user runs the Changelog command
- **THEN** the browser opens `github.com/nanoarmando/minicast/commits/main`

### Requirement: Minicast link scheme
The app SHALL handle `minicast://` links (including extension OAuth callbacks and extension deep links) and
SHALL keep handling `raycast://` and `com.raycast://`. It SHALL NOT register `tinycast://`.

#### Scenario: Extension OAuth
- **WHEN** an extension completes an OAuth sign-in that redirects to `raycast://` or `minicast://`
- **THEN** Minicast receives the callback and the sign-in completes

#### Scenario: Official app installed
- **WHEN** the official Tinycast is installed alongside Minicast
- **THEN** `tinycast://` links open the official app, not Minicast

### Requirement: Backup file type
Backups exported by Minicast SHALL use the `.minicast` extension, and Backup import SHALL accept both
`.minicast` and `.tinycast` files.

#### Scenario: Export
- **WHEN** the user exports a backup
- **THEN** the suggested file name is `Minicast-<date>.minicast`

#### Scenario: Import an old backup
- **WHEN** the user imports a `.tinycast` backup made by Tinycast Fork or the official app
- **THEN** the file can be selected and is imported as before

### Requirement: Names presented to third parties
Names the app sends to services and tools (the AI system prompt, MCP client name and title, HTTP user
agents, Codex and Claude session titles, and extension runtime messages) SHALL say Minicast. Shell commands
run by Minicast SHALL receive `MINICAST=1` and SHALL keep receiving `TINYCAST=1`.

#### Scenario: Shell command detection
- **WHEN** a custom shell command checks `$MINICAST` or `$TINYCAST`
- **THEN** both are set to `1`

#### Scenario: AI chat
- **WHEN** the user asks the AI chat what app it is running in
- **THEN** the system prompt identifies the app as Minicast

#### Scenario: Unsupported extension API
- **WHEN** an extension calls an API the runtime does not support
- **THEN** the error message names Minicast
