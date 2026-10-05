## REMOVED Requirements

### Requirement: No self-update
**Reason**: Updating from a browser-downloaded DMG quarantines the app and makes it easy to install the
wrong build. Minicast now updates itself from its own GitHub releases, on request, from About.
**Migration**: See the `app-updates` capability. Minicast still never contacts upstream Tinycast or any
update source other than `github.com/nanoarmando/minicast`, and never checks in the background.
