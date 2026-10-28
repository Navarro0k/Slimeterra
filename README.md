# 🐌💥 Slime Terra
Un juego de físicas y plataformas 2D estilo pixel art, inspirado en las mecánicas de Angry Birds y los poderes de Bajoterra. El jugador debe superar niveles utilizando una resortera para lanzar distintos tipos de slimes con habilidades especiales.

## ⚙️ Arquitectura Técnica: 
Slime Terra separa la presentación de la simulación matemática. Mientras el motor gráfico gestiona la interfaz y el ciclo de juego, el cálculo de las parábolas, la gravedad y el vuelo se resuelve de forma transparente a través de un backend modular en Python, implementando sistemas de ecuaciones diferenciales (EDOs) y métodos numéricos.

## 📐 Modo educativo: el salto se predice con RK4

Todo el vuelo del slime es la solución numérica de la EDO del tiro con resistencia del aire:

```
dx/dt = v        dv/dt = g − k·v        (g = 9.8 m/s², k = 0.1 s⁻¹)
```

resuelta con **Runge-Kutta de orden 4** (`Scripts/SolverNumerico.gd`). El juego muestra esa matemática en pantalla:

| Qué | Dónde | Cómo se usa |
|---|---|---|
| **Predicción de 15 puntos** | Resortera | Cada punto es un paso de RK4 con Δt = 0.08 s (1.2 s de vuelo). |
| **Panel de datos** | Esquina superior izquierda | v₀, θ, vx, vy, altura máxima, alcance, tiempo de vuelo y error de RK4 frente a la solución exacta, en metros y segundos. Se pliega con el botón `–`. |
| **RK4 por dentro** | Tecla **K** o botón del panel | Dibuja las 4 pendientes k1…k4 de un paso (flechas de colores), dónde se evaluó cada una y el promedio ponderado (amarillo) que lleva al siguiente punto. **Q / E** o la **rueda del ratón** cambian de paso mientras se apunta. |
| **Rastro del tiro** | En el nivel | Cuadritos blancos = predicción; puntos celestes = posición real del slime en los mismos instantes. Si coinciden, RK4 acertó. |
| **Tarjetas "¿Sabías que…?"** | Al iniciar cada nivel y botón **Teoría** | Teoría de la EDO, de RK4 y de la resistencia del aire. |
| **¿Cómo se calculó?** | Botón tras cada tiro | Explica el último salto con sus números reales: condiciones iniciales, primer paso de RK4 y predicción vs. realidad. |

**Escala:** 1 m = 100 px (`Scripts/unidades.gd`), elegida para que la gravedad del proyecto (980 px/s²) sea exactamente 9.8 m/s².

**Archivos nuevos:** `unidades.gd`, `panel_tiro.gd`, `rastro_tiro.gd`, `tarjeta_teoria.gd` y `contenido_teoria.gd` (aquí se editan los textos de las tarjetas).
