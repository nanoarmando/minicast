## 1. Revert the earlier attempt

- [x] 1.1 Restore `ExtensionRuntime.swift`, `ExtensionManager.swift`, `ExtensionMenuBarManager.swift`, `project.pbxproj` and `docs/features/extensions.md` to `main`, and delete `ExtensionVirtualMachines.swift`

## 2. Disable the JIT

- [x] 2.1 Set `JSC_useJIT=false` with `setenv` in `TinycastApp.init()`, with a one-line why comment
- [x] 2.2 Remove `com.apple.security.cs.allow-jit` and its comment from `Tinycast/Tinycast.entitlements`

## 3. Validation

- [x] 3.1 `./Scripts/run-tests.sh`, Debug build, universal Release build (`./Scripts/build-dmg.sh`) and lint with no new warnings
- [ ] 3.2 Install the Release build; with `apple-reminders` and `coffee` refreshing every minute, `vmmap` shows no growing untagged 512 KB regions after 30 minutes
- [x] 3.3 Open Iconify, GIF Search and Kill Process and confirm they work without a noticeable slowdown

## 4. Documentation

- [x] 4.1 Add an invariant to `docs/features/extensions.md` (JIT off and why, never re-add `allow-jit` without fixing the leak) and update the entitlement mention in "Why JavaScriptCore" if present
