# Wheelie Ride (macOS): reglas del proyecto

## Cada commit con cambios de la app se instala en el Mac del usuario

Instrucción permanente del usuario: **siempre que se haga un commit que cambie la app** (cualquier cosa bajo `wheelie-mac/Sources/`, `Assets/`, `build.sh` o `make-icon.swift`), la app instalada en `~/Applications/Wheelie Ride.app` se actualiza con esa misma versión. No hace falta que el usuario lo pida cada vez.

Se salta la instalación solo si el commit no toca la app (solo README, documentación, CI o tests).

### Pasos, en este orden

1. Verificar antes de commitear: `./test.sh` y `"build/Wheelie Ride.app/Contents/MacOS/WheelieRide" --smoke-test`. Si algo falla, no se commitea ni se instala; se informa.
2. Hacer el commit. Subir con `git push` solo si el usuario lo pide.
3. Comprobar que la app no está abierta: `pgrep -x WheelieRide`.
   - Si está abierta, **no cerrarla por la fuerza**: pedir al usuario que la cierre (⌘Q) y esperar, o dejar la instalación pendiente y decirlo.
4. Instalar desde `wheelie-mac/`:

   ```sh
   ./build.sh --install
   ```

   El script compila para la arquitectura del Mac, firma, **guarda la versión anterior en `build/Backups/`**, instala en `~/Applications/Wheelie Ride.app` y la abre. No toca las preferencias ni los récords.
5. Confirmar: `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ~/Applications/Wheelie\ Ride.app/Contents/Info.plist` debe dar la versión del commit, y `pgrep -x WheelieRide` debe mostrar que está abierta.
6. Decir al usuario en el resumen final que la app quedó instalada (versión y ruta de la copia de seguridad), o por qué no se pudo.

### Versión

Cada cambio visible de la app sube la versión en `build.sh` (`CFBundleShortVersionString`) y se anota en el historial de `README.md`, para poder comprobar en el Mac qué versión corre.

### Si algo sale mal

- **La instalación falla o la app no abre:** restaurar la copia más reciente de `build/Backups/` (mover `Wheelie Ride-<fecha>.app` a `~/Applications/Wheelie Ride.app`) y avisar al usuario.
- **El icono antiguo sigue en el Dock o Finder:** es la caché de iconos de macOS; `killall Dock` la refresca.
- `build/` está en `.gitignore`: las copias de seguridad no se versionan y pueden borrarse a mano cuando ocupen demasiado.

## Otras convenciones del proyecto

- Los textos para el usuario (README, avisos de la app) van en español.
- El estado real del proyecto está en `README.md` (sección «Esta versión» más el historial). Se actualiza con cada cambio visible.
- Revisión visual del arte: `WheelieRide --snapshot <carpeta>` guarda capturas, incluidas `lineup-<vehículo>.png` con los diez vehículos en la misma pose.
- Si se toca el solver del piloto (`RiderRig.swift`), pasar `./test.sh`: comprueba 55.440 poses con huesos y contactos exactos.
