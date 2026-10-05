# backup-bundle Specification

## Purpose

Lets the user carry their complete Minicast setup to another Mac as one ZIP bundle and restore it with a
single import. Only Keychain secrets are left out.

## Requirements

### Requirement: Bundle file format
Export SHALL write a single file named `Minicast-<date>.minicast` that is a standard ZIP archive. It
SHALL contain a `manifest.json` that declares format version 2, the app version, the creation date and a
count per included category. The file SHALL keep the `com.minicast.backup` type.

#### Scenario: Bundle opens as a ZIP
- **WHEN** the user exports a bundle and renames the file to `.zip`
- **THEN** Archive Utility extracts it into a folder holding `manifest.json` and one folder per included
  category

#### Scenario: Newer format rejected clearly
- **WHEN** the user imports a bundle whose manifest declares a format newer than the app supports
- **THEN** the import stops before any data changes and reports that the file was made by a newer
  Minicast

### Requirement: Legacy backups still import
Import SHALL keep accepting format-1 `.minicast` files and `.tinycast` files written by the official app,
and SHALL restore the categories those files carry.

#### Scenario: Old Minicast backup
- **WHEN** the user imports a `.minicast` file exported by a Minicast build from before this change
- **THEN** its settings, clipboard history and launcher learning import as they did before

#### Scenario: Official Tinycast backup
- **WHEN** the user imports a `.tinycast` file
- **THEN** it imports exactly as it did before this change

### Requirement: Keychain secrets never enter a bundle
A bundle SHALL NOT contain any value stored in the Keychain: AI API keys, MCP server secrets, installed AI
tool environment values and extension OAuth tokens. Export SHALL NOT read the Keychain, so it SHALL NOT
cause a Keychain access prompt.

#### Scenario: Export with configured AI and MCP
- **WHEN** the user exports a bundle while AI connections with API keys and MCP servers with header
  secrets are configured
- **THEN** the bundle contains the connections and servers, none of their secret values appear anywhere
  in the extracted bundle, and no Keychain prompt is shown

### Requirement: Bundle categories
Export SHALL offer these categories, all selected by default and each deselectable: Settings & Shortcuts,
Extensions, AI & MCP, Clipboard History, AI Chat History, Launcher Learning. The bundle SHALL contain
only the selected categories, and import SHALL offer only the categories present in the bundle.

- **Settings & Shortcuts** SHALL carry every persisted setting except machine-local ones (palette
  position and display geometry, extension package manager and custom search paths, input source to
  switch to, meeting browser, the `settings.json` switch, launch at login). It SHALL also carry every
  hotkey (including quick-action, Apple Shortcut and extension-command hotkeys), custom commands, custom
  quick actions and their settings, window layouts, rooms, custom and room-minimum window sizes,
  favorites, hidden launcher items and kinds, aliases, fallback order and enabled state, hidden meeting
  calendars and pinned emoji.
- **Extensions** SHALL carry every installed extension's files, preferences (including password-type
  values), LocalStorage, cache, per-command state, support folder, recorded store version and appearance
  choice.
- **AI & MCP** SHALL carry AI connections, the default model, shown models, disabled routes, installed AI
  tool selection and overrides, the system prompt and the other AI chat settings, and MCP servers.
- **Clipboard History** SHALL carry clipboard items and their images.
- **AI Chat History** SHALL carry every AI conversation.
- **Launcher Learning** SHALL carry launcher ranking, emoji frequency and calculator history.

#### Scenario: Default export
- **WHEN** the user exports without changing any selection
- **THEN** the bundle contains all six categories

#### Scenario: Partial export
- **WHEN** the user deselects Clipboard History and exports
- **THEN** the bundle contains no clipboard data, and import of that bundle does not offer Clipboard
  History

#### Scenario: Extension carried with its configuration
- **WHEN** the user exports with an extension installed from GitHub that has a password-type preference
  set
- **THEN** the bundle contains that extension's files and its preference values, including the password
  value in plain text

#### Scenario: Machine-local setting not carried
- **WHEN** the user exports after placing the palette on a secondary display
- **THEN** the bundle does not contain the palette position

### Requirement: Bundle sensitivity warning
The export UI SHALL warn that the bundle can contain extension passwords, LocalStorage tokens, clipboard
content and chat history in readable form, and that it should be handled as a sensitive file.

#### Scenario: Warning shown before export
- **WHEN** the user opens the export side of the Import/Export window
- **THEN** the warning is visible before the user chooses where to save

### Requirement: Import replaces selected categories
Import SHALL replace each selected category with the bundle's content, and SHALL leave unselected
categories unchanged. Before any change it SHALL ask for confirmation that names the categories to be
replaced and the installed extensions that would be uninstalled. Within Extensions, replace SHALL install every bundled extension (overwriting one with the same
name) and uninstall installed extensions that are absent from the bundle, with the same cleanup as a
manual uninstall.

#### Scenario: Replace settings and extensions
- **WHEN** the user imports Settings & Shortcuts and Extensions into a Mac that has other settings and
  one extension not present in the bundle
- **THEN** after confirming, settings match the bundle, the bundled extensions are installed with their
  preferences and data, and the extra extension is uninstalled

#### Scenario: Unselected category untouched
- **WHEN** the user imports a bundle but deselects Clipboard History
- **THEN** the destination's clipboard history is unchanged

#### Scenario: Confirmation declined
- **WHEN** the user cancels the replace confirmation
- **THEN** no data changes

#### Scenario: Hotkey for an extension command
- **WHEN** the bundle carries a hotkey bound to an extension command and the user imports Settings &
  Shortcuts and Extensions together
- **THEN** the hotkey works for that command after the import

### Requirement: Capability switches require consent on import
The capability switches (extensions, MCP, AI, quick actions, calendar access, auto-join meetings and
clipboard text recognition) SHALL travel in Settings & Shortcuts. They SHALL only be applied after a
confirmation that lists what would become able to run: the extensions, the local MCP server commands,
the installed AI tool overrides that name a program, and any custom commands or fallbacks that run
shell commands. If the user declines, every other imported content SHALL still apply and the switches
SHALL keep their current values on the destination.

#### Scenario: Consent accepted
- **WHEN** the bundle has extensions and MCP enabled and the user accepts the consent dialog
- **THEN** extensions and MCP are enabled on the destination as in the bundle

#### Scenario: Consent declined
- **WHEN** the user declines the consent dialog
- **THEN** the extensions, MCP servers and other content are imported, and the capability switches keep
  their previous values

#### Scenario: System permission still required
- **WHEN** the imported switches enable calendar access or quick actions
- **THEN** macOS still asks for the matching Calendar or Accessibility permission the first time it is
  needed, and the import does not bypass it

### Requirement: Report of secrets to re-enter
After an import that included AI & MCP, the import summary SHALL list each AI connection, MCP server and
installed AI tool that had secrets on the source and has none on the destination. Each entry SHALL open
the place where that secret is set. Extension OAuth sign-ins SHALL be requested again by the extension on
first use.

#### Scenario: Missing API key listed
- **WHEN** the user imports AI & MCP with an OpenAI connection whose key is not in this Mac's Keychain
- **THEN** the summary lists that connection, and choosing it opens the AI settings for that connection

#### Scenario: Secrets already present
- **WHEN** the destination's Keychain already holds the secret for an imported connection with the same
  identifier
- **THEN** that connection is not listed as pending

### Requirement: Import/Export window
Minicast SHALL provide an Import/Export window with an export side and an import side. The launcher's
Export and Import commands SHALL open it on the matching side, and Settings → Backup SHALL open it. The
Backup pane SHALL keep the Raycast import and the `settings.json` switch.

#### Scenario: Launcher export command
- **WHEN** the user runs the launcher's Export command
- **THEN** the Import/Export window opens on the export side with all categories selected

#### Scenario: Window already open
- **WHEN** the window is open and the user runs the Import command
- **THEN** the existing window comes to the front on the import side instead of opening a second one

### Requirement: Safe bundle extraction
Import SHALL reject a bundle that contains an absolute path, a path that escapes the extraction folder or
a symbolic link, and SHALL reject an extension name that is not a safe folder name, before any data
changes.

#### Scenario: Hostile archive
- **WHEN** the user imports a ZIP containing an entry named `../../Library/LaunchAgents/x.plist`
- **THEN** the import fails with an invalid-file message and nothing is written outside the staging
  folder

### Requirement: Failures reported per category
Import SHALL apply each selected category independently. A failure in one category SHALL be reported in
the import summary without stopping the other categories.

#### Scenario: One extension fails to restore
- **WHEN** one bundled extension cannot be installed
- **THEN** the other extensions and categories import, and the summary names the failed extension and
  the reason
