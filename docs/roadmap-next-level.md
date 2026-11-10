# Roadmap: "feels like a 2026 phone" (started 2026-11-09)

Goal: the S3 Mini should feel current, not just look it. Everything is code-generated, light enough for a 1 GHz Cortex-A9.

| # | Item | Why | Status |
|---|---|---|---|
| 1 | Frosted glass (dock, cards, Control Center, folders, search field) | depth, current design language | done |
| 2 | Wallpaper parallax | motion that responds to the finger | done |
| 3 | Live icons (calendar date, clock hands) | glanceable info | done |
| 4 | Hairline Control Center tiles + haptics | consistency, tactile feedback | done |
| 5 | Weather card (Open-Meteo) | glanceable info | done |
| 6 | Status rings | modern widget style | done |
| 7 | Frosted full-screen backdrop for search and folders (Control Center keeps a plain dim) | stop using flat scrims | done |
| 8 | Glass page indicator pill | polish | done |
| 9 | Greeting on Today, haptics on drag/drop and edit mode | personality, feel | planned |
| 10 | Notification badges on icons (NotificationListenerService) | expected on any modern phone | done |
| 11 | Frame-time measurement (`dumpsys gfxinfo`) and tuning | make sure it is smooth, not only pretty | partly: effects cost ~20 ms/frame, page alpha removed; needs a cleaner benchmark |
| 13 | New app: Tiempo (forecast) | a real weather experience | done |
| 14 | New app: Notas (+ provider shared with the launcher) | notes are the most used glanceable feature | done |
| 12 | Independent review (Codex) and fixes | catch what I miss | planned |

Not attempted on purpose: real-time blur of live content (too heavy for this GPU), anything in stock SystemUI beyond overlays (crash-loop risk, see lessons learned).
