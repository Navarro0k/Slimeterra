extends Node2D
## Script del nivel: es el único que conoce a la resortera y a la UI.
## Les entrega el inventario de slimes y los comunica entre sí.

## Slimes disponibles en este nivel: { tipo de slime: cantidad }.
## Los tipos están definidos en SlimeCatalogo.Tipo.
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

@onready var slingshoot: Node2D = $Slingshoot
@onready var ui: SlimeSelectorUI = $SlimeSelectorUI

func _ready() -> void:
	# Resortera -> UI: cambió la munición o la selección.
	slingshoot.inventario_cambiado.connect(ui.actualizar)
	# UI -> Resortera: el jugador eligió otro tipo de slime.
	ui.slime_elegido.connect(slingshoot.seleccionar)
	# Resortera -> Nivel: ya no queda munición.
	slingshoot.sin_municion.connect(_on_sin_municion)

	# Mismo diccionario para los dos. Primero la UI (crea los slots) y luego la
	# resortera (emite inventario_cambiado y la UI se rellena).
	ui.configurar(slimes_nivel)
	slingshoot.configurar(slimes_nivel)

func _on_sin_municion() -> void:
	# Punto de enganche para derrota / reinicio del nivel.
	pass
