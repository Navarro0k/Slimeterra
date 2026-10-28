extends RigidBody2D

## Ciclo de vida del slime (una sola fuente de verdad, en vez de varios booleanos):
##   CARGADO   -> en la resortera: congelado, movido por código y SIN colisiones.
##   SALIENDO  -> recién lanzado, dentro del ÁREA DE RESPETO (el círculo de estiramiento de
##                la honda): sin colisiones y sin poder pegarse. Sale de este estado cuando
##                su cuerpo queda completamente fuera del círculo y libre de sólidos.
##   EN_VUELO  -> colisiones activas. Se pega solo si CHOCA DE FRENTE contra una superficie pegajosa.
##   TERMINADO -> se pegó o se descartó; ya no reacciona a nada.
enum Estado { CARGADO, SALIENDO, EN_VUELO, TERMINADO }

@export var metodo: SolverNumerico.Metodo = SolverNumerico.Metodo.RK4
@export var tipo_slime: String = "base" # Opciones: "base" o "fuego"
## Segundos máximos en vuelo. Si no choca con nada (cae al vacío) se descarta y el turno termina.
@export var tiempo_vuelo_max: float = 8.0
## Margen (px) extra alrededor del slime para considerar que "toca" un bloque rompible.
@export var margen_quema: float = 2.0

@export_group("Impacto")
## Cuán de frente debe ir el slime contra una superficie para pegarse: es el coseno del ángulo
## entre su velocidad y la dirección hacia el punto de contacto.
## 0 = cualquier contacto por delante; 1 = solo impactos perfectamente frontales.
## Los contactos por detrás o de lado (la superficie de la que acaba de salir) nunca pegan.
@export_range(0.0, 0.9, 0.05) var umbral_impacto: float = 0.1

@export_group("Límites del nivel")
## Velocidad que conserva al rebotar contra los límites del nivel (0 = se amortigua, 1 = rebote perfecto).
@export_range(0.0, 1.0, 0.05) var rebote_limites: float = 0.7
## Si tras rebotar en el límite inferior sale con menos velocidad que esta (px/s), se da por
## perdido y se descarta: evita esperar a `tiempo_vuelo_max` viéndolo rodar por el suelo del nivel.
@export var velocidad_minima_suelo: float = 60.0

@export_group("Sonido")
## Sonido al pegarse a una superficie (tile o plataforma).
@export var sonido_pegado: AudioStream
## Volumen (dB) del sonido de pegado.
@export var volumen_pegado_db: float = -2.0
## Velocidad de reproducción (también cambia el tono): 1.0 = original.
@export_range(0.5, 2.0, 0.05) var velocidad_pegado: float = 1.0
## Variación aleatoria de tono para que no suene siempre idéntico (0 = sin variación).
@export_range(0.0, 0.3, 0.01) var variacion_tono: float = 0.05
## Bus de audio de los efectos. Si no existe en el proyecto, usa Master.
@export var bus_efectos: StringName = &"SFX"

@export_group("Estirado en la resortera")
@export var color_burbujas: Color = Color(1.0, 0.65, 0.9)
@export var burbujas_cantidad: int = 20

@onready var particulas_rastro: CPUParticles2D = $CPUParticles2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var forma_colision: CollisionShape2D = $CollisionShape2D

# Señales arquitectónicas para comunicarse de vuelta con la honda
## plataforma es null si se pegó a un tile; si no, es el nodo móvil al que se pegó.
signal slime_pegado(nueva_posicion, plataforma)
signal turno_terminado

var estado: Estado = Estado.CARGADO

## Rectángulo (coordenadas globales) dentro del que rebota. Lo asigna el nivel al lanzarse;
## un rectángulo sin área significa "sin límites".
var limites: Rect2 = Rect2()

var arrastre: float
var vel_sim: Vector2 = Vector2.ZERO
var v_motor: Vector2 = Vector2.ZERO
var _tiempo_vuelo: float = 0.0

## El slime de fuego quema (rompe) todo bloque rompible que toca mientras vuela.
var _quema_bloques: bool = false
var _radio: float = 7.0

# --- Colisiones y área de respeto -------------------------------------------
var _capa_original: int
var _mascara_original: int
## Tiempo máximo en SALIENDO: pasado este tiempo se fuerza la salida (o se descarta).
var _tiempo_respeto: float = 0.0
## Centro del círculo de respeto (se sigue por nodo: la honda puede ir sobre una plataforma móvil).
var _zona: Node2D = null
## Radio del círculo de estiramiento de la honda (sin contar el cuerpo del slime).
var _radio_zona: float = 0.0

# --- Estirado visual ---------------------------------------------------------
var _escala_base: Vector2 = Vector2.ONE
var _tension: float = 0.0
var _brillo: Sprite2D
var _burbujas: CPUParticles2D

func _ready():
	custom_integrator = true
	contact_monitor = true
	max_contacts_reported = 6

	_quema_bloques = tipo_slime == "fuego"
	var circulo := forma_colision.shape as CircleShape2D
	if circulo != null:
		var escala := forma_colision.global_scale
		_radio = circulo.radius * maxf(absf(escala.x), absf(escala.y))

	_capa_original = collision_layer
	_mascara_original = collision_mask

	var damp_global: float = ProjectSettings.get_setting("physics/2d/default_linear_damp")
	arrastre = linear_damp + damp_global if linear_damp_mode == DAMP_MODE_COMBINE else linear_damp

	_escala_base = sprite.scale
	if _quema_bloques:
		color_burbujas = Color(1.0, 0.6, 0.2)
	_crear_brillo()
	_crear_burbujas()

func _physics_process(delta):
	particulas_rastro.emitting = linear_velocity.length() > 5.0

	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	_tiempo_vuelo += delta
	if _tiempo_vuelo >= tiempo_vuelo_max:
		_descartar()
		return

	if _quema_bloques:
		_quemar_bloques(delta)

	if estado == Estado.SALIENDO:
		_actualizar_salida(delta)

func _process(_delta: float) -> void:
	# Pulso del brillo: más intenso y rápido a más tensión.
	if _tension > 0.0 and _brillo != null and _brillo.visible:
		var pulso := 0.65 + 0.25 * sin(Time.get_ticks_msec() * 0.001 * lerpf(8.0, 18.0, _tension))
		_brillo.modulate.a = _tension * pulso

# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

func preparar():
	estado = Estado.CARGADO
	_tiempo_vuelo = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	_activar_colisiones(false)

func lanzar(velocidad_inicial: Vector2, tiempo_respeto: float = 1.5, zona: Node2D = null, radio_zona: float = 0.0):
	set_tension(0.0)
	estado = Estado.SALIENDO
	_tiempo_vuelo = 0.0
	_tiempo_respeto = tiempo_respeto
	_zona = zona
	_radio_zona = radio_zona

	# Godot llama a _integrate_forces DESPUÉS de mover el cuerpo en cada paso de física,
	# así que el primer paso usaría velocidad_inicial "a secas", sin gravedad ni aire, y todo
	# el vuelo quedaría desfasado un frame respecto a la predicción de la resortera.
	# Para evitarlo se calcula aquí el primer paso de RK4: el motor mueve el slime con la
	# velocidad media de ese paso y llega justo al punto que predice RK4.
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var primer: Array = SolverNumerico.paso(metodo, global_position, velocidad_inicial, dt, gravedad, arrastre)
	vel_sim = primer[1]
	v_motor = (primer[0] - global_position) / dt
	linear_velocity = v_motor

func _actualizar_salida(delta: float) -> void:
	_tiempo_respeto -= delta
	var agotado := _tiempo_respeto <= 0.0
	if not _fuera_del_circulo() and not agotado:
		return

	if _esta_libre():
		estado = Estado.EN_VUELO
		_activar_colisiones(true)
	elif agotado:
		_descartar()

func _fuera_del_circulo() -> bool:
	if _zona == null or not is_instance_valid(_zona):
		return true
	return global_position.distance_to(_zona.global_position) >= _radio_zona + _radio

func _activar_colisiones(activas: bool):
	collision_layer = _capa_original if activas else 0
	collision_mask = _mascara_original if activas else 0

func _esta_libre() -> bool:
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma_colision.shape
	consulta.transform = forma_colision.global_transform
	consulta.collision_mask = _mascara_original
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	var excluidos: Array[RID] = [get_rid()]
	consulta.exclude = excluidos
	var choques := get_world_2d().direct_space_state.intersect_shape(consulta, 1)
	return choques.is_empty()

func _descartar():
	if estado == Estado.TERMINADO:
		return
	estado = Estado.TERMINADO
	turno_terminado.emit()
	queue_free()

func _pegarse(superficie: Node, posicion: Vector2) -> void:
	if estado == Estado.TERMINADO:
		return
	estado = Estado.TERMINADO
	set_deferred("freeze", true)
	_reproducir_sonido_pegado()
	slime_pegado.emit(posicion, superficie)
	queue_free()

func _reproducir_sonido_pegado() -> void:
	var escena := get_tree().current_scene
	if sonido_pegado == null or escena == null:
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido_pegado
	reproductor.volume_db = volumen_pegado_db
	reproductor.pitch_scale = velocidad_pegado * (1.0 + randf_range(-variacion_tono, variacion_tono))
	reproductor.bus = bus_efectos if AudioServer.get_bus_index(bus_efectos) != -1 else &"Master"
	escena.add_child(reproductor)
	reproductor.finished.connect(reproductor.queue_free)
	reproductor.play()

# ---------------------------------------------------------------------------
# Estirado visual en la resortera
# ---------------------------------------------------------------------------

## t: 0..1 (potencia acumulada). Solo controla el brillo y las burbujas;
## el sprite NO se deforma ni rota. direccion_tiron se ignora, se conserva
## en la firma para no tocar slingshoot.gd.
func set_tension(t: float, direccion_tiron: Vector2 = Vector2.ZERO) -> void:
	if _brillo == null or _burbujas == null:
		return
	t = clampf(t, 0.0, 1.0)
	if t <= 0.01 or direccion_tiron == Vector2.ZERO:
		_tension = 0.0
		_brillo.visible = false
		_burbujas.emitting = false
		return

	_tension = t
	_brillo.visible = true
	_burbujas.emitting = t > 0.08
	_burbujas.speed_scale = lerpf(0.7, 2.2, t)  # más potencia = más burbujas por segundo
	_burbujas.scale_amount_max = lerpf(1.5, 3.0, t)
	
func _crear_brillo() -> void:
	_brillo = Sprite2D.new()
	_brillo.texture = sprite.texture
	_brillo.scale = _escala_base * 1.08
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brillo.material = mat
	_brillo.modulate = Color(1, 1, 1, 0)
	_brillo.visible = false
	add_child(_brillo)

func _crear_burbujas() -> void:
	_burbujas = CPUParticles2D.new()
	_burbujas.emitting = false
	_burbujas.amount = burbujas_cantidad
	_burbujas.lifetime = 0.7
	_burbujas.local_coords = false  # las burbujas se quedan flotando donde nacen
	_burbujas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_burbujas.emission_sphere_radius = _radio + 2.0
	_burbujas.direction = Vector2.UP
	_burbujas.spread = 60.0
	_burbujas.gravity = Vector2(0, -14)  # suben
	_burbujas.initial_velocity_min = 2.0
	_burbujas.initial_velocity_max = 8.0
	_burbujas.scale_amount_min = 1.0
	_burbujas.scale_amount_max = 1.5
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([
		Color(color_burbujas, 0.95), Color(color_burbujas, 0.0)
	])
	_burbujas.color_ramp = degradado
	_burbujas.z_index = 1
	add_child(_burbujas)

# ---------------------------------------------------------------------------
# Física
# ---------------------------------------------------------------------------

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	if estado == Estado.EN_VUELO and _evaluar_contactos(state):
		return

	var dt: float = state.step
	var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")

	if state.linear_velocity.distance_to(v_motor) > 0.01:
		vel_sim = state.linear_velocity

	var pos: Vector2 = state.transform.origin
	var r: Array = SolverNumerico.paso(metodo, pos, vel_sim, dt, gravedad, arrastre)
	var nueva_pos: Vector2 = r[0]
	var nueva_vel: Vector2 = r[1]

	if limites.has_area():
		var rebote := _rebotar_en_limites(nueva_pos, nueva_vel)
		if estado == Estado.TERMINADO:
			return
		nueva_pos = rebote[0]
		nueva_vel = rebote[1]

	vel_sim = nueva_vel
	v_motor = (nueva_pos - pos) / dt
	state.linear_velocity = v_motor

func _rebotar_en_limites(pos: Vector2, vel: Vector2) -> Array:
	var izquierda := limites.position.x + _radio
	var derecha := limites.end.x - _radio
	var arriba := limites.position.y + _radio
	var abajo := limites.end.y - _radio

	if pos.x < izquierda:
		pos.x = izquierda
		if vel.x < 0.0:
			vel.x = -vel.x * rebote_limites
	elif pos.x > derecha:
		pos.x = derecha
		if vel.x > 0.0:
			vel.x = -vel.x * rebote_limites

	if pos.y < arriba:
		pos.y = arriba
		if vel.y < 0.0:
			vel.y = -vel.y * rebote_limites
	elif pos.y > abajo:
		pos.y = abajo
		if vel.y > 0.0:
			vel.y = -vel.y * rebote_limites
		if absf(vel.y) < velocidad_minima_suelo:
			_descartar()

	return [pos, vel]

# ---------------------------------------------------------------------------
# Impactos (CORREGIDO)
# ---------------------------------------------------------------------------

func _evaluar_contactos(state: PhysicsDirectBodyState2D) -> bool:
	var velocidad := v_motor if v_motor.length_squared() > 0.000001 else state.linear_velocity
	if velocidad.length_squared() < 0.000001:
		return false
	var dir_vuelo := velocidad.normalized()
	var origen := state.transform.origin

	for i in state.get_contact_count():
		var punto := state.get_contact_collider_position(i)
		var hacia_contacto := punto - origen
		if hacia_contacto.length_squared() < 0.0001:
			continue
		hacia_contacto = hacia_contacto.normalized()

		# CORRECCIÓN: Suavizamos el umbral para impactos laterales durante curvas pronunciadas.
		# Evita que se ignore el choque horizontal si el slime va cayendo rápido.
		if dir_vuelo.dot(hacia_contacto) < umbral_impacto - 0.2:
			continue

		var superficie := state.get_contact_collider_object(i) as Node
		if superficie == null:
			continue

		if superficie is TileMapLayer:
			if _tile_pegajoso_en(superficie, punto, hacia_contacto):
				_pegarse(null, origen)
				return true
		else:
			var plataforma := _buscar_superficie_pegajosa(superficie)
			if plataforma != null:
				_pegarse(plataforma, origen)
				return true
	return false

func _tile_pegajoso_en(capa: TileMapLayer, punto: Vector2, hacia_contacto: Vector2) -> bool:
	# 1. Proyección directa un poco más profunda
	for profundidad in [2.0, 5.0]:
		var celda := capa.local_to_map(capa.to_local(punto + hacia_contacto * profundidad))
		var datos := capa.get_cell_tile_data(celda)
		if datos != null and datos.get_custom_data("es_pegajoso"):
			return true
			
	# 2. CORRECCIÓN: Restauramos el "Escáner infalible" para las esquinas u horizontales
	var celda_impacto := capa.local_to_map(capa.to_local(punto))
	var vecinos = [
		celda_impacto,
		celda_impacto + Vector2i(0, 1), celda_impacto + Vector2i(0, -1),
		celda_impacto + Vector2i(1, 0), celda_impacto + Vector2i(-1, 0),
		celda_impacto + Vector2i(1, 1), celda_impacto + Vector2i(-1, -1),
		celda_impacto + Vector2i(1, -1), celda_impacto + Vector2i(-1, 1)
	]
	
	for vecino in vecinos:
		var datos := capa.get_cell_tile_data(vecino)
		if datos != null and datos.get_custom_data("es_pegajoso"):
			return true
			
	return false

func _buscar_superficie_pegajosa(nodo: Node) -> Node:
	var actual: Node = nodo
	while actual != null and actual != get_tree().root:
		if actual.get("es_pegajoso") == true or actual.is_in_group("plataforma_pegajosa"):
			return actual
		actual = actual.get_parent()
	return null

# ---------------------------------------------------------------------------
# Slime de fuego: quema bloques rompibles
# ---------------------------------------------------------------------------

func _quemar_bloques(delta: float) -> void:
	var radio := _radio + margen_quema
	_quemar_en(global_position, radio)
	_quemar_en(global_position + v_motor * delta, radio)

func _quemar_en(centro: Vector2, radio: float) -> void:
	var forma := CircleShape2D.new()
	forma.radius = radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, centro)
	consulta.collision_mask = _mascara_original
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	var excluidos: Array[RID] = [get_rid()]
	consulta.exclude = excluidos
	for choque in get_world_2d().direct_space_state.intersect_shape(consulta, 8):
		var capa = choque["collider"]
		if capa is TileMapLayer:
			_quemar_celdas(capa, centro, radio)

func _quemar_celdas(capa: TileMapLayer, centro: Vector2, radio: float) -> void:
	var mitad := Vector2(capa.tile_set.tile_size) * 0.5
	var local := capa.to_local(centro)
	var celda_min := capa.local_to_map(local - Vector2(radio, radio))
	var celda_max := capa.local_to_map(local + Vector2(radio, radio))
	for x in range(celda_min.x, celda_max.x + 1):
		for y in range(celda_min.y, celda_max.y + 1):
			var celda := Vector2i(x, y)
			var datos := capa.get_cell_tile_data(celda)
			if datos == null or not datos.get_custom_data("rompible_por_fuego"):
				continue
			var d := (local - capa.map_to_local(celda)).abs() - mitad
			var fuera := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
			if fuera <= radio:
				capa.erase_cell(celda)
