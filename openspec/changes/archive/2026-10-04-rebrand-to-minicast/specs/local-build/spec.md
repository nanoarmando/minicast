## MODIFIED Requirements

### Requirement: Local universal release build
The repository SHALL provide a single local command that produces a signed universal release build of
"Minicast.app" and a `Minicast-<version>.dmg` targeting macOS 13.

#### Scenario: Build on the main Mac
- **WHEN** the user runs the build script on the main Mac with Xcode installed and the local signing
  identity present
- **THEN** the script produces the app and DMG, and fails with a clear message if the identity is missing
  or either architecture slice is absent

### Requirement: Stable local signing
Release builds SHALL be signed with the local self-signed code signing identity "Minicast Self-Signed",
reused for every build, so macOS keeps privacy permissions across rebuilds.

#### Scenario: Rebuild keeps Accessibility
- **WHEN** the user installs a rebuilt app signed with the same identity
- **THEN** the Accessibility permission granted to the previous build still applies

#### Scenario: Identity missing
- **WHEN** the build script runs on a Mac without "Minicast Self-Signed"
- **THEN** it stops before building and points to the signing setup instructions
