# Design language v2 — "Aurora"

Minimal in layout and features, rich in colour. Replaces the all-black v1.
Single source for wallpaper, lock screen, status bar, shade, launcher, icons, apps and boot animation.

## Palette

| Token | Value | Use |
|---|---|---|
| ink | `#0E1030` | deepest tone of the wallpaper, dark text on light glass |
| aurora-blue | `#3B82F6` | wallpaper glow (top-left), primary accent |
| aurora-violet | `#7C3AED` | wallpaper centre, secondary accent |
| aurora-pink | `#F472B6` | wallpaper glow (bottom-right) |
| aurora-amber | `#FBBF77` | small warm highlight, warnings |
| accent | `#6EA8FF` | active toggles, links, focus |
| glass | white @ 16 % + 1 px white @ 22 % border | cards, dock, tiles, notifications |
| glass-strong | white @ 28 % | pressed / expanded state |
| text | `#FFFFFF` | on glass and wallpaper |
| text2 | white @ 70 % | secondary |
| ok / danger | `#34D399` / `#FB7185` | call, missed call, destructive |

Icon tile gradients (top → bottom, white 2.4 dp line glyph on top):
phone `#34D399→#059669`, messages `#60A5FA→#2563EB`, camera `#F9A8D4→#DB2777`, contacts `#FDBA74→#EA580C`,
settings `#94A3B8→#475569`, gallery `#F0ABFC→#C026D3`, clock `#A5B4FC→#4F46E5`, calculator `#FDE68A→#D97706`,
files `#FCD34D→#B45309`, mail `#7DD3FC→#0284C7`, calendar `#FCA5A5→#DC2626`, music `#F9A8D4→#BE185D`,
recorder `#FDA4AF→#E11D48`, store `#5EEAD4→#0D9488`, browser `#93C5FD→#1D4ED8`, other `#C4B5FD→#6D28D9`.

## Rules

- Type: sans-serif-thin for big numerals, light for body, medium only for titles. Big clock = hero of lock and home.
- Shape: continuous squircle for icons (n = 4.6), 24 dp radius for glass cards, full pill for dock and toggles.
- Depth: glass = translucent fill + hairline border, no shadows, no blur (GPU/RAM budget). Wallpaper does the colour work.
- Density: few things per screen, generous spacing; hide developer apps (Magisk, Xposed, GravityBox) from the grid.
- Motion: 160–220 ms, decelerate. Done inside the launcher and apps only (system window animations cannot be overlaid on 7.1).
- Icons: one line-glyph set, 2.4 dp stroke, round caps, always white on a colour tile.
