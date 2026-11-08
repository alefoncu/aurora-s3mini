#!/usr/bin/env python3
"""Hairline versions of the status-bar icons that were still solid: vibrate, alarm, location, and the
portrait battery frame used by the quick-settings battery tile.

usage: gen_status_icons.py <work/sysui/res/drawable>
Names and structure (inset + vector, layer ids) follow the stock SystemUI resources.
"""
import sys
dst = sys.argv[1]
W = 'android:fillColor="#00000000" android:strokeColor="#ffffffff" android:strokeWidth="%s" android:strokeLineCap="round" android:strokeLineJoin="round"'

def status(name, inset, size, vp, sw, paths):
    body = "\n".join('        <path %s android:pathData="%s" />' % (W % sw, p) for p in paths)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<inset android:insetLeft="%sdp" android:insetRight="%sdp"\n  xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <vector android:height="%sdp" android:width="%sdp" android:viewportWidth="%s" android:viewportHeight="%s">\n%s\n    </vector>\n</inset>\n'
           % (inset, inset, size, size, vp, vp, body))
    open("%s/%s.xml" % (dst, name), "w").write(xml); print("wrote", name)

status("stat_sys_ringer_vibrate", "3.0", "18.0", "24.0", "1.5", [
    "M8,4.5h8a1.5,1.5 0 0 1 1.5,1.5v12a1.5,1.5 0 0 1 -1.5,1.5h-8a1.5,1.5 0 0 1 -1.5,-1.5v-12a1.5,1.5 0 0 1 1.5,-1.5z",
    "M3.5,9v6", "M1.2,10.5v3", "M20.5,9v6", "M22.8,10.5v3"])
status("stat_sys_alarm", "2.5", "17.0", "24.0", "1.5", [
    "M12,5a8,8 0 1 0 0,16a8,8 0 1 0 0,-16z", "M12,9v4.5l3,1.8", "M3.5,6.5L7,3.5", "M20.5,6.5L17,3.5"])
status("stat_sys_location", "1.5", "17.0", "48.0", "2.4", [
    "M24,4c-7.7,0 -14,6.3 -14,14c0,10.5 14,26 14,26s14,-15.5 14,-26C38,10.3 31.7,4 24,4z",
    "M24,13a5,5 0 1 0 0,10a5,5 0 1 0 0,-10z"])

# battery frame: outline only, tinted by the host (black source colour, as the stock frame)
open("%s/ic_battery_portrait_frame.xml" % dst, "w").write(
'''<?xml version="1.0" encoding="utf-8"?>
<vector android:height="24.0dp" android:width="24.0dp" android:viewportWidth="24.0" android:viewportHeight="24.0"
  xmlns:android="http://schemas.android.com/apk/res/android">
    <path android:name="frame" android:fillColor="#00000000" android:strokeColor="#ff000000" android:strokeWidth="1.4" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M8.5,3.5h7a1.5,1.5 0 0 1 1.5,1.5v15a1.5,1.5 0 0 1 -1.5,1.5h-7a1.5,1.5 0 0 1 -1.5,-1.5v-15a1.5,1.5 0 0 1 1.5,-1.5z M10,2h4" />
</vector>
''')
print("wrote ic_battery_portrait_frame")

# NOTE: the Privacy Guard shield (android:drawable/stat_notify_privacy_guard) and the USB-debugging ring
# (stat_sys_adb) are posted by system_server; a FrameworkOverlay drawable for them fails with
# Resources$NotFoundException at render time (tried with and without --no-version-vectors), so they stay stock.
