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

@onready var particulas_rastro: CPUParticles2D = $CPUParticles2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var forma_colision: CollisionShape2D = $CollisionShape2D

# Señales arquitectónicas para comunicarse de vuelta con la honda
## plataforma es null si se pegó a un tile; si no, es el nodo móvil al que se pegó.
signal slime_pegado(nueva_posicion, plataforma)
signal turno_terminado

var estado: Estado = Estado.CARGADO

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

func _ready():
	custom_integrator = true
	contact_monitor = true
	# Los contactos se leen en _integrate_forces (ya no con body_entered).
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

func _physics_process(delta):
	particulas_rastro.emitting = linear_velocity.length() > 5.0

	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	_tiempo_vuelo += delta
	if _tiempo_vuelo >= tiempo_vuelo_max:
		_descartar()
		return

	# Se quema ANTES de que la física resuelva el choque: así el slime atraviesa
	# los bloques rompibles en vez de rebotar contra ellos.
	if _quema_bloques:
		_quemar_bloques(delta)

	if estado == Estado.SALIENDO:
		_actualizar_salida(delta)

# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

## Slime cargado en la resortera: congelado, movido por código y SIN colisiones.
func preparar():
	estado = Estado.CARGADO
	_tiempo_vuelo = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	_activar_colisiones(false)

## zona / radio_zona definen el círculo de respeto: la zona que alcanza el slime al estirar
## la honda. Sin zona, el área de respeto se reduce a "estar libre de sólidos".
func lanzar(velocidad_inicial: Vector2, tiempo_respeto: float = 1.5, zona: Node2D = null, radio_zona: float = 0.0):
	estado = Estado.SALIENDO
	_tiempo_vuelo = 0.0
	_tiempo_respeto = tiempo_respeto
	_zona = zona
	_radio_zona = radio_zona

	vel_sim = velocidad_inicial
	v_motor = vel_sim
	linear_velocity = vel_sim

## Área de respeto circular: mientras alguna parte del slime esté dentro del círculo de
## estiramiento de la honda, todo lo que haya ahí se ignora (tiles, plataformas, la superficie
## donde está pegada la honda). Las colisiones se activan cuando el cuerpo ya salió del círculo
## y no queda solapado con ningún sólido (para que el solver no lo empuje).
## Si pasa `tiempo_respeto` sin salir, se fuerza la salida si está libre; si no, se descarta.
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

## ¿El cuerpo completo del slime está fuera del círculo de respeto?
func _fuera_del_circulo() -> bool:
	if _zona == null or not is_instance_valid(_zona):
		return true
	return global_position.distance_to(_zona.global_position) >= _radio_zona + _radio

func _activar_colisiones(activas: bool):
	collision_layer = _capa_original if activas else 0
	collision_mask = _mascara_original if activas else 0

## ¿La forma del slime está libre de cuerpos sólidos en su posición actual?
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

## Atascado dentro de un sólido o perdido en el vacío: se quita y se libera el turno.
func _descartar():
	if estado == Estado.TERMINADO:
		return
	estado = Estado.TERMINADO
	turno_terminado.emit()
	queue_free()

## Se pega a la superficie (tile o plataforma). La honda se encarga de moverse y recargar.
func _pegarse(superficie: Node, posicion: Vector2) -> void:
	if estado == Estado.TERMINADO:
		return
	estado = Estado.TERMINADO
	set_deferred("freeze", true)
	slime_pegado.emit(posicion, superficie)
	queue_free()

# ---------------------------------------------------------------------------
# Física
# ---------------------------------------------------------------------------

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	# Los contactos se evalúan ANTES de integrar: v_motor sigue siendo la velocidad previa
	# al choque (el solver de física todavía no la ha modificado en este paso).
	if estado == Estado.EN_VUELO and _evaluar_contactos(state):
		return

	var dt: float = state.step
	var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")

	if state.linear_velocity.distance_to(v_motor) > 0.01:
		vel_sim = state.linear_velocity

	var pos: Vector2 = state.transform.origin
	var r: Array = SolverNumerico.paso(metodo, pos, vel_sim, dt, gravedad, arrastre)

	vel_sim = r[1]
	v_motor = (r[0] - pos) / dt
	state.linear_velocity = v_motor

# ---------------------------------------------------------------------------
# Impactos
# ---------------------------------------------------------------------------

## Revisa los contactos actuales. Un contacto solo cuenta como impacto si el slime va
## HACIA el punto de contacto: así la superficie de la que acaba de salir (la de la
## resortera, o el sólido que atravesó en el área de respeto) jamás lo pega.
## Se evalúa en cada paso, no solo al empezar el contacto, para no perder impactos
## cuando el slime ya venía rozando una superficie. Devuelve true si se pegó.
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

		# Se aleja o roza la superficie: no es un impacto.
		if dir_vuelo.dot(hacia_contacto) < umbral_impacto:
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

## ¿La celda del tile que está justo detrás del punto de contacto es pegajosa?
## Se muestrea un poco hacia adentro del tile (siguiendo la dirección del contacto).
func _tile_pegajoso_en(capa: TileMapLayer, punto: Vector2, hacia_contacto: Vector2) -> bool:
	for profundidad in [1.0, 2.5]:
		var celda := capa.local_to_map(capa.to_local(punto + hacia_contacto * profundidad))
		var datos := capa.get_cell_tile_data(celda)
		if datos != null and datos.get_custom_data("es_pegajoso"):
			return true
	return false

## Sube por la jerarquía buscando el nodo que tenga la variable o el grupo,
## por si el cuerpo que colisiona es hijo de la raíz de la escena.
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

## Rompe todo bloque rompible que el slime toca ahora o tocará en este paso de física.
## Se evalúa la posición actual y la del siguiente paso para no saltarse bloques a alta velocidad.
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

## Borra las celdas rompibles de la capa cuyo rectángulo intersecta el círculo (centro, radio).
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
			# Distancia del centro del círculo al rectángulo de la celda.
			var d := (local - capa.map_to_local(celda)).abs() - mitad
			var fuera := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
			if fuera <= radio:
				capa.erase_cell(celda)
