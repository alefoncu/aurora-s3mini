#!/usr/bin/env python3
"""Generate Aurora's 192 px Medidor icon (compass dial on a teal squircle) using Pillow only."""
from pathlib import Path
import math
from PIL import Image, ImageDraw

S = 768
image = Image.new('RGBA', (S, S))
mask = Image.new('L', (S, S))
pts = []
for i in range(1440):
    t = i * 2 * math.pi / 1440
    c, s = math.cos(t), math.sin(t)
    pts.append((S/2 + 374 * math.copysign(abs(c)**0.5, c), S/2 + 374 * math.copysign(abs(s)**0.5, s)))
ImageDraw.Draw(mask).polygon(pts, fill=255)
d = ImageDraw.Draw(image)
for y in range(S):
    f = y / (S - 1)
    d.line((0, y, S, y), fill=(int(94 - 60 * f), int(234 - 90 * f), int(212 - 60 * f), 255))
image.putalpha(mask)
d = ImageDraw.Draw(image)
W = 26
cx = cy = S // 2
R = 230
d.ellipse((cx - R, cy - R, cx + R, cy + R), outline='white', width=W)
for k in range(12):
    a = math.radians(k * 30)
    r1 = R - (44 if k % 3 == 0 else 28)
    d.line((cx + math.sin(a) * r1, cy - math.cos(a) * r1, cx + math.sin(a) * (R - 8), cy - math.cos(a) * (R - 8)), fill='white', width=14)
# needle: red north half, white south half
d.polygon([(cx, cy - 170), (cx - 34, cy), (cx + 34, cy)], fill=(255, 80, 96, 255))
d.polygon([(cx, cy + 170), (cx - 34, cy), (cx + 34, cy)], fill=(255, 255, 255, 255))
d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(30, 60, 90, 255))
out = Path(__file__).resolve().parent.parent / 'measure/res/drawable-nodpi/ic_launcher.png'
out.parent.mkdir(parents=True, exist_ok=True)
image.resize((192, 192), Image.Resampling.LANCZOS).save(out)
print(out)
