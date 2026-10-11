extends Node2D

@export var slimes_disponibles: Array[PackedScene]
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
var _municion: Array[PackedScene] = []

@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder

func _ready():
	# Copia: no consumir el array exportado de la escena.
	_municion = slimes_disponibles.duplicate()
	current_drag_position = center_marker.position
	actualizar_cuerdas(current_drag_position)
	cargar_nuevo_slime()

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

func cargar_nuevo_slime():
	if _municion.size() > 0:
		var siguiente_slime = _municion.pop_front()
		slime_actual = siguiente_slime.instantiate()
		holder.add_child(slime_actual)
		slime_actual.position = Vector2.ZERO
		# Cargado en la resortera: congelado y sin colisiones mientras se estira.
		if slime_actual.has_method("preparar"):
			slime_actual.preparar()
		else:
			slime_actual.freeze = true
	else:
		print("¡Te quedaste sin munición de slimes!")

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

func _al_slime_pegarse(nueva_posicion: Vector2):
	# Estas señales salen de un callback de colisión: no se puede modificar el
	# árbol de física ahí, así que todo se difiere al final del frame.
	_mover_y_recargar.call_deferred(nueva_posicion)

func _al_terminar_turno():
	cargar_nuevo_slime.call_deferred()

func _mover_y_recargar(nueva_posicion: Vector2):
	global_position = nueva_posicion
	cargar_nuevo_slime()
