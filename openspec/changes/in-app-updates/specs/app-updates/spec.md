## Purpose

Lets Minicast find, download and install a newer version of itself from its own GitHub releases, from
the About pane, so an update needs no browser download and no Gatekeeper approval.

## ADDED Requirements

### Requirement: Update source
Minicast SHALL look for updates only in the GitHub releases of `nanoarmando/minicast`, using the latest
published release (drafts and prereleases excluded). A release SHALL count as a Minicast version only
when its tag is `minicast-v<major>.<minor>.<patch>` and it has an asset named
`Minicast-<major>.<minor>.<patch>.dmg`. Versions SHALL be compared numerically by major, minor and patch
against the running app's marketing version.

#### Scenario: Newer release
- **WHEN** the running version is 0.2.1 and the latest release is tagged `minicast-v0.2.10` with
  `Minicast-0.2.10.dmg` attached
- **THEN** 0.2.10 is reported as available

#### Scenario: Same or older release
- **WHEN** the latest release is the running version or older
- **THEN** About reports that Minicast is up to date

#### Scenario: Release without a usable asset
- **WHEN** the latest release has a malformed tag or no matching DMG asset
- **THEN** no update is offered, and About says the latest release could not be used

#### Scenario: No other source
- **WHEN** Minicast checks for updates
- **THEN** it contacts only `api.github.com` and the release asset download for `nanoarmando/minicast`,
  never upstream Tinycast or any other update source

### Requirement: When a check happens
Minicast SHALL check for updates when the About pane opens and when the user presses **Check for
Updates** in it. It SHALL NOT check at launch, on a schedule, or in the background, and it SHALL NOT
add an update preference.

#### Scenario: Opening About
- **WHEN** the user opens About
- **THEN** a check starts and the Updates section shows it is checking, then the result

#### Scenario: Never in the background
- **WHEN** Minicast runs for days without About being opened
- **THEN** it makes no update request

#### Scenario: Offline or rate-limited
- **WHEN** the check fails because there is no network, GitHub answers with an error, or the request
  rate limit is reached
- **THEN** About shows that the check failed with GitHub's message when there is one, and **Check for
  Updates** stays available

### Requirement: Showing an available update
When a newer version is available, the Updates section SHALL show the new version number, the release
notes text of that release, a link to the release page and an **Update** button.

#### Scenario: Update available
- **WHEN** a check finds 0.2.2
- **THEN** About shows "0.2.2 available", the release notes and an **Update** button

### Requirement: Download and verification
Pressing **Update** SHALL download the DMG into Minicast's caches with visible progress and a way to
cancel. Minicast SHALL then mount it read-only and refuse to install unless the contained
`Minicast.app` has a valid signature that satisfies the running app's designated requirement (same
bundle identifier and same signing certificate) and declares the version the release announced. Every
failure SHALL leave the installed app untouched, unmount the DMG and delete the download.

#### Scenario: Valid update
- **WHEN** the downloaded app is signed with the same certificate and declares version 0.2.2
- **THEN** Minicast asks for confirmation to quit, install and reopen

#### Scenario: Different signature
- **WHEN** the downloaded app is unsigned, tampered with, or signed with another certificate
- **THEN** the update is refused with a message saying the download is not signed like this copy of
  Minicast, and nothing is installed

#### Scenario: Cancelled download
- **WHEN** the user cancels during the download
- **THEN** the partial file is deleted and About returns to showing the available update

### Requirement: Installing with confirmation
After verification, Minicast SHALL ask for confirmation before quitting. On confirmation it SHALL quit
through its normal termination path, replace its own app bundle with the verified one without a
quarantine attribute, and reopen the new version. If the replacement fails, the previous app SHALL be
restored and reopened.

#### Scenario: Confirmed install
- **WHEN** the user confirms
- **THEN** Minicast quits, the new version replaces it at the same location, and the new version opens
  with the same settings, data and permissions

#### Scenario: Install postponed
- **WHEN** the user declines the confirmation
- **THEN** nothing is installed, the download is deleted, and About keeps offering the update

#### Scenario: No Gatekeeper prompt
- **WHEN** the updated Minicast opens
- **THEN** macOS does not show the quarantine or "unidentified developer" dialog for it

#### Scenario: Replacement fails
- **WHEN** the bundle cannot be replaced, for example because the folder is not writable
- **THEN** the previous Minicast is left in place and reopened, and it reports why the update failed

### Requirement: Where updates are offered
Minicast SHALL offer updates only in the Release channel (`com.minicast.app`) and only when it runs
from a writable location that is not a mounted disk image or a translocated path. Otherwise the Updates
section SHALL explain why updating is unavailable.

#### Scenario: Debug build
- **WHEN** Minicast Dev (`com.minicast.app.dev`) opens About
- **THEN** no check is made and the section says updates are only available in the release build

#### Scenario: Running from the disk image
- **WHEN** Minicast runs from the mounted DMG or from a translocated path
- **THEN** no update is offered and the section asks the user to move Minicast to Applications first
