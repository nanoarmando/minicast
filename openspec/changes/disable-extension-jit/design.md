## Context

See proposal.md for the trace and the measurement. JavaScriptCore reads `JSC_*` environment variables
once, when it initializes its options on first use in the process. Minicast's only JavaScriptCore user
is `Features/Extensions`; WebKit views run their JavaScript out of process.

## Goals / Non-Goals

**Goals:** stop the JIT arena leak with the smallest possible change.

**Non-Goals:** per-command JIT control, a helper process, context reuse (see proposal Out of scope).

## Decisions

1. **`setenv("JSC_useJIT", "false", 1)` in `TinycastApp.init()`.** It is the earliest Swift code that
   runs, before `AppDelegate` builds `AppCore` and long before the first `JSContext`.
   - Alternatives: `JSC_useConcurrentJIT=false` or higher JIT thresholds keep the JIT but are
     unproven; the user chose the measured option. A helper process with its own options is far more
     code for no measured benefit.
2. **Remove `com.apple.security.cs.allow-jit`.** Its only stated purpose is JavaScriptCore's JIT;
   keeping it would grant writable-executable memory nothing uses. JavaScriptCore runs interpreted
   without it (the same mode third-party iOS apps get).
3. **Revert to one virtual machine per run (no code change from `main`).** The earlier idea of one
   machine per extension targeted the wrong cause and is not kept.

## Risks / Trade-offs

- [A future macOS ignores `JSC_useJIT`] → Without `allow-jit` JavaScriptCore cannot JIT anyway; the
  30-minute `vmmap` check guards the release.
- [CPU-heavy extensions run slower] → Not noticeable in manual tests with the heaviest installed
  extensions; reversible by restoring the line and the entitlement.

## Migration Plan

No data or settings migration. Rollback: restore the `setenv` line and the entitlement.
