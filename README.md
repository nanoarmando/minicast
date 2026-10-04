# Minicast

Minicast is Tinycast for every Mac: a small, native macOS launcher that runs from **macOS 13 Ventura** on
Intel and Apple silicon, from one universal build. It started as a personal fork of
[Tinycast](https://github.com/abue-ammar/tinycast) by Abue Ammar to keep older Macs useful without giving
up great tools. It is maintained for personal use and does not track upstream.

All credit for the original app goes to its author. Minicast keeps the AGPL-3.0 license.

## What differs from Tinycast

| Area | Tinycast | Minicast |
| --- | --- | --- |
| Minimum macOS | 26 | 13 |
| Architectures | Apple silicon (Intel via a separate cask) | One universal build (arm64 + x86_64) |
| Appearance | Liquid Glass | Classic macOS blur materials on every version |
| Identity | `com.tinycast.app`, "Tinycast" | `com.minicast.app`, "Minicast" |
| Link scheme | `tinycast://` | `minicast://` |
| Updates | Self-updates from GitHub releases | No self-update; rebuild from source |
| Observation | Apple Observation | [swift-perception](https://github.com/pointfreeco/swift-perception) back-port |

**Removed features:** Apple Intelligence as an AI provider, the Translate quick action, Dictation, Notes,
Quicklinks, the camera preview, Snippets, the Support reminder, Onboarding, the window switcher and menu
bar search (the Navigation pane), and updates.

## Features

- **App launcher** with favorites, running apps and per-app hotkeys.
- **Global hotkey** to summon the palette.
- **Search Files** through Spotlight.
- **Dictionary** lookups.
- **Clipboard history** for text and images.
- **Calculator** with units and live currency conversion.
- **Apple Shortcuts** and **custom shell commands**, with aliases and hotkeys.
- **Window management**: window commands with hotkeys, layouts, rooms and custom sizes.
- **System actions**: lock, sleep, appearance, Bluetooth, mute and more.
- **Calendar and meetings** in the palette and the menu bar.
- **Emoji picker**.
- **AI chat and Quick Actions** with your own API keys or installed AI accounts, plus **MCP** servers.
- **Raycast extensions**, rendered natively.
- **Backup and import**, including import from Raycast.

## Requirements

- To run: macOS 13 or later, Intel or Apple silicon.
- To build: a Mac with Xcode 27 (selected with `xcode-select`, license accepted, first-launch components
  installed). XcodeGen is used from a project-local binary in `.tools/xcodegen/` (not committed); download
  the official release from [XcodeGen](https://github.com/yonaskolb/XcodeGen/releases) into that folder.

## Build

1. Create the local signing identity "Minicast Self-Signed" once per build Mac, following
   [docs/signing.md](docs/signing.md). A stable identity lets macOS keep the Accessibility permission
   across rebuilds.
2. After editing `project.yml`, regenerate the project:
   ```sh
   ./.tools/xcodegen/bin/xcodegen generate
   ```
3. Build the signed universal app and DMG:
   ```sh
   ./Scripts/build-dmg.sh
   ```
   The script checks the signing identity, verifies both architectures and the macOS 13.0 minimum, and
   writes `build/Minicast-<version>.dmg`.

Command-line builds need `-skipMacroValidation` because swift-perception uses a Swift macro; the build
script already passes it.

## Install

Copy "Minicast.app" to `/Applications`. On another Mac (for example the Intel one), copy the same signed
app; if it was transferred through a download, clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/Minicast.app
```

## Data and the other apps

Minicast keeps its data apart from the official Tinycast and from the earlier "Tinycast Fork", so either
of them can be installed at any time and finds its own configuration untouched.

| Data | Minicast | Tinycast Fork | Official Tinycast |
| --- | --- | --- | --- |
| Preferences | `com.minicast.app` | `com.tinycast.app.fork` | `com.tinycast.app` |
| Data (clipboard, AI chats, extensions) | `~/Library/Application Support/com.minicast.app` | `…/com.tinycast.app.fork` | `…/com.tinycast.app` |
| Settings file | `~/.config/minicast/settings.json` | `~/.config/tinycast-fork/settings.json` | `~/.config/tinycast/settings.json` |
| Keychain secrets | `com.minicast.app.*` | `com.tinycast.app.fork.*` | `com.tinycast.app.*` |

The debug build, "Minicast Dev" (`com.minicast.app.dev`), has its own copies of all of these, with the
settings file in `~/.config/minicast-dev/`.

Minicast registers `minicast://`, `raycast://` and `com.raycast://`. It no longer claims `tinycast://`,
which stays with the official app. None of the three apps is suggested by Minicast's launcher. Running
Minicast next to another of them is not recommended because they may register the same hotkeys.

## Migrating into Minicast

A fresh Minicast starts empty. To bring over an existing setup, run the one-time migration script:

1. Quit the source app (Tinycast Fork or the official Tinycast).
2. Copy "Minicast.app" to `/Applications` without opening it.
3. Run one of:
   ```sh
   ./Scripts/migrate-to-minicast.sh                  # from Tinycast Fork (default)
   ./Scripts/migrate-to-minicast.sh --from official  # from the official Tinycast
   ```
   macOS asks for authorization for each Keychain secret (AI keys, MCP secrets, extension sign-ins).
   Denied secrets are skipped and listed.
4. Open Minicast, grant **Accessibility** (and any other permission a feature asks for) and turn
   **launch at login** back on in **Settings → General**. Then quit and remove the old app.

The script copies preferences, Application Support data, caches, the settings file and Keychain secrets.
From the official app it leaves out settings of removed features. It never modifies the source app's
data. It aborts if either app is running, if Minicast is not installed, or if Minicast already has data;
`--force` first moves Minicast's existing data to `~/Documents/Backups/Minicast-<timestamp>/`.

Permissions and the login item cannot be migrated because macOS ties them to the app's identity and
signature.

Alternatively, export a backup from the other app and import it in **Settings → Backup**. Minicast reads
both `.minicast` and `.tinycast` backups; a backup covers settings, hotkeys, clipboard history and
launcher learning, but not AI keys, MCP servers or extensions.

## Permissions

**Accessibility** is needed when Minicast pastes text into another app or reads the selected text for
Quick Actions. Grant it in **System Settings → Privacy & Security → Accessibility**. Calendar access is
requested when the calendar feature is enabled.

## Using it

1. Open **Settings → General** and record a global shortcut to summon the palette (the menu bar item
   also opens it).
2. Press it anywhere, type to filter, **↵** to launch, **↑/↓** to move, **Esc** to dismiss.
3. **Settings → Shortcuts** assigns hotkeys to apps, commands and window actions.

## Tests

```sh
./Scripts/run-tests.sh
```

The runner builds swift-perception once into `.build/harness-perception/` (rebuilt when
`Tinycast.xcodeproj/.../Package.resolved` changes) and links it into every harness. `./Scripts/lint.sh`
requires SwiftLint.

The source folder, Xcode project, target and module are still named `Tinycast`; renaming those internal
names is planned separately.

## Known limitations

- On macOS 13 there are no symbol animations and no focus-ring suppression.
- Custom quick actions saved with SF Symbol names newer than macOS 13 render without an icon.

## License

[AGPL-3.0](LICENSE). Based on [Tinycast](https://github.com/abue-ammar/tinycast) by Abue Ammar.
