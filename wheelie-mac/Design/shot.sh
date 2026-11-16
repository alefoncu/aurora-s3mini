#!/bin/sh
# ./Design/shot.sh <kind> [out.png]  — renders one bike of the studio at 1400x760 with headless Chrome.
cd "$(dirname "$0")/.." && node Design/build-studio.mjs >/dev/null
OUT="${2:-/private/tmp/claude-501/shot-$1.png}"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=1400,760 --screenshot="$OUT" "file://$PWD/Design/studio.html#$1" >/dev/null 2>&1
echo "$OUT"
