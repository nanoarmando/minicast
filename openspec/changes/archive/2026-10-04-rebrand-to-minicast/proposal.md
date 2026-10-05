## Why

The fork has become the user's main launcher on both Macs, but it still presents itself as "Tinycast
Fork", uses upstream's icon and competes with the official app for the `tinycast://` scheme. Giving it its
own name, icon and identity (Minicast) makes it a distinct app while keeping credit to Tinycast.

## What Changes

- **BREAKING** New identity: release `com.minicast.app` / "Minicast", debug `com.minicast.app.dev` /
  "Minicast Dev". All persisted data moves to locations keyed by the new id, so Minicast starts empty
  until the migration runs. The settings file moves to `~/.config/minicast/settings.json`.
- New app icon (the "M" monogram: orange-to-pink gradient M on a dark rounded square) and a matching
  monochrome menu bar icon.
- Every user-visible "Tinycast" (menus, About, Settings, permission prompts, errors, HUDs) becomes
  "Minicast". The About window keeps the upstream credit and adds a link to the Minicast repository.
- **BREAKING** The app registers `minicast://` and stops claiming `tinycast://`; `raycast://` and
  `com.raycast://` stay for extensions.
- Backups export as `.minicast`; old `.tinycast` backups can still be imported.
- Names seen by third parties (AI system prompt, MCP client name, user agents, Codex/Claude titles,
  extension runtime messages) become Minicast. Shell commands receive `MINICAST=1` in addition to the
  existing `TINYCAST=1`.
- The migration script migrates the official Tinycast's data into Minicast, including Keychain secrets.
- Builds produce "Minicast.app" and `Minicast-<version>.dmg`, version 0.2.0, signed with a new local
  identity "Minicast Self-Signed" that replaces "Tinycast Self-Signed".
- The About window explains what Minicast is and why it exists, and keeps the credit to Tinycast.
- `README.md`, `AGENTS.md` and every document under `docs/` are rewritten for Minicast: names, ids,
  macOS 13 floor, classic materials, no self-update and no removed features.
- The GitHub repository is renamed to `nanoarmando/minicast`; the Changelog command points there.
- Internal code names (folder `Tinycast/`, Xcode project, target, module, type names, JS bridge globals)
  are unchanged; renaming them is a separate change, `rename-internal-identifiers`.

## Capabilities

### New Capabilities

- `brand-presentation`: the app's visible name, icon, menu bar icon, About credit, link scheme, backup
  file type, and the names it presents to third parties.

### Modified Capabilities

- `fork-identity`: bundle ids, app names, settings file location, backup import, and the migration
  (source: the official Tinycast; destination: Minicast).
- `local-build`: the build produces "Minicast.app" and its DMG, signed with "Minicast Self-Signed".

## Impact

- `project.yml`, `Tinycast/Info.plist`, generated `Tinycast.xcodeproj`.
- `Platform/AppPaths.swift`, id fallbacks in stores, `AppIndex` self-filter, URL scheme handling in
  extensions, Backup UTType, user-visible strings across about 60 Swift files, AI/MCP protocol strings,
  `ShellCommandRunner` environment.
- Icon assets (`tinycast.icon`, `MenuBarIcon.imageset`), About window.
- `Scripts/raycast-runtime/src` and the regenerated `Resources/RaycastRuntime.generated.js` (needs Node).
- `Scripts/build-dmg.sh`, `Scripts/migrate-from-official.sh`; tests asserting renamed strings.
- `README.md`, `AGENTS.md`, `docs/` (39 files), `openspec/specs/`. `website/` is handled by a separate
  change.
- User impact: a new signing certificate is created once on the build Mac; macOS permissions and launch
  at login must be granted again; the official Tinycast and its data stay until the user removes them.
