extends Node2D

signal inventario_cambiado(inventario: Array, indice_seleccionado: int)
signal sin_municion
signal slime_lanzado(slime: Node2D)
signal slime_cargado(slime: Node2D)

@export_group("Física y Tiro")
@export var multiplicador_fuerza: float = 15.0
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0
@export var grosor_estirado: float = 1.0
@export var caida_reposo: float = 5.0
@export_range(1, 8, 1) var puntos_trayectoria: int = 5
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

var slime_actual: RigidBody2D
var angulo_objetivo: float = 45.0
var potencia_objetivo: float = 65.0
var _inventario: Array[Dictionary] = []
var _indice: int = -1
var _esperando_turno: bool = false
var _padre_original: Node
var _sonido_estirar_sonado: bool = false
var _hud: ShotHUD
var _ultimo_vector_disparo: Vector2 = Vector2.ZERO
var _ultima_posicion_disparo: Vector2 = Vector2.ZERO

var _player_estirar: AudioStreamPlayer
var _player_estirar_loop: AudioStreamPlayer
var _player_lanzar: AudioStreamPlayer

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var center_marker: Marker2D = $CenterMarker
@onready var band_left: Line2D = $BandLeft
@onready var band_right: Line2D = $BandRight
@onready var holder: Area2D = $Holder
@onready var slingshot_sprite: Sprite2D = $SlingshotSprite
@onready var parche_sprite: Sprite2D = $Holder/Sprite2D
@onready var collision_holder: CollisionShape2D = $Holder/CollisionShape2D
@onready var label_angulo: Label = $LabelAngulo

func _ready() -> void:
	_padre_original = get_parent()
	_crear_reproductores()
	actualizar_cuerdas(center_marker.position)
	if collision_holder.shape is CircleShape2D:
		collision_holder.shape.radius = 7.0
	_actualizar_visibilidad(false)
	_crear_hud()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _draw() -> void:
	if mostrar_area_respeto:
		draw_arc(center_marker.position, max_stretch + margen_respeto, 0, TAU, 48, Color(1, 0.3, 0.3, 0.5), 0.5)
	if is_instance_valid(slime_actual) and not _esperando_turno:
		_dibujar_trayectoria()

func _crear_hud() -> void:
	_hud = ShotHUD.new()
	_hud.name = "ShotHUD"
	get_tree().current_scene.call_deferred("add_child", _hud)
	_hud.launch_requested.connect(disparar_con_parametros)
	_hud.aim_changed.connect(_on_aim_changed)
	_hud.set_launch_enabled(is_instance_valid(slime_actual))

func configurar(slimes: Dictionary) -> void:
	_quitar_slime()
	_esperando_turno = false
	_inventario = SlimeInventario.desde_diccionario(slimes)
	_indice = _primer_con_stock()
	_cargar_nuevo_slime()
	inventario_cambiado.emit(_inventario, _indice)

func seleccionar(idx: int) -> void:
	if idx < 0 or idx >= _inventario.size() or _inventario[idx]["cantidad"] <= 0:
		inventario_cambiado.emit(_inventario, _indice)
		return
	if idx != _indice:
		_indice = idx
		if not _esperando_turno and is_instance_valid(slime_actual):
			_quitar_slime()
			_instanciar_slime(_indice)
	_actualizar_hud_estado()
	inventario_cambiado.emit(_inventario, _indice)

func get_inventario() -> Array[Dictionary]:
	return _inventario

func get_indice_seleccionado() -> int:
	return _indice

func actualizar_aim(angulo: float, potencia: float) -> void:
	angulo_objetivo = clampf(angulo, 0.0, 180.0)
	potencia_objetivo = clampf(potencia, 0.0, 100.0)
	queue_redraw()

func disparar_con_parametros(angulo: float, potencia: float) -> void:
	if _esperando_turno or not is_instance_valid(slime_actual) or potencia <= 0.0:
		return
	actualizar_aim(angulo, potencia)
	var theta := deg_to_rad(angulo_objetivo + angulo_desvio_grados)
	var intensidad := potencia_objetivo / 100.0
	var vector_tiro := Vector2(cos(theta), -sin(theta)) * max_stretch * intensidad
	if vector_tiro.length() <= 0.1:
		return
	_ultima_posicion_disparo = holder.global_position
	_ultimo_vector_disparo = vector_tiro * multiplicador_fuerza
	_esperando_turno = true
	_detener_sonidos_estirar()
	_actualizar_visibilidad(true)
	_aplicar_tension_slime(0.0, Vector2.ZERO)
	_ejecutar_disparo(vector_tiro)
	_actualizar_hud_estado()
	queue_redraw()

func _on_aim_changed(angulo: float, potencia: float) -> void:
	actualizar_aim(angulo, potencia)
	if is_instance_valid(_hud):
		var gravedad: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
		var k: float = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))
		var theta := deg_to_rad(angulo_objetivo + angulo_desvio_grados)
		var velocidad := Vector2(cos(theta), -sin(theta)) * max_stretch * potencia_objetivo / 100.0 * multiplicador_fuerza
		_hud.set_model_values(holder.global_position, velocidad, gravedad, k)

func _cargar_nuevo_slime() -> void:
	_esperando_turno = false
	if is_instance_valid(slime_actual):
		_actualizar_hud_estado()
		return
	if _indice < 0 or _indice >= _inventario.size() or _inventario[_indice]["cantidad"] <= 0:
		_indice = _primer_con_stock()
	if _indice == -1:
		sin_municion.emit()
	else:
		_instanciar_slime(_indice)
	_actualizar_hud_estado()
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
	_actualizar_hud_estado()

func _quitar_slime() -> void:
	if is_instance_valid(slime_actual):
		slime_actual.get_parent().remove_child(slime_actual)
		slime_actual.queue_free()
	slime_actual = null

func _ejecutar_disparo(vector_tiro: Vector2) -> void:
	if not is_instance_valid(slime_actual):
		return
	slime_actual.global_position = holder.global_position
	slime_actual.reparent(get_tree().current_scene)
	slime_actual.freeze = false
	if slime_actual.has_signal("slime_pegado"):
		slime_actual.slime_pegado.connect(_al_pegarse)
	if slime_actual.has_signal("turno_terminado"):
		slime_actual.turno_terminado.connect(func(): _cargar_nuevo_slime.call_deferred())
	if slime_actual.has_method("lanzar"):
		var radio: float = max_stretch * absf(global_scale.x) + margen_respeto
		slime_actual.lanzar(vector_tiro * multiplicador_fuerza, tiempo_respeto, center_marker, radio)
	_reproducir(_player_lanzar, volumen_lanzar_db, velocidad_lanzar)
	slime_lanzado.emit(slime_actual)
	slime_actual = null
	_inventario[_indice]["cantidad"] -= 1
	if _inventario[_indice]["cantidad"] <= 0:
		_indice = _primer_con_stock()
	inventario_cambiado.emit(_inventario, _indice)

func _fijar_slime_al_holder() -> void:
	if is_instance_valid(slime_actual):
		slime_actual.global_position = holder.global_position
		slime_actual.global_rotation = 0.0

func _primer_con_stock() -> int:
	for i in _inventario.size():
		if _inventario[i]["cantidad"] > 0:
			return i
	return -1

func _aplicar_tension_slime(t: float, direccion_tiron: Vector2) -> void:
	if is_instance_valid(slime_actual) and slime_actual.has_method("set_tension"):
		slime_actual.set_tension(t, direccion_tiron)

func _actualizar_visibilidad(mostrar: bool) -> void:
	slingshot_sprite.visible = mostrar
	band_left.visible = mostrar
	band_right.visible = mostrar
	parche_sprite.visible = mostrar
	if is_instance_valid(label_angulo):
		label_angulo.visible = false

func actualizar_cuerdas(pos: Vector2) -> void:
	holder.position = pos
	var tension: float = clampf(center_marker.position.distance_to(pos) / max_stretch, 0.0, 1.0)
	var grosor: float = lerpf(grosor_reposo, grosor_estirado, tension)
	band_left.width = grosor
	band_right.width = grosor
	_dibujar_curva(band_left, anchor_left.position, pos, tension)
	_dibujar_curva(band_right, anchor_right.position, pos, tension)

func _dibujar_curva(linea: Line2D, p_ini: Vector2, p_fin: Vector2, tension: float) -> void:
	if tension > 0.05:
		linea.points = [p_ini, p_fin]
	else:
		var medio := p_ini.lerp(p_fin, 0.5)
		medio.y += lerpf(caida_reposo, 0.0, tension)
		linea.points = [p_ini, medio, p_fin]

func _dibujar_trayectoria() -> void:
	var theta := deg_to_rad(angulo_objetivo + angulo_desvio_grados)
	var velocidad := Vector2(cos(theta), -sin(theta)) * max_stretch * potencia_objetivo / 100.0 * multiplicador_fuerza
	var gravedad: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	var k: float = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))
	var puntos := ModeloDisparo.trayectoria(holder.position, velocidad, gravedad, k, paso_tiempo, puntos_trayectoria)
	# Solo se dibujan unos pocos puntos iniciales, como en Angry Birds.
	for i in range(mini(puntos.size(), 5)):
		var p: Vector2 = puntos[i]
		draw_circle(p, maxf(1.0, 2.6 - i * 0.25), Color(0.91, 1.0, 0.97, 0.8 - i * 0.1))

func _actualizar_hud_estado() -> void:
	if is_instance_valid(_hud):
		_hud.set_launch_enabled(is_instance_valid(slime_actual) and not _esperando_turno)
		var g: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
		var k: float = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))
		var theta := deg_to_rad(angulo_objetivo + angulo_desvio_grados)
		var velocidad := Vector2(cos(theta), -sin(theta)) * max_stretch * potencia_objetivo / 100.0 * multiplicador_fuerza
		_hud.set_model_values(holder.global_position, velocidad, g, k)
	queue_redraw()

func _crear_reproductores() -> void:
	var bus := bus_efectos if AudioServer.get_bus_index(bus_efectos) != -1 else &"Master"
	_player_estirar = _nuevo_audio(sonido_estirar, bus, _al_terminar_sonido_inicio)
	_player_estirar_loop = _nuevo_audio(sonido_estirar_loop, bus)
	_player_lanzar = _nuevo_audio(sonido_lanzar, bus)

func _nuevo_audio(stream: AudioStream, bus: StringName, callback: Callable = Callable()) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
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
	pass

func _iniciar_loop() -> void:
	if not _player_estirar_loop.playing:
		_player_estirar_loop.play()

func _detener_sonidos_estirar() -> void:
	_player_estirar.stop()
	_player_estirar_loop.stop()
	_sonido_estirar_sonado = false

func _al_pegarse(pos: Vector2, plataforma: Node) -> void:
	var punto_local: Vector2 = plataforma.to_local(pos) if is_instance_valid(plataforma) else Vector2.ZERO
	_mover_y_recargar.call_deferred(pos, plataforma, punto_local)

func _mover_y_recargar(pos_global: Vector2, plataforma: Node, pos_local: Vector2) -> void:
	if is_instance_valid(plataforma):
		if get_parent() != plataforma:
			reparent(plataforma, true)
		global_position = plataforma.to_global(pos_local)
	elif is_instance_valid(_padre_original):
		reparent(_padre_original, true)
		global_position = pos_global
	_cargar_nuevo_slime.call_deferred()
