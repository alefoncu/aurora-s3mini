# From iOS 7 to "iOS 27": plan of action (started 2026-11-10)

Principle: each phase ends with something verified on the phone and a README entry. Everything is code-generated and must stay light for a 1 GHz Cortex-A9 / 800 MB device.

## Phase 1 — Multitasking (user question: "could you improve multitasking?")
Findings on this phone (Android 7.1.2): split screen works (`am stack` shows a docked stack 3 and the calculator took the top half), but only for **resizable** activities; our apps target an old SDK so Android refuses them ("La aplicación no admite la pantalla dividida"). There is no freeform/PiP feature, and `su` is not available from inside an app.
1. Mark every own app `android:resizeableActivity="true"` and check each in half height (480×400).
2. An **accessibility service** (`GLOBAL_ACTION_TOGGLE_SPLIT_SCREEN`, `GLOBAL_ACTION_RECENTS`), enabled once from adb: lets the launcher dock the current app without root.
3. **Multitarea panel** in the launcher: glass cards of the recent apps (icon, name, time), tap to resume, **Dividir** to open two apps side by side, swipe a card away to close it.
4. Launcher gesture to open it (Home pressed again while on the home screen).

## Phase 2 — Motion ("everything has physics")
Spring-based page snap, icon open/close zoom from the icon with glass blur, dock magnification on touch, rubber-band overscroll, consistent haptics.

## Phase 3 — Design system pass
One set of tokens across all apps (type scale, glass cards, hairlines), the stock apps that still look stock (Settings sub-pages, Messages), Control Center with more tiles.

## Phase 4 — Intelligence
Calendar-aware silence, smarter suggestions, notification digest.

## Status
- Phase 1 (multitasking): items 1–4 done, README entry 71. Split screen verified with Notas + Tiempo.
- Phase 2 (motion): spring page snap, icon fan and Multitarea depth done (README 72). Also done (README 73): interactive Control Center drag, rubber-band overscroll. Still planned: dock magnification, open/close zoom with glass.
- Phase 3: Control Center second row done (README 74); stock-app design audit in progress.
- Phase 4: silence during meetings done (README 75); notification digest and smarter suggestions still planned.
