# Updates

The **Updates** section of About checks Minicast's own GitHub releases and installs a newer version on
request. Source: `Features/Updates/` (`Model/`, `Service/`, `UI/`), with the section placed by
`Windows/About/AboutView.swift`.

## Invariants

- **One source, never in the background.** `UpdateClient` asks only for
  `api.github.com/repos/nanoarmando/minicast/releases/latest` and that release's DMG. A check runs
  when About opens and when **Check for Updates** is pressed, never at launch or on a timer, and there
  is no preference for it. The only launch-time work is `reportFailedSwap()`, which reads a local file.
- **A private `.ephemeral` session with `urlCache = nil`**, as for every networked feature. The
  download is written by Minicast itself, so it carries no quarantine attribute.
- **Releases are recognised by name only:** tag `minicast-v<major>.<minor>.<patch>` and asset
  `Minicast-<major>.<minor>.<patch>.dmg` (`UpdateRelease`). Versions compare numerically
  (`AppVersion`), so 0.2.10 is newer than 0.2.9. `docs/release.md` publishes exactly these names.
- **Nothing is installed unless it is signed like the running copy.** `UpdateInstaller` checks the
  mounted app against the running app's designated requirement (same bundle id, same certificate)
  and against the announced version, copies it with `ditto --noextattr --noqtn` into
  `caches/updates/staged/`, detaches and deletes the DMG, and checks the staged copy again. Every
  failure deletes the download and leaves the installed app untouched.
- **The swap happens after Minicast quits.** After the user confirms, a `/bin/sh` script built from
  fixed text and single-quoted paths waits for the PID, moves the installed app aside, moves the
  staged one in, restores the previous app if that fails, clears quarantine and opens the result.
  Minicast then quits through `NSApp.terminate(nil)`, so normal termination runs. A failed swap
  leaves `caches/updates/failure.txt`, which the restored app shows once on launch.
- **Where updating is refused** (`UpdateEligibility`): any bundle id other than `com.minicast.app`
  (so Minicast Dev never checks), a bundle under `/Volumes/` or `/AppTranslocation/`, or a parent
  folder that is not writable. The section says why instead of offering the button.
- **`Model/` stays Foundation-only**; `updates-test` compiles it.

## States

`UpdateCoordinator.State`: `unavailable(reason)`, `checking`, `upToDate`, `available(update)` with the
release notes, a **View on GitHub** link and **Update**, `downloading(update)` with a cancellable
progress HUD, and `failed(message)` with GitHub's message when it sends one. A cancelled download or
a declined confirmation deletes the download and returns to `available`.

## Limits

- A release signed by a different identity (for example after the signing certificate is lost) is
  refused; install that version by hand once. See [signing.md](../signing.md).
- Keychain may ask again after an update; that depends on the certificate, not on the updater.
- No prereleases, no delta updates, no rollback.
