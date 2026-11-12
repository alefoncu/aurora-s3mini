# Arte de Wheelie Ride 2

Los paisajes `valley.png` y `dunes.png` se generaron con la herramienta integrada `image_gen`, en modo de generación nueva (sin referencias copiadas), y se guardaron en esta carpeta para distribuirlos dentro de la app. Los vehículos, piloto, terreno, texturas de carretera, objetos y partículas se dibujan en código Swift. El icono actual se genera con `../make-icon.swift` usando el mismo dibujo del vehículo y el piloto que la app.

## Prompt: valley.png

Use case: stylized-concept. Asset type: production background for a native Mac 2D side-scrolling motorcycle wheelie game. Create a very wide 3:1 panoramic natural environment, 3072x1024, refined painterly realism with photographic texture, modern high-quality game matte painting. A lush rural foothill landscape: pale blue slightly hazy sky across top 38 percent, large softly focused mountains in the far distance, overlapping medium-distance olive and sage green hills, eucalyptus and pine woodland around scattered tan limestone rocks and sunlit dry grass nearer the bottom. Eye-level side-on viewpoint, not aerial, horizontal composition. The bottom 25% is a low meadow, so a separate game road can be rendered over it. Environment fills the whole image, no road, no foreground tree blocking the central playing field, NO motorcycles, NO rider, NO vehicles, NO buildings, NO interface, NO letters, NO frame. Natural muted earth colors with lively rich foliage and warm afternoon sunlight, depth and subtle photographic grain; believable natural forms rather than flat geometric vectors. Similar quiet height/brightness at left and right edges so it can scroll looped. Pure game environment artwork, not a screenshot.

## Prompt: dunes.png

Use case: stylized-concept. Asset type: panoramic backdrop for a 2D side-scrolling motorcycle game on Mac. Make an original 3:1 wide landscape matte painting with photographic texture and subtle painterly realism. Rocky desert at golden sunset: pale warm peach and dusty lilac sky taking top 40%, distant low mauve and rust mountains fading in haze, amber sandstone ridges, scattered boulders and desert scrub, small tufts of dry grass, a broad low sandy meadow in bottom 25%. Camera looks horizontally straight across the landscape, not down, low horizon. Rich realistic natural surfaces, layered depth, warm grazing sunlight from right. No road or track, no text, no vehicles, no people, no UI. No large foreground objects blocking the central area where gameplay will overlay. Similar colors and horizon heights at both edges so it can be scrolled. This is a clean environment texture, NOT a game screenshot. Wide 3072x1024 composition.

## Regenerar el icono

Desde `wheelie-mac/`:

```sh
xcrun swiftc -O -parse-as-library -framework Cocoa Sources/VehicleRig.swift Sources/BikePhysics.swift Sources/RiderRig.swift Sources/Renderer.swift Sources/VehicleArtwork.swift Sources/RiderArtwork.swift make-icon.swift -o build/MakeIcon
build/MakeIcon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Assets/AppIcon.icns
```
