#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/Wheelie Ride.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -framework Cocoa -framework AVFoundation Sources/*.swift -o "$APP/Contents/MacOS/WheelieRide"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WheelieRide</string>
<key>CFBundleIdentifier</key><string>com.scratch.wheelieride.mac</string>
<key>CFBundleName</key><string>Wheelie Ride</string>
<key>CFBundleDisplayName</key><string>Wheelie Ride</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>6.7</string>
<key>CFBundleVersion</key><string>17</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Independent recreation. Original artwork and code.</string>
</dict></plist>
PLIST
if [[ -f Assets/AppIcon.icns ]]; then cp Assets/AppIcon.icns "$APP/Contents/Resources/"; fi
cp Assets/valley.png Assets/dunes.png "$APP/Contents/Resources/"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
if [[ "${1:-}" == "--install" ]]; then
  INSTALL="$HOME/Applications/Wheelie Ride.app"
  if pgrep -x WheelieRide >/dev/null; then
    echo 'Cierra Wheelie Ride antes de instalar la actualización.' >&2
    exit 1
  fi
  mkdir -p "$HOME/Applications" "$PWD/build/Backups"
  STAGE="$HOME/Applications/.WheelieRide-install-$(date +%Y%m%d-%H%M%S).app"
  ditto "$APP" "$STAGE"
  codesign --verify --strict "$STAGE"
  if [[ -e "$INSTALL" ]]; then
    ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALL/Contents/Info.plist")
    [[ "$ID" == "com.scratch.wheelieride.mac" ]] || { echo 'La app existente no es Wheelie Ride.' >&2; exit 1; }
    BACKUP="$PWD/build/Backups/Wheelie Ride-$(date +%Y%m%d-%H%M%S).app"
    mv "$INSTALL" "$BACKUP"
    echo "Versión anterior conservada en $BACKUP"
  fi
  mv "$STAGE" "$INSTALL"
  open "$INSTALL"
fi
