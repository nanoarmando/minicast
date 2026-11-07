## Why

Minicast's memory grows without limit while Raycast extensions refresh in the background or in the
menu bar. Every run evaluates the Raycast runtime in a fresh JavaScript context, and JavaScriptCore's
JIT compiler threads allocate 512 KB arena granules (`WTF::SequesteredArenaAllocator`) that are never
returned. With four commands refreshing every minute, a 7-day-old Release process held about 23,600
such regions, a 982 MB footprint, far over the 100 MB budget in `docs/standards.md`.

`malloc_history` traced 15 of 16 new regions to `JSC::JITWorklistThread` → `BaselineJITPlan` →
`SequesteredArenaAllocator::addGranule` → `mmap`. Relaunching the same build with `JSC_useJIT=false`
produced zero new regions over 7 minutes with a stable 50-55 MB footprint, and the heaviest installed
extensions (Iconify, GIF Search, Kill Process) showed no noticeable slowdown.

## What Changes

- Minicast turns off JavaScriptCore's JIT for its own process at launch, before any JavaScript runs.
  Extensions run in JavaScriptCore's interpreter.
- The `com.apple.security.cs.allow-jit` entitlement, which exists only so JavaScriptCore can JIT, is
  removed, so the hardened runtime no longer allows writable-executable memory.
- No change to how extensions are loaded, isolated, scheduled or rendered: each run still gets a
  fresh context in its own virtual machine, as today.
- Out of scope: keeping the JIT for interactive commands (JavaScriptCore options are process-wide),
  running extensions in a helper process, reusing contexts, and changing refresh intervals.

## Capabilities

### New Capabilities
- `extension-runtime-memory`: memory stays bounded across repeated extension runs.

### Modified Capabilities
None.

## Impact

- Code: `Tinycast/App/TinycastApp.swift` (set the option at launch), `Tinycast/Tinycast.entitlements`.
- Docs: `docs/features/extensions.md` (invariant and the "Why JavaScriptCore" notes).
- Performance: JavaScript runs interpreted; no noticeable difference in manual tests.
- No data, settings, permission prompt or user interface changes.
