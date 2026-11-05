# 🐌💥 Slime Terra

Un juego de físicas y plataformas 2D estilo pixel art, inspirado en las mecánicas de Angry Birds y los poderes de Bajoterra. El jugador debe superar niveles utilizando una resortera para lanzar distintos tipos de slimes con habilidades especiales.

## ⚙️ Arquitectura Técnica

Slime Terra está desarrollado en Godot 4 (renderizador GL Compatibility) con GDScript. La simulación del tiro (gravedad, amortiguamiento y trayectoria) se resuelve con un solver numérico propio (`SolverNumerico`) que implementa Euler, Heun y Runge-Kutta 4, y se muestra de forma dinámica en el HUD: ecuación parabólica en el nivel 1 y el sistema lineal en espacio de estados (matrices) en el nivel 2.

La lógica se separa en:
- `NivelSlimes` (nivel, límites, meta, cámara, progresión).
- `Slingshoot` (resortera, inventario, disparo, HUD de apuntado).
- `Slime` (RigidBody2D con máquina de estados: cargado → saliendo → en vuelo → terminado).
- `SlimeCatalogo` / `SlimeInventario` (tipos y cantidades de slimes).
- `ShotHUD` (ángulo, potencia, ecuación y botón de disparo).

## 🎮 Controles
- Arrastrar el slime con el ratón para apuntar y soltar para disparar.
- Usar el dial de ángulo y el slider de potencia del HUD.
- `Esc` / botón "Pausa" para pausar.

## 📁 Estructura
- `Scenes/` escenas de niveles, UI y slimes.
- `Scripts/` lógica del juego.
- `Assets/` arte, tilesets y audio.