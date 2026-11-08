# Engineering notes (chronological, detailed)

Estado a 2026-11-02. Todo lo que se ha instalado en el móvil, de dónde sale y cómo se revierte.

## Qué hay instalado

| Pieza | Dónde está en el móvil | Fuentes en este Mac |
|---|---|---|
| Overlays estáticos (Calculadora, Reloj, Contactos, Galería, Mensajes, Ajustes, Teléfono, Framework) | `/system/vendor/overlay/*Overlay.apk` | `work/<app>/res`, APKs en `out/` |
| Fuente fina (peso 400 → Roboto Light) | `/system/etc/fonts.xml` | original en `backup/fonts.xml` (y `/system/etc/fonts.xml.orig` en el móvil) |
| Launcher v2 | app de usuario `com.scratch.ios7launcher` | `launcher2/` (APK v1.1 antiguo en `launcher/launcher_v1.1.apk`) |
| Cámara propia (foto + vídeo software) | app de usuario `com.scratch.ioscamera` | `camera/` |
| Acceso directo de cámara en pantalla de bloqueo | prefs de GravityBox (`pref_lockscreen_shortcut0`) | original en `backup/gb_prefs.xml` |

Los APK originales de las apps de sistema están copiados en `backup/` y **no se han modificado**.

## Fase 2 (2026-11-02): minimalismo oscuro

Lenguaje de diseño en `design/tokens.md` (fondo `#0A0A0C`, superficie `#16161A`, texto `#F2F2F5`, acento `#4C9AFF`).

| Pieza | Dónde | Notas |
|---|---|---|
| Boot animation v2 (anillo fino + cometa azul) | `/system/media/bootanimation.zip` | generada con `boot2/MakeBoot.java`; copias: `bootanimation_v1.zip` en el móvil y `backup/bootanimation_current.zip` |
| SystemUI (barra de estado, ajustes rápidos, tarjetas de notificación oscuras) | `/system/vendor/overlay/SystemUIOverlay.apk` | fuentes `work/sysui/res` |
| Framework (acento, estilos de texto de notificaciones, controles planos) | `/system/vendor/overlay/FrameworkOverlay.apk` | fuentes `work/frame/res`; versiones previas en `backup/FrameworkOverlay_v1.apk` y `_v2.apk` |
| Pantalla de bloqueo oscura, sin accesos duplicados | prefs de GravityBox | original en `backup/gb_prefs_before_dark.xml` |
| Launcher v3 (reloj grande, iconos de línea dibujados en código, dock en píldora) | `com.scratch.ios7launcher` | `launcher2/` (`Glyphs.java` = iconos), build con `tools/build_launcher.sh` |
| Overlays de apps recoloreados | `/system/vendor/overlay/*Overlay.apk` | `tools/recolor.py` aplica los tokens; la Calculadora además lleva un tema oscuro |

Lecciones:
- **Animaciones de ventana por overlay: no funcionan.** Los recursos en archivo (`res/anim/*`) de un overlay del framework fallan en `system_server` (`FileNotFoundException res/anim-v1/...`) y dejan el launcher en negro. Descartado; las fuentes quedaron en `work/frame_anim_disabled/`.
- Un overlay no puede referenciar sus propios recursos desde un estilo (`@color/...` da `Resource ID not found` en la app).
- La carátula de la tarjeta de notificación sale oscura gracias a los estilos `TextAppearance.Material.Notification*` del overlay del framework.
- Tras un arranque en frío Ajustes tarda ~15 s en dibujar la lista (poca RAM).

## Fase 3 (2026-11-02): "Aurora" con color

La fase 2 (todo negro) se descartó: «minimalista» era diseño y funciones simples, con color. Tokens v2 en `design/tokens.md`.

- **Fondo**: `wallpaper/MakeWallpaper.java` → `aurora.jpg`; se aplica con `am start -n com.scratch.ios7launcher/.SetWallpaperActivity --es path /sdcard/aurora.jpg` (usa `setBitmap`; `setStream` falla con «Invalid wallpaper data»). GravityBox `pref_lockscreen_background=default` para que la pantalla de bloqueo use el fondo del sistema; `pref_lockscreen_carrier_text=" "` oculta el texto del operador; los accesos de GravityBox (shortcut0/1) están eliminados. Copias: `backup/gb_prefs_before_aurora.xml`.
- **Launcher v4**: barra de estado transparente, iconos de color con degradado y glifo blanco (`Glyphs.java` + tabla en `gradientFor`), dock de cristal, 3 filas por página, herramientas (Magisk, Xposed, GravityBox) en la segunda página, deslizar hacia abajo abre el panel de notificaciones.
- **Barra de estado / ajustes rápidos** (`work/sysui/res/drawable`, generados con `tools/gen_icons.py`): wifi y señal finos, bluetooth, no molestar, datos desactivados; panel de ajustes rápidos como lámina de cristal índigo con esquinas redondeadas; tarjetas de notificación translúcidas (colores en `work/sysui/res/values/overlay.xml` y estilos de texto en el overlay del framework).
- **Apps**: barras índigo `#1E1B4B`, acento `#3B82F6` (`tools/recolor.py` guarda los tokens; las sustituciones recientes se hicieron con `sed` sobre `work/<app>/res`).
- **Boot animation v3** (`boot2/`, `bootanimation_v3.zip`): fotogramas de 320x320 centrados sobre fondo `#14123A`, anillo con cometa azul→violeta→rosa. Sin verificar visualmente en el arranque.

**Lección importante (notificaciones):** SystemUI exige que el fondo de las tarjetas sea **opaco** (`IllegalArgumentException: background can not be translucent`). Con colores con alpha, cualquier notificación fallaba y la app que la publicaba se cerraba con `RemoteServiceException: Couldn't expand RemoteViews`. Por eso las tarjetas son lavanda claro opaco (`#F4F2FF`) con el texto oscuro por defecto. No sobrescribir los estilos `TextAppearance.Material.Notification*`. Para probar: `am broadcast -a com.scratch.ios7launcher.NOTIFY -n com.scratch.ios7launcher/.NotifyReceiver --es title T --es text X --ei id 11`. Si el launcher se cierra, Android pide elegir inicio: `cmd package set-home-activity com.scratch.ios7launcher/.HomeActivity`.

Iconos finos añadidos (barra de estado y ajustes rápidos): zen/no molestar, sin SIM, alarma, modo avión, bluetooth, cast y pantalla nocturna, además de wifi y señal. Los vectores animados (linterna, rotación, avión y ubicación de los ajustes rápidos) se dejan de serie: sus animaciones dependen de nombres de grupo y morphing de rutas.

**Barra de estado (final):** reloj en `sans-serif` ligero de 13 sp (estilo `TextAppearance.StatusBar.Clock` en `work/sysui/res/values/styles.xml`), iconos de estado finos (wifi, señal, sin SIM, no molestar `stat_sys_dnd*`), batería sin icono (GravityBox `pref_battery_style=0`) con porcentaje en texto y barra fina de 2 dp arriba (`pref_battery_bar_show=true`; carga `#34D399`, crítica `#FB7185`). Copia previa de prefs: `backup/gb_prefs_before_aurora.xml`. **No** sobrescribir `status_bar_icon_drawing_alpha` (un `<item type="dimen" format="float">` rompe `PhoneStatusBarView` y SystemUI entra en bucle de cierres: `Resource ID type #0x4 is not valid`).

## Modo claro/oscuro automático (2026-11-02)

- **Programador**: `/data/local/ios/daynight.sh` (copia en `tools/device/`), lanzado al arrancar por `/data/local/userinit.sh` (`/system/etc/init.d/90userinit`). Cada 30 s calcula día/noche por mes (amanecer/atardecer aproximados para España; noviembre 7–18 h) y llama a `service call uimode 4 i32 1|2` (1 = día, 2 = noche). Ajuste manual: `settings put system ios_theme_mode auto|day|night`. Cambia también el fondo con `SetWallpaperActivity` (`wall_day.jpg` / `wall_night.jpg`, generados en `wallpaper/`).
- **Overlays con variantes `values-night`** (funcionan: aapt2 las compila como `night-v8`). Cada overlay tiene `values/` (día: barras `#3D4FD1`, acento `#3B6BEA`) y `values-night/` (barras `#1E1B4B`, acento `#7BA7FF`). `tools/apply_daynight.py` hizo la separación; `tools/gen_night.py` clasifica los colores de una app para generar `colors_auto.xml` de noche.
- **Funciona de noche**: launcher (etiquetas, dock y buscador se adaptan; recrea al cambiar `uiMode`), Ajustes (tema padre oscuro `Theme.DeviceDefault`), Calculadora, tarjetas de notificación oscuras (`values-night` de SystemUI y del framework), fondo.
- **No funciona de noche** (se queda claro y legible): Contactos, Mensajes y Teléfono de serie. Sus layouts tienen colores de texto fijos que un overlay no puede cambiar (con los colores nocturnos generados salía texto negro sobre fondo oscuro), así que se retiraron los `colors_auto.xml` de esas tres apps. Remapear los colores base `*_material_light` del framework en `values-night` tampoco afecta a esas apps. La solución real es sustituirlas por apps propias.
- Buscador del launcher: deslizar hacia arriba; busca apps y contactos (`READ_CONTACTS` concedido con `pm grant`).
- Barra de batería de GravityBox: 1 dp, blanca al 35 %, verde translúcido al cargar (`backup/gb_prefs_before_softbar.xml`).

Pendiente de esta fase: iconos de batería, sin SIM, linterna, rotación y notificaciones de la barra; probar tarjetas con notificaciones reales; modo claro.

## Cómo reconstruir

- Overlays: `tools/build_overlay.sh <Nombre> <paquete.destino> <carpeta con res/>` genera `out/<Nombre>Overlay.apk`. Después copiarlo a `/system/vendor/overlay/` (remontando `/system` en rw), `chmod 644` y reiniciar. En Android 7.1 no existe `isStatic`: todo lo que está en esa carpeta es estático.
- Cámara: `tools/build_camera.sh` compila, firma (keystore de depuración) e instala.
- Launcher v2: mismo flujo que la cámara (javac 17 `--release 8` + d8 + aapt2 + apksigner); target SDK 25 para poder actualizar la v1.1.

## Cómo revertir

- Un overlay: borrar su APK de `/system/vendor/overlay/` y reiniciar. Si el móvil no arranca, borrarlo desde TWRP.
- Fuente: copiar `/system/etc/fonts.xml.orig` sobre `/system/etc/fonts.xml` y reiniciar.
- Launcher: `adb install -r launcher/launcher_v1.1.apk` solo funciona si la firma coincide; si no, desinstalar la v2 primero.
- Cámara: `adb uninstall com.scratch.ioscamera`; restaurar `backup/gb_prefs.xml` para que el acceso de bloqueo vuelva a Snap.

## Cosas a saber

- **Vídeo:** el codificador hardware `OMX.ST.VFM.H264Enc` no arranca (error -1010). La cámara graba con `MediaCodec` software a 320x240, ~14 fps, AAC mono. No tocar `media_codecs.xml`: probado y revertido (el software vía MediaRecorder cuelga la grabación).
- **RAM:** ~20 MB libres de 803 MB con GMS y Play Store detenidos. Cuidado con añadir servicios.
- **`at_distributor`:** se cierra con SIGABRT cada ~5 s (`cannot locate symbol "GetClientData"`). Ya ocurría antes de estos cambios; consume CPU de fondo. Sin investigar.
- **Magisk:** sigue apareciendo la app `com.topjohnwu.magisk`; no se usa para el root (el root es el addonsu).
- El launcher v2 no incluye el Centro de Control simulado de la v1.1 (GravityBox gestiona el real) ni arrastrar/reordenar iconos.
- Un overlay solo cambia valores de recursos (colores, dimensiones, estilos). No cambia formas ni iconos propios de cada app.

## Pendiente

- Probar la cámara frontal, el flash y `IMAGE_CAPTURE` desde otras apps.
- Revisar Mensajes y Contactos con la fuente fina.
- Deslizar entre páginas del launcher (ahora todo cabe en una).

## Visual review, 2026-11-03–04 (current additions)

Earlier sections are a chronological diary, not the current complete state. The hardware H.264 **decoder** was subsequently disabled (request 27; `tools/device/media_codecs_swavc.diff`); do not confuse this with the earlier failed attempt to remove the **encoder**. Animated quick-settings glyphs and the cold-boot animation were subsequently tested (README requests 26 and 28).

Phase 3 adjusts the launcher day clock/date, separates icon publishing from semantic indexing, refreshes an open query after the worker completes, makes the search sheet opaque in both modes, and tints Settings day cards with its existing lavender surface. See `docs/visual-review-2026-11-03.md` for scope and limitations. Local rollback APKs, screenshots and logs are in ignored `backup/review_20261103/`. No APKs, personal screenshots or dumps are committed.

### Device checks, 2026-11-07 (not yet committed)

- H.264 software decode, Gallery `VideoPane`: 854x480 plays with 0 % dropped frames; 1280x720 drops ~84 % (unusable). No ANR/FATAL. Measured with Play Store/GMS stopped; with them running, 480p dropped ~30 %.
- Camera: live preview visible; `IMAGE_CAPTURE` + `EXTRA_OUTPUT` writes the JPEG and returns without saving to DCIM; front camera previews and saves; flash toggles auto/off in the UI (actual flash firing not verified). A chooser appears for `IMAGE_CAPTURE` because Snap also handles it (no default set).
