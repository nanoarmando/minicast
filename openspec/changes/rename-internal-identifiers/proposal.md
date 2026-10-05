## Why

After `rebrand-to-minicast`, the app is Minicast to the user, but the code still uses Tinycast names
internally. Renaming them keeps the codebase consistent with the product. It is deferred because it is a
large mechanical diff with no user-visible effect and makes cherry-picking from upstream harder.

## What Changes

- Rename the source folder `Tinycast/`, `Tinycast.xcodeproj`, the target, scheme and module to Minicast.
- Rename product-named types and files (`TinycastApp`, `Tinycast.entitlements`, `tinycast.icon`,
  `*TinycastPasteboardMutation`, `runsInTinycast`, `UTType.tinycastBackup`, symbol category ids).
- Rename the build variable `TINYCAST_BUNDLE_IDENTIFIER`, logging subsystems, signpost subsystem,
  dispatch queue labels and the internal pasteboard type.
- Rename the extension runtime bridge globals (`__tinycast*`) and form props (`onTinycast*`) and
  regenerate the runtime.
- Rename temp-file and MCP server name prefixes, keeping cleanup of old `tinycast-` leftovers.
- Update every script, lint config and test path (`run-tests.sh`, `.swiftlint.yml`, `format.sh`).
- Optionally rename the signing identity "Tinycast Self-Signed" (requires a new certificate per Mac).

No behavior changes; specs are not modified.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

About 700 lines across scripts, project configuration and sources; generated project and runtime;
`AGENTS.md`, `README.md`. Status: deferred until the user asks to continue.
