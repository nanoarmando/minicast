# Release

How a build reaches a Mac. The local development loop is in [development.md](development.md); the
signing identity itself is in [signing.md](signing.md).

Minicast has no CI, no self-update and no Homebrew cask. A release is a universal DMG built on the main
Mac and attached to a GitHub release of `nanoarmando/minicast`.

## Building the DMG

```sh
./Scripts/build-dmg.sh            # -> build/Minicast-<version>.dmg (version from project.yml)
./Scripts/build-dmg.sh 0.2.1      # -> build/Minicast-0.2.1.dmg
```

The script:

1. Stops before building if the `Minicast Self-Signed` identity is missing, pointing to
   [signing.md](signing.md).
2. Builds the Release configuration of the `Tinycast` scheme (the internal name) into
   `build/DerivedData`, signed with that identity and passing `-skipMacroValidation` for
   swift-perception's macro.
3. Checks that `Minicast.app`'s executable and the embedded `ClipboardTextHelper` both carry the
   `arm64` and `x86_64` slices and a minimum macOS of exactly 13.0. A thin helper inside a universal app
   is the quiet form of this bug: the app boots on Intel and only clipboard OCR stops working.
4. Packs the app with an `/Applications` symlink into `build/Minicast-<version>.dmg`.

`./Scripts/verify-signature.sh build/DerivedData/Build/Products/Release/Minicast.app` checks the
signature, the hardened runtime and the entitlement each usage string needs before macOS shows its
permission prompt.

## Gatekeeper

The app is signed with a self-signed identity, not an Apple Developer ID, so macOS quarantines a DMG
that was downloaded. After copying the app to `/Applications`, clear the flag once:

```sh
xattr -dr com.apple.quarantine /Applications/Minicast.app
```

A copy made over the local network or from a USB drive is not quarantined. Details in
[signing.md](signing.md).

## Installing on the second Mac

The same DMG runs on the Intel Mac on macOS 13. Copy the app, clear the quarantine flag if needed, then
run the migration on that Mac too (see the README). Because both Macs run the same signed build, a later
rebuild signed with the same identity keeps the Accessibility grant on each.

Once a Mac runs a version with the updater (0.3.0 or later), later versions install from **About**
instead: Minicast downloads the DMG itself, so nothing is quarantined. See
[updates.md](features/updates.md).

## Publishing a release

1. Set `MARKETING_VERSION` in `project.yml` (and bump `CURRENT_PROJECT_VERSION`), regenerate with
   `./.tools/xcodegen/bin/xcodegen generate`, and commit both.
2. Run the whole bar in [testing.md](testing.md#definition-of-done), then `./Scripts/build-dmg.sh`.
3. Tag and publish with the GitHub CLI. The updater reads only this tag and asset naming
   (`minicast-v<version>`, `Minicast-<version>.dmg`), so keep both exactly:
   ```sh
   gh release create minicast-v<version> build/Minicast-<version>.dmg \
       --repo nanoarmando/minicast --title "Minicast <version>" --generate-notes
   ```

The palette's **Changelog** command opens `github.com/nanoarmando/minicast/commits/main`, so the commit
history is the changelog; nothing else needs updating in the app.

`Scripts/release-notes.sh` is upstream's CI release-notes composer. Minicast does not use it.
