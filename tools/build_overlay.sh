#!/bin/bash
# usage: build_overlay.sh <name> <targetPackage> <dir with res/>  -> out/<name>Overlay.apk
set -e
[ -f ~/ios-reskin/work/framework-res.apk ] || { echo "missing work/framework-res.apk: run  adb pull /system/framework/framework-res.apk ~/ios-reskin/work/" >&2; exit 1; }
BT=~/Library/Android/sdk/build-tools/30.0.3
R=~/ios-reskin; D=$3; N=$1
cat > $D/AndroidManifest.xml <<M
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.scratch.ios.overlay.$N">
    <overlay android:targetPackage="$2" android:priority="1"/>
    <application android:hasCode="false"/>
</manifest>
M
mkdir -p $R/out; rm -f $D/res.zip $D/u.apk $D/a.apk
$BT/aapt2 compile --dir $D/res -o $D/res.zip
$BT/aapt2 link -I $R/work/framework-res.apk --manifest $D/AndroidManifest.xml $([ -f $D/ids.txt ] && echo --stable-ids $D/ids.txt) $D/res.zip -o $D/u.apk
$BT/zipalign -f 4 $D/u.apk $D/a.apk
$BT/apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android --key-pass pass:android --v1-signing-enabled true --v2-signing-enabled false --out $R/out/${N}Overlay.apk $D/a.apk
echo built $N
