#!/usr/bin/env python3
"""Generate Aurora's 192 px weather icon (sun peeking behind a cloud) using Pillow only."""
from pathlib import Path
import math
from PIL import Image, ImageDraw

S = 768
image = Image.new('RGBA', (S, S))
mask = Image.new('L', (S, S))
points = []
for i in range(1440):
    t = i * 2 * math.pi / 1440
    c, s = math.cos(t), math.sin(t)
    points.append((S/2 + 374 * math.copysign(abs(c)**0.5, c), S/2 + 374 * math.copysign(abs(s)**0.5, s)))
ImageDraw.Draw(mask).polygon(points, fill=255)
d = ImageDraw.Draw(image)
for y in range(S):  # sky: light blue -> deep blue
    f = y / (S - 1)
    d.line((0, y, S, y), fill=(int(110 - 70 * f), int(190 - 90 * f), int(255 - 40 * f), 255))
image.putalpha(mask)
d = ImageDraw.Draw(image)
W = 26
cx, cy, r = 470, 300, 78
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 226, 110, 255), width=W)
for k in range(8):
    a = math.radians(k * 45)
    d.line((cx + math.sin(a) * (r + 40), cy - math.cos(a) * (r + 40), cx + math.sin(a) * (r + 82), cy - math.cos(a) * (r + 82)), fill=(255, 226, 110, 255), width=W)
# cloud (outline, white), drawn over the sun with a fill that matches the sky behind it
cloud = Image.new('RGBA', (S, S), (0, 0, 0, 0))
cd = ImageDraw.Draw(cloud)
def blob(fill):
    cd.rounded_rectangle((170, 450, 610, 580), radius=65, fill=fill)
    cd.ellipse((222, 372, 392, 542), fill=fill)
    cd.ellipse((330, 330, 530, 530), fill=fill)
blob((88, 140, 240, 255))
image = Image.alpha_composite(image, cloud)
d = ImageDraw.Draw(image)
cd2 = Image.new('RGBA', (S, S), (0, 0, 0, 0))
c2 = ImageDraw.Draw(cd2)
cd = c2
blob((255, 255, 255, 255))
inner = Image.new('RGBA', (S, S), (0, 0, 0, 0))
# white outline = white blob minus a shrunken blob
shr = Image.new('L', (S, S), 0)
sd = ImageDraw.Draw(shr)
sd.rounded_rectangle((170 + W, 450 + W // 2 + 4, 610 - W, 580 - W), radius=40, fill=255)
sd.ellipse((222 + W, 372 + W, 392 - W, 542 - W), fill=255)
sd.ellipse((330 + W, 330 + W, 530 - W, 530 - W), fill=255)
alpha = cd2.split()[3]
from PIL import ImageChops
ring = ImageChops.subtract(alpha, shr)
white = Image.new('RGBA', (S, S), (255, 255, 255, 255))
white.putalpha(ring)
image = Image.alpha_composite(image, white)
out = Path(__file__).resolve().parent.parent / 'weather/res/drawable-nodpi/ic_launcher.png'
out.parent.mkdir(parents=True, exist_ok=True)
image.resize((192, 192), Image.Resampling.LANCZOS).save(out)
print(out)
