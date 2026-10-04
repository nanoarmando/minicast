## Why

Upstream Tinycast requires macOS 26, so it cannot run on an Intel MacBook Pro (2017) whose last supported
system is macOS 13 Ventura. This private fork must run on that machine and also replace the official app on
the main Mac (Apple Silicon, macOS 27), with its own isolated configuration so the official app can be
reinstalled at any time without conflicts.

## What Changes

- Lower the minimum system to macOS 13.0 and build a universal binary (arm64 + x86_64) for the app and the
  `ClipboardTextHelper`.
- Replace the Observation framework (macOS 14+) with the swift-perception back-port. On macOS 14+ it delegates
  to native Observation, so behavior on the main Mac is unchanged.
- Replace every other API unavailable on macOS 13 (keyboard handling, scroll geometry, `onChange` variants,
  `Mutex`, app activation, EventKit access, pointer styles, and others) with macOS 13 equivalents.
- **BREAKING (visual)**: replace Liquid Glass with classic macOS blur materials on every macOS version. Scroll
  fades and the thin scrollbar are simplified where no macOS 13 equivalent exists (functional-first fidelity).
- **BREAKING**: remove the Apple Intelligence AI provider (FoundationModels) and the Translate quick action
  (Translation framework).
- **BREAKING**: remove features the user does not need, to shrink the port and the code to maintain:
  Dictation (including the `DictationHelper` target), Notes, Quicklinks, Camera preview, Snippets, Support
  reminder, Onboarding, and Navigation (window switcher and menu bar search). Window management is kept
  intact.
- Give the fork its own identity: bundle id `com.tinycast.app.fork`, app name "Tinycast Fork". All
  preferences, data, settings file and Keychain items are isolated from the official app, including the
  extension OAuth Keychain service that upstream hard-codes.
- **BREAKING**: disable the self-update mechanism and hide "Check for Updates…".
- Sign builds with a local self-signed identity and add a local script that produces the universal build.
- Remove upstream GitHub Actions workflows that depend on the upstream author's secrets and services.
- Add a one-time migration script that copies everything from the official app that does not depend on the
  code signature (preferences, data, caches, settings file, Keychain secrets) into the fork.
- Keep the existing test harness suite (`Scripts/run-tests.sh`) passing; no new tests are added.
- Update `README.md` and `AGENTS.md` to describe the fork and override upstream's "latest macOS only" posture.

## Capabilities

### New Capabilities

- `platform-compatibility`: minimum supported macOS, supported architectures, and consistent behavior and
  appearance across macOS 13 and newer systems.
- `fork-identity`: app identity, isolation of all persisted data from the official app, one-time migration
  from the official app, and disabled self-update.
- `feature-availability`: features removed from the fork and how previously persisted references to them
  are handled.
- `local-build`: how the fork is built, signed, and validated locally.

### Modified Capabilities

None. The repository has no existing OpenSpec specs.

## Impact

- **Code**: about 75 `@Observable` types and their consumers (about 190 environment readers, 36 `@Bindable`,
  7 `withObservationTracking` sites), about 120 `onChange` sites, 19 `onKeyPress` sites, scroll and geometry
  modifiers, glass effects, AI provider and quick action code, `ReleaseChannel`/updater, `AppPaths`,
  `ExtensionOAuthKeychain`, `Permissions` (EventKit).
- **Project**: `project.yml` (regenerated with XcodeGen into `Tinycast.xcodeproj`), `Info.plist` (legacy
  calendar and reminders usage keys), new Swift Package dependency `pointfreeco/swift-perception`.
- **Scripts and CI**: new `Scripts/migrate-from-official.sh`, `Scripts/build-dmg.sh`, `Scripts/run-tests.sh`, `Scripts/verify-signature.sh`;
  `.github/workflows/*` removed.
- **Tooling prerequisites**: full Xcode on the main Mac and XcodeGen (`brew install xcodegen`).
- **Data**: the app itself carries no migration code. The optional `Scripts/migrate-from-official.sh` copies
  the official app's data into the fork once; privacy permissions and the login item are granted again by
  hand. The official app's data is never modified (a manual copy also exists outside the repository).
- **Upstream**: upstream changes are not merged after this port.
