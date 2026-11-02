#!/system/bin/sh
# Day/night scheduler. Mode override: `settings put system ios_theme_mode auto|day|night`.
# Switches the system night mode (overlays use values-night) and the wallpaper.
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 20
last=""
while true; do
  mode=$(settings get system ios_theme_mode)
  [ "$mode" = "null" ] && mode=auto
  h=$(date +%H); h=${h#0}; mo=$(date +%m); mo=${mo#0}
  case $mo in
    1|12) sr=8; ss=18;; 2) sr=8; ss=19;; 3) sr=7; ss=19;; 4) sr=7; ss=20;;
    5|6|7) sr=7; ss=21;; 8) sr=8; ss=21;; 9) sr=8; ss=20;; 10) sr=8; ss=19;; *) sr=7; ss=18;;
  esac
  case $mode in
    day) n=1;; night) n=2;;
    *) if [ "$h" -ge "$sr" ] && [ "$h" -lt "$ss" ]; then n=1; else n=2; fi;;
  esac
  if [ "$n" != "$last" ]; then
    service call uimode 4 i32 $n >/dev/null 2>&1
    if [ "$(settings get system ios_wall_state)" != "$n" ]; then
      if [ "$n" = "1" ]; then w=/data/local/ios/wall_day.jpg; else w=/data/local/ios/wall_night.jpg; fi
      am start -n com.scratch.ios7launcher/.SetWallpaperActivity --es path $w >/dev/null 2>&1
      settings put system ios_wall_state $n
    fi
    last=$n
  fi
  sleep 30
done
