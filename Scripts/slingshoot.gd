extends Node2D

# ==============================================================================
# SEÑALES
# ==============================================================================
signal inventario_cambiado(inventario: Array, indice_seleccionado: int)
signal sin_municion
signal slime_lanzado(slime: Node2D)
signal slime_cargado(slime: Node2D)
## Se emite mientras se apunta, cada vez que cambia la predicción (para el panel de datos).
signal prediccion_actualizada(datos: Dictionary)
## Se emite al disparar, con la predicción completa del tiro (para el rastro y las tarjetas).
signal tiro_disparado(datos: Dictionary)
## Se emite al activar/desactivar la vista "RK4 por dentro".
signal vista_rk4_cambiada(visible: bool)

# ==============================================================================
# EXPORTS (Configuración del nodo)
# ==============================================================================
@export_group("Física y Tiro")
@export var multiplicador_fuerza: float = 15.0
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0
@export var grosor_estirado: float = 1.0
@export var caida_reposo: float = 5.0
## Cantidad de puntos de la predicción. Cada punto es UN paso de RK4.
@export var puntos_trayectoria: int = 15
## Δt (s) entre puntos de la predicción: 15 pasos x 0.08 s = 1.2 s de vuelo predicho.
@export var paso_tiempo: float = 0.08
@export var angulo_desvio_grados: float = 0.0

@export_group("Modo educativo (RK4)")
## Muestra las 4 pendientes de RK4 (k1..k4) sobre el paso seleccionado de la predicción.
## Se alterna en juego con la tecla K o con el botón del panel de datos.
@export var mostrar_rk4: bool = false
## Paso de la predicción cuyas etapas se dibujan (0 = primer paso). Q/E o la rueda del ratón.
@export var paso_rk4: int = 0

@export_group("Área de Respeto")
@export var tiempo_respeto: float = 1.5
@export var margen_respeto: float = 2.0
@export var mostrar_area_respeto: bool = false

@export_group("Audio")
@export var bus_efectos: StringName = &"SFX"
@export var sonido_estirar: AudioStream
@export var sonido_estirar_loop: AudioStream
@export var sonido_lanzar: AudioStream
@export var volumen_loop_min_db: float = -20.0
@export var volumen_estirar_db: float = -4.0
@export var volumen_lanzar_db: float = 0.0
@export var tono_loop_min: float = 0.9
@export var tono_loop_max: float = 1.3
@export_range(0.5, 2.0, 0.05) var velocidad_inicio: float = 1.0
@export_range(0.5, 2.0, 0.05) var velocidad_lanzar: float = 1.0
@export_range(0.0, 0.3, 0.01) var variacion_tono: float = 0.05

# ==============================================================================
# VARIABLES DE ESTADO
# ==============================================================================
var slime_actual: RigidBody2D
var is_dragging: bool = false
var current_drag_position: Vector2

var _inventario: Array[Dictionary] = []
var _indice: int = -1
var _esperando_turno: bool = false
var _padre_original: Node
var _sonido_estirar_sonado: bool = false
## Última predicción calculada mientras se apunta (ver _calcular_datos).
var _datos: Dictionary = {}
## Capa hija donde se dibujan la predicción y las flechas de RK4. Tiene z_index alto para
## que los puntos no queden tapados por los tiles del nivel.
var _capa_prediccion: Node2D

# Reproductores
var _player_estirar: AudioStreamPlayer
var _player_estirar_loop: AudioStreamPlayer
var _player_lanzar: AudioStreamPlayer

# ==============================================================================
# NODOS (@onready)
# ==============================================================================
@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder
@onready var slingshot_sprite = $SlingshotSprite
@onready var parche_sprite = $Holder/Sprite2D
@onready var collision_holder = $Holder/CollisionShape2D
@onready var label_angulo = $LabelAngulo

# ==============================================================================
# CICLO DE VIDA (Engine Callbacks)
# ==============================================================================
func _ready() -> void:
	_padre_original = get_parent()
	current_drag_position = center_marker.position

	_crear_reproductores()
	actualizar_cuerdas(current_drag_position)

	_capa_prediccion = Node2D.new()
	_capa_prediccion.name = "CapaPrediccion"
	_capa_prediccion.z_index = 20
	_capa_prediccion.z_as_relative = false
	add_child(_capa_prediccion)
	_capa_prediccion.draw.connect(_dibujar_prediccion)

	if collision_holder.shape is CircleShape2D:
		collision_holder.shape.radius = 7.0

	_actualizar_visibilidad(false)
	_redibujar()

func _physics_process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_soltar_resortera()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cambiar_paso_rk4(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cambiar_paso_rk4(-1)
		return

	if event is InputEventMouseMotion:
		_procesar_arrastre()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_K:
			alternar_rk4()
		KEY_E, KEY_RIGHT:
			cambiar_paso_rk4(1)
		KEY_Q, KEY_LEFT:
			cambiar_paso_rk4(-1)
		_:
			return
	get_viewport().set_input_as_handled()

func _draw() -> void:
	if mostrar_area_respeto:
		draw_arc(center_marker.position, max_stretch + margen_respeto, 0, TAU, 48, Color(1, 0.3, 0.3, 0.5), 0.5)


## Dibuja en la capa de predicción (encima de los tiles).
func _dibujar_prediccion() -> void:
	if is_dragging and slime_actual:
		_dibujar_trayectoria()

## Redibuja la resortera y su capa de predicción.
func _redibujar() -> void:
	queue_redraw()
	if _capa_prediccion:
		_capa_prediccion.queue_redraw()

# ==============================================================================
# API PÚBLICA (Usada por el nivel/UI)
# ==============================================================================
func configurar(slimes: Dictionary) -> void:
	_quitar_slime()
	_esperando_turno = false
	_inventario = SlimeInventario.desde_diccionario(slimes)
	_indice = _primer_con_stock()
	_cargar_nuevo_slime()
	inventario_cambiado.emit(_inventario, _indice)

func seleccionar(idx: int) -> void:
	if is_dragging or idx < 0 or idx >= _inventario.size() or _inventario[idx]["cantidad"] <= 0:
		inventario_cambiado.emit(_inventario, _indice)
		return

	if idx != _indice:
		_indice = idx
		if not _esperando_turno and slime_actual:
			_quitar_slime()
			_instanciar_slime(_indice)

	inventario_cambiado.emit(_inventario, _indice)

func get_inventario() -> Array[Dictionary]:
	return _inventario

func get_indice_seleccionado() -> int:
	return _indice

## Activa/desactiva la vista "RK4 por dentro" (tecla K o botón del panel).
func alternar_rk4() -> void:
	mostrar_rk4 = not mostrar_rk4
	vista_rk4_cambiada.emit(mostrar_rk4)
	_refrescar_prediccion()

## Cambia el paso de la predicción cuyas etapas k1..k4 se muestran.
func cambiar_paso_rk4(delta: int) -> void:
	paso_rk4 = clampi(paso_rk4 + delta, 0, maxi(puntos_trayectoria - 1, 0))
	_refrescar_prediccion()

func _refrescar_prediccion() -> void:
	if is_dragging and slime_actual:
		_calcular_datos()
		_redibujar()

# ==============================================================================
# LÓGICA PRINCIPAL (Disparo y Munición)
# ==============================================================================
func _cargar_nuevo_slime() -> void:
	_esperando_turno = false
	if is_instance_valid(slime_actual):
		return

	if _indice < 0 or _indice >= _inventario.size() or _inventario[_indice]["cantidad"] <= 0:
		_indice = _primer_con_stock()

	if _indice == -1:
		sin_municion.emit()
	else:
		_instanciar_slime(_indice)

	inventario_cambiado.emit(_inventario, _indice)

func _instanciar_slime(idx: int) -> void:
	slime_actual = SlimeCatalogo.escena(_inventario[idx]["tipo"]).instantiate()
	holder.add_child(slime_actual)
	slime_actual.position = Vector2.ZERO

	if slime_actual.has_method("preparar"):
		slime_actual.preparar()
	else:
		slime_actual.freeze = true

	slime_cargado.emit(slime_actual)

func _quitar_slime() -> void:
	if is_instance_valid(slime_actual):
		slime_actual.get_parent().remove_child(slime_actual)
		slime_actual.queue_free()
	slime_actual = null

func _soltar_resortera() -> void:
	_aplicar_tension_slime(0.0, Vector2.ZERO)
	is_dragging = false
	var vector_tiro = center_marker.position - current_drag_position

	if angulo_desvio_grados != 0:
		vector_tiro = SolverNumerico.aplicar_matriz_rotacion(vector_tiro, deg_to_rad(angulo_desvio_grados))

	_detener_sonidos_estirar()
	_redibujar()

	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): if not is_dragging: _actualizar_visibilidad(false))

	if vector_tiro.length() > 5.0 and slime_actual:
		_calcular_datos()
		_ejecutar_disparo(vector_tiro)
		tiro_disparado.emit(_datos)

func _ejecutar_disparo(vector_tiro: Vector2) -> void:
	slime_actual.global_position = holder.global_position
	slime_actual.reparent(get_tree().current_scene)
	slime_actual.freeze = false

	if slime_actual.has_signal("slime_pegado"):
		slime_actual.slime_pegado.connect(_al_pegarse)
	if slime_actual.has_signal("turno_terminado"):
		slime_actual.turno_terminado.connect(func(): _cargar_nuevo_slime.call_deferred())
	if slime_actual.has_method("lanzar"):
		var radio = max_stretch * absf(global_scale.x) + margen_respeto
		slime_actual.lanzar(vector_tiro * multiplicador_fuerza, tiempo_respeto, center_marker, radio)

	_reproducir(_player_lanzar, volumen_lanzar_db, velocidad_lanzar)
	slime_lanzado.emit(slime_actual)
	slime_actual = null

	_esperando_turno = true
	_inventario[_indice]["cantidad"] -= 1
	if _inventario[_indice]["cantidad"] <= 0:
		_indice = _primer_con_stock()
	inventario_cambiado.emit(_inventario, _indice)

func _fijar_slime_al_holder() -> void:
	if is_instance_valid(slime_actual):
		slime_actual.global_position = holder.global_position
		slime_actual.global_rotation = 0.0

func _procesar_arrastre() -> void:
	var offset = get_local_mouse_position() - center_marker.position
	current_drag_position = center_marker.position + offset.limit_length(max_stretch)
	var tension = clampf(current_drag_position.distance_to(center_marker.position) / max_stretch, 0.0, 1.0)

	if not _sonido_estirar_sonado and offset.length() > 5.0:
		_sonido_estirar_sonado = true
		if sonido_estirar:
			_reproducir(_player_estirar, volumen_estirar_db, velocidad_inicio)
		else:
			_iniciar_loop()

	if _sonido_estirar_sonado:
		_player_estirar_loop.volume_db = lerpf(volumen_loop_min_db, volumen_estirar_db, tension)
		_player_estirar_loop.pitch_scale = lerpf(tono_loop_min, tono_loop_max, tension)

	_aplicar_tension_slime(tension, current_drag_position - center_marker.position)
	actualizar_cuerdas(current_drag_position)

	var vector_tiro = center_marker.position - current_drag_position
	# Ángulo de elevación: medido desde la horizontal, positivo hacia arriba (como en física).
	var grados := roundi(Unidades.angulo_grados(vector_tiro))
	label_angulo.text = str(grados) + "°"
	label_angulo.position = center_marker.position + Vector2(10, 0)

	if is_instance_valid(slime_actual) and "tipo_slime" in slime_actual:
		if slime_actual.tipo_slime == "fuego":
			label_angulo.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		else:
			label_angulo.add_theme_color_override("font_color", Color(1.0, 0.65, 0.9))
	# -----------------------------------------------------

	_calcular_datos()
	_redibujar()

func _primer_con_stock() -> int:
	for i in _inventario.size():
		if _inventario[i]["cantidad"] > 0:
			return i
	return -1

func _aplicar_tension_slime(t: float, direccion_tiron: Vector2) -> void:
	if is_instance_valid(slime_actual) and slime_actual.has_method("set_tension"):
		slime_actual.set_tension(t, direccion_tiron)

# ==============================================================================
# LÓGICA VISUAL Y DIBUJO
# ==============================================================================
func _actualizar_visibilidad(mostrar: bool) -> void:
	slingshot_sprite.visible = mostrar
	band_left.visible = mostrar
	band_right.visible = mostrar
	parche_sprite.visible = mostrar
	if label_angulo: label_angulo.visible = mostrar

func actualizar_cuerdas(pos: Vector2) -> void:
	holder.position = pos
	var tension = clamp(center_marker.position.distance_to(pos) / max_stretch, 0.0, 1.0)
	var grosor = lerp(grosor_reposo, grosor_estirado, tension)

	band_left.width = grosor
	band_right.width = grosor
	_dibujar_curva(band_left, anchor_left.position, pos, tension)
	_dibujar_curva(band_right, anchor_right.position, pos, tension)

func _dibujar_curva(linea: Line2D, p_ini: Vector2, p_fin: Vector2, tension: float) -> void:
	if tension > 0.05:
		linea.points = [p_ini, p_fin]
	else:
		var medio = p_ini.lerp(p_fin, 0.5)
		medio.y += lerp(caida_reposo, 0.0, tension)
		linea.points = [p_ini, medio, p_fin]

func _vector_tiro_actual() -> Vector2:
	var vector_tiro = center_marker.position - current_drag_position
	if angulo_desvio_grados != 0:
		vector_tiro = SolverNumerico.aplicar_matriz_rotacion(vector_tiro, deg_to_rad(angulo_desvio_grados))
	return vector_tiro

## Calcula con RK4 todo lo que se muestra mientras se apunta: los puntos de la predicción,
## las magnitudes del tiro (altura máxima, alcance, tiempo), el error frente a la solución
## exacta y las etapas k1..k4 del paso seleccionado. Lo guarda en _datos y avisa al panel.
func _calcular_datos() -> void:
	var vector_tiro := _vector_tiro_actual()
	if vector_tiro.length() <= 5.0:
		_datos = {}
		prediccion_actualizada.emit(_datos)
		return

	var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var k: float = ProjectSettings.get_setting("physics/2d/default_linear_damp")
	var dt_motor := 1.0 / float(Engine.physics_ticks_per_second)
	var pos0: Vector2 = holder.position
	var v0: Vector2 = vector_tiro * multiplicador_fuerza
	paso_rk4 = clampi(paso_rk4, 0, maxi(puntos_trayectoria - 1, 0))

	var puntos := SolverNumerico.trayectoria(pos0, v0, gravedad, k, paso_tiempo, puntos_trayectoria, SolverNumerico.Metodo.RK4)
	var puntos_global := PackedVector2Array()
	for p in puntos:
		puntos_global.append(to_global(p))

	_datos = {
		"v0": v0,
		"pos0": pos0,
		"pos0_global": to_global(pos0),
		"gravedad": gravedad,
		"k": k,
		"dt": paso_tiempo,
		"dt_motor": dt_motor,
		"n": puntos_trayectoria,
		"puntos": puntos,
		"puntos_global": puntos_global,
		"prediccion": SolverNumerico.predecir_tiro(pos0, v0, gravedad, k, dt_motor),
		"error_px": SolverNumerico.error_en(SolverNumerico.Metodo.RK4, pos0, v0, gravedad, k, paso_tiempo, puntos_trayectoria),
		"primer_paso": SolverNumerico.etapas_rk4(pos0, v0, paso_tiempo, gravedad, k),
		"paso_sel": paso_rk4,
		"etapas": SolverNumerico.etapas_en_paso(pos0, v0, gravedad, k, paso_tiempo, paso_rk4),
		"rk4_visible": mostrar_rk4,
	}
	prediccion_actualizada.emit(_datos)

## Colores de las etapas de RK4 (los mismos en el dibujo, el panel y las tarjetas).
const COLORES_K: Array[Color] = [
	Color(1.0, 0.35, 0.35), # k1
	Color(1.0, 0.7, 0.28),  # k2
	Color(0.45, 0.9, 0.45), # k3
	Color(0.35, 0.7, 1.0),  # k4
]
const COLOR_PROMEDIO := Color(1.0, 0.95, 0.4)

func _dibujar_trayectoria() -> void:
	if _datos.is_empty():
		return
	var puntos: PackedVector2Array = _datos["puntos"]
	var sel: int = _datos["paso_sel"]
	for i in puntos.size():
		var p := puntos[i]
		# Borde oscuro para que el punto se vea sobre fondos claros (hielo, cielo).
		_capa_prediccion.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0, 0, 0, 0.35))
		var color := Color(1, 1, 1, 0.85)
		if mostrar_rk4 and (i == sel or i == sel - 1):
			color = COLOR_PROMEDIO
		_capa_prediccion.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), color)

	if mostrar_rk4:
		_dibujar_etapas_rk4(_datos["etapas"])

## Dibuja un paso de RK4 "por dentro": desde el punto de partida, una flecha por cada
## pendiente k1..k4 (hasta donde llegaría el slime si usara SOLO esa pendiente durante Δt),
## un puntito donde se evaluó cada pendiente y, en amarillo, el promedio ponderado
## (k1 + 2k2 + 2k3 + k4) / 6, que es el que realmente lleva al siguiente punto.
func _dibujar_etapas_rk4(e: Dictionary) -> void:
	var origen: Vector2 = e["pos"]
	var dt: float = e["dt"]
	var kp: Array = e["kp"]
	var evals: Array = e["puntos_eval"]
	for i in 4:
		_dibujar_flecha(origen, origen + (kp[i] as Vector2) * dt, COLORES_K[i], 1.0)
		_capa_prediccion.draw_circle(evals[i], 1.5, COLORES_K[i])
	_dibujar_flecha(origen, e["pos_nueva"], COLOR_PROMEDIO, 1.5)

func _dibujar_flecha(desde: Vector2, hasta: Vector2, color: Color, grosor: float) -> void:
	var dir := hasta - desde
	if dir.length() < 0.5:
		return
	_capa_prediccion.draw_line(desde, hasta, color, grosor)
	var u := dir.normalized()
	var punta := 3.5
	_capa_prediccion.draw_colored_polygon(PackedVector2Array([
		hasta,
		hasta - u * punta + u.orthogonal() * punta * 0.55,
		hasta - u * punta - u.orthogonal() * punta * 0.55,
	]), color)

# ==============================================================================
# AUDIO
# ==============================================================================
func _crear_reproductores() -> void:
	var bus = bus_efectos if AudioServer.get_bus_index(bus_efectos) != -1 else &"Master"
	_player_estirar = _nuevo_audio(sonido_estirar, bus, _al_terminar_sonido_inicio)
	_player_estirar_loop = _nuevo_audio(sonido_estirar_loop, bus)
	_player_lanzar = _nuevo_audio(sonido_lanzar, bus)

func _nuevo_audio(stream: AudioStream, bus: StringName, callback: Callable = Callable()) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	if callback.is_valid():
		player.finished.connect(callback)
	add_child(player)
	return player

func _reproducir(player: AudioStreamPlayer, vol: float, vel: float) -> void:
	if player and player.stream:
		player.volume_db = vol
		player.pitch_scale = vel * (1.0 + randf_range(-variacion_tono, variacion_tono))
		player.play()

func _al_terminar_sonido_inicio() -> void:
	if is_dragging: _iniciar_loop()

func _iniciar_loop() -> void:
	if not _player_estirar_loop.playing: _player_estirar_loop.play()

func _detener_sonidos_estirar() -> void:
	_player_estirar.stop()
	_player_estirar_loop.stop()
	_sonido_estirar_sonado = false

# ==============================================================================
# EVENTOS (Callbacks de Nodos)
# ==============================================================================
func _on_holder_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if slime_actual:
			is_dragging = true
			_actualizar_visibilidad(true)

func _al_pegarse(pos: Vector2, plataforma: Node) -> void:
	var punto_local = plataforma.to_local(pos) if plataforma else Vector2.ZERO
	_mover_y_recargar.call_deferred(pos, plataforma, punto_local)

func _mover_y_recargar(pos_global: Vector2, plataforma: Node, pos_local: Vector2) -> void:
	if is_instance_valid(plataforma):
		if get_parent() != plataforma:
			reparent(plataforma, true)
		global_position = plataforma.to_global(pos_local)
	elif is_instance_valid(_padre_original):
		reparent(_padre_original, true)
		global_position = pos_global

	_cargar_nuevo_slime()
