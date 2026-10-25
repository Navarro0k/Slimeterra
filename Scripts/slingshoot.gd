extends Node2D

# ==============================================================================
# SEÑALES
# ==============================================================================
signal inventario_cambiado(inventario: Array, indice_seleccionado: int)
signal sin_municion
signal slime_lanzado(slime: Node2D)
signal slime_cargado(slime: Node2D)

# ==============================================================================
# EXPORTS (Configuración del nodo)
# ==============================================================================
@export_group("Física y Tiro")
@export var multiplicador_fuerza: float = 15.0
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0
@export var grosor_estirado: float = 1.0
@export var caida_reposo: float = 5.0
@export var puntos_trayectoria: int = 4
@export var paso_tiempo: float = 0.08
@export var angulo_desvio_grados: float = 0.0

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

# ==============================================================================
# CICLO DE VIDA (Engine Callbacks)
# ==============================================================================
func _ready() -> void:
	_padre_original = get_parent()
	current_drag_position = center_marker.position
	
	_crear_reproductores()
	actualizar_cuerdas(current_drag_position)
	
	if collision_holder.shape is CircleShape2D: 
		collision_holder.shape.radius = 7.0
		
	_actualizar_visibilidad(false)
	queue_redraw()

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
		
	if event is InputEventMouseMotion:
		_procesar_arrastre()

func _draw() -> void:
	if mostrar_area_respeto: 
		draw_arc(center_marker.position, max_stretch + margen_respeto, 0, TAU, 48, Color(1, 0.3, 0.3, 0.5), 0.5)
		
	if is_dragging and slime_actual:
		_dibujar_trayectoria()

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
	queue_redraw()
	
	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): if not is_dragging: _actualizar_visibilidad(false))

	if vector_tiro.length() > 5.0 and slime_actual:
		_ejecutar_disparo(vector_tiro)

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
	
	# SOLUCIÓN: Calculamos la tensión usando la distancia ya limitada (current_drag_position) 
	# y nos aseguramos de que no supere el 1.0 (100%).
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
	queue_redraw()

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

func _dibujar_trayectoria() -> void:
	var vector_tiro = center_marker.position - current_drag_position
	
	if angulo_desvio_grados != 0: 
		vector_tiro = SolverNumerico.aplicar_matriz_rotacion(vector_tiro, deg_to_rad(angulo_desvio_grados))
	
	if vector_tiro.length() > 5.0:
		var gravedad = ProjectSettings.get_setting("physics/2d/default_gravity")
		var k = ProjectSettings.get_setting("physics/2d/default_linear_damp")
		var puntos = SolverNumerico.trayectoria(
			holder.position, vector_tiro * multiplicador_fuerza, 
			gravedad, k, paso_tiempo, puntos_trayectoria, SolverNumerico.Metodo.RK4
		)
		for p in puntos:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.6))

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
