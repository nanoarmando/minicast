## Context

See proposal.md for motivation. About is a Settings pane (`Windows/About/AboutView.swift`, a grouped
`Form`) opened through `SettingsCoordinator.showAbout()`. Releases are published with
`gh release create minicast-v<version> build/Minicast-<version>.dmg` (`docs/release.md`). The DMG root
holds `Minicast.app` and an `Applications` symlink. Builds are signed with the self-signed identity
"Minicast Self-Signed"; the designated requirement is
`identifier "com.minicast.app" and certificate leaf = H"<hash>"`, which is stable across builds made
with that identity. The app is not sandboxed and Release uses the hardened runtime.

There is no precedent in the code for self-relaunch, DMG mounting or runtime signature checks. The
reusable pieces are the private ephemeral session (`CurrencyRateStore`, `ExtensionStoreClient.get` for
GitHub headers and error bodies), `ToolRunner`, `AppPaths.caches()`, and `AppCore`'s dialogs and
progress HUD.

## Goals / Non-Goals

**Goals:**
- One manual check path with no background traffic, and an install that cannot leave Minicast broken.

**Non-Goals:**
- Delta updates, rollback to an older version, prereleases, notarization, Keychain prompts.

## Decisions

### D1. Feature layout
`Tinycast/Features/Updates/`:
- `Model/` (Foundation only, harness-tested): `AppVersion` (parse `major.minor.patch`, numeric compare),
  `UpdateRelease` (decode the GitHub release JSON, pick the tag and the asset by the spec's naming
  rule), and `UpdateEligibility` (bundle id and path facts in, offer/refuse reason out).
- `Service/`: `UpdateClient` (GitHub fetch and streamed download), `UpdateInstaller` (mount, verify,
  stage, swap script).
- `UI/`: `UpdateCoordinator` (`@Perceptible`, owned by `AppCore`, injected through `@Environment`) and
  `AboutUpdatesSection`, which `AboutView` places between the hero and Links.

### D2. Network
`GET https://api.github.com/repos/nanoarmando/minicast/releases/latest` on a private `.ephemeral`
session with `urlCache = nil`, `User-Agent: Minicast` and `Accept: application/vnd.github+json`, copied
from the `ExtensionStoreClient` shape rather than shared, since that client belongs to Extensions. A 403
or 429 surfaces GitHub's `message`. The DMG is fetched with `session.download(for:)` and moved into
`AppPaths.caches()/updates/`. `URLSession` downloads carry no `com.apple.quarantine` attribute.

### D3. Verification
`hdiutil attach -nobrowse -readonly -noautoopen -mountrandom <tmp> -plist` through `ToolRunner`. The
running app's requirement comes from `SecCodeCopySelf` and `SecCodeCopyDesignatedRequirement`. The
mounted `Minicast.app` is checked with `SecStaticCodeCreateWithPath` and `SecStaticCodeCheckValidity`
using `kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode` and that requirement.
Its `CFBundleShortVersionString` must equal the release version. The verified app is then copied with
`ditto --noextattr --noqtn` into `caches/updates/staged/Minicast.app`, the DMG is detached and deleted,
and the staged copy is verified once more, so the swap never reads from a mounted volume.
- *Alternative:* `/usr/bin/codesign --verify -R`. It works the same way but needs requirement-string
  escaping. Security framework calls keep it in-process.

### D4. Swap after quit
Before terminating, Minicast launches `/bin/sh` with a script built from fixed text and quoted paths
(the PID, the staged app, the target app). The script:
1. waits for the PID to exit;
2. renames the installed app to a sibling `.Minicast-previous.app`;
3. moves the staged app into place;
4. on failure, renames the previous app back;
5. clears any `com.apple.quarantine` attribute;
6. runs `open` on the result and deletes the previous copy only after a successful move.
A `Process` child is reparented to launchd when Minicast exits, so it outlives it. Minicast then calls
`NSApp.terminate(nil)`, so `prepareForTermination` (settings flush, Hyper Key restore, child processes)
runs as on any quit.
- *Alternative:* a bundled helper executable. More to sign and build for a 20-line job.

### D5. Eligibility
`UpdateEligibility` refuses when the bundle id is not `com.minicast.app`, when the bundle path is under
`/Volumes/` or contains `/AppTranslocation/`, or when the parent folder is not writable. The section
shows the reason instead of the button.

### D6. Release notes
The release `body` is shown as Markdown through `AttributedString(markdown:)` in a scrollable,
height-limited area, with a "View on GitHub" link to `html_url`.

## Risks / Trade-offs

- [Release built with a different identity, for example after losing the certificate] → The
  verification refuses it, as intended. The documented recovery is a one-time manual install.
- [Termination is cancelled, for example by an open dialog] → The script waits for the PID with no
  time limit, so it only acts once Minicast actually quits.
- [Swap leaves no app if the machine powers off mid-move] → Renames on the same volume are atomic, and
  the previous copy is deleted only after the new one is in place.
- [GitHub anonymous limit of 60 requests per hour] → Only manual checks, so the limit is unreachable in
  practice. The error is reported if it happens.
- [Keychain asks again after every update] → Accepted and out of scope. It depends on the signing
  certificate.

## Migration Plan

No data migration. The first version with the updater must still be installed by hand. Every later
version can be installed from About. Releases must keep the `minicast-v<version>` tag and the
`Minicast-<version>.dmg` asset name, already required by `docs/release.md`.
