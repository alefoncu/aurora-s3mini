#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/wheelie"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BT="$SDK/build-tools/30.0.3"
AJ="$SDK/platforms/android-25/android.jar"
JAVAC="/opt/homebrew/opt/openjdk@17/bin/javac"
mkdir -p build/classes dex
"$JAVAC" --release 8 -cp "$AJ" -d build/classes src/com/scratch/wheelie/*.java
"$BT/d8" --release --min-api 22 --lib "$AJ" --output dex build/classes/com/scratch/wheelie/*.class
"$BT/aapt2" compile --dir res -o res.zip
"$BT/aapt2" link -I "$AJ" --manifest AndroidManifest.xml --min-sdk-version 22 --target-sdk-version 25 -o base.apk res.zip
cp base.apk out.apk
(cd dex && zip -q ../out.apk classes.dex)
"$BT/zipalign" -f 4 out.apk aligned.apk
"$BT/apksigner" sign --ks "$HOME/.android/debug.keystore" --ks-pass pass:android --key-pass pass:android --out WheelieRide.apk aligned.apk
"$BT/apksigner" verify WheelieRide.apk
if [[ "${1:-}" == "--install" ]]; then
  DEVICE="${ANDROID_SERIAL:-4790069249ec5032}"
  adb -s "$DEVICE" push WheelieRide.apk /data/local/tmp/WheelieRide.apk
  adb -s "$DEVICE" shell pm install -r /data/local/tmp/WheelieRide.apk
fi
