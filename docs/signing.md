# Signing

Minicast is signed with a **stable self-signed identity** called `Minicast Self-Signed`. Keeping the
_same_ identity on every build is what makes macOS remember the Accessibility permission across
rebuilds — ad-hoc signing changes every build and macOS forgets the grant. There is no Apple Developer
ID and no notarization.

You create this identity **once per build Mac**. `project.yml` signs both Debug and Release with it, and
`Scripts/build-dmg.sh` refuses to build without it.

## Create the `Minicast Self-Signed` identity (once)

Run these in a terminal. They generate a self-signed code-signing certificate and import it into the
login keychain:

```sh
# Generate a self-signed code-signing cert (10-year, codeSigning use).
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout /tmp/mc-key.pem -out /tmp/mc-cert.pem \
  -subj "/CN=Minicast Self-Signed" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

# Bundle it as a .p12 (the non-empty password keeps `security import` happy).
openssl pkcs12 -export -inkey /tmp/mc-key.pem -in /tmp/mc-cert.pem \
  -name "Minicast Self-Signed" -out /tmp/mc.p12 -passout pass:minicast

# Import into the login keychain so codesign can use it without prompting.
security import /tmp/mc.p12 -k ~/Library/Keychains/login.keychain-db \
  -P minicast -A -T /usr/bin/codesign

rm -f /tmp/mc-key.pem /tmp/mc-cert.pem /tmp/mc.p12
```

If `security import` rejects the `.p12` with a MAC verification error, the installed OpenSSL wrote a
format the keychain does not read; add `-legacy` to the `openssl pkcs12` line and run it again.

Verify it's there:

```sh
security find-identity -p codesigning | grep "Minicast Self-Signed"
```

Now local builds (Xcode, `xcodebuild`, `build-dmg.sh`) sign with it, and you grant Accessibility once.

### Losing the identity

If the identity is lost, create it again with the steps above. Its key is new, so macOS treats the next
build as a different app: grant Accessibility (and any other permission) once more, and it is stable
again from then on. The in-app updater also refuses any release signed by the new identity, because
it checks downloads against the running app's designated requirement, so install that one version by
hand.

## Hardened runtime

**Release only**, on both targets: `ENABLE_HARDENED_RUNTIME: YES`. Debug must stay without it —
hardened runtime turns on library validation, and Xcode's `Minicast Dev.debug.dylib` is refused at
launch because a self-signed identity carries no Team ID for the loader to match. The flag is not part
of the designated requirement, so turning it on costs no Accessibility grant. Each entitlement in
`Tinycast/Tinycast.entitlements` earns its place:

| Entitlement | Without it |
| --- | --- |
| `com.apple.security.cs.allow-jit` | JavaScriptCore cannot JIT, and every extension command runs on the interpreter |
| `com.apple.security.automation.apple-events` | Every Apple event is refused with `-1743` and no prompt — Get Info, the Finder selection an extension reads, and the System Events–driven system actions all die silently |
| `com.apple.security.personal-information.calendars` | The calendar request returns `false` in milliseconds with no dialog, and Minicast never appears under System Settings › Calendars |

**A usage string is not enough under the hardened runtime.** `tccd` checks the matching entitlement
*before* it prompts, and without it logs "requires entitlement … but it is missing" and denies on the
spot — no dialog, no error, status still `.notDetermined`. Adding a protected resource therefore means
adding its usage string *and* its entitlement.

`RESOURCE_ENTITLEMENTS` in `Scripts/verify-signature.sh` maps every protected resource's usage string
to its entitlement, including resources Minicast does not use. That grants nothing — only
`Tinycast.entitlements` does, and a row whose usage string `Info.plist` doesn't declare is skipped. It
is there so a future feature that adds the usage string but forgets the entitlement fails the check
instead of shipping a prompt that can never appear.

Nothing else is needed: the only `dlopen` is Apple's own IOBluetooth, so library validation is left
on, and `node`, `ray` and shell commands are separate processes it never reaches. Bluetooth has no
hardened-runtime entitlement.

`./Scripts/verify-signature.sh <path-to-.app>` asserts all of this — the runtime flag on the app *and*
on `Contents/Helpers/ClipboardTextHelper`, an intact nested seal, no `get-task-allow`, and an
entitlement for every usage string `Info.plist` declares. Run it on the Release app before packaging a
release.

## Quarantine (separate from signing)

macOS quarantines anything downloaded from the internet, and Gatekeeper blocks even a correctly
self-signed app with an "unverified developer" warning. Clear the flag once after copying a downloaded
app to `/Applications`:

```sh
xattr -dr com.apple.quarantine /Applications/Minicast.app
```
