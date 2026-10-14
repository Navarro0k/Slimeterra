extends Node2D

## Se emite cada vez que cambia el inventario o el slime seleccionado.
## inventario: [{ "tipo": SlimeCatalogo.Tipo, "cantidad": int }, ...] (solo lectura).
## indice_seleccionado: -1 si no queda munición.
signal inventario_cambiado(inventario: Array, indice_seleccionado: int)
## Se emite cuando ya no queda ningún slime (ni en vuelo) para cargar.
signal sin_municion

@export var multiplicador_fuerza: float = 15.0
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0
@export var grosor_estirado: float = 1.0
@export var caida_reposo: float = 5.0
@export var puntos_trayectoria: int = 15
@export var paso_tiempo: float = 0.08

@export_group("Área de respeto")
## Tiempo máximo (s) que un slime puede atravesar sólidos si fue lanzado desde
## dentro de uno. Pasado ese tiempo se descarta y se carga el siguiente.
@export var tiempo_respeto: float = 1.5

var is_dragging: bool = false
var current_drag_position: Vector2
var slime_actual: RigidBody2D

## Munición por tipo: [{ "tipo": SlimeCatalogo.Tipo, "cantidad": int }].
var _inventario: Array[Dictionary] = []
## Índice (en _inventario) del tipo seleccionado. -1 = ninguno disponible.
var _indice: int = -1
## true desde que se lanza un slime hasta que termina su turno.
## Mientras es true NO se carga ningún slime en el holder.
var _esperando_turno: bool = false
## Padre original de la honda: a él vuelve cuando el slime se pega a un tile.
var _padre_original: Node

@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder

func _ready():
	_padre_original = get_parent()
	current_drag_position = center_marker.position
	actualizar_cuerdas(current_drag_position)
	# La munición NO se carga aquí: el nivel llama a configurar().

# ---------------------------------------------------------------------------
# API pública (la usa el script del nivel)
# ---------------------------------------------------------------------------

## Define los slimes con los que cuenta la resortera: { SlimeCatalogo.Tipo: cantidad }
## y carga el primero disponible.
func configurar(slimes: Dictionary) -> void:
	_quitar_slime_cargado()
	_esperando_turno = false
	_inventario = SlimeInventario.desde_diccionario(slimes)
	_indice = _primer_indice_con_stock()
	cargar_nuevo_slime()
	_notificar()

## Cambia el tipo de slime a disparar. Si hay uno cargado y no se está
## arrastrando, se cambia por uno del tipo nuevo (sin gastar munición).
func seleccionar(indice: int) -> void:
	if is_dragging or not _indice_valido(indice) or _inventario[indice]["cantidad"] <= 0:
		_notificar() # Re-sincroniza la UI con el estado real.
		return

	if indice != _indice:
		_indice = indice
		# Si hay un slime en vuelo solo cambia la selección: se cargará al terminar el turno.
		if not _esperando_turno and slime_actual != null:
			_quitar_slime_cargado()
			_instanciar_slime(_indice)
	_notificar()

func get_inventario() -> Array[Dictionary]:
	return _inventario

func get_indice_seleccionado() -> int:
	return _indice

# ---------------------------------------------------------------------------
# Posicionamiento del slime cargado
# ---------------------------------------------------------------------------

# El slime cargado SIEMPRE va en la punta de la cauchera (el Holder).
# Se fija por código en cada frame porque la física pisa la posición de un
# RigidBody2D congelado y no sigue bien el movimiento de su padre.
func _physics_process(_delta):
	_pegar_slime_al_holder()

func _process(_delta):
	_pegar_slime_al_holder()

func _pegar_slime_al_holder():
	if slime_actual != null and is_instance_valid(slime_actual):
		slime_actual.global_position = holder.global_position
		slime_actual.global_rotation = 0.0

# ---------------------------------------------------------------------------
# Input y dibujo
# ---------------------------------------------------------------------------

func _input(event):
	if not is_dragging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		soltar_resortera()
		return

	if event is InputEventMouseMotion:
		var mouse_pos = get_local_mouse_position()
		var drag_vector = mouse_pos - center_marker.position
		current_drag_position = center_marker.position + drag_vector.limit_length(max_stretch)

		actualizar_cuerdas(current_drag_position)
		queue_redraw()

func _draw():
	if is_dragging and slime_actual != null:
		var vector_disparo = center_marker.position - current_drag_position

		if vector_disparo.length() > 5.0:
			var velocidad_inicial = vector_disparo * multiplicador_fuerza
			var gravedad = ProjectSettings.get_setting("physics/2d/default_gravity")
			var k = ProjectSettings.get_setting("physics/2d/default_linear_damp")

			var puntos = SolverNumerico.trayectoria(
				holder.position, velocidad_inicial, gravedad, k,
				paso_tiempo, puntos_trayectoria, SolverNumerico.Metodo.RK4
			)
			for p in puntos:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 1.0, 1.0, 0.6))

func _on_holder_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if slime_actual != null:
			is_dragging = true

# ---------------------------------------------------------------------------
# Munición
# ---------------------------------------------------------------------------

func cargar_nuevo_slime():
	_esperando_turno = false
	# Guarda anti-duplicados: si ya hay un slime cargado, no crear otro.
	if slime_actual != null and is_instance_valid(slime_actual):
		return

	# Si el tipo seleccionado se agotó, pasa al primero que tenga stock.
	_ajustar_seleccion()

	if _indice == -1:
		print("¡Te quedaste sin munición de slimes!")
		sin_municion.emit()
	else:
		_instanciar_slime(_indice)
	_notificar()

func _instanciar_slime(indice: int) -> void:
	var escena: PackedScene = SlimeCatalogo.escena(_inventario[indice]["tipo"])
	slime_actual = escena.instantiate()
	holder.add_child(slime_actual)
	slime_actual.position = Vector2.ZERO
	# Cargado en la resortera: congelado y sin colisiones mientras se estira.
	if slime_actual.has_method("preparar"):
		slime_actual.preparar()
	else:
		slime_actual.freeze = true

## Quita el slime cargado (sin gastarlo) para poder cambiarlo por otro.
func _quitar_slime_cargado() -> void:
	if slime_actual != null and is_instance_valid(slime_actual):
		slime_actual.get_parent().remove_child(slime_actual)
		slime_actual.queue_free()
	slime_actual = null

func _indice_valido(indice: int) -> bool:
	return indice >= 0 and indice < _inventario.size()

func _primer_indice_con_stock() -> int:
	for i in _inventario.size():
		if _inventario[i]["cantidad"] > 0:
			return i
	return -1

## Mantiene la selección si aún hay stock de ese tipo; si no, elige otro.
func _ajustar_seleccion() -> void:
	if _indice_valido(_indice) and _inventario[_indice]["cantidad"] > 0:
		return
	_indice = _primer_indice_con_stock()

func _notificar() -> void:
	inventario_cambiado.emit(_inventario, _indice)

# ---------------------------------------------------------------------------
# Cuerdas
# ---------------------------------------------------------------------------

func actualizar_cuerdas(pos: Vector2):
	holder.position = pos

	var distancia = center_marker.position.distance_to(pos)
	var tension_ratio = clamp(distancia / max_stretch, 0.0, 1.0)
	var grosor_actual = lerp(grosor_reposo, grosor_estirado, tension_ratio)

	band_left.width = grosor_actual
	band_right.width = grosor_actual

	dibujar_banda_curva(band_left, anchor_left.position, pos, tension_ratio)
	dibujar_banda_curva(band_right, anchor_right.position, pos, tension_ratio)

func dibujar_banda_curva(linea: Line2D, p_inicio: Vector2, p_fin: Vector2, tension: float):
	var puntos = PackedVector2Array()

	if tension > 0.05:
		puntos.append(p_inicio)
		puntos.append(p_fin)
	else:
		var hundimiento = lerp(caida_reposo, 0.0, tension)
		var medio = p_inicio.lerp(p_fin, 0.5)
		medio.y += hundimiento

		puntos.append(p_inicio)
		puntos.append(medio)
		puntos.append(p_fin)

	linea.points = puntos

# ---------------------------------------------------------------------------
# Disparo
# ---------------------------------------------------------------------------

func soltar_resortera():
	is_dragging = false
	var vector_disparo = center_marker.position - current_drag_position

	queue_redraw()

	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING)\
		 .set_ease(Tween.EASE_OUT)

	if vector_disparo.length() > 5.0 and slime_actual != null:
		# Sale exactamente desde la punta de la cauchera, aunque el ratón se haya movido en este frame.
		slime_actual.global_position = holder.global_position
		slime_actual.reparent(get_tree().current_scene)
		slime_actual.freeze = false

		# Conectamos la resortera al destino y destino del slime
		if slime_actual.has_signal("slime_pegado"):
			slime_actual.slime_pegado.connect(_al_slime_pegarse)
		if slime_actual.has_signal("turno_terminado"):
			slime_actual.turno_terminado.connect(_al_terminar_turno)

		if slime_actual.has_method("lanzar"):
			# Nace sin colisiones y las recupera en cuanto su forma queda libre de sólidos.
			slime_actual.lanzar(vector_disparo * multiplicador_fuerza, tiempo_respeto)

		slime_actual = null

		# El disparo gasta una unidad del tipo seleccionado.
		_esperando_turno = true
		_inventario[_indice]["cantidad"] -= 1
		_ajustar_seleccion()
		_notificar()

func _al_slime_pegarse(nueva_posicion: Vector2, plataforma: Node):
	# Estas señales salen de un callback de colisión: no se puede modificar el
	# árbol de física ahí, así que todo se difiere al final del frame.
	# Si es una plataforma móvil, guardamos el punto en SU espacio local para
	# no perder el desfase por lo que se mueve entre el impacto y el diferido.
	var punto_local := Vector2.ZERO
	if plataforma != null:
		punto_local = plataforma.to_local(nueva_posicion)
	_mover_y_recargar.call_deferred(nueva_posicion, plataforma, punto_local)

func _al_terminar_turno():
	cargar_nuevo_slime.call_deferred()

func _mover_y_recargar(nueva_posicion: Vector2, plataforma: Node, punto_local: Vector2):
	var destino: Vector2 = nueva_posicion

	if plataforma != null and is_instance_valid(plataforma):
		# La honda pasa a ser hija de la plataforma para viajar con ella.
		if get_parent() != plataforma:
			reparent(plataforma, true)
		destino = plataforma.to_global(punto_local)
	elif get_parent() != _padre_original and is_instance_valid(_padre_original):
		# Se pegó a un tile: la honda vuelve a la escena normal.
		reparent(_padre_original, true)

	global_position = destino
	cargar_nuevo_slime()
