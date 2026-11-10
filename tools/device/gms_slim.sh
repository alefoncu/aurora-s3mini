#!/bin/bash
# Frees RAM on the S3 Mini by disabling optional Google Play Services components (cast, ads, stats, nearby, feedback, wear, car).
# Usage: gms_slim.sh disable|enable   (list: tools/device/gms_disabled_components.txt)
act=${1:-disable}
list=$(dirname "$0")/gms_disabled_components.txt
adb shell "su -c 'cmd package list packages' >/dev/null 2>&1"
while read -r c; do adb shell "su -c 'pm $act $c'" 2>&1 | grep -v WARN | tail -0; done < "$list"
if [ "$act" = disable ]; then
  adb shell "su -c 'cmd appops set com.android.vending RUN_IN_BACKGROUND ignore; am force-stop com.android.vending; am force-stop com.google.android.gms'" 2>&1 | grep -v WARN
fi
