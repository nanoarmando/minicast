## 1. Identity

- [x] 1.1 Update `project.yml` (bundle id prefix, ids, product names, version 0.2.0) and regenerate the Xcode project
- [x] 1.2 Update `AppPaths` stable id and folder base, the id fallbacks, `AppDisplayName` fallback, `CommandID` names and the `AppIndex` self-filter; update `settings-file-test` expectations
- [x] 1.3 Switch the URL scheme to `minicast` in `Info.plist`, `ExtensionOAuthSession`, `ExtensionDeepLink` and placeholder entry URLs; update `ext-test`
- [x] 1.4 Export `com.minicast.backup` (`.minicast`) and import the old `.tinycast` type; default export name "Minicast"

## 2. Text

- [x] 2.1 Rename user-visible strings and `Info.plist` usage descriptions and copyright, keeping upstream credit in About
- [x] 2.2 Rename third-party-visible strings (AI preamble, Codex prompt, MCP client info, user agents, CLI titles) and add `MINICAST=1`; update the asserting tests
- [x] 2.3 Rename runtime messages in `Scripts/raycast-runtime/src` and regenerate `RaycastRuntime.generated.js`

## 3. Brand assets

- [x] 3.1 Replace the app icon layer with the M monogram and the menu bar icon with an M template; confirm an icon is embedded for macOS 13
- [x] 3.2 Rework About: statement, Minicast repository link, Tinycast credit; point Changelog to `nanoarmando/minicast`

## 4. Scripts and docs

- [x] 4.1 Update `build-dmg.sh` and `project.yml` for "Minicast", `Minicast-<version>.dmg` and "Minicast Self-Signed"
- [x] 4.2 Replace the migration script with `migrate-to-minicast.sh` (`--from fork|official`)
- [x] 4.3 Rewrite `README.md`, `AGENTS.md` and all of `docs/` for Minicast, including the new signing setup
- [x] 4.4 Create "Minicast Self-Signed" on the main Mac following `docs/signing.md` (user)

## 5. Verification and release

- [x] 5.1 `./Scripts/run-tests.sh` passes; Debug and universal Release builds have no errors or new warnings
- [ ] 5.2 On the main Mac: migrate from Tinycast Fork, check AI keys, extensions, settings file, icons, About, palette names and an extension OAuth or deep link
- [ ] 5.3 On the 2017 Mac: install, migrate, check the icon on macOS 13
- [x] 5.4 Commit, merge, rename the GitHub repository, update the remote and publish `minicast-v0.2.0`
