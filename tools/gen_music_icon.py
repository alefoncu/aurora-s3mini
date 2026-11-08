#!/usr/bin/env python3
"""Generate Aurora Música's 192 px launcher icon with Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw


def main():
    size, scale = 192, 4
    side = size * scale
    mask = Image.new("L", (side, side), 0)
    # Superellipse gives the same soft shoulders as an iOS squircle.
    draw = ImageDraw.Draw(mask)
    points = []
    import math
    for step in range(721):
        angle = step * 2 * math.pi / 720
        c, s = math.cos(angle), math.sin(angle)
        points.append((side / 2 + (side / 2 - 2 * scale) * math.copysign(abs(c) ** 0.5, c),
                       side / 2 + (side / 2 - 2 * scale) * math.copysign(abs(s) ** 0.5, s)))
    draw.polygon(points, fill=255)
    icon = Image.new("RGBA", (side, side))
    pixels = icon.load()
    top, bottom = (255, 105, 164), (193, 24, 132)
    for y in range(side):
        for x in range(side):
            t = min(1, max(0, (y * .78 + x * .22) / (side - 1)))
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,)
    icon.putalpha(mask)
    note = ImageDraw.Draw(icon)
    def poly(coords):
        note.polygon([(int(x * scale), int(y * scale)) for x, y in coords], fill="white")
    def ellipse(box):
        note.ellipse(tuple(int(p * scale) for p in box), fill="white")
    # Beamed pair of notes, intentionally drawn instead of relying on a font.
    poly([(77, 60), (139, 46), (139, 65), (77, 79)])
    poly([(77, 63), (86, 61), (86, 132), (77, 134)])
    poly([(130, 50), (139, 48), (139, 120), (130, 122)])
    ellipse((52, 121, 86, 147))
    ellipse((105, 109, 139, 135))
    icon = icon.resize((size, size), Image.Resampling.LANCZOS)
    destination = Path(__file__).resolve().parent.parent / "music/res/drawable-nodpi/ic_launcher.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    icon.save(destination)
    print(destination)


if __name__ == "__main__":
    main()
