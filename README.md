# Tinycast Fork

A private fork of [Tinycast](https://github.com/abue-ammar/tinycast) by Abu Ammar: a tiny, fully native
macOS launcher. The fork runs on **macOS 13 Ventura or later**, on Intel and Apple silicon, from one
universal build. It is maintained for personal use and does not track upstream.

All credit for the original app goes to its author. The fork keeps the AGPL-3.0 license.

## What differs from upstream

| Area | Upstream | This fork |
| --- | --- | --- |
| Minimum macOS | 26 | 13 |
| Architectures | Apple silicon (Intel via a separate cask) | One universal build (arm64 + x86_64) |
| Appearance | Liquid Glass | Classic macOS blur materials on every version |
| Identity | `com.tinycast.app`, "Tinycast" | `com.tinycast.app.fork`, "Tinycast Fork" |
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

1. Create the local signing identity once per Mac, following [docs/signing.md](docs/signing.md). A stable
   identity lets macOS keep the Accessibility permission across rebuilds.
2. After editing `project.yml`, regenerate the project:
   ```sh
   ./.tools/xcodegen/bin/xcodegen generate
   ```
3. Build the signed universal app and DMG:
   ```sh
   ./Scripts/build-dmg.sh
   ```
   The script checks the signing identity, verifies both architectures and the macOS 13.0 minimum, and
   writes `build/Tinycast-Fork-<version>.dmg`.

Command-line builds need `-skipMacroValidation` because swift-perception uses a Swift macro; the build
script already passes it.

## Install

Copy "Tinycast Fork.app" to `/Applications`. On another Mac (for example the Intel one), copy the same
signed app; if it was transferred through a download, clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine "/Applications/Tinycast Fork.app"
```

## Data and the official app

The fork keeps all its data apart from the official app, so the official app can be reinstalled at any
time and finds its own configuration untouched.

| Data | Official app | Fork |
| --- | --- | --- |
| Preferences | `com.tinycast.app` | `com.tinycast.app.fork` |
| Data (clipboard, AI chats, extensions) | `~/Library/Application Support/com.tinycast.app` | `~/Library/Application Support/com.tinycast.app.fork` |
| Settings file | `~/.config/tinycast/settings.json` | `~/.config/tinycast-fork/settings.json` |
| Keychain secrets | `com.tinycast.app.*` | `com.tinycast.app.fork.*` |

Running both apps at the same time is not recommended: they claim the same URL schemes (`tinycast://`,
`raycast://`) and may register the same hotkeys. While the fork runs, the official app is hidden from the
fork's launcher.

## Migrating from the official app

A fresh fork starts empty. To bring over an existing setup, run the one-time migration script:

1. Quit the official Tinycast.
2. Copy "Tinycast Fork.app" to `/Applications` without opening it.
3. Run:
   ```sh
   ./Scripts/migrate-from-official.sh
   ```
   macOS asks for authorization for each Keychain secret (AI keys, MCP secrets, extension sign-ins).
   Denied secrets are skipped and listed.
4. Open the fork, grant **Accessibility** (and any other permission a feature asks for) and turn
   **launch at login** back on in **Settings → General**.

The script copies preferences, Application Support data, caches, the settings file (without keys of
removed features) and Keychain secrets. It never modifies the official app's data. It aborts if either
app is running, if the fork is not installed, or if the fork already has data; `--force` first moves the
fork's existing data to `~/Documents/Backups/Tinycast-Fork-<timestamp>/`.

Permissions and the login item cannot be migrated because macOS ties them to the app's signature.

Alternatively, export a backup from the official app and import it in **Settings → Backup**; it covers
settings, hotkeys, clipboard history and launcher learning, but not AI keys, MCP servers or extensions.

## Permissions

**Accessibility** is needed when Tinycast pastes text into another app or reads the selected text for
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

## Known limitations

- On macOS 13 there are no symbol animations and no focus-ring suppression.
- Custom quick actions saved with SF Symbol names newer than macOS 13 render without an icon.

## License

[AGPL-3.0](LICENSE). Based on Tinycast by Abu Ammar.
