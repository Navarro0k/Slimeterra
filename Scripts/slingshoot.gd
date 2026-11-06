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
@export_range(1, 8, 1) var puntos_trayectoria: int = 10
@export var paso_tiempo: float = 0.08
@export var angulo_desvio_grados: float = 0.0
## Modo de ecuación que muestra el HUD: "parabola" (nivel 1) o "matrices" (nivel 2).
@export var modo_ecuacion: String = "parabola"


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
var _arrastrando_slime: bool = false
## Solo se dibuja la trayectoria predictiva mientras se apunta (arrastrando o moviendo dial/slider).
var _mostrar_trayectoria: bool = false
var _posicion_holder_reposo: Vector2 = Vector2.ZERO

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
	_posicion_holder_reposo = center_marker.position
	if collision_holder.shape is CircleShape2D:
		collision_holder.shape.radius = 7.0
	_actualizar_visibilidad(false)
	_crear_hud()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _process(_delta: float) -> void:
	_fijar_slime_al_holder()

func _unhandled_input(event: InputEvent) -> void:
	if _esperando_turno or not is_instance_valid(slime_actual):
		return
	if is_instance_valid(_hud) and _hud.cartilla_activa:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _arrastrando_slime:
			var mouse_global := get_global_mouse_position()
			var radio_captura := maxf(12.0, max_stretch * 0.55)
			if mouse_global.distance_to(holder.global_position) <= radio_captura:
				_arrastrando_slime = true
				_mostrar_trayectoria = true
				if not _sonido_estirar_sonado:
					_sonido_estirar_sonado = true
					_reproducir(_player_estirar, volumen_estirar_db, velocidad_inicio)
				_iniciar_loop()
				_actualizar_visibilidad(true)
				_actualizar_arrastre(mouse_global)
				get_viewport().set_input_as_handled()
		elif not event.pressed and _arrastrando_slime:
			_arrastrando_slime = false
			_mostrar_trayectoria = false
			var potencia_final := potencia_objetivo
			var angulo_final := angulo_objetivo
			if potencia_final > 1.0:
				disparar_con_parametros(angulo_final, potencia_final)
			else:
				holder.position = _posicion_holder_reposo
				actualizar_cuerdas(holder.position)
				_actualizar_visibilidad(false)
				_aplicar_tension_slime(0.0, Vector2.ZERO)
				queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		# Fin de cualquier interacción de apuntado (dial/slider incluidos):
		# ocultar honda y trayectoria hasta la próxima manipulación.
		if _mostrar_trayectoria:
			_mostrar_trayectoria = false
			_actualizar_visibilidad(false)
			queue_redraw()
	elif event is InputEventMouseMotion and _arrastrando_slime:
		_actualizar_arrastre(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _actualizar_arrastre(mouse_global: Vector2) -> void:
	_mostrar_trayectoria = true
	var centro_global := center_marker.global_position
	var desplazamiento := mouse_global - centro_global
	# Arrastre libre en 360°: el slime puede estirarse en cualquier dirección.
	if desplazamiento.length() > max_stretch:
		desplazamiento = desplazamiento.normalized() * max_stretch
	holder.global_position = centro_global + desplazamiento
	actualizar_cuerdas(holder.position)
	var vector_lanzamiento := centro_global - holder.global_position
	if vector_lanzamiento.length() > 0.5:
		angulo_objetivo = fposmod(rad_to_deg(atan2(-vector_lanzamiento.y, vector_lanzamiento.x)), 360.0)
	potencia_objetivo = clampf(desplazamiento.length() / maxf(max_stretch, 0.001) * 100.0, 0.0, 100.0)
	_aplicar_tension_slime(potencia_objetivo / 100.0, desplazamiento.normalized())
	if is_instance_valid(_hud):
		_hud.set_aim_from_drag(angulo_objetivo, potencia_objetivo)
		_actualizar_modelo_hud()
	queue_redraw()

func _draw() -> void:
	if mostrar_area_respeto:
		draw_arc(center_marker.position, max_stretch + margen_respeto, 0, TAU, 48, Color(1, 0.3, 0.3, 0.5), 0.5)
	if _mostrar_trayectoria and is_instance_valid(slime_actual) and not _esperando_turno:
		_dibujar_trayectoria()

func _crear_hud() -> void:
	_hud = ShotHUD.new()
	_hud.name = "ShotHUD"
	_hud.modo_ecuacion = modo_ecuacion
	get_tree().current_scene.call_deferred("add_child", _hud)
	_hud.launch_requested.connect(disparar_con_parametros)
	_hud.aim_changed.connect(_on_aim_changed)
	_hud.cartilla_cerrada.connect(_actualizar_hud_estado)
	_hud.set_launch_enabled(is_instance_valid(slime_actual))

func configurar(slimes: Dictionary) -> void:
	_quitar_slime()
	_esperando_turno = false
	_inventario = SlimeInventario.desde_diccionario(slimes)
	_indice = _primer_con_stock()
	_cargar_nuevo_slime()
	inventario_cambiado.emit(_inventario, _indice)

func seleccionar(idx: int) -> void:
	# Validar que el índice exista y tenga munición.
	if idx < 0 or idx >= _inventario.size():
		return
	if _inventario[idx]["cantidad"] <= 0:
		return
	# Si ya está seleccionado, no hacer nada.
	if idx == _indice:
		return
	# Actualizar el índice seleccionado.
	_indice = idx
	# Si hay un slime cargado, reemplazarlo.
	if is_instance_valid(slime_actual):
		_quitar_slime()
		_instanciar_slime(_indice)
	# Si no hay slime en vuelo, cargar el seleccionado.
	elif not _esperando_turno:
		_instanciar_slime(_indice)
	_mostrar_trayectoria = false
	_actualizar_visibilidad(false)
	_actualizar_hud_estado()
	inventario_cambiado.emit(_inventario, _indice)

func get_inventario() -> Array[Dictionary]:
	return _inventario

func get_indice_seleccionado() -> int:
	return _indice

func actualizar_aim(angulo: float, potencia: float) -> void:
	angulo_objetivo = fposmod(angulo, 360.0)
	potencia_objetivo = clampf(potencia, 0.0, 100.0)
	queue_redraw()

func disparar_con_parametros(angulo: float, potencia: float) -> void:
	_arrastrando_slime = false
	if _esperando_turno or not is_instance_valid(slime_actual) or potencia <= 0.0:
		return
	if is_instance_valid(_hud) and _hud.cartilla_activa:
		return
	actualizar_aim(angulo, potencia)
	# Misma función que usa la vista previa: una sola fuente de verdad para la velocidad inicial.
	var velocidad := _velocidad_inicial(angulo_objetivo, potencia_objetivo)
	if velocidad.length() <= 0.1:
		return
	# CORRECCIÓN: el slime sale desde donde está sujeto AHORA (el mismo punto donde la
	# vista previa empieza a dibujar), no desde el punto de reposo de la honda.
	var origen_global := holder.global_position
	_esperando_turno = true
	holder.position = _posicion_holder_reposo
	actualizar_cuerdas(holder.position)
	_detener_sonidos_estirar()
	_actualizar_visibilidad(false)
	_aplicar_tension_slime(0.0, Vector2.ZERO)
	_ejecutar_disparo(velocidad, origen_global)
	_actualizar_hud_estado()
	queue_redraw()

func _on_aim_changed(angulo: float, potencia: float) -> void:
	_mostrar_trayectoria = true
	_actualizar_visibilidad(true)
	actualizar_aim(angulo, potencia)
	_actualizar_modelo_hud()

func _cargar_nuevo_slime() -> void:
	_esperando_turno = false
	_mostrar_trayectoria = false
	_actualizar_visibilidad(false)
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

## velocidad_inicial: velocidad real en px/s (ya incluye multiplicador_fuerza).
## origen_global: punto exacto de partida (el mismo que usa la vista previa).
func _ejecutar_disparo(velocidad_inicial: Vector2, origen_global: Vector2) -> void:
	if not is_instance_valid(slime_actual):
		return
	slime_actual.global_position = origen_global
	slime_actual.reparent(get_tree().current_scene)
	slime_actual.freeze = false
	if slime_actual.has_signal("slime_pegado"):
		slime_actual.slime_pegado.connect(_al_pegarse)
	if slime_actual.has_signal("turno_terminado"):
		slime_actual.turno_terminado.connect(func(): _cargar_nuevo_slime.call_deferred())
	if slime_actual.has_method("lanzar"):
		var radio: float = max_stretch * absf(global_scale.x) + margen_respeto
		slime_actual.lanzar(velocidad_inicial, tiempo_respeto, center_marker, radio)
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

# ---------------------------------------------------------------------------
# Parámetros físicos compartidos entre la vista previa y el slime real.
# Todo lo que influye en la trayectoria sale de AQUÍ, para que lo dibujado
# y lo simulado por slime.gd no puedan divergir.
# ---------------------------------------------------------------------------

## Velocidad inicial (px/s, coordenadas globales) para un ángulo/potencia dados.
func _velocidad_inicial(angulo: float, potencia: float) -> Vector2:
	var theta := deg_to_rad(fposmod(angulo, 360.0) + angulo_desvio_grados)
	var intensidad := clampf(potencia, 0.0, 100.0) / 100.0
	return Vector2(cos(theta), -sin(theta)) * max_stretch * intensidad * multiplicador_fuerza

func _gravedad_fisica() -> float:
	# slime.gd integra con esta misma configuración (ignora gravity_scale).
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

## Amortiguamiento que realmente usa el slime (linear_damp + global, o solo el propio).
func _arrastre_fisico() -> float:
	if is_instance_valid(slime_actual):
		var valor: Variant = slime_actual.get("arrastre")
		if valor != null:
			return float(valor)
	return float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))

## Método de integración que realmente usa el slime (RK4 por defecto).
func _metodo_fisico() -> SolverNumerico.Metodo:
	if is_instance_valid(slime_actual):
		var valor: Variant = slime_actual.get("metodo")
		if valor != null:
			return int(valor) as SolverNumerico.Metodo
	return SolverNumerico.Metodo.RK4

## Paso de simulación real del motor de física (el mismo que recibe slime.gd en state.step).
func _dt_fisica() -> float:
	return 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)

func _actualizar_modelo_hud() -> void:
	if not is_instance_valid(_hud):
		return
	var velocidad := _velocidad_inicial(angulo_objetivo, potencia_objetivo)
	_hud.set_model_values(holder.global_position, velocidad, _gravedad_fisica(), _arrastre_fisico())

func _dibujar_trayectoria() -> void:
	var velocidad := _velocidad_inicial(angulo_objetivo, potencia_objetivo)
	var gravedad := _gravedad_fisica()
	var k := _arrastre_fisico()
	var metodo := _metodo_fisico()
	var dt := _dt_fisica()

	var total_puntos := mini(puntos_trayectoria, 10)
	var pasos_por_punto := maxi(1, roundi(paso_tiempo / dt))
	var pasos_totales := pasos_por_punto * total_puntos

	# La simulación corre en coordenadas GLOBALES, desde el mismo punto donde
	# arrancará el slime (holder.global_position), con el mismo dt y el mismo
	# integrador. Solo al dibujar se pasa a coordenadas locales de este nodo.
	var pos := holder.global_position
	var vel := velocidad
	var posiciones_puntos: Array[Vector2] = []

	for step in range(pasos_totales):
		var r: Array = SolverNumerico.paso(metodo, pos, vel, dt, gravedad, k)
		pos = r[0]
		vel = r[1]
		if (step + 1) % pasos_por_punto == 0:
			posiciones_puntos.append(pos)

	var ultimo_punto: Vector2 = pos

	# Dibujar los puntos como pixeles (2x2 para visibilidad).
	for i in range(posiciones_puntos.size()):
		var pt := to_local(posiciones_puntos[i])
		var alpha := 0.9 - i * 0.08
		var color_px := Color(0.91, 1.0, 0.97, alpha)
		draw_rect(Rect2(pt - Vector2(1, 1), Vector2(2, 2)), color_px)

	# Punto final visible: el mismo sprite del slime, desvanecido.
	var textura: Texture2D = null
	if is_instance_valid(slime_actual):
		var nodo_sprite := slime_actual.get_node_or_null("Sprite2D") as Sprite2D
		if nodo_sprite != null:
			textura = nodo_sprite.texture
	if textura != null:
		var escala := 0.5
		var tam := textura.get_size() * escala
		var rect := Rect2(to_local(ultimo_punto) - tam * 0.5, tam)
		draw_texture_rect(textura, rect, false, Color(1.0, 1.0, 1.0, 0.4))

func _actualizar_hud_estado() -> void:
	if is_instance_valid(_hud):
		var puede := is_instance_valid(slime_actual) and not _esperando_turno
		if _hud.cartilla_activa:
			puede = false
		_hud.set_launch_enabled(puede)
		_actualizar_modelo_hud()
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
