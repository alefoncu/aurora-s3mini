#!/bin/bash
# Restore a snapshot made by backup_state.sh onto the phone (needs adb + root; reboots the phone).
# usage: tools/device/restore_state.sh <snapshot dir> [what]      what = all (default) | overlays | apps
set -e
D=$1; W=${2:-all}
[ -d "$D/system" ] || { echo "not a snapshot dir: $D" >&2; exit 1; }
if [ "$W" = all ] || [ "$W" = overlays ]; then
  adb shell 'su -c "mount -o remount,rw /system"'
  for f in "$D"/system/_system_vendor_overlay_*.apk; do
    n=$(basename "$f" | sed 's/^_system_vendor_overlay_//')
    adb push "$f" /data/local/tmp/$n >/dev/null
    adb shell "su -c 'cp /data/local/tmp/$n /system/vendor/overlay/$n && chmod 644 /system/vendor/overlay/$n'"
  done
  if [ "$W" = all ]; then
    adb push "$D/system/_system_etc_fonts.xml" /data/local/tmp/fonts.xml >/dev/null
    adb push "$D/system/_system_etc_media_codecs.xml" /data/local/tmp/media_codecs.xml >/dev/null
    adb shell 'su -c "cp /data/local/tmp/fonts.xml /system/etc/fonts.xml; cp /data/local/tmp/media_codecs.xml /system/etc/media_codecs.xml; chmod 644 /system/etc/fonts.xml /system/etc/media_codecs.xml"'
    adb push "$D/system/_system_media_bootanimation.zip" /data/local/tmp/bootanimation.zip >/dev/null
    adb shell 'su -c "cp /data/local/tmp/bootanimation.zip /system/media/bootanimation.zip; chmod 644 /system/media/bootanimation.zip"'
  fi
  adb shell 'su -c "sync; mount -o remount,ro /system"'
fi
if [ "$W" = all ] || [ "$W" = apps ]; then
  for a in "$D"/apps/*.apk; do
    adb push "$a" /data/local/tmp/$(basename "$a") >/dev/null
    adb shell "pm install -r /data/local/tmp/$(basename "$a")" | tail -1
  done
fi
echo "rebooting"; adb reboot
