## Context

See `proposal.md`. Verified facts from the codebase inventory:

- Identity comes from `project.yml` (`TINYCAST_BUNDLE_IDENTIFIER`, `PRODUCT_NAME`, `bundleIdPrefix`);
  `Info.plist` uses build variables. Runtime UI names use `Bundle.main.appDisplayName` except
  `CommandID.swift` (hardcoded) and `AppDisplayName.swift`'s fallback literal.
- All persisted data derives from `Bundle.main.bundleIdentifier`; there is no app group or keychain access
  group. `AppPaths.configFolderName` hardcodes the stable id `com.tinycast.app` to map ids to
  `~/.config/<name>[-suffix]`. Six stores fall back to `"com.tinycast.app"` when the id is nil.
- `tinycast://` is declared in `Info.plist` and accepted in `ExtensionOAuthSession` and
  `ExtensionDeepLink.claims`; other `tinycast://` strings are placeholder entry URLs never parsed.
- `AppIndex.ownBundlePrefix = "com.tinycast."` keeps the app out of launcher suggestions.
- The app icon is the Icon Composer bundle `Tinycast/tinycast.icon` (one SVG layer); the menu bar icon is
  `Assets.xcassets/MenuBarIcon.imageset/thunder.svg` (template). About reads the bundle icon.
- The extension runtime JS is generated from `Scripts/raycast-runtime/src` by `build.mjs` (Node).
- `migrate-from-official.sh` migrates official → fork, including Keychain via `security`.

## Goals / Non-Goals

**Goals:** a complete user-visible rename with a new identity, icon and scheme; a migration from the
official Tinycast that keeps the user's setup; no change in behavior otherwise.

**Non-Goals:** renaming internal code names (folder, project, target, module, types, `__tinycast*` JS
globals, `onTinycast*` props, temp-file prefixes, logging subsystems, dispatch labels); `website/`
(separate change).

## Decisions

### 1. Identity
`project.yml`: `bundleIdPrefix: com.minicast`, `TINYCAST_BUNDLE_IDENTIFIER` = `com.minicast.app` /
`com.minicast.app.dev`, `PRODUCT_NAME` = "Minicast" / "Minicast Dev", `MARKETING_VERSION` 0.2.0. The
build-variable name keeps its `TINYCAST_` prefix (internal name). `AppPaths` stable id becomes
`com.minicast.app` and its folder base `minicast`. Id fallbacks become `"com.minicast.app"`.
`AppDisplayName` fallback and `CommandID` names say Minicast.

### 2. Self-filter
`AppIndex` filters any of `com.minicast.`, `com.tinycast.` so neither Minicast nor the other Tinycast
apps are suggested.

### 3. Scheme
`Info.plist` registers `raycast`, `minicast`, `com.raycast`; `ExtensionOAuthSession` and
`ExtensionDeepLink.claims` replace `tinycast` with `minicast`. Placeholder entry URLs switch to
`minicast://` for consistency.

### 4. Backup type
Export a new UTI `com.minicast.backup` with extension `minicast`. Import the old `com.tinycast.backup` /
`.tinycast` as an imported type declaration (`UTImportedTypeDeclarations`) so the open panel accepts
both. The archive format is unchanged.
- Alternative: keep exporting `.tinycast`. Rejected: the rename's purpose is a distinct identity.

### 5. User-visible and third-party strings
Replace "Tinycast" in user-visible strings and third-party-visible strings (AI preamble, Codex prompt,
MCP `client_name`/client info, user agents, Codex/Claude titles, backup manifest text, MCP OAuth browser
page). Keep credit strings in About. `ShellCommandRunner` and `ExecutableLocator` export `MINICAST=1`
next to `TINYCAST=1`. Runtime JS messages and `process.versions`/`process.title` change in
`Scripts/raycast-runtime/src`, then the generated file is rebuilt with `node build.mjs`; JS bridge
global names stay.
- Risk: MCP servers with dynamic client registration may treat the new `client_name` as a new client;
  migrated registrations stay valid because the redirect URI is unchanged. Re-authorize if needed.

### 6. Icons
Replace the `.icon` layer with the M monogram (gradient stroke) over a dark fill in `icon.json`, and the
menu bar SVG with a single-color M template. Keep the asset file names (internal). The build must embed
an `.icns` usable on macOS 13; if Xcode 27 does not emit one from the `.icon` for the 13.0 target, fill
`AppIcon.appiconset` with PNGs rendered from the same SVG and point `ASSETCATALOG_COMPILER_APPICON_NAME` at
it.

### 7. About
`AboutView` shows the Minicast icon, name and version, the statement from the spec, and a
"Minicast on GitHub" row. Upstream's website, Discord, X and email rows are removed; a credit block reads
"Based on Tinycast by Abue Ammar · AGPL-3.0" with a link to `github.com/abue-ammar/tinycast`. Layout,
spacing and materials follow the existing About design. Changelog URL →
`github.com/nanoarmando/minicast/commits/main`.

### 8. Signing identity
`project.yml` and `build-dmg.sh` use "Minicast Self-Signed". `docs/signing.md` gives the steps to create
it once on the build Mac; the old "Tinycast Self-Signed" certificate can be deleted afterwards. The bundle
id change already resets permissions, so the new certificate adds no extra reset.

### 9. Documentation
`README.md`, `AGENTS.md` and all of `docs/` describe Minicast as it is: names, ids, paths, macOS 13 floor,
swift-perception, classic materials, local signing and release, no self-update; sections about removed
features (Dictation, Notes, Quicklinks, Snippets, Camera, Translate, Apple Intelligence, Updates,
Onboarding, WindowSwitcher, MenuSearch) are deleted. `AGENTS.md` drops the note that `docs/` describes
upstream. Archived OpenSpec changes are history and are not edited.

### 10. Migration
Rename `Scripts/migrate-from-official.sh` to `Scripts/migrate-to-minicast.sh`. The source is the
official Tinycast only (`com.tinycast.app`, `~/.config/tinycast`, Keychain services
`com.tinycast.app.*` and `com.tinycast.extensions.oauth`); the destination is Minicast. The internal
"Tinycast Fork" test build is not a supported source. The settings-key filter drops keys of removed
features. Backups of existing Minicast data go to
`~/Documents/Backups/Minicast-<timestamp>/`. The old script is removed.

### 11. Repository and release
After merging: `gh repo rename minicast`, update the `origin` remote, release `minicast-v0.2.0` with
`Minicast-0.2.0.dmg`.

## Risks / Trade-offs

- [Permissions and launch at login reset] → Unavoidable with a new id; the migration summary says so.
- [Saved `tinycast://` links stop opening Minicast] → Accepted; `raycast://` covers extensions.
- [Synced `~/.config` on the other Mac] → `~/.config/minicast/` is new; enable the mirror once per Mac
  after migrating, as before.
- [Tests assert renamed strings] → Update the assertions in the same change; no new tests.

## Migration Plan

1. Build and install Minicast.app; quit Tinycast.
2. Run `./Scripts/migrate-to-minicast.sh`, authorize Keychain prompts.
3. Open Minicast, grant permissions, enable launch at login; remove Tinycast if no longer needed.
4. Repeat on the 2017 Mac. Rollback: keep using Tinycast, whose data is untouched.
