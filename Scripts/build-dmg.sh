#!/bin/bash
# Build a signed universal "Minicast.app" into build/Minicast-<version>.dmg.
# Usage: ./Scripts/build-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IDENTITY="Minicast Self-Signed"
DERIVED="build/DerivedData"
APP_NAME="Minicast"
MINIMUM_MACOS="13.0"

if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
    echo "✗ '$IDENTITY' code-signing identity not found — create it once (docs/signing.md)." >&2
    exit 1
fi

echo "▸ Building signed $APP_NAME.app (Release, universal)…"
# The Perception macro is a package plugin, which xcodebuild refuses to run unless told to trust it.
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -skipMacroValidation \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
    ${1:+MARKETING_VERSION="$1"} \
    build

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
for BIN in "$APP/Contents/MacOS/$APP_NAME" "$APP/Contents/Helpers/ClipboardTextHelper"; do
    ARCHS="$(lipo -archs "$BIN")"
    if [[ " $ARCHS " != *" x86_64 "* || " $ARCHS " != *" arm64 "* ]]; then
        echo "✗ ${BIN##*/} is not universal (archs: $ARCHS)" >&2
        exit 1
    fi
    MINOS="$(vtool -show-build "$BIN" | awk '$1 == "minos" { print $2 }' | sort -u)"
    if [ "$MINOS" != "$MINIMUM_MACOS" ]; then
        echo "✗ ${BIN##*/} minimum macOS is '${MINOS//$'\n'/, }', expected $MINIMUM_MACOS" >&2
        exit 1
    fi
    echo "  ${BIN##*/}: $ARCHS, minos $MINOS"
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Minicast-${VERSION}.dmg"

echo "▸ Packaging ${DMG}"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
diskutil image create from "$STAGE" --format UDZO --volumeName "$APP_NAME" "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ $DMG"
