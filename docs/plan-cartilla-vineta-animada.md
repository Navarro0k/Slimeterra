# Plan: cartilla con viñeta animada (honda + slime)

> Objetivo: que los tableros explicativos que aparecen antes de cada nivel se sientan
> más vivos y se entiendan de un vistazo, añadiendo una **viñeta ilustrada que se
> reproduce en bucle** (la honda dispara un slime) como apoyo visual de cada página.
>
> Restricción principal: **no se cambia la información de la cartilla**. Los textos,
> ecuaciones, valores y el bloqueo del nivel hasta leer las 3 páginas se mantienen
> intactos. Solo cambia la presentación.

---

## 1. Diagnóstico del estado actual

| Elemento | Estado | Consecuencia |
|---|---|---|
| `Scenes/UI/Cartilla.tscn` | Un `PanelContainer` a pantalla completa con una sola columna de texto (`RichTextLabel`). | Es un muro de texto: no hay apoyo visual, todo depende de la lectura. |
| `Scripts/cartilla.gd` | Navegación de 3 páginas, `ProgressBar`, música, cierre. API: `modo_ecuacion`, `set_model_values(pos, vel, g, k)`, señal `cerrada`. | Es la única puerta de entrada al nivel; hay que conservar su contrato. |
| `Scripts/cartilla_contenido.gd` | Genera el BBCode de cada página a partir del modelo real del disparo. | La fuente de verdad del contenido. No debe reescribirse. |
| `ShotHUD` | Crea la cartilla, le pasa `modo_ecuacion` y luego `set_model_values`. | Ya existe el dato necesario (posición, velocidad, g, k) para dibujar una trayectoria fiel. |
| `Slingshoot` / `slime_visual` | Ya tienen resortera, bandas y estela. | Hay arte y lógica reutilizable; la viñeta no necesita assets nuevos. |

**Espacio disponible (medido):** viewport 480×270; el panel ocupa 464×254; con los
márgenes actuales el contenido interior es de **440×238 px**. Cualquier elemento nuevo
sale de ese presupuesto, así que la viñeta debe ser una **columna lateral compacta**,
no un panel grande.

---

## 2. Alcance

### Sí entra
- Rediseño de layout de la cartilla (columna de lectura + columna de viñeta).
- Nueva viñeta animada no interactiva, en bucle, con 3 variantes (una por página).
- Ajuste tipográfico para que las ecuaciones sigan cabiendo en la columna más estrecha.
- Micro-animaciones de entrada de página y realce de la ecuación protagonista.
- Estilos nuevos en `HudTema` (papel, cuadrícula, trazos).
- Actualización del `README.md`.

### No entra
- Cambiar, resumir o reordenar el texto de `CartillaContenido`.
- Cambiar valores, fórmulas o la física del juego.
- Añadir interacción a la viñeta (nada de clics, arrastre ni controles).
- Tocar la HUD de apuntado, el temporizador, las estrellas o la progresión.
- Assets nuevos obligatorios (se reutilizan `Honda madera.png`, `parche honda.png`,
  `slime-base.png` / `slime_fuego.png`).

---

## 3. Concepto visual

**“La libreta con una viñeta al margen”.** La cartilla ya es un cuaderno de papel;
la viñeta se integra como un recorte pegado en el margen derecho:

- Marco de papel claro con borde de tinta de 1 px.
- Fondo con cuadrícula tenue (como hoja cuadriculada).
- Línea de suelo con sombreado corto.
- Honda de madera (sprite existente) y slime (sprite existente).
- Trayectoria dibujada con puntos de 2×2 px, igual que la previsualización del juego.
- Leyenda al pie de la viñeta: `VIÑETA · EL MODELO` / `· LA CURVA` / `· EL DISPARO`
  (rótulo de chrome, derivado del título de la página; no añade información nueva).

La acción es **siempre la misma y siempre en bucle**: tensar → soltar → volar →
llegar → reiniciar. Sin sonido y sin interacción, para que acompañe la lectura sin
competir con ella.

---

## 4. Layout propuesto

```
┌──────────────────────────────────────────────────────────────┐
│ BITÁCORA DE FÍSICA      NIVEL 1 · TIRO IDEAL           1 / 3 │
│ ┌────────────────────────────────────┐  ┌─────────────────┐ │
│ │ El modelo del nivel                │  │  · · · · · ●    │ │
│ │ Gravedad, aire y condiciones...    │  │        · ·      │ │
│ │                                    │  │      ·          │ │
│ │ El slime se trata como una...      │  │   ╱             │ │
│ │ ┌──────────────────────────────┐   │  │  Y              │ │
│ │ │        a = g − k·v           │   │  │ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁  │ │
│ │ └──────────────────────────────┘   │  │ VIÑETA · 1 / 3  │ │
│ │ ...                                │  └─────────────────┘ │
│ └────────────────────────────────────┘                      │
│ ▓▓▓░░░                                                      │
│ [← ANTERIOR]      Página visitada...        [SIGUIENTE →]   │
└──────────────────────────────────────────────────────────────┘
```

### Medidas de referencia (a validar en el editor)

| Zona | Tamaño | Notas |
|---|---|---|
| Panel interior | 440 × 238 | Igual que hoy. |
| `Cuerpo` (HBox) | 440 × ~195 | Contiene lectura + viñeta. |
| `Lectura` | ~312 × 195 | `Titulo` + `Subtitulo` + `Texto`. |
| `Vineta` | **120 × 195** | Fija; no se estira. |
| `Lienzo` de la viñeta | ~112 × ~175 | Área de dibujo real. |
| `Leyenda` | 112 × 10 | Fuente 6 px, centrada. |

> El ancho de la viñeta queda como constante (`ANCHO_VINETA`) en `cartilla.gd` para
> poder ajustarlo entre **108 y 150 px** tras la validación visual. A 120 px el texto
> pierde ~29 % de ancho: es el mejor equilibrio entre viñeta legible y lectura cómoda.

### Árbol de escena resultante (`Cartilla.tscn`)

```
Cartilla (Control)
├─ Fondo (ColorRect)                      # igual
├─ Panel (PanelContainer)                 # igual
│  └─ Margen (MarginContainer)
│     └─ Contenido (VBoxContainer)
│        ├─ Cabecera (HBoxContainer)      # igual
│        ├─ Cuerpo (HBoxContainer)        # NUEVO   sep 8
│        │  ├─ Lectura (VBoxContainer)    # NUEVO   expand
│        │  │  ├─ Titulo
│        │  │  ├─ Subtitulo
│        │  │  └─ Texto (RichTextLabel)
│        │  └─ Vineta (PanelContainer)    # NUEVO   120 px
│        │     └─ MargenVineta (MarginContainer 4)
│        │        └─ ColumnaVineta (VBoxContainer)
│        │           ├─ Lienzo (VinetaDisparo)   # Control con _draw
│        │           └─ Leyenda (Label, 6 px)
│        ├─ Progreso (ProgressBar)        # igual (restyling en fase 4)
│        └─ Pie (HBoxContainer)           # igual
└─ Musica (AudioStreamPlayer)             # igual
```

Lo que **no** se mueve: nombres y rutas de `Titulo`, `Subtitulo`, `Texto`,
`Progreso`, `BtnAnterior`, `BtnSiguiente`, `EstadoLectura`, `Cabecera`, `Pie`, `Musica`.
Así `cartilla.gd` conserva sus `@onready` y el resto del juego no se entera.

### Presupuesto de texto

Con 312 px de ancho y fuente de 10 px (JetBrains Mono) caben ~50–52 caracteres por
línea. Las páginas actuales quedan al borde de necesitar scroll; por eso el plan
incluye tres medidas compensatorias (fase 1):

1. `line_separation` de `Texto` de 1 → **0**.
2. Márgenes del panel de 12/8 → **10/6** (recupera ~10 px de alto).
3. Auto-ajuste de tamaño solo en los bloques de ecuación (ver §7.6).

Criterio de aceptación: ninguna página debe necesitar **más de una pantalla de
scroll** ni cortar ecuaciones horizontalmente. Si no se cumple, bajar la viñeta a
108 px antes de tocar el tamaño del texto normal.

---

## 5. Comportamiento de la viñeta

### 5.1 Ciclo base (≈6 s, en bucle)

| Fase | % del ciclo | Qué se ve |
|---|---|---|
| Reposo | 0–12 % | Honda quieta, slime en la horquilla, cuadrícula respirando muy leve. |
| Tensión | 12–28 % | El parche retrocede ~10 px, las bandas se estiran y el slime se aplasta. |
| Suelta | 28–32 % | Destello corto en la horquilla; el parche vuelve al centro. |
| Vuelo | 32–74 % | El slime recorre la trayectoria; la estela se revela punto a punto. |
| Llegada | 74–86 % | Aplastado en el punto final + polvillo de 3–4 píxeles. |
| Reinicio | 86–100 % | La estela se desvanece; el slime reaparece en la horquilla. |

Easing suave (`TRANS_SINE`) en tensión, vuelo y desvanecido. Sin aleatoriedad: mismo
recorrido siempre (el polvillo usa posiciones derivadas del índice, no `randf`).

### 5.2 Variante por página

| Página | Título | Qué enfatiza la viñeta |
|---|---|---|
| 0 | El modelo del nivel | Al soltar, se marcan `p0`, `v0` (flecha), `g` (flecha hacia abajo) y `k·v` (flecha que se opone a la velocidad y se acorta al perder rapidez). |
| 1 | La curva del tiro ideal / El sistema lineal | **Parábola:** se dibujan dos rutas, la ideal punteada y la real con puntos; la separación entre ambas se abre sola y se resalta con una llave discreta. **Matrices:** la estela aparece en pasos discretos (un punto por paso de integración) con un tick intermitente en la cabeza. |
| 2 | Listo para disparar | La honda se orienta al ángulo real, un arco fino marca el ángulo, una barra lateral muestra la potencia y **después** dispara con esos valores. |

Los símbolos (`p0`, `v0`, `g`, `k·v`, “sin aire”, “con aire”) ya existen en los textos
de la cartilla: la viñeta los repite, no introduce conceptos nuevos.

### 5.3 Sin modelo disponible

La cartilla puede abrirse antes de que `ShotHUD` envíe `set_model_values`. En ese caso
la viñeta usa un modelo de ejemplo **interno** (ángulo 45°, rapidez media, la `g` y `k`
reales del proyecto) y lo sustituye en cuanto llega el modelo real, sin reiniciar el
ciclo ni saltar. La leyenda lo indica con el mismo rótulo, sin texto adicional.

---

## 6. Arquitectura técnica

### 6.1 Archivos

| Archivo | Acción |
|---|---|
| `Scripts/vineta_disparo.gd` | **Nuevo.** `class_name VinetaDisparo extends Control`: ciclo, dibujo y configuración. |
| `Scenes/UI/VinetaDisparo.tscn` | **Nuevo.** Control raíz + script. Se instancia dentro de `Cartilla.tscn` como `Lienzo`. |
| `Scenes/UI/Cartilla.tscn` | Reestructurar el `Contenido` (HBox `Cuerpo`) y añadir la viñeta. Sin tocar nodos existentes. |
| `Scripts/cartilla.gd` | Conectar la viñeta, pasarle página y modelo, transición de página, rótulo. Mantener la API pública. |
| `Scripts/cartilla_contenido.gd` | Añadir `etiqueta_vineta(pagina)` y el auto-ajuste de ancho de las ecuaciones. **No tocar el texto.** |
| `Scripts/fisica_disparo.gd` | Extraer `simular(...)` reutilizable (sin cambiar el comportamiento de `simular_trayectoria`). |
| `Scripts/hud_tema.gd` | Constantes de paleta de la viñeta + `estilo_vineta()`. |
| `README.md` | Mencionar la viñeta en la descripción de `Cartilla`. |

### 6.2 API de `VinetaDisparo`

```gdscript
## Configura modo y modelo real del disparo. No reinicia el ciclo.
func configurar(modo: String, pos0: Vector2, vel0: Vector2, gravedad: float, amortiguamiento: float) -> void

## Página visible (0..2). Cambia el énfasis y reinicia el ciclo con un fade corto.
func set_pagina(pagina: int) -> void

## Textura del slime cargado (opcional; por defecto slime-base).
func set_textura_slime(textura: Texture2D) -> void

## Control del bucle (para QA y para el cierre).
func reiniciar() -> void
func detener() -> void
```

- `process_mode = PROCESS_MODE_ALWAYS` (la cartilla ya lo usa).
- `mouse_filter = MOUSE_FILTER_IGNORE`, `focus_mode = FOCUS_NONE`.
- `_process` sale de inmediato si `not is_visible_in_tree()`.
- `queue_redraw()` solo mientras la viñeta está visible.

### 6.3 Flujo de datos

```
Slingshoot ──set_model_values──▶ ShotHUD ──▶ Cartilla ──▶ VinetaDisparo.configurar(...)
                                   │                         ▲
                                   └── modo_ecuacion ────────┘
Cartilla._actualizar_pagina() ──▶ VinetaDisparo.set_pagina(p)
```

`set_model_values` ya se llama en cada cambio de ángulo/potencia desde `_al_hud_listo`
y `_actualizar_modelo_hud`, así que la viñeta se mantiene sincronizada sin lógica nueva.

### 6.4 Dibujo y coordenadas

- Todo se dibuja con `_draw()` sobre el `Control` (nada de `Node2D` sueltos):
  `draw_rect`, `draw_line`, `draw_circle`, `draw_arc`, `draw_texture_rect`,
  `draw_polyline`, `draw_string` para símbolos.
- La ruta se calcula **una vez** al configurar, con el mismo integrador del juego:

```gdscript
var pasos := FisicaDisparo.simular(_pos0, _vel0, _g, _k, 1.0 / 60.0, 150)
```

- Se normaliza la ruta al lienzo respetando proporción (sin deformar la curva) y con
  margen interior de 6 px. La posición absoluta del nivel se ignora; solo importan
  dirección, rapidez, `g` y `k`.
- Para la página 1 en modo parábola, la ruta ideal se obtiene con
  `SolverNumerico.ecuacion_parabolica` y se muestrea en el mismo rango de `x`; el
  encuadre usa la unión de ambas rutas.
- Al ser esquemático, el vuelo se comprime a una ventana fija del ciclo (no pretende
  ser tiempo real); no se escribe ninguna cifra nueva en pantalla.

### 6.5 Refactor mínimo en `FisicaDisparo`

```gdscript
## N pasos completos de RK4 con dt fijo.
static func simular(pos0: Vector2, vel0: Vector2, gravedad: float, k: float, dt: float, pasos: int) -> PackedVector2Array
```

`simular_trayectoria` pasa a delegar en `simular` y a muestrear cada
`pasos_por_punto`, conservando exactamente los puntos que devuelve hoy (la
previsualización del juego no debe cambiar).

### 6.6 Auto-ajuste tipográfico de ecuaciones

`CartillaContenido._eq()` recibe un ancho máximo (constante `ANCHO_LECTURA = 300`):

1. Se mide cada línea del bloque con `Font.get_string_size()` usando
   `JetBrainsMono-Regular.ttf`.
2. Si no cabe, se baja el tamaño en pasos de 1 px hasta un mínimo de 9.
3. Si aún no cabe (caso raro), se insertan saltos de línea en los separadores
   naturales (`      ` y `, `).

Esto solo cambia tamaño y saltos de línea: **el contenido y los valores no se tocan**.
El caso más ajustado es la línea `a = …  b = …  c = …` (≈43 caracteres) y la línea
`g = …  k = …`; con este sistema caben sin recortes.

### 6.7 Paleta y estilos nuevos (`HudTema`)

```gdscript
const VINETA_FONDO := Color(0.99, 0.97, 0.89)
const VINETA_CUADRICULA := Color(0.45, 0.33, 0.14, 0.10)
const VINETA_TRAZO := Color(0.30, 0.20, 0.08, 0.85)
const VINETA_IDEAL := Color(0.55, 0.32, 0.08, 0.55)
const VINETA_VERDE := VERDE
const VINETA_AZUL := AZUL
```

- `estilo_vineta()`: `StyleBoxFlat` con `VINETA_FONDO`, borde de 1 px, radio 3,
  sombra suave de 2 px (coherente con `estilo_panel`).
- El acento (verde/azul) sigue a `modo_ecuacion`, igual que la cabecera.
- `texture_filter` del proyecto ya es *nearest* (0): los sprites 32/24 px se ven
  nítidos. Escalas enteras o 0.75, nunca 1.3.

---

## 7. Fases de implementación

| Fase | Trabajo | Archivos | Criterio de aceptación |
|---|---|---|---|
| **0. Línea base** | Capturas de las 3 páginas en ambos niveles (480×270 y 1280×720) y copia del texto actual para el diff final. | — | Se puede comparar “antes/después” y verificar que no cambió ni una palabra. |
| **1. Layout** | `Cuerpo` HBox, `Lectura`, `Vineta` con marco vacío y leyenda; márgenes y `line_separation`; transición de página (fade + 4 px). | `Cartilla.tscn`, `cartilla.gd`, `hud_tema.gd` | Las 3 páginas siguen navegando igual; el texto no se corta; el marco no roba foco; `set_model_values` sigue funcionando. |
| **2. Núcleo de la viñeta** | Escena + script; fondo, cuadrícula, suelo, honda, bandas, slime; ciclo completo; página 0 con `p0/v0/g/k·v`. | `VinetaDisparo.tscn`, `vineta_disparo.gd`, `fisica_disparo.gd`, `hud_tema.gd` | El bucle corre indefinidamente sin errores; sin `set_model_values` usa el modelo de ejemplo; el coste por frame es imperceptible. |
| **3. Variantes de página** | Página 1: ideal vs real (parábola) y pasos discretos (matrices). Página 2: ángulo + potencia + disparo con valores reales. | `vineta_disparo.gd`, `cartilla.gd`, `cartilla_contenido.gd` (solo `etiqueta_vineta`) | Cada página muestra su énfasis; el cambio de página reinicia limpio; el modo matrices se ve distinto al de parábola. |
| **4. Pulido** | Auto-ajuste de ecuaciones, realce breve de la ecuación protagonista, pips de progreso, scrollbar de papel, hover/foco de botones, textura del slime según inventario. | `cartilla_contenido.gd`, `cartilla.gd`, `Cartilla.tscn`, `shot_hud.gd`/`slingshoot.gd` (solo el icono) | Ninguna ecuación se recorta; el conjunto se siente de la misma libreta; la viñeta no distrae durante la lectura. |
| **5. QA y cierre** | Pruebas en los dos niveles, export HTML, `README.md`. | `README.md` | Checklist de §8 completa. |

Dependencias: 2 depende de 1; 3 depende de 2; 4 y 5 al final. Las fases 1 y 4 se
pueden revisar visualmente antes de seguir.

---

## 8. QA y criterios de aceptación

### Funcional
- [ ] Se visitan las 3 páginas y `COMENZAR NIVEL →` solo aparece en la última.
- [ ] Al cerrar: `cerrada` se emite, `cartilla_activa = false`, la música del nivel se
      reanuda y **el cronómetro arranca en 0**.
- [ ] `Esc` no abre la pausa mientras la cartilla está abierta.
- [ ] `set_model_values` con valores distintos actualiza la viñeta sin reiniciar el bucle.
- [ ] Con ángulo casi vertical (`vx ≈ 0`) y con `k = 0` no hay errores ni divisiones por cero.

### Visual
- [ ] Ninguna ecuación se corta ni se sale del marco en 480×270.
- [ ] El scroll de cada página no supera una pantalla.
- [ ] La viñeta se lee a 1280×720 sin pixelado sucio (filtro nearest).
- [ ] El bucle no “parpadea” al reiniciar (sin salto visible del slime).
- [ ] Los colores verde/azul coinciden con el nivel.
- [ ] Capturas comparadas con la línea base: **el texto es idéntico**.

### Rendimiento
- [ ] La viñeta no reasigna arrays por frame (rutas cacheadas).
- [ ] Sin partículas ni `Tween` nuevos por frame; un solo `Control` que se redibuja.
- [ ] Prueba en la exportación HTML (`Executable/HTML`) sin tirones.

---

## 9. Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| El texto necesita demasiado scroll al estrecharse | Media | Constante `ANCHO_VINETA` ajustable 108–150; `line_separation = 0`; auto-ajuste de ecuaciones; criterio de aceptación medible. |
| La animación distrae de la lectura | Media | Un solo movimiento por página, contraste bajo, sin sonido, ciclo largo; el texto nunca se anima letra a letra. |
| Duplicar información o añadir afirmaciones nuevas | Baja | La viñeta solo usa símbolos ya presentes; los rótulos se derivan del título; revisión con diff de `cartilla_contenido.gd`. |
| Coste en Godot GL Compatibility / Web | Baja | Rutas cacheadas, `_draw` vectorial simple, sin shaders, sin partículas. |
| Romper la API de la cartilla | Baja | No se renombran nodos ni métodos; `set_model_values` y `cerrada` intactos. |
| Sprites borrosos al escalar | Baja | Escalas enteras o 0.75; `default_texture_filter = 0` ya configurado. |

---

## 10. Estimación orientativa

| Fase | Esfuerzo |
|---|---|
| 0. Línea base | 0,5 h |
| 1. Layout | 2–3 h |
| 2. Núcleo de la viñeta | 4–6 h |
| 3. Variantes de página | 2–3 h |
| 4. Pulido | 2–3 h |
| 5. QA y README | 1–2 h |
| **Total** | **≈ 12–18 h** |

---

## 11. Checklist “no cambia la información”

- [ ] `git diff Scripts/cartilla_contenido.gd` solo muestra cambios de formato
      (`_eq`, `etiqueta_vineta`), nunca de frases ni de valores.
- [ ] Las fórmulas siguen siendo las mismas (`a = g − k·v`, `y(x) = a·x² + b·x + c`,
      `s' = A·s + b`, matrices de `A` y `b`).
- [ ] Los números mostrados provienen de `SolverNumerico` / `FisicaDisparo`, como hoy.
- [ ] Las 3 páginas conservan sus títulos, subtítulos y el orden.
- [ ] La viñeta no introduce texto explicativo nuevo más allá de su rótulo.
