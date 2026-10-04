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
- **Backup and import** of the whole setup as one ZIP bundle (settings, extensions, AI and MCP
  configuration, chats, clipboard), excluding Keychain secrets, plus import from Raycast.

## Philosophy: new features are extensions

Minicast stays small on purpose. Very few features will be added beyond the ones listed above; the
work goes into keeping those fast, stable and working on every Mac from macOS 13.

**If you want a feature, the way to get it is a Raycast extension.** Minicast runs Raycast extensions
natively, so anything an extension can do — a list, a form, a detail view, a menu bar item, a
background refresh — needs no change to Minicast at all. Check the
[Raycast Store](https://www.raycast.com/store) first: the feature may already exist.

### Writing your own extension

Raycast itself is not needed: an extension is a small Node project, and the `ray` build tool comes
with the `@raycast/api` package. You need Node and npm (or pnpm, Bun or Yarn).

1. **Create it.** A folder with four files is a complete extension:

   ```
   hello-minicast/
     package.json        the manifest: name, title, commands
     tsconfig.json
     assets/icon.png     a 512×512 PNG
     src/hello.tsx       one file per command, named after the command
   ```

   `package.json`:
   ```json
   {
     "$schema": "https://www.raycast.com/schemas/extension.json",
     "name": "hello-minicast",
     "title": "Hello Minicast",
     "description": "A minimal extension",
     "icon": "icon.png",
     "author": "your-github-user",
     "license": "MIT",
     "platforms": ["macOS"],
     "categories": ["Developer Tools"],
     "commands": [
       { "name": "hello", "title": "Say Hello", "description": "Shows a greeting", "mode": "view" }
     ],
     "dependencies": { "@raycast/api": "latest" },
     "devDependencies": { "@types/react": "^19", "@types/node": "^22", "typescript": "^5" }
   }
   ```

   `tsconfig.json`:
   ```json
   {
     "compilerOptions": {
       "lib": ["ES2023"], "module": "commonjs", "target": "ES2022", "strict": true,
       "isolatedModules": true, "esModuleInterop": true, "skipLibCheck": true,
       "forceConsistentCasingInFileNames": true, "jsx": "react-jsx", "resolveJsonModule": true
     },
     "include": ["src/**/*", "raycast-env.d.ts"]
   }
   ```

   `src/hello.tsx`:
   ```tsx
   import { List } from "@raycast/api";

   export default function Command() {
     return (
       <List>
         <List.Item title="Hello from Minicast" />
       </List>
     );
   }
   ```

   A command's `mode` is `view` (it shows a list, grid, form or detail), `no-view` (it runs and
   finishes) or `menu-bar`. The [Raycast developer docs](https://developers.raycast.com) cover the
   whole API, and the extensions in
   [raycast/extensions](https://github.com/raycast/extensions/tree/main/extensions) are good examples
   to copy from.
2. **Build it** from the extension's folder:
   ```sh
   npm install
   npx ray build -e dist -o build
   ```
   The `build/` folder then holds `package.json`, `assets/` and one `.js` file per command. Use
   `-e dist -o build`, not `ray build` alone: its default dev mode tries to install into a local
   Raycast instead of writing a build.
3. **Install it in Minicast** (Settings → Extensions; turn extensions on first, which asks for
   consent because extensions run third-party code). Under **Install New**:
   - **Add from folder** — pick the `build/` folder from step 2. Rebuild and add it again after each
     change.
   - **Install from GitHub** — push the extension to a repository and paste `owner/repo` (or the link
     to its folder). Minicast downloads only that folder and builds it on this Mac, which needs Node and
     a package manager (pnpm, Bun, Yarn or npm).
   - **Search extensions** — once it is published to the Raycast Store, install the store's prebuilt
     copy; no Node needed.

Not every Raycast API exists here: the `AI`, `BrowserExtension` and `WindowManagement` services and
AI tools are unavailable. The full list is in
[docs/features/extensions.md](docs/features/extensions.md#what-isnt-supported-yet).

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

## Data and the official Tinycast

Minicast keeps its data apart from the official Tinycast, so Tinycast can be installed at any time and
finds its own configuration untouched.

| Data | Minicast | Official Tinycast |
| --- | --- | --- |
| Preferences | `com.minicast.app` | `com.tinycast.app` |
| Data (clipboard, AI chats, extensions) | `~/Library/Application Support/com.minicast.app` | `~/Library/Application Support/com.tinycast.app` |
| Settings file | `~/.config/minicast/settings.json` | `~/.config/tinycast/settings.json` |
| Keychain secrets | `com.minicast.app.*` | `com.tinycast.app.*` |

The debug build, "Minicast Dev" (`com.minicast.app.dev`), has its own copies of all of these, with the
settings file in `~/.config/minicast-dev/`.

Minicast registers `minicast://`, `raycast://` and `com.raycast://`. It does not claim `tinycast://`,
which stays with the official app. Neither app is suggested by Minicast's launcher. Running both at
once is not recommended because they may register the same hotkeys.

## Migrating from Tinycast

A fresh Minicast starts empty. To bring over an existing Tinycast setup, run the one-time migration
script:

1. Quit Tinycast.
2. Copy "Minicast.app" to `/Applications` without opening it.
3. Run:
   ```sh
   ./Scripts/migrate-to-minicast.sh
   ```
   macOS asks for authorization for each Keychain secret (AI keys, MCP secrets, extension sign-ins).
   Denied secrets are skipped and listed.
4. Open Minicast, grant **Accessibility** (and any other permission a feature asks for) and turn
   **launch at login** back on in **Settings → General**. Then quit and remove Tinycast if you no
   longer need it.

The script copies preferences, Application Support data, caches, the settings file (without settings
of removed features) and Keychain secrets. It never modifies Tinycast's data. It aborts if either app
is running, if Minicast is not installed, or if Minicast already has data; `--force` first moves
Minicast's existing data to `~/Documents/Backups/Minicast-<timestamp>/`.

Permissions and the login item cannot be migrated because macOS ties them to the app's identity and
signature.

Alternatively, export a backup from Tinycast and import it in **Settings → Backup**. A `.tinycast`
backup covers settings, hotkeys, clipboard history and launcher learning, but not AI keys, MCP
servers or extensions.

## Moving to another Mac

Open **Import & Export** from the launcher (Export Backup / Import Backup) or from **Settings →
Backup**. Export writes one `Minicast-<date>.minicast` file, which is a ZIP. It can hold six
categories, all selected by default: Settings & Shortcuts, Extensions, AI & MCP, Clipboard History, AI
Chat History and Launcher Learning.

On the other Mac, import the file and choose the categories to restore. Each selected category
**replaces** what is there; unselected ones are not touched. Then:

- Feature switches that grant a capability (extensions, MCP, AI, quick actions, calendar, auto-join,
  clipboard text recognition) turn on only if you accept a dialog listing what would be able to run.
- Keychain secrets never travel: the summary lists the AI connections, MCP servers and installed AI
  tools whose keys must be entered again, and extensions ask for their sign-in again.
- The file can contain extension passwords, tokens, clipboard content and chats in readable form.
  Treat it as a sensitive file.

A bundle needs a Minicast build with this format on both Macs; older builds cannot read it.

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
