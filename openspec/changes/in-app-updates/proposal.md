## Why

Installing a new Minicast version means downloading the DMG with a browser, which quarantines it, so
macOS asks for Gatekeeper approval on every update. It is also easy to install the wrong build: the 2017
Mac kept running 0.2.0 because nothing in the app says that 0.2.1 exists. An updater inside About that
reads Minicast's own GitHub releases removes both problems.

## What Changes

- About gains an **Updates** section. Opening About checks the latest release of
  `nanoarmando/minicast` on GitHub, and a **Check for Updates** button checks again. There is no
  background or scheduled check.
- When a newer version exists, About shows the version and its release notes with an **Update**
  button. Update downloads the DMG, verifies that the new app is signed with the same certificate as the
  running app, and then asks for confirmation before quitting, replacing the app and reopening it.
- The download is made by Minicast itself, so the installed app carries no quarantine attribute and
  Gatekeeper does not ask again.
- Debug builds, and a Minicast running from a disk image or a translocated path, never offer to update.
- **BREAKING (spec):** `fork-identity`'s "No self-update" requirement is removed and replaced by the new
  `app-updates` capability. Minicast still never contacts upstream Tinycast or any other update source.

## Capabilities

### New Capabilities
- `app-updates`: checking Minicast's own GitHub releases from About, and downloading, verifying and
  installing a newer version with confirmation.

### Modified Capabilities
- `fork-identity`: the "No self-update" requirement is removed.

## Impact

- Code: a new `Tinycast/Features/Updates/` feature (Model, Service, UI) with an `UpdateCoordinator` owned
  by `AppCore`. `Windows/About/AboutView.swift` gains the Updates section. `SettingsAnchor` and
  `SettingsSearchCatalog` gain an "Updates" entry.
- System tools: `hdiutil` (mount the DMG), `codesign`/Security framework (verify), `ditto`, and a small
  detached shell step that swaps the bundle after the app quits and reopens it.
- Network: `api.github.com` and the release asset download, on a private ephemeral session.
- Docs: `AGENTS.md` (removed-features list and "no self-update" line), `README.md`, `docs/release.md`,
  `docs/signing.md`, a new `docs/features/updates.md`, `docs/architecture.md`, `docs/testing.md`.
- Out of scope: Keychain prompts after an update (they depend on the signing certificate, not on how the
  app is installed), notarization, background checks, and changing the signing identity.
