# Wheelie Ride 6.13 · macOS

Juego independiente inspirado en la base de Wheelie Challenge: conducción lateral, caballitos, equilibrio, saltos, vehículos y piloto personalizables. Swift/AppKit nativo, sin navegador, red ni descargas en tiempo de ejecución.

## Diseño nativo de Mac

El taller usa `NSSplitViewController`: lista lateral de vehículos, vista previa sobre fondo neutro e inspector desplazable con los controles reales de macOS. Puedes ocultar ambas columnas desde la barra de herramientas. La ventana se redimensiona libremente y respeta la apariencia del sistema.

Al jugar se retiran los paneles y los botones táctiles móviles. La escena ocupa toda la vista; velocidad, distancia y tiempo se muestran en un HUD compacto. La conducción se realiza con teclado y Touch Bar. Pausa y resultados usan botones nativos y material translúcido de AppKit.

## Mecánicas y personajes

Desde la versión 4 hay una geometría en metros compartida por la física, el vehículo dibujado y los anclajes del piloto: no hay una escala distinta para las ruedas visibles y sus contactos.

- Chasis con masa, movimiento vertical y cabeceo; dos masas de rueda con contacto independiente.
- Muelles, amortiguadores, hundimiento por peso, topes de compresión y extensión. La horquilla cambia el solape de sus tubos y el basculante sigue el eje físico.
- Enduro con mayor recorrido; Sport con menor recorrido; BMX con cuadro rígido y una pequeña flexibilidad de neumáticos.
- Brazos, piernas y torso de longitud fija, con poses resueltas para el asiento, manillar y estriberas de cada vehículo. En BMX, pies y pedales comparten fase y radio.
- Saltos por impulso, aterrizajes que comprimen los muelles y caballitos medidos por el contacto real de ambas ruedas.
- Los conos se tumban y transmiten un golpe a la rueda. El chasis y la suspensión determinan el efecto sobre el equilibrio.
- En las caídas, el piloto se desprende y conserva gravedad, impulso, restricciones de huesos, fricción y contacto con el terreno; la moto continúa asentándose.

Es un modelo de conducción arcade lateral: las ruedas tienen recorrido vertical y el chasis tiene cabeceo; no modela la dirección lateral, deformación completa del neumático ni una moto tridimensional. Los controles de peso incluyen amortiguación para que los caballitos puedan corregirse.

## Esta versión (6.13)

- **Diez vehículos:** Street 125, Enduro 250, Sport 600, BMX, Scooter 80, Scrambler 400, Trial 200, Hyper R 1000, Cruiser 750 y Volt E-8, con geometría, velocidad, aceleración y respuesta distintas.
- **Cinco rutas:** Valle de asfalto, Sierra de tierra, Dunas al atardecer, Nieve y Ciudad bajo la lluvia, de 1.200 m (o de 3.000 y 6.000 m en rodar libre y carrera) en cuatro tramos de dificultad creciente, más un **modo infinito** sin meta, con modo nocturno y clima dinámico opcional.
- **Trucos y puntuación:** caballito, invertido, saltos, volteretas, manos fuera, giro de 360° y superman, con cadenas y multiplicador.
- **Retos:** tutorial guiado, contrarreloj, carrera contra rival, circuito cerrado de tres vueltas con tres rivales, modo infinito y fantasma de tu mejor vuelta.
- **Progresión:** monedas, desbloqueos, estilos comprables de casco, chaqueta y moto, misiones diarias y semanal, estadísticas y logros, tres modos de dificultad.
- **Presentación:** vehículos con mecánica a la vista (motores monocilíndrico, V-twin y cuatro en línea, radiadores, bastidores, escapes, cadena, horquilla con tijas) y piloto con proporciones humanas, volúmenes y materiales propios, color libre de moto, chaqueta, casco y piel, sombras y polvo, fondo en capas de Core Animation a 60 fps, sonido sintetizado de motor, rodadura, ambiente e interfaz.
- **Mac nativo:** ventana Retina, pantalla completa, barra de herramientas personalizable, menús, atajos y Touch Bar.
- Récords separados por vehículo, ruta, dificultad y clima. Las preferencias de versiones anteriores se conservan; los récords nuevos usan un espacio separado (`v5`) porque la física cambió, y los anteriores permanecen guardados.

No contiene todo el catálogo de vehículos ni las pistas del juego original. El código y el arte utilizado en la app son propios. Las referencias visuales consultadas no se incluyen en el paquete.

Limitaciones conocidas: el modelo es plano (sin derrape lateral ni neumáticos deformables), no hay rutas con bifurcaciones, y el ajuste de equilibrio (precios, dificultad del rival, sensaciones de conducción) se hizo con pilotos simulados, no con sesiones de juego largas.

## Teclado y ratón

| Acción | Tecla |
|---|---|
| Acelerar | ↑ / W |
| Levantar | ← / A |
| Corregir hacia delante | → / D |
| Frenar | ↓ / S |
| Invertido (sobre la rueda delantera) | Mantener E, o ↓ + → |
| Saltar | Espacio |
| Truco / voltereta | Mantener T al saltar y ← o → en el aire; soltar T pasada la media vuelta |
| Manos fuera del manillar | Mantener H (sin peso ni freno delantero; el piloto levanta un brazo) |
| Giro de 360° | Mantener G en el aire (suelta para alinear) |
| Superman | Mantener V en el aire (≥ 0,4 s): el piloto se tumba sobre el asiento con las piernas estiradas hacia atrás |
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

## Actualización automática de la app instalada

Cada commit que cambie la app se instala también en `~/Applications/Wheelie Ride.app`, con copia de seguridad de la versión anterior. Las reglas y los pasos están en [`CLAUDE.md`](CLAUDE.md), que Claude Code carga al trabajar en esta carpeta. Para hacerlo a mano: `./build.sh --install` (con la app cerrada).

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
- Caída del muñeco durante cinco segundos sobre los terrenos: gravedad, impulso, huesos, contacto y estabilidad entre frecuencias de imagen.
- Touch Bar: controles deshabilitados en taller/pausa, parejas de pulsación/liberación, telemetría, cancelación de combinaciones y pérdida de foco.
- Transmisión (marchas, embrague, limitador, BMX y CVT) y retos con fantasma: persistencia por contexto, interpolación, límites de grabación y rechazo de datos corruptos.
- Puntuación (cadenas, multiplicador, pérdida al caer), monedas y desbloqueos, migración de jugadores existentes.
- Voltereta en el aire, charcos, ABS, mezcla de obstáculos y todas las rutas con el piloto prudente.
- Estadísticas, logros, misiones por fecha, tutorial, niveles del rival, desgaste, modo infinito, giro y manos fuera.
- Audio offline: muestras finitas y de volumen acotado, canales estéreo, silencio, impacto y BMX. No abre altavoces.

La app también acepta `--smoke-test` para probar su máquina de estados real con una ventana efímera y preferencias aisladas. Incluye una caída completa con desprendimiento del piloto y paso a resultados. Las pruebas de interfaz incluyen selección de moto/ruta, personalización, acompañante, aceleración, caballito, freno, pausa y atajo para volver al taller. La regresión de Touch Bar comprueba la misma barra en ventana, controlador y botones Continuar/Reiniciar al tomar el foco; también comprueba bloqueo modal, recuperación y resultados.

## Archivos

- `Sources/VehicleRig.swift`: dimensiones, masas, recorridos y anclajes compartidos.
- `Sources/BikePhysics.swift`: chasis, ruedas, muelles, amortiguadores y contactos.
- `Sources/Transmission.swift`: caja de cambios manual/automática, embrague, limitador y CVT del scooter.
- `Sources/RideScore.swift`: puntos, cadenas y multiplicador.
- `Sources/RideStats.swift`: estadísticas de por vida y logros.
- `Sources/RideMissions.swift`: misiones diarias y semanal.
- `Sources/RideTutorial.swift`: tutorial guiado de seis pasos.
- `Sources/RideRival.swift`: rival con niveles, errores y volteretas.
- `Sources/RideProgress.swift`: monedas y desbloqueos.
- `Sources/RideChallenges.swift`: retos (caballito, invertido, salto, contrarreloj) y fantasma de la mejor vuelta.
- `Sources/RiderRig.swift`: postura y cinemática inversa del piloto.
- `Sources/RiderRagdoll.swift`: caída del personaje desprendido.
- `Sources/VehicleArtwork.swift`: ruedas, frenos, basculante, amortiguador, horquilla, bastidor, motores, escapes y manillar.
- `Sources/VehicleBodies.swift`: carrocería de cada vehículo (depósito, carenados, faros, asientos).
- `Sources/RiderArtwork.swift`: dibujo del muñeco a partir del esqueleto resuelto.
- `Sources/Renderer.swift`: carretera, motocicletas y piloto articulado.
- `Sources/GameView.swift`: estado de la partida, preferencias, entrada y récords (clase `RideView`). El resto de `RideView` está repartido en extensiones: `RideView+Simulation.swift` (bucle de fotograma y colisiones), `RideView+Rules.swift` (reglas de la partida: puntos, rival, tutorial, misiones, avisos), `RideView+Overlay.swift` (pausa y resultados), `RideView+Drawing.swift` (escena), `RideView+HUD.swift` (marcador), `RideBackdrop.swift` (fondo y velos como capas de Core Animation) y `RideLayers.swift` (vistas por capas y captura compuesta).
- `Sources/RideRace.swift`: posiciones, adelantamientos y premios de carrera.
- `Sources/RideCosmetics.swift`: estilos de casco, chaqueta y decoración.
- `Sources/RideWeather.swift`: niebla, tormentas y relámpagos a lo largo de la ruta.
- `Sources/RideProfile.swift`: medidor de tiempo por sección para `--bench`.
- `Sources/TouchBarController.swift`: controles Touch Bar nativos.
- `Sources/EngineAudio.swift`: síntesis local sin micrófono.
- `Sources/NativeGarage.swift`: biblioteca lateral e inspector nativos.
- `Sources/main.swift`: ventana dividida, barra de herramientas, menús y personalización.
- `Assets/`: paisajes originales generados con la herramienta integrada de imágenes; ver `Assets/README.md`.

## Historial de versiones

Las descripciones de abajo son el diario de cada versión; el estado actual está en «Esta versión». Si una cifra difiere, vale la de la versión más reciente.

### Actualización 4.1

El piloto cambia de equipo y postura con el vehículo: chaqueta textil y vaqueros en Street, equipación con gafas y botas en Enduro, mono de cuero en Sport y camiseta, rodilleras y casco abierto en BMX. El color elegido se conserva como acento del conjunto. El acompañante lleva ropa urbana.

El acelerador y la presión de freno tienen respuesta progresiva. Cada neumático dispone de un presupuesto de adherencia longitudinal calculado a partir del contacto, la carga de suspensión y la combinación de superficie y vehículo. El freno combinado reparte la solicitud entre ambos ejes; en el aire no frena la traslación. Las motos tienen retención de motor y la BMX rueda libre. Las bielas y los pies de BMX comparten la fase que modula el empuje de pedaleo. El cuerpo responde suavemente a aceleraciones y frenadas sin soltar sus apoyos.

Sigue siendo física arcade planar: no simula deslizamiento lateral, ABS ni neumáticos deformables. La adherencia limita la fuerza; no es una simulación completa de deslizamiento del neumático.

### Actualización 5.0

Ocho vehículos disponibles desde el taller (Cruiser 750 y Volt E-8 llegaron en 6.5). Scooter, Scrambler y Trial añaden siluetas, geometrías y ajustes propios; conservan sus índices los cuatro vehículos anteriores y se mantienen sus preferencias.

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

### Actualización 6.0

- **Rampas más justas:** más anchas, más bajas y más separadas, con una zona de aterrizaje larga. El piloto prudente de las pruebas vuelve a recorrer todas las rutas a 12 m/s.
- **Trucos en el aire:** mantén T en el aire con ← (voltereta hacia atrás) o → (hacia delante). Con T el amortiguamiento de giro se relaja y se conserva el momento angular; al soltar T vuelve a estabilizarse. El ángulo se mide con la moto en contacto: puedes girar libremente y se cae al aterrizar mal.
- **Puntos y combos:** caballito (12/m), invertido (30/m), saltos (por tiempo y altura), volteretas (400 cada una) y obstáculos esquivados (30). Cada tipo distinto de truco suma +0,5 al multiplicador. La cadena se guarda tras 2,5 s sin trucos; si te caes con una cadena abierta, pierdes esos puntos. Récord de puntos por vehículo y ruta.
- **Fantasma por tramos:** el HUD muestra la diferencia en segundos con tu mejor vuelta y, al cruzar cada tramo, cuánto has ganado o perdido. Los resultados listan los cuatro tramos.
- **Monedas y desbloqueos:** 1 moneda cada 80 m y 1 por cada 200 puntos. Empiezas con 150; Scooter 40, Sport y Scrambler 80, Trial 100, Hyper R 220, Dunas 60, Nieve y Ciudad 100. Los jugadores con récords anteriores conservan todo.
- **Rutas nuevas:** Nieve (poca adherencia, pinos y nevada) y Ciudad bajo la lluvia (asfalto mojado, rascacielos y farolas). Se dibujan por código, sin nuevas imágenes.
- **Obstáculos variados:** conos, barriles (más duros) y troncos bajos que se pueden saltar, según el tramo; charcos que cortan la adherencia un 45 %. Se activan con "Obstáculos y charcos".
- **Carrera contra rival:** nuevo reto con un rival de la misma física y vehículo (turquesa) que rueda como el piloto prudente. Gana quien llegue antes; si el rival cae, ganas al terminar.
- **Física:** el amortiguamiento de giro cambia de forma continua en vez de saltar entre valores. **Frenos ABS** opcional: sin deslizamiento de frenada y fuerza justo por debajo del límite de adherencia (frena menos distancia en nieve y tierra). Sigue sin haber derrape lateral: el modelo es plano.
- **Distribución:** `./package.sh` genera `build/WheelieRide-<versión>.dmg`. Sin certificado la firma es ad hoc; con `SIGN_IDENTITY="Developer ID Application: …"` (y `NOTARY_PROFILE` para notarizar) firma el app y el dmg. `.github/workflows/wheelie-mac.yml` ejecuta `test.sh` y compila en cada push.
- La suspensión ya tenía controles en el inspector del taller (dureza y amortiguación por vehículo).

### Actualización 6.1

Aviso honesto: no he jugado esta versión a mano. El ajuste fino se hizo con pilotos simulados (los mismos de las pruebas) y capturas de pantalla; conviene una tarde de juego para afinar sensaciones y precios.

- **Volteretas afinadas:** con T pulsada al saltar, el impulso sube un 60 %, lo que da tiempo de giro. Mientras mantienes T giras; al soltarla pasada la media vuelta el piloto "se compromete" y nivela la moto para aterrizar (soltar antes aborta la voltereta). Con una prueba que recorre los ocho vehículos, todos aterrizan voltereta hacia atrás y hacia delante desde un salto en parado; antes la hacia atrás casi nunca salía. Sin T, un salto en parado no gira.
- **Más trucos:** manos fuera del manillar (H: sin peso ni freno delantero, 40 puntos/s a más de 6 m/s; combina con el caballito), giro de 360° (G en el aire: la moto gira sobre su eje vertical, se dibuja como un aplastamiento horizontal; soltar alinea, aterrizar de lado se cae; 350 puntos/giro) y superman (V en el aire, 200 + 80/s). Entran en el combo como tipos distintos. No hay animaciones nuevas del piloto: el superman lo muestra echándose atrás y levantándose del asiento. El giro 360° es una ilusión visual: el modelo sigue siendo plano.
- **Tutorial guiado** (reto "Tutorial guiado"): acelerar, caballito de 4 m, corregir, frenar, saltar y voltereta, con banner y barra de progreso, sin obstáculos. +40 monedas la primera vez.
- **Misiones:** tres diarias y una semanal, distintas cada día (se generan de la fecha), con recompensa en monedas. Se listan en el taller. Una misión completada no paga dos veces.
- **Estadísticas y logros:** totales de por vida y 14 logros (hay botón en el taller). Los logros pagan monedas.
- **Rival con carácter:** niveles fácil, normal y experto (velocidad, errores humanos ocasionales); puede usar otro vehículo; el experto salta y hace volteretas en rutas lisas (valle, nieve y ciudad). En la simulación terminan la ruta el 93 %, 98 % y 99 % de las veces y los tiempos medios son 129, 113 y 106 s.
- **Desgaste:** los neumáticos pierden hasta un 30 % de adherencia por derrapes y frenadas al límite; los amortiguadores se calientan en terreno roto y pierden hasta un 35 % de amortiguación. Ambos se muestran en el HUD y se reponen en cada salida.
- **Modo infinito:** sin meta; el último tramo se repite con obstáculos cada 25 m y se anuncia cada vuelta de 1.200 m. No es un circuito cerrado: el terreno no se repite. Su récord es aparte.
- **Noche con faro:** en modo noche la moto proyecta un haz de luz.
- **Sonido ambiental:** lluvia y zumbido de ciudad en la ruta Ciudad, viento en Nieve (más fuerte con la velocidad) y brisa en Dunas. Solo suena con el sonido activado y en partida.
- **Pruebas de interfaz:** el smoke test recorre el taller con los controles reales (saldo, bloqueos, compras, retos, rival, ABS, obstáculos), la carrera, el tutorial, el modo infinito, las teclas de truco y una ruta completa hasta la meta comprobando monedas, estadísticas, logros y que no se cuente dos veces. `--snapshot <carpeta>` guarda capturas de rutas, noche, tutorial y giro.

### Actualización 6.2

Cierra las limitaciones de 6.1 hasta donde el modelo lo permite.

- **Poses nuevas del piloto:** el esqueleto del piloto tiene ahora mezclas continuas de "manos fuera" (el brazo se separa del manillar y sube) y "superman" (cuerpo plano, piernas estiradas hacia atrás, manos en el manillar). Las pruebas comprueban longitudes de hueso exactas, que las mezclas no den saltos y que las poses en reposo no cambien (44.352 poses del test anterior siguen idénticas).
- **Circuito cerrado:** reto "Circuito cerrado · 3 vueltas". El terreno se repite cada 1.200 m de verdad (ondulaciones con un número entero de ciclos, suelo y pendiente continuos en la costura, zona de salida plana), con línea de meta a cada vuelta, tiempo por vuelta, comparación con el fantasma y rival. Dificultad constante. Las pruebas recorren dos vueltas con los ocho vehículos en las cinco rutas.
- **Aterrizaje de las volteretas:** al soltar T el piloto nivela la moto con el terreno donde va a aterrizar (pendiente 0,2 s por delante), no con la horizontal.
- **Giro de 360°:** sigue siendo una ilusión (el modelo es plano), pero ahora deja dos imágenes residuales tenues que sugieren el giro.
- **Rival experto en tierra y dunas:** no resuelto. Investigué por qué: en terreno roto la moto rebota casi continuamente y, aunque el rival sólo salte en rampas reales y con tiempo de enfriamiento, aun así se cae en torno al 40-70 % de las rutas con volteretas. Sin volteretas termina el 98 %. Por eso el rival experto sigue haciendo volteretas únicamente en valle, nieve y ciudad.

### Actualización 6.3

- **Avisos en partida:** cuando un logro o una misión queda a tu alcance durante la ruta, aparece un aviso dorado ("★ Logro: …", "★ Misión cumplida: …"). Se calcula con una vista previa que no cambia nada; las monedas se cobran al terminar la ruta, como antes. Un aviso no se repite en la misma salida.
- **Dificultad:** tres modos en el taller. *Asistido* nivela la moto antes de aterrizar (también tras saltos normales y rampas), perdona inclinaciones mayores, gasta los neumáticos a la mitad y da un 25 % menos de monedas. *Normal* es el equilibrio de siempre. *Realista* no nivela las volteretas por ti (soltar T deja la moto girando), es más estricto con la inclinación, gasta el doble y da un 25 % más de monedas. Los récords y fantasmas son independientes por modo.
- **Rival experto en tierra y dunas:** resuelto. La causa no era el terreno en sí, sino el tiempo en el aire: en terreno roto los saltos son más cortos y el rival aterrizaba a mitad de giro. Ahora calcula cuánto aire le queda (altura de la rueda, velocidad vertical y terreno de aterrizaje) y, si no le da para terminar la voltereta, suelta y nivela la moto. Sin cambios de modelo: en la simulación el experto hace unas 120 volteretas en las cinco rutas y se cae en 1 de 120 salidas (antes entre el 40 y el 70 % de las salidas con volteretas en tierra).
- **Medición de rendimiento (`--bench`):** imprime el coste por fotograma (simulación y dibujo) de seis escenas, con el desglose por sección. El smoke test lo ejecuta con una guarda *relativa* (ninguna escena cuesta más de 4 veces el valle sin adornos, ni medio segundo) para no fallar en máquinas lentas. Resultado honesto en este Mac, dibujando a resolución nativa Retina por CPU: valle 31 ms, Sierra con obstáculos 45 ms, nieve 45 ms, ciudad con lluvia y noche 75 ms, con rival 79 ms. Es decir, **por debajo de 60 fps**: la causa es el número de pasadas a pantalla completa (cada una cuesta unos 6 ms a 2482×1504). Mejoras ya aplicadas: fondos prerrenderizados y copiados con Core Graphics (la ciudad pasó de 110 a 75 ms), degradados cacheados, lluvia y nieve en un solo trazado, recorte de carretera sin antialiasing y sin relleno redundante de ventana. A 1× (sin Retina) la misma escena pesada baja a 30 ms. Esa limitación quedó resuelta en 6.4 (más abajo).
- **Refactor de `GameView.swift`:** de 585 líneas a 175 más cinco extensiones por responsabilidad. Sin cambios de comportamiento: las 9 suites y el smoke test pasan igual.
- **CI:** el runner `macos-14` no está soportado en este repositorio (el job se cancelaba al instante); el workflow usa `macos-latest`. La primera ejecución real descubrió además que unas expresiones de `AudioTests` tardan demasiado en compilarse con el compilador más nuevo del runner; ya están simplificadas.

### Actualización 6.4

**Fondo y velos en capas de Core Animation (GPU).** La escena ya no se dibuja entera por CPU. Desde atrás hacia delante: fondo (capas GPU) → mundo (CPU: carretera, obstáculos, rival, fantasma, piloto, lluvia y nieve) → sombreado de bordes (capas GPU) → marcador (CPU). El taller sigue dibujándose como antes.

- **Fondo (`RideBackdrop`):** las fotografías del valle y las dunas se reescalan una sola vez y se deslizan como dos capas con paralaje (las teselas alternas se espejan para que las costuras casen); la nieve son cuatro capas de montañas con un único trazado cada una; la ciudad son tres tiras de edificios horneadas una vez (con sus ventanas) que se deslizan; cielos, tintes, velo nocturno, luna, estrellas y neblina son capas estáticas. Por fotograma solo se mueven unas pocas posiciones (0,1–0,2 ms).
- **Sombreado de bordes (`RideOverlay`):** dos capas de degradado estáticas sobre el mundo y bajo el marcador, para que el texto siga nítido.
- **Medición:** coste de CPU por fotograma (simulación, capas y dibujo de mundo y marcador, a resolución Retina nativa): valle 31 → 15-16 ms, Sierra con obstáculos 45 → 17 ms, nieve 45 → 14-16 ms, ciudad con lluvia y noche 75 → 15-16 ms, con rival 79 → 19-21 ms, circuito 62 → 17-22 ms (varía unos milisegundos entre ejecuciones). **Fotogramas reales en la ventana** (`--fps`, impulsado por el temporizador a 60 Hz del juego): 60 fps constantes en valle, Sierra, nieve y ciudad con lluvia y noche.
- **Pruebas:** el smoke test comprueba que en todas las rutas, de día y de noche, con tres alturas de ventana y 400 posiciones de cámara, las capas del fondo cubren siempre la ventana sin huecos; que cada ruta compone un fotograma; y mantiene la guarda de coste relativo.
- **Herramientas de desarrollo:** `--snapshot <carpeta>` (composición por software), `--screenshot <carpeta>` (captura de la ventana real, con las capas GPU) y `--fps` (fotogramas por segundo reales). `--bench` ahora mide el coste de CPU.
- Un fallo encontrado y corregido gracias a la captura de la ventana real: la invalidación de las capas leía `needsDisplay` tras asignarlo, y para una ventana que no está en pantalla devuelve falso, así que el fondo se quedaba en la ruta anterior.

### Actualización 6.5

- **Touch Bar:** tres botones nuevos en *Personalizar Touch Bar…* (visibles en partida): **SIN MANOS** (✋), **GIRO 360** (⟳) y **SUPERMAN** (✈︎). Se mantienen pulsados igual que H, G y V, se combinan con otros dedos y se sueltan al pausar o perder el foco. Las pruebas de Touch Bar los cubren.
- **Sonidos de interfaz y trucos:** ocho efectos sintetizados, sin archivos de audio: arpegio de logro o misión, moneda al cobrar una cadena o comprar, golpe con destello al aterrizar una voltereta, "whoosh" del giro 360°, golpe suave al aterrizar un salto largo, tic de combo que sube con el multiplicador, zumbido grave al denegar una compra y trueno. Suenan siempre que el sonido esté activo, también en el taller. Solo hay 6 voces simultáneas y la prueba comprueba que ninguna se corta, satura ni suena en silencio.
- **Carrera por vueltas con tres rivales:** el *Circuito cerrado* ahora corre contra tres rivales de niveles repartidos alrededor del elegido (cada uno con su moto o la tuya, con otro color). HUD con **posición** y distancia al siguiente; aviso y puntos (+80) al **adelantar**; el podio (1.º o 2.º) completa el reto. El duelo contra un rival sigue siendo 1.º o nada. Premios en monedas: duelo 25; con rivales múltiples 40 / 20 / 8 para 1.º / 2.º / 3.º. Los rivales caídos se quedan donde cayeron y no cuentan como adelantamiento.
- **Personalización comprable:** sección *Estilo (con monedas)* en el taller. Cascos: franja central (30), llamas (50), visera dorada (70). Chaquetas: bandas reflectantes (25), rayas de carreras (40), bicolor (60). Moto: dorsal con número (35), rayas deportivas (45), cuadros de meta (60). Los colores base siguen siendo gratis. Elegir un estilo que no tienes bloquea *Rodar* hasta comprarlo (se compra con el mismo botón de desbloqueo, varios a la vez). La vista previa lo muestra antes de pagar. Las decoraciones de la moto van en la zona de cola, no en el depósito (lo tapa el piloto), y no se dibujan en la BMX.
- **Clima dinámico:** niebla en el valle y las dunas, tormenta con relámpagos en la Sierra y la ciudad, ventisca en la nieve, cada una a mitad de ruta (suave al entrar y salir). Efectos reales: la lluvia moja la carretera (hasta un 25 % menos de adherencia), la niebla vela el paisaje (capas GPU), los relámpagos iluminan la escena y el trueno llega unos 0,9 s después; el sonido de la lluvia sigue su intensidad. Casilla *Clima dinámico* en el taller, activada por defecto, con **récords propios** (sufijo `.clima`); desactivada, el juego es el de antes (la ciudad sigue lloviendo). Hay etiqueta en el marcador ("NIEBLA DENSA", "TORMENTA").
- **Dos vehículos nuevos:** **Cruiser 750** (120 monedas): larga, baja y pesada, asiento bajo, manillar alto, pies adelantados, alforja y respaldo; V-twin grave, 150 km/h. **Volt E-8** (150 monedas): eléctrica, una sola marcha, par instantáneo, 130 km/h, batería con luces verdes. Es **silenciosa**: no tiene voz de motor, solo ruido de rodadura (no he sintetizado un zumbido eléctrico). Pasan todas las pruebas de física, giros, tutorial y rival con los diez vehículos.
- **No hecho: rutas con bifurcaciones.** El terreno es una única función de la distancia: una bifurcación real (dos caminos a la vez, con elección) exige un modelo de terreno por carril, cámara y obstáculos por carril, rival y fantasma por carril. No he querido fingirlo con un salto decorativo; queda como trabajo de diseño propio.

### Actualización 6.6

Rediseño del arte de motos y piloto. La física y la geometría del rig no cambian (los 55.440 poses y todas las suites pasan igual); solo cambia cómo se dibujan.

- **Piloto con proporciones humanas:** extremidades ahusadas con musculatura (muslo, gemelo, bíceps, antebrazo), torso con curva lumbar y hombros, pelvis sentada, cuello, y cabeza con perfil. Manos con palma, cuatro dedos y pulgar sobre el puño, con guantes de cuero o protecciones según el equipo; zapatillas con suela y cordones, botas de cuero con puntera y botas de enduro con hebillas; rodilleras, deslizadores, coderas, hump de espalda y paneles del mono. Casco integral con carcasa moldeada, visera tintada con sello de goma, pivote y reflejo, ventilaciones, goma en la base, pico y gafas en enduro. Los guantes cierran el puño sobre el manillar (nudillos acorazados en deportiva y enduro) y se ve el contrapeso del extremo del manillar.
- **Motos con mecánica a la vista:** bastidor visible por tipo (cuna de acero, doble viga de aluminio, cuna abierta), motores monocilíndrico con aletas, V-twin de 45° con varillas cromadas y cuatro en línea con colectores, radiadores con mangueras, escapes propios (silenciador de titanio bajo el colín en las deportivas, cámara de expansión en el enduro, tubos escalonados en la custom, tubo alto con protector en la scrambler), basculante con refuerzo y tensor, cadena con piñón y corona dentados, amortiguador con depósito remoto, horquilla invertida en las deportivas con tijas, pinzas de freno (radial en las deportivas), discos ondulados y llantas de radios cruzados, de cinco brazos o de tres.
- **Carrocerías por vehículo:** deportivas con colín, depósito, carenado, quilla y pantalla (esquinas suavizadas, sin formas de huevo); Street y Scrambler retro con faro cromado; enduro con tomas de radiador, porta número y guardabarros; Cruiser con depósito de gota, guardabarros profundos, alforja de cuero y respaldo; Scooter con escudo, plataforma y tapa de transmisión; Trial esquelética; Volt E-8 con batería aleteada y motor central.
- **Revisión con Gemini y ajustes:** los brazos ya no se bloquean (el solver deja siempre unos 4 cm de holgura, un codo de unos 140°, y el torso se inclina hacia el manillar; los 55.440 poses siguen exactos); el casco es un 9 % más pequeño y el cuello más grueso; el colín de la Sport y la Hyper es más corto y más alto; la caja de aire del enduro ya no parece una maleta; la Volt E-8 lleva una viga fina en lugar de un depósito de gasolina. Descartado por no ser un defecto: la rueda delantera levantada en las capturas es el caballito de la física.
- **Rendimiento:** el dibujo de moto y piloto cuesta unos 9,5 ms de CPU por fotograma (antes el fotograma completo rondaba 15 a 17 ms); en la ventana real se miden 58,5 a 60 fps en las cuatro escenas de `--fps`.
- **Icono nuevo:** la Sport cian con el piloto en un caballito sobre un atardecer retro (sol con franjas, montañas y carretera), ajustado a la rejilla de macOS con margen y sombra. Se regenera con `make-icon.swift` (receta en `Assets/README.md`).
- **Herramientas:** `--snapshot` guarda además `lineup-<vehículo>.png` con los diez vehículos en la misma pose, para revisar el arte.
- No he jugado a mano esta versión: la revisión visual se hizo con capturas. Pendiente de revisar en pantalla: aspecto de la BMX (solo cambió el piloto, el cuadro tiene más detalle), colores secundarios fijos (negro, plata, cromo) que no siguen el color elegido, y cómo queda la combinación de estilos comprados con las nuevas carrocerías.

### Actualización 6.7

La app es responsive: la partida y el taller se adaptan a cualquier tamaño de ventana.

- **Escena:** el lienzo lógico ya no es de 1280 puntos fijos. Se escala por la altura (720 puntos lógicos) y su ancho sigue a la ventana, entre 900 y 1700 puntos: una ventana ancha o ultrapanorámica enseña más carretera por delante, una estrecha o baja no recorta la moto ni el marcador. La moto se coloca al 29 % del ancho y el suelo al 63,6 % del alto. El fondo, el sombreado y las nubes se reconstruyen por escalones de ancho para no rehacerlos en cada píxel al redimensionar.
- **Marcador:** velocidad, tiempo, puntos, posición, avisos y tutorial se anclan a los bordes o al centro de la ventana en vez de a coordenadas fijas. En carrera, las líneas de posición ya no se solapan con el cuadro de puntos.
- **Taller:** el tamaño mínimo de la ventana baja de 1000×620 a 760×520. Por debajo de 1060 puntos de ancho se oculta la lista lateral de vehículos y un selector **Vehículo** al principio del panel de ajustes la sustituye (también existe en ventanas anchas). La vista previa de la moto ya se escalaba al espacio disponible.
- **Herramientas:** `--responsive <carpeta>` captura la partida a seis tamaños de ventana y el taller real (ancho y estrecho). No guarda esos tamaños como la posición de ventana del usuario, y el smoke test fija su propio tamaño sin guardarlo.
- Pendiente de revisar a mano: ventanas muy estrechas (≈760 pt) con el marcador cargado en carrera con tres rivales, y pantalla completa en monitores ultrapanorámicos.

### Actualización 6.8

Taller más corto: el panel de ajustes ya no es una columna de nueve secciones abiertas.

- **Secciones plegables:** cada sección es una cabecera con triángulo que se despliega o se pliega, y el estado se recuerda entre sesiones. Al empezar solo están abiertas **Vehículo**, **Reto** (modo de juego y rival) y **Ruta** (con la casilla de noche); el resto está plegado y la cabecera de Monedas muestra el saldo.
- **Orden nuevo:** Vehículo, Reto, Ruta, Opciones (casco, acompañante, obstáculos, ABS y clima), Conducción (cambio y suspensión), Apariencia, Estilo con monedas, Monedas, Misiones y Récord de la ruta. Lo que se toca en cada salida va arriba y lo que se ajusta una vez abajo. La antigua sección «Piloto y circuito» se llamaba así por error: contenía las opciones de partida.
- Los controles plegados siguen funcionando igual (las pruebas de interfaz los manejan con sus acciones reales).

### Actualización 6.9

Modo infinito de verdad y rutas largas. Ambos comparten un generador de terreno procedural.

- **Modo infinito:** sin meta y sin límite de 1.200 m. El terreno se genera mientras avanzas y cada partida es distinta. Cada 240 m cambia de **zona**, con transiciones suaves entre ellas: **Colinas**, **Saltos** (rampas de distinta altura y separación), **Terreno roto** (baches de alta frecuencia), **Cuestas** (subidas y bajadas largas) y **Respiro** (un tramo calmado, cada vez menos frecuente). La dificultad crece con la distancia hacia un tope (nivel nuevo cada 600 m): rampas más altas, terreno más rugoso y obstáculos cada vez más seguidos (de uno cada ~95 m a uno cada ~25 m). Hay cartel de nivel cada 600 m, aviso al entrar en cada zona y marcador «INFINITO · NIVEL n · ZONA». Los obstáculos nunca caen sobre una rampa ni en un respiro. Récord de distancia aparte.
- **Rutas largas:** nuevo selector **Longitud** en la sección Ruta del taller: Clásica 1.200 m (el terreno de siempre), Larga 3.000 m y Maratón 6.000 m, para rodar libre y carrera. Las largas usan el mismo generador (con meta, tramos de un cuarto de la longitud y la misma subida de dificultad) con una semilla fija por ruta y longitud, así que los récords y el fantasma comparan lo mismo. Cada longitud tiene su propio récord. Contrarreloj, retos, tutorial y circuito siguen en el recorrido clásico.
- **Dónde está:** «Modo infinito» y «Carrera contra rival» pasan a los primeros puestos de la lista de retos (justo tras Rodar libre).
- **Verificación:** el terreno es continuo con pendiente acotada en las cinco rutas (12 km, paso de 5 cm), determinista, y las zonas varían sin repetir cuestas ni respiros seguidos. Un piloto prudente recorre 3.000 m en cuatro vehículos y cinco rutas, y llega a 4.000 m en el infinito. Al ajustar el generador se midió que el piloto automático se caía en «Terreno roto» de la Sierra (13 de 72 carreras con los tres vehículos peores); se suavizó esa zona y quedó en 0 de 72. En total, 0 caídas en 480 carreras de infinito en las otras cuatro rutas.
- Solo se dibujan y comprueban los obstáculos cercanos a la moto (búsqueda binaria), porque un infinito tiene miles.
- Pendiente de revisar a mano: sensación de las cuestas y del terreno roto con otras motos, ritmo de la dificultad pasados los 5.000 m y cómo se ve el fondo con rutas muy largas.

### Actualización 6.10

Caída del piloto rehecha.

- **Impulso propio:** el piloto sale con la velocidad que llevaba (un filtro de la velocidad de la moto de unos 0,2 s), no con la de la moto en el instante del choque. Antes, cuando la moto volcaba y se paraba en seco, el piloto salía casi sin velocidad y el giro de la moto sin limitar lo lanzaba hacia atrás y fuera de la pantalla. Ahora solo hereda la mitad del giro (máximo ±3 rad/s) y la velocidad vertical se acota, de modo que en un volteo hacia delante vuela hacia delante, describe un arco, aterriza y se desliza, siempre a la vista.
- **Articulaciones con sentido:** rodillas y codos solo doblan hacia su lado: si una articulación se doblaba al revés se refleja respecto a la línea entre sus vecinas (las longitudes de hueso se conservan).
- **Herramienta:** `--crash <carpeta>` guarda tiras de tres caídas (looping de caballito, volteo sobre la rueda delantera y aterrizaje a alta velocidad) para revisarlas.
- No he jugado a mano esta versión. Pendiente: el piloto no choca con la moto ni con los obstáculos mientras cae, y la cámara no lo sigue si sale muy lejos.

### Actualización 6.11

- **Ruedas con desenfoque de giro:** a partir de unos 16 rad/s (≈ 18 km/h en una moto normal) los radios se atenúan y los sustituye un disco translúcido con estelas tenues, hasta un 85 % a toda velocidad. Se aplica a tu moto, a los rivales y al fantasma; la vista previa del taller sigue nítida.
- Pendiente (sigue sin sentirse bien, según tu valoración): formas y proporciones de algunas motos, animación del conjunto moto-piloto en marcha y nivel de acabado. Para acertar necesito que me digas qué moto y qué momento (parada, aceleración, caballito, salto) ves peor.

### Actualización 6.12

Revisión del icono: la moto es un 8 % mayor y está más centrada; el sol es más grande y sus franjas ya no se salen del disco; el polvo y las rayas de la carretera quedan dentro de la esquina redondeada del icono en vez de recortados. Se lee igual a 128, 64 y 32 px sobre fondo claro y oscuro.

### Actualización 6.13

- **La moto es sólida para el piloto que cae:** mientras cae, el ragdoll choca contra las dos ruedas y el chasis de la moto caída (tres círculos que se actualizan cada fotograma). Una partícula solo choca después de haber salido una vez de la moto, porque el piloto empieza sentado dentro de ella. Nueva prueba: un piloto lanzado contra un sólido nunca lo atraviesa más de 16 cm y sus huesos siguen íntegros.
- **BMX:** el manillar baja de 81 a 72 unidades de dibujo (de chopper a BMX); el solver del piloto sigue exacto con los 55.440 poses.
- **Android:** la versión `wheelie/` queda documentada como congelada en la 1.1.

## Estado final y límites conocidos

Lo que está verificado: 10 conjuntos de pruebas automáticas (física a 30/120 fps, 55.440 poses del piloto con huesos exactos, ragdoll, terreno procedural, puntuación, progreso, clima, Touch Bar lógica, audio), un smoke test de la app real con ventana efímera (taller, carrera, tutorial, infinito, ruta larga, caída, Touch Bar), medición de fotogramas (58 a 60 fps) y capturas de todos los vehículos, tamaños de ventana, zonas del infinito y caídas.

Lo que **no** se ha podido comprobar y conviene revisar jugando:

- **Sensación de las motos:** forma, animación y acabado se han mejorado con revisión de capturas, pero no con juego prolongado. Si algo sigue pareciendo falso, anotar moto y momento (parada, aceleración, caballito, salto).
- **Equilibrio:** precios, monedas y dificultad de los rivales no están calibrados con personas; el modo infinito se calibró con un piloto automático prudente (0 caídas en 480 carreras en cuatro rutas y 0 en 72 en la Sierra tras suavizar el terreno roto).
- **Touch Bar:** la lógica está probada, pero no sobre hardware con Touch Bar.
- **Ventanas muy estrechas** (≈ 760 pt) con el marcador cargado en carrera con tres rivales, y pantalla completa en monitores ultrapanorámicos.
- **No existe:** modo de rutas con bifurcaciones (exige un modelo de terreno por carril, con cámara, obstáculos, rival y fantasma por carril).
- **Caída del piloto:** no choca con los obstáculos del terreno, y la cámara no lo sigue si sale muy lejos.

