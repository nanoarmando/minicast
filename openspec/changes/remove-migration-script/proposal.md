## Why

The full backup bundle now carries a complete Minicast setup between Macs, and the official Tinycast's
`.tinycast` backup, a Raycast export and the `settings.json` mirror cover every other way in. The
one-time `Scripts/migrate-to-minicast.sh` duplicates those paths, copies Keychain secrets with a prompt
per item, and is one more thing to keep in step with every storage change.

## What Changes

- **BREAKING:** `Scripts/migrate-to-minicast.sh` is deleted. There is no command that copies the
  official Tinycast's data folders or Keychain items into Minicast.
- The supported ways to bring an existing setup into Minicast are stated as a requirement: a Minicast
  bundle, a `.tinycast` backup, a Raycast export, and the `~/.config/minicast/settings.json` file.
- README's "Migrating from Tinycast" section becomes "Moving from Tinycast or Raycast", built on those
  imports. `AGENTS.md`, `docs/architecture.md` and `docs/release.md` drop their references to the script.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `fork-identity`: removes "One-time migration into Minicast", adds "Bringing an existing setup", and
  drops the migration wording from "Isolated persisted data".
- `feature-availability`: "Persisted references to removed features" covers imported data instead of
  migrated data.

## Impact

- Files: `Scripts/migrate-to-minicast.sh` (deleted), `README.md`, `AGENTS.md`, `docs/architecture.md`,
  `docs/release.md`.
- No app code changes: the bundle, `.tinycast`, Raycast and settings-file imports already exist.
- Users who relied on the script now export a backup from Tinycast and import it. A `.tinycast` backup
  does not carry AI keys, MCP servers or extensions, which must be set again by hand.
