#!/usr/bin/env python3
"""Generate Aurora's 192 px notes icon (yellow squircle with a pencil on lined paper) using Pillow only."""
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
    d.line((0, y, S, y), fill=(255, int(226 - 62 * f), int(110 - 70 * f), 255))
image.putalpha(mask)
d = ImageDraw.Draw(image)
W = 26
d.rounded_rectangle((210, 170, 520, 600), radius=44, outline='white', width=W)
for k in range(3):
    y = 300 + k * 84
    d.line((270, y, 460, y), fill='white', width=W - 6)
# pencil
import PIL.ImageDraw as D
pencil = Image.new('RGBA', (S, S), (0, 0, 0, 0))
p = D.Draw(pencil)
p.polygon([(560, 250), (610, 300), (430, 520), (380, 540), (400, 490)], outline='white', width=W)
image = Image.alpha_composite(image, pencil)
out = Path(__file__).resolve().parent.parent / 'notes/res/drawable-nodpi/ic_launcher.png'
out.parent.mkdir(parents=True, exist_ok=True)
image.resize((192, 192), Image.Resampling.LANCZOS).save(out)
print(out)
