class_name NivelSlimes
extends Node2D
## Script del nivel: es el único que conoce a la resortera y a la UI.
## Les entrega el inventario de slimes y los comunica entre sí.
## También decide cuándo termina el nivel: victoria al tocar una Meta, derrota al quedarse sin slimes.

## Orden de los niveles del juego. Al ganar se pasa al siguiente de esta lista y el último
## cierra el juego. Para añadir un nivel basta con añadirlo aquí.
const ORDEN_NIVELES: Array[String] = [
	"res://Scenes/Levels/jungleLevel.tscn",
	"res://Scenes/Levels/Level_Ice.tscn",
]

## Slimes disponibles en este nivel: { tipo de slime: cantidad }.
## Los tipos están definidos en SlimeCatalogo.Tipo.
## Cada nivel concreto lo redefine en su propio script (ver jungle_level.gd).
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

@export_group("Límites del nivel")
@export var mostrar_limites: bool = false

@export_group("Estrellas")
## Tiempo (s) máximo para conseguir 3 estrellas.
@export var tiempo_3_estrellas: float = 45.0
## Tiempo (s) máximo para conseguir 2 estrellas. Más que esto = 1 estrella.
@export var tiempo_2_estrellas: float = 90.0

var limites_globales: Rect2 = Rect2()
var tiempo_transcurrido: float = 0.0
var _etiqueta_tiempo: Label

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
	slingshoot.slime_lanzado.connect(_on_slime_lanzado)
	slingshoot.slime_cargado.connect(_on_slime_cargado)

	pantalla = get_node_or_null("PantallaFin") as PantallaFin
	if pantalla == null:
		pantalla = PantallaFin.new()
		add_child(pantalla)
	_configurar_progresion()

	# Meta(s) del nivel: cualquier nodo Meta en la escena se encuentra por su grupo.
	var metas := get_tree().get_nodes_in_group("meta")
	if metas.is_empty():
		push_warning("Este nivel no tiene ninguna Meta (instancia Scenes/Meta.tscn): no se podrá ganar.")
	for meta in metas:
		meta.meta_alcanzada.connect(_on_meta_alcanzada)
	# Límites: la cámara no sale del nivel y el slime rebota en sus bordes.
	limites_globales = _calcular_limites()
	camara.aplicar_limites(limites_globales)
	if mostrar_limites:
		print("%s límites: %s" % [name, limites_globales])
		_crear_marco_limites()

	# Mismo diccionario para los dos. Primero la UI (crea los slots) y luego la
	# resortera (emite inventario_cambiado y la UI se rellena).
	ui.configurar(slimes_nivel)
	slingshoot.configurar(slimes_nivel)

	# La cámara arranca ya sobre la resortera (sin paneo inicial).
	camara.seguir(slingshoot, true)

	_crear_hud_tiempo()

func _process(delta: float) -> void:
	if _terminado or _etiqueta_tiempo == null:
		return
	tiempo_transcurrido += delta
	_etiqueta_tiempo.text = _formatear_tiempo(tiempo_transcurrido)

# ---------------------------------------------------------------------------
# Contador de tiempo y estrellas
# ---------------------------------------------------------------------------

func _crear_hud_tiempo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_etiqueta_tiempo = Label.new()
	_etiqueta_tiempo.text = "0:00.0"
	_etiqueta_tiempo.custom_minimum_size = Vector2(80, 0)
	_etiqueta_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_tiempo.add_theme_font_size_override("font_size", 14)
	_etiqueta_tiempo.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta_tiempo.add_theme_constant_override("outline_size", 4)
	capa.add_child(_etiqueta_tiempo)
	_etiqueta_tiempo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	_etiqueta_tiempo.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _formatear_tiempo(t: float) -> String:
	var minutos := floori(t / 60.0)
	var segundos := fmod(t, 60.0)
	return "%d:%04.1f" % [minutos, segundos]

func _calcular_estrellas() -> int:
	if tiempo_transcurrido <= tiempo_3_estrellas:
		return 3
	if tiempo_transcurrido <= tiempo_2_estrellas:
		return 2
	return 1

# ---------------------------------------------------------------------------

func _on_slime_lanzado(slime: Node2D) -> void:
	# El slime en vuelo rebota en los límites del nivel y la cámara lo sigue.
	slime.set("limites", limites_globales)
	camara.seguir(slime)

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
	var mensaje := "Tiempo: %s\nSlimes sobrantes: %d" % [_formatear_tiempo(tiempo_transcurrido), _slimes_restantes()]
	pantalla.mostrar_victoria.call_deferred(mensaje, _calcular_estrellas())

## Slimes que aún no se han disparado (el que está volando ya se descontó).
func _slimes_restantes() -> int:
	var total := 0
	for entrada in slingshoot.get_inventario():
		total += int(entrada["cantidad"])
	return total

## Le dice a la pantalla de fin qué viene después de este nivel según ORDEN_NIVELES.
## Un nivel que no esté en la lista (por ejemplo Level_1) solo ofrece repetirse.
func _configurar_progresion() -> void:
	var posicion := ORDEN_NIVELES.find(scene_file_path)
	if posicion < 0:
		return
	pantalla.primer_nivel = ORDEN_NIVELES[0]
	if posicion + 1 < ORDEN_NIVELES.size():
		pantalla.siguiente_nivel = ORDEN_NIVELES[posicion + 1]
	else:
		pantalla.es_final_del_juego = true


func _calcular_limites() -> Rect2:
	var colision := get_node_or_null(
		"LimitesCamara/CollisionShape2D"
	) as CollisionShape2D

	if colision == null:
		push_error(
			"Falta LimitesCamara/CollisionShape2D en el nivel: " + name
		)
		return Rect2()

	if not colision.shape is RectangleShape2D:
		push_error(
			"LimitesCamara debe usar RectangleShape2D en el nivel: " + name
		)
		return Rect2()

	var rectangulo := colision.shape as RectangleShape2D
	var tamano: Vector2 = rectangulo.size * colision.global_scale.abs()

	if tamano.x <= 0.0 or tamano.y <= 0.0:
		push_error("El rectángulo de límites tiene tamaño inválido.")
		return Rect2()

	var origen: Vector2 = colision.global_position - tamano / 2.0

	return Rect2(origen, tamano)


func _crear_marco_limites() -> void:
	if not limites_globales.has_area():
		return
	var r := limites_globales
	var marco := Line2D.new()
	marco.width = 1.0
	marco.default_color = Color(1.0, 0.2, 0.2, 0.9)
	marco.z_index = 100
	marco.points = PackedVector2Array([
		to_local(r.position), to_local(Vector2(r.end.x, r.position.y)),
		to_local(r.end), to_local(Vector2(r.position.x, r.end.y)), to_local(r.position),
	])
	add_child(marco)
