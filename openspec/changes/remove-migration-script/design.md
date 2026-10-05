## Context

See proposal.md for motivation. `Scripts/migrate-to-minicast.sh` is a standalone shell script, outside
the app. No Swift code, harness or build step calls it. The in-app paths it overlaps with already exist:
the Import & Export window (`.minicast` and `.tinycast`), Settings → Backup → Import from Raycast, and the
settings-file switch.

## Goals / Non-Goals

**Goals:**
- Remove the script and every pointer to it, and state the supported import paths once.

**Non-Goals:**
- A new import for the official Tinycast's raw data folders or its `~/.config/tinycast/settings.json`.
- Carrying Keychain secrets from the official app.

## Decisions

### D1. Delete instead of deprecate
The script is deleted outright, with no stub that prints a notice. It is not installed anywhere and has
no callers, so a deprecation period would protect nothing.

### D2. The README section describes the in-app paths
"Moving from Tinycast or Raycast" explains the order: export a backup from Tinycast and import it,
optionally import a Raycast export, then enter AI keys, add MCP servers and install extensions by hand,
since a `.tinycast` backup does not carry them.

## Risks / Trade-offs

- [A Tinycast user loses the one path that copied extensions, AI keys and MCP servers] → Accepted. The
  README lists what must be set again. Between Minicast installs, the bundle carries all of it except
  Keychain secrets.
