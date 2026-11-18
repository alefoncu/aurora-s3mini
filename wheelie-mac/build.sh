#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/Wheelie Ride.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Absolute source paths and a module name: the App Intents metadata processor matches the compiler's constant values by path.
SOURCES=("$PWD"/Sources/*.swift)
INTENTS="$PWD/build/intents"
mkdir -p "$INTENTS"
echo '["AppIntent","EntityQuery","AppEntity","TransientEntity","AppEnum","AppShortcutProviding","AppShortcutsProvider","AnyResolverProviding","AppIntentsPackage","DynamicOptionsProvider","_IntentValueRepresentable","_AssistantIntentsProvider"]' > "$INTENTS/gather.json"
xcrun swiftc -O -wmo -module-name WheelieRide -target "$(uname -m)-apple-macos13.0" -framework Cocoa -framework AVFoundation -framework GameController -framework CoreHaptics -framework CoreSpotlight -framework AppIntents "${SOURCES[@]}" \
  -emit-const-values -Xfrontend -const-gather-protocols-file -Xfrontend "$INTENTS/gather.json" -Xfrontend -emit-const-values-path -Xfrontend "$INTENTS/WheelieRide.swiftconstvalues" \
  -o "$APP/Contents/MacOS/WheelieRide"
# The driver also drops the constant values next to the binary; they must not ship inside the signed bundle.
rm -f "$APP/Contents/MacOS/WheelieRide.swiftconstvalues"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WheelieRide</string>
<key>CFBundleIdentifier</key><string>com.scratch.wheelieride.mac</string>
<key>CFBundleName</key><string>Wheelie Ride</string>
<key>CFBundleDisplayName</key><string>Wheelie Ride</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>6.36</string>
<key>CFBundleVersion</key><string>35</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>com.scratch.wheelieride.link</string><key>CFBundleURLSchemes</key><array><string>wheelieride</string></array></dict></array>
<key>NSHumanReadableCopyright</key><string>Independent recreation. Original artwork and code.</string>
</dict></plist>
PLIST
if [[ -f Assets/AppIcon.icns ]]; then cp Assets/AppIcon.icns "$APP/Contents/Resources/"; fi
cp Assets/valley.png Assets/dunes.png "$APP/Contents/Resources/"
# App Intents (Atajos, Spotlight, Siri). If the processor fails the app still installs, just without them.
printf '%s\n' "${SOURCES[@]}" > "$INTENTS/sources.txt"; echo "$INTENTS/WheelieRide.swiftconstvalues" > "$INTENTS/consts.txt"; : > "$INTENTS/empty.txt"
if xcrun appintentsmetadataprocessor --output "$INTENTS/out.appintents" --toolchain-dir "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain" --module-name WheelieRide \
    --sdk-root "$(xcrun --sdk macosx --show-sdk-path)" --xcode-version "$(xcodebuild -version | awk '/Build version/{print $3}')" --platform-family macOS --deployment-target 13.0 \
    --target-triple "$(uname -m)-apple-macos13.0" --source-file-list "$INTENTS/sources.txt" --swift-const-vals-list "$INTENTS/consts.txt" \
    --metadata-file-list "$INTENTS/empty.txt" --static-metadata-file-list "$INTENTS/empty.txt" --no-app-shortcuts-localization >/dev/null 2>&1 && [[ -d "$INTENTS/out.appintents/Metadata.appintents" ]]; then
  ditto "$INTENTS/out.appintents/Metadata.appintents" "$APP/Contents/Resources/Metadata.appintents"
else
  echo 'Aviso: no se pudieron generar los metadatos de App Intents; la app se instala sin Atajos.' >&2
fi
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
