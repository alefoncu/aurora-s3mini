# Wheelie Ride 5 · macOS

Juego independiente inspirado en la base de Wheelie Challenge: conducción lateral, caballitos, equilibrio, saltos, vehículos y piloto personalizables. Swift/AppKit nativo, sin navegador, red ni descargas en tiempo de ejecución.

## Diseño nativo de Mac

El taller usa `NSSplitViewController`: lista lateral de vehículos, vista previa sobre fondo neutro e inspector desplazable con los controles reales de macOS. Puedes ocultar ambas columnas desde la barra de herramientas. La ventana se redimensiona libremente y respeta la apariencia del sistema.

Al jugar se retiran los paneles y los botones táctiles móviles. La escena ocupa toda la vista; velocidad, distancia y tiempo se muestran en un HUD compacto. La conducción se realiza con teclado y Touch Bar. Pausa y resultados usan botones nativos y material translúcido de AppKit.

## Mecánicas y personajes

La versión 4 usa una geometría en metros compartida por la física, el vehículo dibujado y los anclajes del piloto. Ya no hay una escala distinta para las ruedas visibles y sus contactos.

- Chasis con masa, movimiento vertical y cabeceo; dos masas de rueda con contacto independiente.
- Muelles, amortiguadores, hundimiento por peso, topes de compresión y extensión. La horquilla cambia el solape de sus tubos y el basculante sigue el eje físico.
- Enduro con mayor recorrido; Sport con menor recorrido; BMX con cuadro rígido y una pequeña flexibilidad de neumáticos.
- Brazos, piernas y torso de longitud fija, con poses resueltas para el asiento, manillar y estriberas de cada vehículo. En BMX, pies y pedales comparten fase y radio.
- Saltos por impulso, aterrizajes que comprimen los muelles y caballitos medidos por el contacto real de ambas ruedas.
- Los conos se tumban y transmiten un golpe a la rueda. El chasis y la suspensión determinan el efecto sobre el equilibrio.
- En las caídas, el piloto se desprende y conserva gravedad, impulso, restricciones de huesos, fricción y contacto con el terreno; la moto continúa asentándose.

Es un modelo de conducción arcade lateral: las ruedas tienen recorrido vertical y el chasis tiene cabeceo; no modela la dirección lateral, deformación completa del neumático ni una moto tridimensional. Los controles de peso incluyen amortiguación para que los caballitos puedan corregirse.

## Esta versión

- Street 125, Enduro 250, Sport 600, BMX, Scooter 80, Scrambler 400, Trial 200 y Hyper R 1000: geometría, velocidad, aceleración y respuesta distintas.
- Valle de asfalto, Sierra de tierra y Dunas al atardecer; 1.200 metros por ruta y modo nocturno.
- Vehículos y muñecos redibujados con volúmenes, materiales, reflejos y detalles mecánicos; acompañante opcional, sombras y polvo.
- Color libre de moto, chaqueta, casco y piel, usando los selectores de color de macOS.
- Conos opcionales con contacto en ambas ruedas e impulso físico; saltos para evitarlos.
- Sonido sintetizado de motor y rodadura; la BMX no suena como un motor.
- Récords separados por vehículo y ruta. Las preferencias de la versión anterior se conservan; los nuevos récords usan un espacio separado (`v5`) porque la física ha cambiado. Los anteriores permanecen guardados.
- Ventana Retina, pantalla completa, barra de herramientas personalizable, menús, atajos y paneles nativos.

No contiene todo el catálogo de vehículos ni las pistas del juego original. El código y el arte utilizado en la app son propios. Las referencias visuales consultadas no se incluyen en el paquete.

## Teclado y ratón

| Acción | Tecla |
|---|---|
| Acelerar | ↑ / W |
| Levantar | ← / A |
| Corregir hacia delante | → / D |
| Frenar | ↓ / S |
| Saltar | Espacio |
| Truco | Mantener T |
| Pausar / continuar | P / Escape |
| Reiniciar | R / ⌘R |
| Volver al taller | ⌘G |
| Personalizar piloto y moto | ⌘, |
| Pantalla completa | ⌃⌘F |
| Silenciar | ⇧⌘M |
| Salir | ⌘Q |

Acelera y mantén levantar para iniciar un caballito. Suelta levantar y usa correcciones cortas hacia delante o freno. Mantener gas por sí solo permite rodar con ambas ruedas en el suelo. El teclado y la Touch Bar permiten combinar acciones. La lista lateral, el inspector y los botones de pausa/resultados se manejan con ratón, trackpad o teclado.

Al perder el foco, la partida se pausa y libera todas las entradas. La conducción se bloquea mientras hay un panel de personalización abierto.

## Touch Bar

Integración real con `NSTouchBar` de AppKit, sin complementos ni herramientas externas:

- GAS, LEVANTAR, BAJAR y FRENO momentáneos: funcionan mientras mantienes el dedo.
- Se pueden combinar con varios dedos.
- Durante la conducción: velocidad, distancia de caballito, pausa y reinicio.
- En pausa: barra específica con **Continuar**, **Reiniciar** y **Taller**.
- En el taller: **Rodar**. En resultados: **Otra vuelta** y **Taller**.
- Cada contexto conserva una instancia estable de `NSTouchBar`; cambiar el foco entre botones nativos mantiene la barra correcta.
- Los paneles modales bloquean las acciones de partida hasta cerrarlos.
- Durante una partida, en **Visualización → Personalizar Touch Bar…** puedes añadir salto, truco y taller. Las acciones de pausa y resultados son fijas para que las preferencias de personalización no las oculten.
- Retirar el dedo, deslizarlo fuera, pausar, cerrar un elemento o perder el foco libera los controles.

Las pruebas automáticas validan el estado del controlador, pulsación/liberación accesible, entradas combinadas y cancelación. No simulan dedos ni verifican la distribución o respuesta sobre el hardware físico; esa comprobación se hace en el Mac con Touch Bar.

## Compilar e instalar

Requiere macOS 13+ y herramientas de desarrollo de Xcode. Compila para la arquitectura del Mac actual.

```sh
./build.sh
./build.sh --install
```

Antes de actualizar, cierra Wheelie Ride. La instalación crea `~/Applications/Wheelie Ride.app`, guarda la app anterior en `build/Backups/` y abre la nueva. No borra las preferencias ni los récords.

## Verificación

```sh
./test.sh
```

Incluye:

- Física a 30/120 fps; recorridos completos de todos los vehículos y rutas; contacto y no penetración; hundimiento estático; recorrido independiente; frenado y recuperación; impactos y aterrizajes; asentamiento tras caída.
- 22.176 poses sobre cuatro geometrías: contactos de manos/pies y longitudes de huesos con error inferior a `1e-6` metros.
- Caída del muñeco durante cinco segundos sobre los tres terrenos: gravedad, impulso, huesos, contacto y estabilidad entre frecuencias de imagen.
- Touch Bar: controles deshabilitados en taller/pausa, parejas de pulsación/liberación, telemetría, cancelación de combinaciones y pérdida de foco.
- Transmisión (marchas, embrague, limitador, BMX y CVT) y retos con fantasma: persistencia por contexto, interpolación, límites de grabación y rechazo de datos corruptos.
- Audio offline: muestras finitas y de volumen acotado, canales estéreo, silencio, impacto y BMX. No abre altavoces.

La app también acepta `--smoke-test` para probar su máquina de estados real con una ventana efímera y preferencias aisladas. Incluye una caída completa con desprendimiento del piloto y paso a resultados. Las pruebas de interfaz incluyen selección de moto/ruta, personalización, acompañante, aceleración, caballito, freno, pausa y atajo para volver al taller. La regresión de Touch Bar comprueba la misma barra en ventana, controlador y botones Continuar/Reiniciar al tomar el foco; también comprueba bloqueo modal, recuperación y resultados.

## Archivos

- `Sources/VehicleRig.swift`: dimensiones, masas, recorridos y anclajes compartidos.
- `Sources/BikePhysics.swift`: chasis, ruedas, muelles, amortiguadores y contactos.
- `Sources/Transmission.swift`: caja de cambios manual/automática, embrague, limitador y CVT del scooter.
- `Sources/RideChallenges.swift`: retos (caballito, invertido, salto, contrarreloj) y fantasma de la mejor vuelta.
- `Sources/RiderRig.swift`: postura y cinemática inversa del piloto.
- `Sources/RiderRagdoll.swift`: caída del personaje desprendido.
- `Sources/VehicleArtwork.swift`: materiales y piezas móviles de los vehículos.
- `Sources/RiderArtwork.swift`: dibujo del muñeco a partir del esqueleto resuelto.
- `Sources/Renderer.swift`: carretera, motocicletas y piloto articulado.
- `Sources/GameView.swift`: partida, entrada, taller y récords.
- `Sources/TouchBarController.swift`: controles Touch Bar nativos.
- `Sources/EngineAudio.swift`: síntesis local sin micrófono.
- `Sources/NativeGarage.swift`: biblioteca lateral e inspector nativos.
- `Sources/main.swift`: ventana dividida, barra de herramientas, menús y personalización.
- `Assets/`: paisajes originales generados con la herramienta integrada de imágenes; ver `Assets/README.md`.

### Actualización 4.1

El piloto cambia de equipo y postura con el vehículo: chaqueta textil y vaqueros en Street, equipación con gafas y botas en Enduro, mono de cuero en Sport y camiseta, rodilleras y casco abierto en BMX. El color elegido se conserva como acento del conjunto. El acompañante lleva ropa urbana.

El acelerador y la presión de freno tienen respuesta progresiva. Cada neumático dispone de un presupuesto de adherencia longitudinal calculado a partir del contacto, la carga de suspensión y la combinación de superficie y vehículo. El freno combinado reparte la solicitud entre ambos ejes; en el aire no frena la traslación. Las motos tienen retención de motor y la BMX rueda libre. Las bielas y los pies de BMX comparten la fase que modula el empuje de pedaleo. El cuerpo responde suavemente a aceleraciones y frenadas sin soltar sus apoyos.

Sigue siendo física arcade planar: no simula deslizamiento lateral, ABS ni neumáticos deformables. La adherencia limita la fuerza; no es una simulación completa de deslizamiento del neumático.

### Actualización 5.0

Ocho vehículos disponibles desde el taller. Scooter, Scrambler y Trial añaden siluetas, geometrías y ajustes propios; conservan sus índices los cuatro vehículos anteriores y se mantienen sus preferencias.

Las tres rutas tienen cuatro tramos de 300 m: iniciación, técnica, exigente y experto. El relieve aumenta progresivamente su dificultad sin saltos de altura en las transiciones. Los conos opcionales comparten una única distribución entre dibujo y colisión, con menor separación al avanzar. El HUD anuncia los cambios y los carteles del circuito marcan cada tramo. La progresión del terreno funciona también con los conos desactivados. Los récords anteriores quedan conservados bajo su clave previa; la nueva pista usa `v5`.

### Actualización 5.1

Hyper R 1000 disponible junto a los siete vehículos anteriores: superbike con carenado angular propio, alerón lateral, postura recogida, mono de circuito y ajuste de potencia superior. La velocidad se genera mediante fuerzas de tracción y resistencia, con menor resistencia aerodinámica para este carenado. La cámara amplía progresivamente el campo visible a alta velocidad, manteniendo la misma escala para el terreno, el vehículo y los contactos. Comparación en recta plana, después de 30 s con gas y corrección de equilibrio: alrededor de 170 km/h frente a 99 km/h de la Sport 600. El relieve y las frenadas reducen esa velocidad en circuito.

### Actualización 5.2

Objetivos de velocidad en asfalto llano: Street 125 110 km/h, Enduro 250 125 km/h, Sport 600 240 km/h, Scooter 80 85 km/h, Scrambler 400 165 km/h, Trial 200 80 km/h y Hyper R 1000 295 km/h. Son ajustes de los vehículos ficticios del juego, no cifras homologadas de modelos comerciales. La BMX conserva su ajuste previo.

La curva de empuje sigue aportando la fuerza necesaria para compensar resistencia de rodadura y aerodinámica al llegar a su velocidad objetivo. Antes el empuje caía a cero y las puntas configuradas eran inalcanzables. La adherencia sigue limitando la fuerza y la resistencia crece con el cuadrado de la velocidad, siguiendo la [ecuación de resistencia aerodinámica](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/). Se comprueban velocidades efectivas tras 60 s en una recta plana y frenado completo desde cada punta. La cámara adapta su campo visible a la velocidad de cualquier vehículo. El taller muestra el objetivo en recta; el circuito real conserva sus pendientes, saltos y necesidad de frenar. Esta actualización sustituye las cifras de velocidad de la sección 5.1.

### Actualización 5.3

BMX revisada como bicicleta de pedaleo: objetivo aproximado de 35 km/h en llano, respuesta inicial más gradual, cadencia y empuje sincronizados y rueda libre al soltar. No se le aplican los valores de potencia de las motocicletas.

Invertido sobre la rueda delantera: entra con velocidad moderada y combina freno con peso delante (↓ + → o S + D), o mantén E. En Touch Bar puedes mantener FRENO + BAJAR o añadir INVERTIDO desde Personalizar Touch Bar. Suelta el freno y corrige el peso hacia atrás para apoyar de nuevo la rueda trasera. La física usa el contacto delantero real y permite volcar si te pasas de inclinación; no es una animación automática. El HUD y la Touch Bar indican el invertido, y el récord de distancia se conserva por vehículo y ruta junto a los resultados de la partida.

### Actualización 5.4

Corrección de la verificación y de la Hyper R 1000. `test.sh` no compilaba (faltaba `Transmission.swift`) y no ejecutaba las pruebas de transmisión ni de retos; ahora ejecuta todas. Con gas a fondo desde parado, la Hyper R daba la vuelta en unos 2 s (aceleración 9,2 m/s²), en contra de lo descrito arriba; se ha ajustado a 7,0 m/s² (la Sport 600 tiene 6,3) y conserva su punta de unos 295 km/h. Las pruebas de recorrido usan un piloto algo más prudente en Sierra y Dunas (11 m/s menos 1,2 por tramo), porque con el anterior la caída en un aterrizaje cerca del metro 1.151 dependía del vehículo. La prueba de recuperación del invertido entra en la BMX con -0,30 rad en lugar de -0,40, el límite que su batalla corta permite recuperar.

Física: el empuje pierde su palanca sobre el cabeceo a partir de ~0,55 rad, de modo que un caballito de potencia se estabiliza en vez de dar la vuelta; la Hyper R levanta la rueda delantera al arrancar (~0,56 rad) pero no vuelca. En cuesta arriba, sin gas ni freno, la moto rueda hacia atrás (hasta 3 m/s) en lugar de quedarse clavada; cualquier freno la sujeta y el gas la saca si su empuje supera la pendiente. Nuevas pruebas: ningún vehículo vuelca con gas a fondo y rodadura hacia atrás con freno y gas.
