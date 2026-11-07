# Aurora visual review — 2026-11-03–04

Device: GT-I8190N, 480×800, LineageOS 14.1. Existing Aurora tokens are the reference. Private screenshots, logs and rollback APKs stay under ignored `backup/review_20261103/`.

## Findings and changes

- **Home, day — poor contrast:** the clock and date used fixed white on the pastel wallpaper. They now use the existing day/night text tokens (ink by day, white by night).
- **Home, initial load — avoidable blank grid:** `reload()` waited for every capability and translated-label query before publishing icons. Icons and label search now publish first; the general metadata index fills afterwards. No dictionary of special-case queries was added.
- **Search — background interference:** home clock and icon labels remained visible through the search sheet. Its existing indigo/lavender surface is now opaque, so results stand apart from home.
- **Settings, day — inconsistent surface:** dashboard cards were pure white despite the lavender background token. Their existing `card_background` resource now uses `#F6F5FF`. Categories, suggestions and stock icons remain; this is a surface adjustment, not a replacement Settings app.

## Scope and limitations

This is a visual review of the main screens and selected secondary screens, not proof of every device feature. Calls and SMS/MMS remain unverified without a SIM. Camera preview cannot be assessed from adb screenshots. Stock contact editing remains light at night. The existing Privacy Guard notification was observed; its policy was not modified. Existing Gallery items were left intact.

## Reverting

Restore the backed-up Settings overlay to `/system/vendor/overlay/SettingsOverlay.apk`, mode 0644, then reboot. Reinstall the backed-up launcher with `pm install -r`. Rollback APKs are local only.

## Review criteria

- Native 480×800 screen: titles, tab labels, bottom controls, spacing and text legibility.
- Aurora continuity: pastel day / indigo night, thin large headings, coloured glyphs, glass surfaces.
- Main screens: Home, Phone keypad, Contacts list, Messages empty state, Gallery grid, Clock alarms, Settings dashboard, camera controls.
- Secondary checks: Today, launcher search, quick settings and a synthetic notification.
- Screenshots verify rendering only; they do not verify calling, SMS delivery, camera preview or every interaction.

The Settings suggestion header and category labels remain stock. A full redesign of Settings and the stock contact editor remains future work.

## Evidence and outstanding checks

The first installed changes survived a reboot (`sys.boot_completed=1`, no Java FATAL or ANR in the captured boot log). Main night screens were captured after that boot. A second launcher build adds the opaque search sheet and the independent review's query-refresh fix.

Private captures include the day Contacts/Phone/Gallery/Clock/Messages screens, night main screens, Today, search, quick settings and a synthetic notification. Settings needed a longer loading wait. Camera controls can be inspected, but the black screenshot viewfinder proves nothing about preview quality. Some adb capture batches timed out under load and were repeated; failed captures were not accepted as evidence.

The review is not exhaustive: populated message threads, all Settings subpages, stock contact editing, camera front/flash/capture intents and telephony still need separate checks. No claim is made that 480p H.264 playback has been tested (the earlier test was 320×240).
