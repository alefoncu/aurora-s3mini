#!/usr/bin/env python3
"""Generate Aurora's calendar launcher icon with Pillow (no downloaded assets)."""

from pathlib import Path

from PIL import Image, ImageDraw


def main():
    size, scale = 192, 4
    width = size * scale
    image = Image.new("RGBA", (width, width))
    mask = Image.new("L", (width, width))
    pixels, alpha = image.load(), mask.load()
    # A fourth-order superellipse produces a continuous squircle outline.
    center, radius = (width - 1) / 2, width / 2 - 1
    for y in range(width):
        for x in range(width):
            progress = (0.28 * x + 0.72 * y) / (width - 1)
            pixels[x, y] = (
                round(255 - 27 * progress),
                round(89 - 49 * progress),
                round(130 - 41 * progress),
                255,
            )
            if abs((x - center) / radius) ** 4 + abs((y - center) / radius) ** 4 <= 1:
                alpha[x, y] = 255
    image.putalpha(mask)
    draw = ImageDraw.Draw(image)

    def box(coords):
        return tuple(round(value * scale) for value in coords)

    # White calendar page with an open header, binding loops and nine date marks.
    draw.rounded_rectangle(box((38, 45, 154, 153)), radius=14 * scale, fill=(255, 255, 255, 255))
    draw.rounded_rectangle(box((46, 53, 146, 76)), radius=7 * scale, fill=(247, 61, 111, 255))
    for x in (65, 127):
        draw.rounded_rectangle(box((x - 4, 34, x + 4, 64)), radius=4 * scale, fill="white")
    for row in range(3):
        for column in range(3):
            x, y = 64 + column * 32, 96 + row * 20
            color = (235, 54, 102, 255) if (row, column) == (1, 1) else (241, 144, 168, 255)
            draw.rounded_rectangle(box((x - 5, y - 4, x + 5, y + 4)), radius=3 * scale, fill=color)

    output = Path(__file__).resolve().parent.parent / "calendar/res/drawable-nodpi/ic_launcher.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(output)
    print("Created {} ({}x{}, RGBA)".format(output, size, size))


if __name__ == "__main__":
    main()
