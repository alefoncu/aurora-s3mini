#!/system/bin/sh
# runs at boot through /system/etc/init.d/90userinit
if [ -x /system/bin/setsid ]; then
  setsid /system/bin/sh /data/local/ios/daynight.sh >/dev/null 2>&1 &
else
  /system/bin/sh /data/local/ios/daynight.sh >/dev/null 2>&1 &
fi
