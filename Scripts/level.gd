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

@export_group("Límites del nivel")
## Rectángulo del nivel en coordenadas del nivel. Si tiene tamaño, se usa tal cual.
@export var limites: Rect2 = Rect2()
## Sin límites manuales, los calcula con el dibujo del nivel (tiles visibles y sprites de fondo).
@export var limites_automaticos: bool = false
## Si está activo, ignora fondos y sprites y usa solo los tiles con colisión.
@export var solo_tiles_solidos: bool = false
## Margen extra (px) fuera del dibujo. Por defecto 0: los límites coinciden con el dibujo.
@export var margen_izquierda: float = 0.0
@export var margen_arriba: float = 0.0
@export var margen_derecha: float = 0.0
@export var margen_abajo: float = 0.0
## Dibuja el marco de los límites (útil para ajustarlos).
@export var mostrar_limites: bool = false

## Límites en coordenadas globales (sin área = el nivel no tiene límites).
var limites_globales: Rect2 = Rect2()

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
	pantalla.mostrar_victoria.call_deferred("Slimes sobrantes: %d" % _slimes_restantes())

## Slimes que aún no se han disparado (el que está volando ya se descontó).
func _slimes_restantes() -> int:
	var total := 0
	for entrada in slingshoot.get_inventario():
		total += int(entrada["cantidad"])
	return total
	# Punto de enganche para derrota / reinicio del nivel.

## Límites manuales o, si están activados, los del dibujo del nivel: el rectángulo que
## engloba lo que realmente se ve (tiles visibles y sprites de fondo) más los márgenes.
func _calcular_limites() -> Rect2:
	if limites.has_area():
		return Rect2(to_global(limites.position), limites.size)
	if not limites_automaticos:
		return Rect2()

	var area := Rect2()
	var hay_dibujo := false

	# Capas de tiles visibles (la capa de fondo oculta no cuenta).
	for nodo in find_children("*", "TileMapLayer", true, false):
		var capa := nodo as TileMapLayer
		if capa.tile_set == null or not capa.is_visible_in_tree():
			continue
		if solo_tiles_solidos and capa.tile_set.get_physics_layers_count() == 0:
			continue
		var celdas := capa.get_used_rect()
		if celdas.size == Vector2i.ZERO:
			continue
		var mitad := Vector2(capa.tile_set.tile_size) * 0.5
		var desde := capa.to_global(capa.map_to_local(celdas.position) - mitad)
		var hasta := capa.to_global(capa.map_to_local(celdas.end - Vector2i.ONE) + mitad)
		area = Rect2(desde, hasta - desde) if not hay_dibujo else area.merge(Rect2(desde, hasta - desde))
		hay_dibujo = true

	# Sprites de fondo visibles (con su escala, posición y recorte reales).
	if not solo_tiles_solidos:
		for nodo in find_children("*", "Sprite2D", true, false):
			var sprite := nodo as Sprite2D
			if sprite.texture == null or not sprite.is_visible_in_tree() or _es_dinamico(sprite):
				continue
			var rect_sprite := _rect_global(sprite)
			area = rect_sprite if not hay_dibujo else area.merge(rect_sprite)
			hay_dibujo = true

	if not hay_dibujo:
		return Rect2()
	area = area.expand(slingshoot.global_position) # La resortera siempre queda dentro.
	return area.grow_individual(margen_izquierda, margen_arriba, margen_derecha, margen_abajo)

## Rectángulo global que ocupa un sprite (caja que engloba a sus cuatro esquinas).
func _rect_global(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var t := sprite.global_transform
	var esquinas := [
		t * local.position, t * Vector2(local.end.x, local.position.y),
		t * local.end, t * Vector2(local.position.x, local.end.y),
	]
	var rect := Rect2(esquinas[0], Vector2.ZERO)
	for punto in esquinas:
		rect = rect.expand(punto)
	return rect

## Lo que se mueve o no es escenario (la resortera, plataformas móviles, UI) no define el dibujo.
func _es_dinamico(nodo: Node) -> bool:
	var actual := nodo.get_parent()
	while actual != null and actual != self:
		if actual == slingshoot or actual is CollisionObject2D or actual is CanvasLayer:
			return true
		actual = actual.get_parent()
	return false

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
