# Aurora × Apple Design Awards 2026: action plan (started 2026-11-18)

Source: review of the 12 ADA 2026 winners and their finalists (developer.apple.com/design/awards). 50 proposals were
derived for the launcher; this file records what was built, what already existed and what is deferred.
Rule: everything local, light for a 1 GHz Cortex-A9 / 800 MB, nothing resident, no real blur.

## Architecture
- `Aura.java`: option store (`home` prefs, keys `opt_*`), haptic vocabulary (`tick` / `confirm` / `warn`), reduced-motion
  detection (own switch **or** system animator scale = 0), offline moon phase and sun times, seasons, phrase of the day,
  phone health score, screen-time reader.
- `AuroraField`: monochrome ("tinta") saturation, motion strength, seasonal tint, dawn/dusk keyframes shifted to the real sun.
- `HomeActivity`: Aura sheet (accessibility/motion/gestures/cards), breathing overlay, hourly chart, first-run tour,
  tilt (parallax + shake), new search answers.

## Status of the 50 proposals
Legend: **done** built in this pass · **existed** already in the launcher · **deferred** not built (reason).

| # | Proposal | Status |
|---|---|---|
| 1 | Phrase of the day | done (under the date, Today page only, hand-written face, offline bank of 31) |
| 2 | Hand-drawn style empty states | done: `Icons.doodle` (sleep, freeday, notes, recents, offline, inbox, chart; hairline ink + soft accent) on the Today cards (alarm, agenda, notes), Multitarea, the day timeline and the offline hourly chart |
| 3 | Micro-copy with personality | done (greetings, empty states, breathing, tour) |
| 4 | Clock bounce on tap | done |
| 5 | Shake/tilt makes icons move | done (shake wiggle; off when motion is reduced) |
| 6 | Folder opening stagger | done |
| 7 | Accessibility labels for icons/cards | done for icons, folders, rows and sheet; Today cards inherit text |
| 8 | Spoken context ("Página 2 de 4") | done (announce on page change) |
| 9 | Font scale 1.3× | text is in sp; layout check pending on device |
| 10 | High contrast | done (opaque glass, strong edges, full-strength text) |
| 11 | Differentiate without colour | done in the sheet (switches show "Sí/No" text, not only colour) |
| 12 | Logical focus order | existed (grid is added in reading order) |
| 13 | Legibility option | done ("Texto más legible": heavier weights everywhere) |
| 14 | Haptic strength | done (off / soft / normal) |
| 15 | Aurora intensity slider | done |
| 16 | Automatic reduced motion | done (system animator scale 0 or own switch) |
| 17 | Configurable gestures | done for the double tap (lock / search / nothing) |
| 18 | One accessibility sheet | done ("Aura", from Control Center or search) |
| 19 | 48 dp touch targets | done for pills and sheet rows |
| 20 | Configurable Today cards | done (show/hide four cards) |
| 21 | Parallax | done for dock and dots (tilt); clock excluded to avoid fighting the page scroll |
| 22 | Stereo UI sounds | done, opt-in and off by default (70 ms panned blip on page change, only with the ringer on); **not verified by ear** |
| 23 | Handwritten notes | done (notes card and phrase use the system cursive face) |
| 24 | Pages as "rooms" with their own accent | done: accent per page plus names (defaults Hoy / Inicio / Página N); a glass label shows the name on every page change, long-press the dots to rename or reset, spoken on page change |
| 25 | Hidden commands | done (breathe, moon, health, screen time, my day, phrase, tour, ink, focus, simple…) |
| 26 | Hourly chart that draws itself | done (command "tiempo por horas" and Aura sheet) |
| 27 | Sky-tinted glass | existed in effect: the glass samples the live aurora frame, whose palette already follows the real sun and weather |
| 28 | Mini temperature chart in the card | done (sparkline right of the temperature, from the hourly cache refreshed with each forecast) |
| 29 | Specular edge following tilt | done (top highlight rotates up to a few degrees with the tilt; zero cost when the phone is flat) |
| 30 | Accent from the opened icon | done for Multitarea (card accent bar = icon's dominant colour); the launching window itself cannot be tinted on 7.1 |
| 31 | Notification digest | done as the search answer "notificaciones" (reuses `BadgeService` counts: total, apps, top four); a proactive digest is still phase 4 |
| 32 | Focus mode | done (hides browser, store and social from the grid; still searchable) |
| 33 | Calm mode | done ("modo tranquilo": ringer to vibrate + focus mode, previous ringer restored on exit; full silent needs a policy the app cannot get) |
| 34 | One-minute breathing | done |
| 35 | Kind screen-time card | done as search answer ("tiempo de pantalla") |
| 36 | Onboarding | done (4 steps, first run only, replay with "tutorial") |
| 37 | Sky card | done (sunrise/sunset in the header, moon and daylight in search) |
| 38 | Aurora tied to real sunrise/sunset | done |
| 39 | Ghost-hand tutorial | done |
| 40 | Simple mode | done (six large apps, 3×2) |
| 41 | Self-explanatory icons | done: `Icons.glyph` (about 25 hairline glyphs) on every text-only button (Listo, Mostrar ocultas, Abrir, Dividir pantalla, Cerrar, Siguiente), on every Aura-sheet row, and the Control Center shortcuts now show the app glyph above the label |
| 42 | Day timeline | done ("mi día": vertical timeline with events, alarm, sunrise, sunset and an "Ahora" marker) |
| 43 | Contextual suggestions | existed (`Smart` + context boosts) |
| 44 | Haptic wheels on sliders | done (tick per step on brightness and volume; existed on the page selector) |
| 45 | Pressed-in buttons | done (0.92 press + tick) |
| 46 | Phone health score | done as search answer ("salud") |
| 47 | Hide notification content on lock | done in the sheet; needs a one-time `adb shell pm grant com.scratch.ios7launcher android.permission.WRITE_SECURE_SETTINGS` (the sheet says so if missing) |
| 48 | Seasonal palettes | done (7 % tint; on/off in the sheet) |
| 49 | Ink (monochrome) mode | done |
| 50 | Double tap to lock | existed |

## Still open after the gap pass
9 (font scale 1.3 layout on the real screen) and every on-device check. The seasonal tint stays on by default (7 %); the phrase of the day lives on the Today page only (user's choice).

## Verification
- `Aura` maths checked on the host (`javac` + a throwaway class): full moon 2026-11-24 → 100 %, new moon 2026-11-09 → 0 %,
  Madrid 2026-11-18 sunrise 08:04 / sunset 17:56, 2026-06-21 06:45 / 21:48, polar night → null.
- Bug found by review and fixed: the Aura-sheet switches replaced their pill on every tap but kept a reference to the old one,
  so a second tap would have crashed.
- `tools/build_launcher.sh` now discovers the installed SDK/JDK (it used to require android-25, build-tools 30.0.3 and a
  fixed JDK path) and was run end to end: it produced a 140 KB signed APK.
- Compiles clean against android-35 (`javac --release 8`), dexes and signs (`Launcher2.apk`, 135 KB). Built with the SDK now
  installed (android-35, build-tools 36.0.0, JDK 17) because `tools/build_launcher.sh` expects android-25 / 30.0.3.
- **Not yet installed or run on the phone**: on 2026-11-18 the S3 Mini stayed on the boot animation (`sys.boot_completed`
  empty for over 3 minutes), so every "done" above means "implemented and compiled", not "seen working".
- Rollback APK of the previous launcher: kept outside the repo (scratchpad `Launcher2.before.apk`).
- To check on the phone once it boots: Control Center → tile "Aura"; search "respirar", "luna", "salud", "tiempo por horas",
  "tutorial"; font scale 1.3 (`settings put system font_scale 1.3`); high contrast and motion switches; shake to wiggle.
