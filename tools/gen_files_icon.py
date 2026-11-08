#!/usr/bin/env python3
"""Generate Aurora's 192px Files launcher icon using only Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


def main():
    size, scale = 192, 4
    n = size * scale
    mask = Image.new("L", (n, n))
    # Superellipse: a continuous squircle rather than a rounded rectangle.
    pixels = mask.load()
    for y in range(n):
        yy = abs((y + 0.5 - n / 2) / (n / 2))
        for x in range(n):
            xx = abs((x + 0.5 - n / 2) / (n / 2))
            pixels[x, y] = 255 if xx ** 4 + yy ** 4 <= 1 else 0
    icon = Image.new("RGBA", (n, n))
    gradient = Image.new("RGBA", (n, n))
    draw = ImageDraw.Draw(gradient)
    for y in range(n):
        t = y / (n - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip((255, 225, 105), (245, 164, 26)))
        draw.line((0, y, n, y), fill=color + (255,))
    icon.paste(gradient, (0, 0), mask)

    def box(values):
        return tuple(round(v * scale) for v in values)

    shadow = Image.new("RGBA", (n, n))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(box((36, 63, 156, 141)), radius=12 * scale, fill=(119, 65, 0, 54))
    icon = Image.alpha_composite(icon, shadow.filter(ImageFilter.GaussianBlur(5 * scale)))
    glyph = Image.new("RGBA", (n, n))
    gd = ImageDraw.Draw(glyph)
    gd.rounded_rectangle(box((35, 56, 90, 93)), radius=8 * scale, fill=(255, 247, 214, 255))
    gd.rounded_rectangle(box((35, 68, 157, 136)), radius=10 * scale, fill=(255, 247, 214, 255))
    gd.rounded_rectangle(box((39, 79, 153, 139)), radius=9 * scale, fill=(255, 255, 249, 255))
    gd.line(box((48, 85, 144, 85)), fill=(255, 255, 255, 255), width=scale)
    icon = Image.alpha_composite(icon, glyph)
    icon = icon.resize((size, size), Image.Resampling.LANCZOS)
    output = Path(__file__).resolve().parent.parent / "files/res/drawable-nodpi/ic_launcher.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    icon.save(output)
    print(output)


if __name__ == "__main__":
    main()
