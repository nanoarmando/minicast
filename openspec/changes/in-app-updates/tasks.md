## 1. Model

- [x] 1.1 Add `AppVersion` parsing and numeric comparison in `Features/Updates/Model/`
- [x] 1.2 Add `UpdateRelease` decoding of the GitHub release JSON with tag and asset selection
- [x] 1.3 Add `UpdateEligibility` (Release channel, not `/Volumes/`, not translocated, writable parent)
- [x] 1.4 Add an `updates-test` harness for the three model files and register it in `run-tests.sh`

## 2. Service

- [x] 2.1 Add `UpdateClient`: latest-release fetch and streamed DMG download on a private ephemeral
  session, with GitHub error messages and cancellation
- [x] 2.2 Add `UpdateInstaller`: mount read-only, verify against the running app's designated
  requirement and the announced version, stage with `ditto`, detach, re-verify, clean up on every path
- [x] 2.3 Add the post-quit swap script launch (wait for PID, rename aside, move, restore on failure,
  clear quarantine, reopen)

## 3. UI

- [x] 3.1 Add `UpdateCoordinator` on `AppCore`, injected through `@Environment`, with states: unavailable
  (reason), checking, up to date, available, downloading, failed
- [x] 3.2 Add the Updates section to `AboutView` with Check for Updates, release notes, View on GitHub
  and Update, plus the `aboutUpdates` anchor and search catalog entry
- [x] 3.3 Wire download progress and cancel through the progress HUD and the install confirmation
  through `AppCore.confirm`

## 4. Docs and verification

- [x] 4.1 Add `docs/features/updates.md` with invariants; update `AGENTS.md`, `README.md`,
  `docs/release.md`, `docs/signing.md`, `docs/architecture.md` and `docs/testing.md`
- [ ] 4.2 Run the Definition of Done, then publish a test release and update an installed older version
  from About
