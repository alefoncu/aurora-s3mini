#!/bin/bash
# Re-applies the Aurora live wallpaper (Android falls back to the stock wallpaper whenever the launcher APK is reinstalled).
adb shell "su -c 'pm enable com.android.wallpaper.livepicker; settings put system ios_live_wall 1'" >/dev/null 2>&1
adb shell "input keyevent KEYCODE_WAKEUP; sleep 1" >/dev/null 2>&1
if adb shell "dumpsys window | grep mCurrentFocus" 2>/dev/null | grep -q StatusBar; then adb shell "input swipe 240 700 240 200 300; sleep 2" >/dev/null 2>&1; fi
adb shell "am start -n com.scratch.ios7launcher/.SetWallpaperActivity --ez aurora true" >/dev/null 2>&1
sleep 5
adb shell "input tap 285 78; sleep 3; input tap 250 485; sleep 4; input keyevent KEYCODE_HOME" >/dev/null 2>&1
