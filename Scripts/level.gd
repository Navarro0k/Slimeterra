class_name NivelSlimes
extends Node2D
## Script del nivel: es el único que conoce a la resortera y a la UI.
## Les entrega el inventario de slimes y los comunica entre sí.
## También decide cuándo termina el nivel: victoria al tocar una Meta, derrota al quedarse sin slimes.

## Slimes disponibles en este nivel: { tipo de slime: cantidad }.
## Los tipos están definidos en SlimeCatalogo.Tipo.
## Cada nivel concreto lo redefine en su propio script (ver jungle_level.gd).
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

@onready var slingshoot: Node2D = $Slingshoot
@onready var ui: SlimeSelectorUI = $SlimeSelectorUI
@onready var camara: CamaraSeguimiento = $Camara

## Pantalla de pausa / fin de nivel. Si el nivel no tiene un nodo "PantallaFin", se crea sola.
var pantalla: PantallaFin
## true cuando el nivel ya terminó (victoria o derrota): evita que una pantalla pise a la otra.
var _terminado: bool = false

func _ready() -> void:
	# Resortera -> UI: cambió la munición o la selección.
	slingshoot.inventario_cambiado.connect(ui.actualizar)
	# UI -> Resortera: el jugador eligió otro tipo de slime.
	ui.slime_elegido.connect(slingshoot.seleccionar)
	# Resortera -> Nivel: ya no queda munición.
	slingshoot.sin_municion.connect(_on_sin_municion)
	# Resortera -> Cámara: sigue al slime en vuelo y vuelve a la resortera al recargar.
	slingshoot.slime_lanzado.connect(camara.seguir)
	slingshoot.slime_cargado.connect(_on_slime_cargado)

	pantalla = get_node_or_null("PantallaFin") as PantallaFin
	if pantalla == null:
		pantalla = PantallaFin.new()
		add_child(pantalla)

	# Meta(s) del nivel: cualquier nodo Meta en la escena se encuentra por su grupo.
	for meta in get_tree().get_nodes_in_group("meta"):
		meta.meta_alcanzada.connect(_on_meta_alcanzada)

	# Mismo diccionario para los dos. Primero la UI (crea los slots) y luego la
	# resortera (emite inventario_cambiado y la UI se rellena).
	ui.configurar(slimes_nivel)
	slingshoot.configurar(slimes_nivel)

	# La cámara arranca ya sobre la resortera (sin paneo inicial).
	camara.seguir(slingshoot, true)

func _on_slime_cargado(_slime: Node2D) -> void:
	camara.seguir(slingshoot)

func _on_sin_municion() -> void:
	camara.seguir(slingshoot)
	if _terminado:
		return
	_terminado = true
	pantalla.mostrar_derrota.call_deferred("Te quedaste sin slimes")

func _on_meta_alcanzada() -> void:
	if _terminado:
		return
	_terminado = true
	pantalla.mostrar_victoria.call_deferred("Slimes sobrantes: %d" % _slimes_restantes())

## Slimes que aún no se han disparado (el que está volando ya se descontó).
func _slimes_restantes() -> int:
	var total := 0
	for entrada in slingshoot.get_inventario():
		total += int(entrada["cantidad"])
	return total
