#!/bin/zsh
# Builds the app and packs it into build/WheelieRide-<version>.dmg.
#
# Signing: by default the app is ad-hoc signed (right-click > Open on other Macs).
# For distribution without that warning, export a Developer ID identity and,
# optionally, a notarytool keychain profile:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="my-notary-profile" ./package.sh
set -euo pipefail
cd "${0:A:h}"
./build.sh
APP="$PWD/build/Wheelie Ride.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
fi
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Wheelie Ride.app"
ln -s /Applications "$STAGE/Applications"
DMG="$PWD/build/WheelieRide-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Wheelie Ride $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi
echo "Creado $DMG"
