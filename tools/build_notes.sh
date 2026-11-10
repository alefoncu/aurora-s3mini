#!/bin/bash
# Builds and signs the notes app (sources in ~/ios-reskin/notes).
set -e
cd ~/ios-reskin/notes
JAVAC=/opt/homebrew/Cellar/openjdk@17/17.0.21.0.3/bin/javac
BT=~/Library/Android/sdk/build-tools/30.0.3
AJ=~/Library/Android/sdk/platforms/android-25/android.jar
rm -rf build dex res.zip base.apk out.apk aligned.apk IOSNotes.apk
mkdir -p build/classes dex
out=$($JAVAC --release 8 -cp $AJ -d build/classes src/com/scratch/iosnotes/*.java 2>&1) || { echo "$out"; echo "javac failed" >&2; exit 1; }
echo "$out" | grep -v "^Note" || true
$BT/d8 --release --min-api 22 --lib $AJ --output dex $(find build/classes -name '*.class')
$BT/aapt2 compile --dir res -o res.zip
$BT/aapt2 link -I $AJ --manifest AndroidManifest.xml --min-sdk-version 22 --target-sdk-version 22 -o base.apk res.zip
cp base.apk out.apk && (cd dex && zip -q ../out.apk classes.dex)
$BT/zipalign -f 4 out.apk aligned.apk
$BT/apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android --key-pass pass:android --out IOSNotes.apk aligned.apk
echo "APK creado: $PWD/IOSNotes.apk"
