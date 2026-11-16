#!/bin/sh
# ./Design/preview.sh <Board.dc.html> [out.png] — renders the board's inline SVG with headless Chrome.
cd "$(dirname "$0")/canvas/project" || exit 1
OUT="${2:-/private/tmp/claude-501/prev-$(basename "$1" .dc.html).png}"
python3 - "$1" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
m=re.search(r'<svg.*?</svg>',s,re.S)
open('/private/tmp/claude-501/prev.html','w').write('<html><body style="margin:0">'+m.group(0)+'</body></html>')
PY
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=1200,800 --screenshot="$OUT" "file:///private/tmp/claude-501/prev.html" >/dev/null 2>&1
echo "$OUT"
