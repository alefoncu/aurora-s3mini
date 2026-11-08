#!/usr/bin/env python3
"""Generate Aurora's 192 px recorder icon using Pillow only."""
from pathlib import Path
from PIL import Image, ImageDraw

S = 768
image = Image.new('RGBA', (S, S))
mask = Image.new('L', (S, S))
m = ImageDraw.Draw(mask)
# Superellipse gives the continuous iOS squircle outline.
points = []
import math
for i in range(1440):
    t = i * 2 * math.pi / 1440
    c, s = math.cos(t), math.sin(t)
    points.append((S/2 + 374 * math.copysign(abs(c)**0.5, c),
                   S/2 + 374 * math.copysign(abs(s)**0.5, s)))
m.polygon(points, fill=255)
draw = ImageDraw.Draw(image)
for y in range(S):
    f = y / (S-1)
    draw.line((0, y, S, y), fill=(255, int(114-60*f), int(100-46*f), 255))
image.putalpha(mask)
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((302, 158, 466, 430), radius=82, fill='white')
draw.arc((244, 288, 524, 506), 0, 180, fill='white', width=28)
draw.line((244, 350, 244, 396), fill='white', width=28)
draw.line((524, 350, 524, 396), fill='white', width=28)
draw.line((384, 496, 384, 594), fill='white', width=28)
draw.rounded_rectangle((300, 578, 468, 606), radius=14, fill='white')
out = Path(__file__).resolve().parent.parent / 'recorder/res/drawable-nodpi/ic_launcher.png'
image.resize((192, 192), Image.Resampling.LANCZOS).save(out)
print(out)
