# Release checklist — what is left before this can be called "done"

Status as of 2026-11-08. `[x]` = done and verified on the phone, `[ ]` = open, `(owner)` = needs the owner (SIM, hands, a decision).

## Needs a SIM or hands (owner)

- [ ] (owner) Make a **full TWRP backup** of the phone — the only complete protection. `tools/device/backup_state.sh` covers just what this project changes (see `restore.md`).
- [ ] (owner) Insert a SIM and check: place a call, receive a call, in-call UI (stock dialer is still used for the call screen), send/receive an SMS (stock Messages with overlay), send/receive an MMS, notification for an incoming SMS, behaviour after a reboot.
- [ ] (owner) Camera: the flash really fires (photo, auto mode), record a video (starts, stops, plays back in the Gallery), front camera zoom, self-timer 10 s and cancel.
- [ ] (owner) Use it as the daily phone for a few days: any unexpected reboot, SystemUI restarts, battery drain, heat. Run `adb logcat -b crash -d` afterwards.
- [ ] (owner) Decide about Play Store / GMS CPU use (they dominate load for minutes after boot): leave, disable until needed, or remove.
- [ ] (owner) Decide about 720p video: playback drops ~84 % of frames with the software decoder (480p is fine). Accept, or look for another decoder.

## Added on 2026-11-08 evening and still unverified in some paths

- [ ] Music: previous/shuffle/seek and background playback; Files: share/details; Recorder: share; Calendar: deleting a recurring series. (Add/delete event, record/play/rename/delete, folder create/rename/delete and *next* were verified.)
- [ ] Control Center: day-mode look (Wi-Fi, Bluetooth, volume, brightness and rotation were verified). Double-tap lock needs `dpm set-active-admin` after every launcher reinstall.
- [ ] The new ringtone and notification tone have never been heard by me; the Today music card never appeared (nothing was playing).
- [ ] Deliberately **not done**: stock Messages in dark, an own in-call screen, lock-screen restyling beyond the existing tokens.

## Open technical items (can be done without hardware)

- [ ] Stock Messages stays **white at night** (hard-coded app theme; colour overlays cannot change it).
- [ ] A clean-room install from the README (new phone/ROM) was never tried.

## Verified (2026-11-08)

- [x] Launcher edit mode × on a user app opens Android's uninstall confirmation (checked with a dummy package, dialog dismissed with Back; the launcher drops the icon by itself when the package disappears). The actual uninstall confirmation was not tapped.
- [x] Dragging a folder from the grid onto the dock works (it takes the slot; the displaced app goes to the grid).
- [x] `restore_state.sh all` (reboot, 12 files md5-identical, 8 APKs reinstalled, 0 FATAL); `overlays` also verified earlier. `apps` alone not run separately.
- [x] Frame stats of the launcher (`dumpsys gfxinfo`, 300 frames of page swipes, search and app open/close): p50 7 ms, p90 15 ms, p95 40 ms, p99 113 ms, 9 % janky (mainly search/app start).
- [x] Stock Calculator hidden from Settings > Apps with `pm hide com.android.calculator2` (undo: `su -c "pm unhide com.android.calculator2"`).

- [x] Launcher: reorder, folders (grid and dock), dock drag, edit mode (hide), Today page incl. next alarm, day and night.
- [x] Own apps: Calculator, Clock (ghost-alarm bug fixed), Gallery gestures, Camera (zoom, focus, timer, grid), Contacts, Phone — day and night.
- [x] Thin status-bar icons and quick-settings battery glyph; global window transitions (Framework overlay, values only).
- [x] Cold reboots after every system change: 0 FATAL; overlay restore from a snapshot works.
- [x] Settings subpages (Wi-Fi, Sound, Display, Apps), contact editor and Messages reviewed day and night.
