#!/bin/bash
# Closed-device cleanup for the Aurora S3 Mini: no Play Store, no Google services, no unused stock apps.
# Everything is reversible (pm disable-user): `debloat.sh enable` puts it all back. Nothing is uninstalled.
act=${1:-disable}
cmd=disable-user; [ "$act" = enable ] && cmd=enable
PKGS="
com.android.vending
com.google.android.gms
com.google.android.gsf
com.google.android.gsf.login
com.google.android.backuptransport
com.google.android.configupdater
com.google.android.feedback
com.google.android.onetimeinitializer
com.google.android.partnersetup
com.google.android.setupwizard
com.google.android.syncadapters.calendar
com.google.android.syncadapters.contacts
com.google.android.verifier
com.google.android.tts
com.google.android.ext.services
com.google.android.ext.shared
com.android.egg
com.android.dreams.basic
com.android.dreams.phototable
com.android.htmlviewer
com.android.development
com.android.printspooler
com.android.printservice.recommendation
com.android.stk
com.android.managedprovisioning
com.android.wallpaper.livepicker
com.android.wallpaperbackup
com.android.sharedstoragebackup
com.android.backupconfirm
com.android.calllogbackup
com.android.statementservice
com.cyanogenmod.lockclock
com.cyanogenmod.trebuchet
com.cyanogenmod.setupwizard
com.cyanogenmod.eleven
org.cyanogenmod.weather.provider
org.cyanogenmod.weatherservice
org.lineageos.updater
org.lineageos.recorder
"
for p in $PKGS; do
  r=$(adb shell "su -c 'pm $cmd --user 0 $p'" 2>&1 | grep -v WARN | tail -1)
  echo "$p: $r"
done
