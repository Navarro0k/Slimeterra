# Plan: intro de cámara, ayuda contextual en el HUD y más mapa vertical con fondo

> Objetivo (los 3 cambios pedidos):
> 1. Al iniciar el nivel, la cámara hace un **recorrido mostrando todo el mapa**.
> 2. Los **carteles explicativos** dejan de abrirse siempre al arrancar: pasan a un
>    **botón `?` en el HUD**. La primera vez que se juega el nivel la información
>    aparece sola; después se relee pulsando `?`.
> 3. Se **aumenta la vista vertical** (se ve más mapa de arriba a abajo) y se añade
>    un **fondo** para que nunca se vea el gris por defecto de Godot.
>
> Restricción: no cambia el contenido de `CartillaContenido`, ni la física, ni el
> inventario, ni los tiempos de estrellas.

---

## 1. Alcance

### Sí entra
- Cinemática de entrada de cámara (paneo por el mapa + retorno al disparador).
- Botón `?` en el HUD y reapertura de la cartilla a mitad de nivel.
- Persistencia “tutorial visto” por nivel.
- Nueva política de encuadre vertical de la cámara y límites de cámara ampliados.
- Fondo de nivel + color de limpieza, en ambos niveles.
- Reordenación mínima de la secuencia de arranque del nivel (intro → jugar).

### No entra
- Reescribir textos, fórmulas o el número de páginas de la cartilla.
- Cambiar la resolución del viewport (`480×270`) ni el layout del HUD existente.
- Cambiar la física del tiro, los límites de rebote del slime (`limites_globales`).
- Nuevos sprites: se reutilizan `background_1.png`, `background_2.png` y la paleta
  de `HudTema`.

---

## 2. Diagnóstico del estado actual

| Elemento | Estado | Consecuencia |
|---|---|---|
| `Scripts/camara_seguimiento.gd` | Solo sabe seguir un objetivo (`seguir()`) y fijar límites (`aplicar_limites()`). El zoom se fuerza a “caber a lo ancho”. | No hay cinemática; al arrancar la cámara salta directo al disparador. |
| `Scripts/level.gd` → `_ready()` | `camara.seguir(slingshoot, true)` inmediatamente; el cronómetro no arranca hasta que se cierra la cartilla (`_explicacion_completada`). | El nivel empieza bloqueado por la cartilla, siempre, en cada partida. |
| `Scripts/shot_hud.gd` | Construye toda la interfaz por código y crea la cartilla en `_ready`. La cartilla se destruye al cerrar (`queue_free`) y no hay forma de reabrirla. | No existe botón de ayuda ni segunda lectura. |
| `Scripts/nivel_limites.gd` | Deriva el rectángulo de `LimitesCamara/CollisionShape2D`. Ese mismo rect se usa para la cámara **y** para el rebote del slime (`level.gd:_on_slime_lanzado`). | No se puede ampliar sin romper la física. |
| Fondos de nivel | `jungleLevel` tiene `Fondo` (TileMapLayer) dentro del mapa; `Level_Ice` tiene un `Sprite2D`. No hay capa de fondo de pantalla. | Al bajar el zoom se vería el gris por defecto de Godot. |
| Persistencia | No hay `ConfigFile` ni `user://` en el proyecto. | “La primera vez” hay que implementarlo. |

### 2.1 Medidas reales (480×270, `canvas_items`)

En `CamaraSeguimiento.aplicar_limites()` hoy se usa
`zoom = max(480 / ancho, 270 / alto)`, es decir **se encaja a lo ancho**:

| Nivel | Rect de límites | zoom actual | Alto visible |
|---|---|---|---|
| Jungle | ≈ 285 × 925 px (centro `-48.5, -368.5`) | 1.68 | **160 px** |
| Ice | 313.5 × 838 px (centro `-25.75, -317`) | 1.53 | **176 px** |

El mapa mide ~900 px de alto, pero el jugador solo ve ~160–176 px: por eso “no se
ve el mapa de manera vertical”. **No es que falten límites: sobra zoom.** El zoom
ancho se eligió para no mostrar los laterales vacíos; al bajarlo hay que cubrir
esos laterales con un fondo.

---

## 3. Decisiones y supuestos

1. **“Primera vez” = por nivel**, no por partida. Primera vez que se juega un nivel
   se abre la cartilla automáticamente **antes** de la intro; a partir de ahí solo con `?`.
   (Es lo que mejor encaja con “que no sean al inicio” + “la primera vez sale la
   información”. Si se quisiera *nunca* auto-abrir, basta con una constante en §5.3.)
2. **Vista vertical objetivo ≈ 300 px** (hoy 160–176), configurable por export
   entre 280 y 360. Se amplían límites de cámara (no los de física) y se añade
   fondo para cubrir lo que queda fuera del mapa.
3. **Pausa real del árbol** (`get_tree().paused = true`) mientras la cartilla está
   abierta: así se congela el vuelo del slime y el cronómetro sin lógica nueva.
4. Se mantiene la señal `cartilla_cerrada` de `ShotHUD` para no romper
   `slingshoot.gd`; se añaden señales nuevas en vez de renombrar las existentes.

---

## 4. Parte A — Intro de cámara

### 4.1 Comportamiento

1. El nivel carga y la cámara se coloca en la **parte baja** del mapa (junto al
   disparador), sin HUD visible.
2. Paneo suave **abajo → arriba** por el centro del mapa (duración ~2.4 s).
3. Pausa breve arriba (~0.4 s) y **vuelta abajo** en diagonal leve (~1.2 s).
4. La cámara queda en el disparador, se **desvanece el HUD** y se habilita el juego.
5. **Saltar**: cualquier clic o tecla (tras 0.3 s) cancela el tween, coloca la
   cámara en su destino y continúa la secuencia.

Durante todo el recorrido: sin entrada de disparo, sin cronómetro corriendo y con
la pausa bloqueada.

### 4.2 API nueva de `CamaraSeguimiento`

```gdscript
signal intro_terminada

## Reproduce la cinemática. No sigue al objetivo mientras dura.
## rect: rectángulo de cámara (ya ampliado, ver §6.3).
func reproducir_intro(rect: Rect2, duracion: float = 3.4, pausa_extremos: float = 0.4) -> void

## Cancela la intro y salta al estado final (se emite intro_terminada una sola vez).
func saltar_intro() -> void

## Política de zoom por cobertura vertical (sustituye al encaje a lo ancho).
func aplicar_limites(rect: Rect2) -> void   # se conserva el nombre
``` 

Detalles de implementación:
- Bandera `_en_intro`: `_process()` no sigue al objetivo mientras esté activa.
- Cálculo de centros válidos con el zoom aplicado:
  `mitad = viewport_size / (2 * zoom)` y `clamp` a `rect.position + mitad` /
  `rect.end - mitad` (si `rect` es menor que la vista, usar el centro del rect).
- Un solo `Tween` encadenado; `saltar_intro()` hace `kill()` y aplica el último
  paso. La señal `intro_terminada` se emite tanto al terminar como al saltar.
- Sin `await` dentro de la cámara para las señales: el nivel espera a
  `intro_terminada` (evita dobles esperas si se salta).

### 4.3 Secuencia de arranque en `NivelSlimes` (`level.gd`)

Nuevo estado explícito para no depender de `_explicacion_completada`:

```gdscript
enum Estado { INTRO, JUGANDO, CARTILLA, TERMINADO }
var _estado: Estado = Estado.INTRO
```

`_ready()` pasa a:
1. `_conectar_resortera()`, `_crear_pantalla_fin()`, `_conectar_metas()`,
   `_agrupar_musica()`, `_aplicar_limites()` (como hoy).
2. `ui.configurar(...)`, `slingshoot.configurar(...)`.
3. `slingshoot.interactivo = false`, `hud` oculto, `pantalla.bloquear_pausa(true)`.
4. Esperar a que el HUD exista (hoy se añade con `call_deferred`): añadir señal
   `hud_listo` en `Slingshoot` y esperarla antes de continuar (o `await get_tree().process_frame`).
5. Si `ProgresoTutorial.visto(scene_file_path)` → se salta al paso 7.
   Si no → `_estado = Estado.CARTILLA` y `hud.abrir_cartilla("inicial")`.
6. Al cerrarse esa cartilla (`motivo == "inicial"`): marcar visto y lanzar la intro.
7. `await camara.intro_terminada` tras `camara.reproducir_intro(limites_camara, ...)`;
   después `camara.seguir(slingshoot, true)`, mostrar HUD y `pantalla.bloquear_pausa(false)`.
8. `_entrar_en_juego()`.

`_entrar_en_juego()`: `_estado = Estado.JUGANDO`, `slingshoot.interactivo = true`,
`_hud_tiempo.mostrar(0)`, `tiempo_transcurrido = 0`.

### 4.4 Bloqueo de interacción y cronómetro

- `slingshoot.gd`: nuevo `var interactivo: bool = true`; guardar al inicio de
  `_unhandled_input()` y de `disparar_con_parametros()` (`if not interactivo: return`).
- El cronómetro (`level.gd:_process`) solo avanza en `Estado.JUGANDO`; con la pausa
  del árbol ni siquiera se ejecuta mientras la cartilla está abierta.
- La pausa (`Esc`) queda bloqueada durante `INTRO` y `CARTILLA`.

### 4.5 Casos límite

- Si el rectángulo de cámara es menor que la vista (niveles muy pequeños), centrar
  sin `clamp` invertido.
- Si se salta la intro antes de que termine, no debe quedar ningún `Tween` vivo.
- Tras la intro, el zoom definitivo es el de juego (no el de la intro): la intro usa
  el mismo `aplicar_limites` para no dar un salto de zoom al volver al disparador.

---

## 5. Parte B — Botón `?` y tutorial persistente

### 5.1 Botón en el HUD (`shot_hud.gd`)

Nuevo botón “logotipo de pregunta” arriba a la derecha, sin chocar con el botón de
pausa (que vive en `PantallaFin`, capa 50, en `x ≈ 440–474, y 6–30`):

```gdscript
_help_button = Button.new()
_help_button.name = "HelpButton"
_help_button.text = "?"
_help_button.custom_minimum_size = Vector2(30, 24)
_help_button.focus_mode = Control.FOCUS_NONE
_help_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
_help_button.offset_left = -76   # hueco libre a la izquierda de la pausa
_help_button.offset_top = 6
_help_button.offset_right = -44
_help_button.offset_bottom = 30
```

- Estilo con `HudTema.estilo_boton(...)` (mismo cuaderno que el resto).
- Fuente `HudTema.fuente_pixel()`, tamaño 12, centrado.
- `tooltip_text = "Cómo jugar"`.
- Señal nueva `signal ayuda_solicitada()`; el `pressed` la emite.
- Visible solo en `Estado.JUGANDO` (oculto en intro y con la cartilla abierta).

### 5.2 Ciclo de vida de la cartilla (reabrible)

`shot_hud.gd` deja de crear la cartilla de forma fija en `_ready` y la gestiona:

```gdscript
signal cartilla_abierta()
signal cartilla_cerrada()          # se mantiene

func abrir_cartilla(motivo: String = "ayuda") -> void
func _crear_cartilla() -> Control  # instancia y conecta; null si falla
```

- `abrir_cartilla()`: si ya hay una, no hace nada. Crea la instancia, le pasa
  `modo_ecuacion`, `set_textura_slime(...)` y `set_model_values(...)` (ya disponibles),
  activa `cartilla_activa = true`, **pausa el árbol**, pausa la música del nivel
  (grupo `musica_nivel`) y emite `cartilla_abierta`.
- `_on_cartilla_cerrada()`: `cartilla_activa = false`, `_cartilla = null`,
  despausa el árbol y la música, emite `cartilla_cerrada` (comportamiento actual
  para `slingshoot.gd`).
- `cartilla.gd`:
  - Nuevo `func set_motivo(motivo: String)`: si es `"ayuda"`, la última página usa
    `VOLVER AL JUEGO  →` en vez de `COMENZAR NIVEL  →` y el texto de estado cambia.
  - `_unhandled_input`: `Esc` cierra (solo si ya se visitaron las 3 páginas, para no
    saltarse la lectura la primera vez).
  - `_cerrar()` despausa por seguridad (`get_tree().paused = false`) antes de emitir.

### 5.3 Persistencia “tutorial visto”

Nuevo `Scripts/progreso_tutorial.gd` (`class_name ProgresoTutorial`, estático, sin
autoload) con `ConfigFile` en `user://tutorial.cfg`:

```gdscript
static func visto(ruta_nivel: String) -> bool
static func marcar_visto(ruta_nivel: String) -> void
```

- Clave estable = `ruta_nivel.md5_text()` (evita `/` en las keys del `ConfigFile`).
- `level.gd` decide la autoapertura (§4.3) y marca visto **al cerrar** la cartilla
  inicial (`motivo == "inicial"`), no al abrirla, para que si el jugador sale a
  medias vuelva a verla la próxima vez.
- Solo se marca si la cartilla **llegó a mostrarse**: `abrir_cartilla()` devuelve
  `true/false` y el nivel guarda ese resultado. Si la escena no se pudo instanciar,
  el nivel arranca igual (intro) pero no registra el nivel como visto.
- Constante `AUTOABRIR_PRIMERA_VEZ := true` en `level.gd` para desactivarlo sin
  reescribir la lógica.
- Funciona en la exportación web (Godot usa IndexedDB para `user://`).
- Para repetir la prueba de “primera vez”, borra o renombra `user://tutorial.cfg`
  (en Windows: `%APPDATA%\Godot\app_userdata\SlimeTerra\tutorial.cfg`).

### 5.4 Pausa y cronómetro

- Con la cartilla abierta, `get_tree().paused = true`: el `_process` del nivel no
  avanza el tiempo, la física del slime se congela y el árbol queda estable.
- Todo lo que debe seguir respondiendo ya es `PROCESS_MODE_ALWAYS`: `ShotHUD`,
  `Cartilla` (hijo de `ShotHUD`), `PantallaFin`. El botón `?` y los botones de la
  cartilla siguen funcionando.
- Al cerrar una reapertura (`"ayuda"`), **no** se reinicia `tiempo_transcurrido`.

### 5.5 Compatibilidad

- No se renombran señales ni nodos usados por `slingshoot.gd`.
- `Slingshoot.explicacion_completada` deja de usarse como “nivel listo”; se
  sustituye por la lógica de `Estado` del nivel (o se mantiene emitiéndose al
  entrar en `JUGANDO`, por si otro consumidor lo usa). Revisar con `grep` antes de
  borrar.

---

## 6. Parte C — Más mapa vertical y fondo

### 6.1 Nueva política de zoom (sustituye al encaje a lo ancho)

En `CamaraSeguimiento`:

```gdscript
@export_range(200.0, 500.0, 10.0) var cobertura_vertical: float = 250.0
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0

func aplicar_limites(rect: Rect2) -> void:
    if not rect.has_area():
        quitar_limites(); return
    var pantalla := get_viewport_rect().size
    var z := clampf(pantalla.y / cobertura_vertical, zoom_min, zoom_max)
    zoom = Vector2(z, z)
    limit_left   = floori(rect.position.x)
    limit_top    = floori(rect.position.y)
    limit_right  = ceili(rect.end.x)
    limit_bottom = ceili(rect.end.y)
```

Con `cobertura_vertical = 250`: `zoom = 270/250 = 1.08`.

| Nivel | zoom nuevo | Ancho visible | Sobra a los lados |
|---|---|---|---|
| Jungle | 1.08 | ≈ 444 px | ≈ 158 px (79 por lado) |
| Ice | 1.08 | ≈ 444 px | ≈ 131 px (65 por lado) |

Se conserva `ajustar_zoom_a_limites` como interruptor de compatibilidad
(`false` = no tocar el zoom).

### 6.2 ¿Basta con subir los límites verticales?

No. Subir `limit_top`/`limit_bottom` solo deja que la cámara se desplace más allá
del mapa; el mapa seguiría viéndose igual de pequeño. **El cambio que hace ver más
mapa es el zoom** (la fórmula de §6.1). Los límites de cámara se amplían solo en
horizontal; en vertical se mantienen en el mapa para que **nunca asome el fondo**
por arriba ni por abajo.

### 6.3 Límites de cámara ≠ límites de juego

Importante: `limites_globales` (rebote del slime) **no se toca**. Se añade un rect
solo para la cámara:

```gdscript
# nivel_limites.gd
static func ampliar(rect: Rect2, margen_h: float, margen_v: float) -> Rect2:
    return rect.grow_individual(margen_h, margen_v, margen_h, margen_v)
```

En `level.gd`:

```gdscript
@export_group("Cámara")
@export var margen_camara_h: float = 160.0
@export var margen_camara_v: float = 0.0

func _aplicar_limites() -> void:
    limites_globales = NivelLimites.calcular(self)          # física: intacto
    var limites_camara := NivelLimites.ampliar(limites_globales, margen_camara_h, margen_camara_v)
    camara.aplicar_limites(limites_camara)
```

Los márgenes se eligen así:
- **horizontal**: cubrir la mitad del ancho visible menos el mapa
  (`(444 − 285)/2 ≈ 79`) con aire de sobra → **160 px**.
- **vertical**: **0 px**, para que la cámara se detenga justo en los bordes del
  mapa y no se vea fondo arriba ni abajo.

### 6.4 Fondo de nivel y color de limpieza

Implementado como capa de pantalla fija respecto a la cámara:

1. **Color de limpieza global** en `project.godot`
   (`rendering/environment/defaults/default_clear_color`): red de seguridad de un
   frame si algo falla al construir el fondo.
2. **Cielo y siluetas** (`level.gd:_crear_fondo()`): `CanvasLayer` `FondoPantalla`
   con `layer = -100` y `mouse_filter = IGNORE`, formada por:
   - `ColorRect` a pantalla completa con `color_cielo` (export por nivel).
   - `TextureRect` a pantalla completa con `textura_fondo`, filtro `nearest` y
     `STRETCH_KEEP_ASPECT_COVERED`; `tinte_fondo` adapta la silueta a cada nivel.
   Las imágenes `background_1.png` y `background_2.png` tienen transparencia en la
   parte superior, así que el cielo se ve detrás de la línea de árboles.
3. **Valores por nivel** (propiedades del nodo raíz de cada escena):
   - Jungle: cielo `#10241C`, `background_1`, tinte verdoso.
   - Ice: cielo `#142233`, `background_2`, tinte azulado.

### 6.5 Orden de capas resultante

```
CanvasLayer layer=-100   → FondoPantalla (cielo + siluetas)
TileMapLayer Fondo       → mapa (jungle) / Sprite2D (ice)        [sin cambios]
TileMapLayer Plataformas → mundo jugable                          [sin cambios]
... Slingshoot, Meta ...
CanvasLayer layer=20     → cronómetro
CanvasLayer layer=40     → SlimeSelectorUI
CanvasLayer layer=45     → ShotHUD (y botón ?)
CanvasLayer layer=50     → PantallaFin (pausa/resultado)
```

---

## 7. Archivos afectados

| Archivo | Acción |
|---|---|
| `Scripts/camara_seguimiento.gd` | Intro (tween, `intro_terminada`, `saltar_intro`), nueva política de zoom. |
| `Scripts/level.gd` | Estado `INTRO/JUGANDO/CARTILLA/TERMINADO`, secuencia de arranque, rect de cámara ampliado, autoapertura del tutorial, clear color. |
| `Scripts/nivel_limites.gd` | `ampliar(rect, margen_h, margen_v)` estático. |
| `Scripts/slingshoot.gd` | `interactivo`, señal `hud_listo`; guardas de entrada y disparo. |
| `Scripts/shot_hud.gd` | Botón `?`, señal `ayuda_solicitada`, `abrir_cartilla()`, ciclo de vida reabrible, pausa del árbol. |
| `Scripts/cartilla.gd` | `set_motivo()`, texto de cierre “VOLVER AL JUEGO”, `Esc` para cerrar. |
| `Scripts/progreso_tutorial.gd` | **Nuevo.** `ConfigFile` `user://tutorial.cfg` (visto/marcar). |
| `Scenes/Levels/jungleLevel.tscn` | Propiedades `color_cielo`, `textura_fondo` y `tinte_fondo` en el nodo raíz. |
| `Scenes/Levels/Level_Ice.tscn` | Propiedades `color_cielo`, `textura_fondo` y `tinte_fondo` en el nodo raíz. |
| `Scripts/hud_tema.gd` | (Opcional) estilo/color del botón `?` y del fondo. |
| `project.godot` | (Opcional) `default_clear_color`. |
| `README.md` | Documentar botón `?`, intro y nuevo encuadre. |

---

## 8. Fases de implementación

| Fase | Trabajo | Archivos | Criterio de aceptación |
|---|---|---|---|
| **0. Línea base** | Capturas del arranque y de la vista actual en ambos niveles; anotar zoom y alto visible. | — | Se puede comparar “antes/después”. |
| **1. Fondo y encuadre vertical** | `cobertura_vertical`, `NivelLimites.ampliar`, `FondoCamara` en ambos niveles, clear color. | `camara_seguimiento.gd`, `nivel_limites.gd`, `level.gd`, ambos `.tscn`, `project.godot` | No se ve gris en ningún punto; se ve ~300 px de alto; el slime rebota con los mismos límites de antes. |
| **2. Intro de cámara** | Tween, `intro_terminada`, `saltar_intro`, secuencia en `level.gd`, `interactivo` en `slingshoot.gd`. | `camara_seguimiento.gd`, `level.gd`, `slingshoot.gd` | Al entrar se recorre el mapa, se puede saltar, y el juego no acepta disparos durante la intro. |
| **3. Botón `?` y reapertura** | Botón, `abrir_cartilla()`, pausa del árbol, `set_motivo`, `Esc`. | `shot_hud.gd`, `cartilla.gd` | En cualquier momento de la partida `?` abre la cartilla, pausa el juego y al cerrarla el cronómetro continúa donde estaba. |
| **4. Persistencia “primera vez”** | `ProgresoTutorial` + autoapertura/registro en `level.gd`. | `progreso_tutorial.gd`, `level.gd` | 1.ª partida del nivel: la cartilla se abre sola antes de la intro. 2.ª: solo con `?`. |
| **5. Pulido** | Fade del HUD, pausa visible, tooltip, colores de fondo por nivel, ajuste fino de `margen_camara_*`. | `level.gd`, `shot_hud.gd`, `.tscn` | La transición de intro al juego no da saltos ni parpadeos. |
| **6. QA y cierre** | Pruebas en los 2 niveles + export HTML; `README.md`. | `README.md` | Checklist de §9 completa. |

Dependencias: 2 depende de 1 (la intro usa los límites nuevos); 4 depende de 3.

---

## 9. QA y criterios de aceptación

### Intro de cámara
- [ ] Se ve el recorrido completo del mapa (abajo → arriba → disparador) una vez por nivel.
- [ ] Un clic o tecla salta la intro sin dejar `Tween` activo.
- [ ] Durante la intro no se puede disparar ni abrir la pausa y el cronómetro está en `0:00.0`.
- [ ] Al terminar, la cámara queda en el disparador sin salto de zoom.

### Botón `?` y tutorial
- [ ] En la 1.ª partida del nivel la cartilla se abre sola; en las siguientes, no.
- [ ] `?` abre la cartilla en cualquier momento y la última página dice `VOLVER AL JUEGO`.
- [ ] Con la cartilla abierta la física y el cronómetro están detenidos; al cerrar continúan.
- [ ] `Esc` no abre la pausa mientras la cartilla está abierta (`pausa_bloqueada`).
- [ ] El simulador del slime no se reinicia al cerrar una reapertura.
- [ ] `user://tutorial.cfg` sobrevive a cerrar el juego.

### Encuadre y fondo
- [ ] Se ven ~300 px de alto en ambos niveles (frente a 160–176 antes).
- [ ] No aparece el gris por defecto de Godot en ningún ángulo del mapa ni al saltar la intro.
- [ ] El fondo hace bucle sin costuras visibles a 480×270 y a 1280×720.
- [ ] El slime sigue rebotando dentro de los mismos límites (no se amplió la física).

### Regresión
- [ ] El tiro, el inventario, la meta, las estrellas y la pantalla final funcionan igual.
- [ ] `set_model_values` sigue actualizando la viñeta y las ecuaciones del HUD al mover ángulo/potencia.
- [ ] Sin errores en la consola al reabrir la cartilla varias veces.
- [ ] Prueba en exportación HTML (`Executable/HTML`) sin tirones.

---

## 10. Riesgos y mitigaciones

| Riesgo | Prob. | Mitigación |
|---|---|---|
| Godot centra mal la cámara si el rect es menor que la vista | Media | En `aplicar_limites`, si `rect.size < pantalla/zoom`, usar el centro del rect y no hacer `clamp` invertido. |
| Bajar el zoom deja ver demasiados laterales | Media | `cobertura_vertical` configurable (280–360) y fondo/capas de parallax que cubran ≥ 124 px por lado. |
| Pausar el árbol afecta a la música o a animaciones | Baja | Música por `stream_paused` (ya se usa) y `process_mode = ALWAYS` en HUD/cartilla/pantalla final. |
| El HUD aún no existe al empezar la intro (`call_deferred`) | Media | Señal `hud_listo` en `Slingshoot`; el nivel espera antes de abrir la cartilla. |
| La autoapertura se repite si el jugador cierra el juego a medias | Baja | Registrar “visto” al cerrar la cartilla inicial, no al abrirla. |
| Reabrir la cartilla crea/repite nodos | Baja | `abrir_cartilla()` es idempotente (`if _cartilla != null: return`) y se instancia una sola vez por apertura. |
| El botón `?` choca con el de pausa al escalar | Baja | Ambos anclados a `PRESET_TOP_RIGHT` con offsets fijos; validar a 480×270 y 1280×720. |

---

## 11. Estimación orientativa

| Fase | Esfuerzo |
|---|---|
| 0. Línea base | 0,5 h |
| 1. Fondo y encuadre vertical | 2–3 h |
| 2. Intro de cámara | 3–4 h |
| 3. Botón `?` y reapertura | 3–4 h |
| 4. Persistencia “primera vez” | 1–2 h |
| 5. Pulido | 1–2 h |
| 6. QA y README | 1–2 h |
| **Total** | **≈ 12–18 h** |

---

## 12. Checklist “no cambia lo que ya funciona”

- [ ] `git diff Scripts/cartilla_contenido.gd` no muestra cambios (el texto no se toca).
- [ ] `limites_globales` sigue saliendo de `NivelLimites.calcular()` sin ampliar.
- [ ] `modo_ecuacion`, `set_model_values`, `set_textura_slime` y la señal `cerrada`
      de la cartilla conservan su contrato.
- [ ] El cronómetro arranca en `0` al entrar en juego y las estrellas usan los
      mismos umbrales (`tiempo_3_estrellas`, `tiempo_2_estrellas`).
- [ ] El slime no rebota fuera del rectángulo original.
