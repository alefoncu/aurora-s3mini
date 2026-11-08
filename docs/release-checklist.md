# Release checklist — what is left before this can be called "done"

Status as of 2026-11-08. `[x]` = done and verified on the phone, `[ ]` = open, `(owner)` = needs the owner (SIM, hands, a decision).

## Needs a SIM or hands (owner)

- [ ] (owner) Make a **full TWRP backup** of the phone — the only complete protection. `tools/device/backup_state.sh` covers just what this project changes (see `restore.md`).
- [ ] (owner) Insert a SIM and check: place a call, receive a call, in-call UI (stock dialer is still used for the call screen), send/receive an SMS (stock Messages with overlay), send/receive an MMS, notification for an incoming SMS, behaviour after a reboot.
- [ ] (owner) Camera: the flash really fires (photo, auto mode), record a video (starts, stops, plays back in the Gallery), front camera zoom, self-timer 10 s and cancel.
- [ ] (owner) Use it as the daily phone for a few days: any unexpected reboot, SystemUI restarts, battery drain, heat. Run `adb logcat -b crash -d` afterwards.
- [ ] (owner) Decide about Play Store / GMS CPU use (they dominate load for minutes after boot): leave, disable until needed, or remove.
- [ ] (owner) Decide about 720p video: playback drops ~84 % of frames with the software decoder (480p is fine). Accept, or look for another decoder.

## Open technical items (can be done without hardware)

- [ ] Stock Messages stays **white at night** (hard-coded app theme; colour overlays cannot change it).
- [ ] Uninstall path of the launcher edit mode (the × on a user app) and dragging a folder onto the dock were never exercised.
- [ ] `restore_state.sh all` and `apps` were never run (`overlays` was).
- [ ] No frame-rate measurement of the new animations.
- [ ] A clean-room install from the README (new phone/ROM) was never tried.
- [ ] The Apps list in Settings still shows the stock Calculator next to ours.

## Verified (2026-11-08)

- [x] Launcher: reorder, folders (grid and dock), dock drag, edit mode (hide), Today page incl. next alarm, day and night.
- [x] Own apps: Calculator, Clock (ghost-alarm bug fixed), Gallery gestures, Camera (zoom, focus, timer, grid), Contacts, Phone — day and night.
- [x] Thin status-bar icons and quick-settings battery glyph; global window transitions (Framework overlay, values only).
- [x] Cold reboots after every system change: 0 FATAL; overlay restore from a snapshot works.
- [x] Settings subpages (Wi-Fi, Sound, Display, Apps), contact editor and Messages reviewed day and night.
