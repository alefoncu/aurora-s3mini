#!/bin/bash
# Snapshot of everything this project changes on the phone (needs adb + root).
# usage: tools/device/backup_state.sh [dest]    default: backup/state_YYYYMMDD_HHMM (git-ignored)
set -e
D=${1:-$HOME/ios-reskin/backup/state_$(date +%Y%m%d_%H%M)}
mkdir -p "$D/system" "$D/apps" "$D/settings"
pull() { adb shell "su -c 'cat $1'" > "$D/system/$(echo $1 | tr / _)" 2>/dev/null || echo "missing: $1"; }
for f in /system/vendor/overlay/*.apk; do :; done
for f in $(adb shell 'ls /system/vendor/overlay/*.apk' | tr -d '\r'); do pull $f; done
for f in /system/etc/fonts.xml /system/etc/fonts.xml.orig /system/etc/media_codecs.xml /system/etc/init.d/90userinit \
         /system/media/bootanimation.zip /system/media/bootanimation_original.zip /system/media/bootanimation_v1.zip; do pull $f; done
for p in $(adb shell pm list packages -3 | tr -d '\r' | sed 's/package://' | grep -E '^com\.scratch\.'); do
  path=$(adb shell pm path $p | tr -d '\r' | sed 's/package://' | head -1)
  adb pull "$path" "$D/apps/$p.apk" >/dev/null
done
for ns in system secure global; do adb shell settings list $ns | tr -d '\r' > "$D/settings/$ns.txt"; done
adb shell 'su -c "cat /data/data/com.scratch.ios7launcher/shared_prefs/home.xml"' > "$D/settings/launcher_home_prefs.xml" 2>/dev/null || true
adb shell pm list packages -f | tr -d '\r' > "$D/packages.txt"
adb shell getprop > "$D/getprop.txt"
( cd "$D" && find . -type f | xargs shasum > MANIFEST.sha1 )
echo "backup in $D ($(du -sh "$D" | cut -f1))"
