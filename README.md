# 🐌💥 Slime Terra
Un juego de físicas y plataformas 2D estilo pixel art, inspirado en las mecánicas de Angry Birds y los poderes de Bajoterra. El jugador debe superar niveles utilizando una resortera para lanzar distintos tipos de slimes con habilidades especiales.

## ⚙️ Arquitectura Técnica: 
Slime Terra separa la presentación de la simulación matemática. Mientras el motor gráfico gestiona la interfaz y el ciclo de juego, el cálculo de las parábolas, la gravedad y el vuelo se resuelve de forma transparente a través de un backend modular en Python, implementando sistemas de ecuaciones diferenciales (EDOs) y métodos numéricos.
