# Backup and restore

What this project changes on the phone, and how to get it back.

## What is covered

`tools/device/backup_state.sh` snapshots (to `backup/state_<date>/`, git-ignored):

- all `/system/vendor/overlay/*.apk` (Framework, SystemUI, Settings, Dialer, Contacts, Clock, Calculator, Gallery, Messaging),
- `/system/etc/fonts.xml` (+ `.orig`), `/system/etc/media_codecs.xml`, `/system/etc/init.d/90userinit`,
- the three boot animations,
- every installed `com.scratch.*` APK,
- `settings` dumps (system / secure / global), the launcher preferences, the package list and `getprop`,
- a `MANIFEST.sha1` of everything above.

It does **not** cover user data, the base ROM (LineageOS 14.1), GApps, Xposed/GravityBox or Magisk: make a full **TWRP backup** of the phone for that (the only complete protection).

## Routine

```bash
tools/device/backup_state.sh                      # before any system-level change
tools/device/restore_state.sh backup/state_<date> overlays   # only the overlays
tools/device/restore_state.sh backup/state_<date> apps       # only our apps
tools/device/restore_state.sh backup/state_<date>            # everything above, then reboot
```

`restore_state.sh overlays` was exercised on 2026-11-08 (restored the current overlays, rebooted, md5 of Framework/SystemUI/Settings identical, 0 FATAL). `all` and `apps` were not run.

## Single overlay rollback

```bash
adb push backup/<file>.apk /data/local/tmp/X.apk
adb shell 'su -c "mount -o remount,rw /system && cp /data/local/tmp/X.apk /system/vendor/overlay/FrameworkOverlay.apk && chmod 644 /system/vendor/overlay/FrameworkOverlay.apk && sync && mount -o remount,ro /system"'
adb reboot
```

Known-good earlier versions: `backup/review_20261108/` (`FrameworkOverlay.before_anim.apk`, original `SystemUIOverlay.apk`).

## After reinstalling the launcher

The double-tap-to-lock feature needs the launcher to be a device admin again:

```bash
adb shell 'su -c "dpm set-active-admin --user 0 com.scratch.ios7launcher/.AdminReceiver"'
adb shell 'su -c "appops set com.scratch.ios7launcher WRITE_SETTINGS allow"'   # Control Center brightness/rotation
```

To uninstall the launcher first run `dpm remove-active-admin com.scratch.ios7launcher/.AdminReceiver`.

## If the phone does not boot

1. Boot into TWRP, open the file manager (or `adb shell` in recovery), mount `/system` read-write.
2. Delete the overlay you installed last from `/system/vendor/overlay/` (Framework and SystemUI are the dangerous ones), or copy the earlier version back.
3. Reboot. If it still fails, restore the TWRP backup.

## Things that look scary but are harmless

- `at_distributor` crashing every 5 s on boot (factory-test service, `libatparser.so` lacks `GetClientData`). `setprop ctl.stop at_distributor` silences it until the next reboot.
- Play Store and GMS hog the CPU for a few minutes after boot.
