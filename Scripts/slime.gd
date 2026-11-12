extends RigidBody2D
## Ciclo de vida del slime: CARGADO, SALIENDO, EN_VUELO, TERMINADO.

enum Estado { CARGADO, SALIENDO, EN_VUELO, TERMINADO }

@export var tipo_slime: SlimeCatalogo.Tipo = SlimeCatalogo.Tipo.BASE
## Segundos máximos en vuelo antes de descartarse.
@export var tiempo_vuelo_max: float = 8.0
## Margen (px) extra para considerar que toca un bloque rompible.
@export var margen_quema: float = 2.0

@export_group("Impacto")
## Coseno del ángulo mínimo para pegarse (1 = solo frontal).
@export_range(0.0, 0.9, 0.05) var umbral_impacto: float = 0.1

@export_group("Límites del nivel")
## Velocidad conservada al rebotar (0 = amortiguado, 1 = perfecto).
@export_range(0.0, 1.0, 0.05) var rebote_limites: float = 0.7
## Velocidad mínima en el suelo antes de dar el slime por perdido.
@export var velocidad_minima_suelo: float = 60.0

@export_group("Sonido")
@export var sonido_pegado: AudioStream
@export var sonido_quemar: AudioStream
@export var volumen_pegado_db: float = -2.0
@export_range(0.5, 2.0, 0.05) var velocidad_pegado: float = 1.0
@export_range(0.0, 0.3, 0.01) var variacion_tono: float = 0.05
@export var bus_efectos: StringName = &"SFX"

@export_group("Estirado en la resortera")
@export var color_burbujas: Color = Color(1.0, 0.65, 0.9)
@export var burbujas_cantidad: int = 20

@onready var particulas_rastro: CPUParticles2D = $CPUParticles2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var forma_colision: CollisionShape2D = $CollisionShape2D

## plataforma es null si se pegó a un tile.
signal slime_pegado(nueva_posicion, plataforma)
signal turno_terminado

var estado: Estado = Estado.CARGADO

## Rectángulo donde rebota; sin área = sin límites.
var limites: Rect2 = Rect2()

var arrastre: float
var vel_sim: Vector2 = Vector2.ZERO
var v_motor: Vector2 = Vector2.ZERO
var _tiempo_vuelo: float = 0.0

var _quema_bloques: bool = false
var _radio: float = 7.0

var _capa_original: int
var _mascara_original: int
## Tiempo máximo en SALIENDO.
var _tiempo_respeto: float = 0.0
## Centro del círculo de respeto.
var _zona: Node2D = null
var _radio_zona: float = 0.0

var _visual: SlimeVisual
var _impacto: SlimeImpacto
var _quemador: SlimeQuemador


func _ready():
	custom_integrator = true
	contact_monitor = true
	max_contacts_reported = 6

	_quema_bloques = tipo_slime == SlimeCatalogo.Tipo.FUEGO
	if _quema_bloques:
		color_burbujas = Color(1.0, 0.6, 0.2)

	_radio = _calcular_radio()
	_capa_original = collision_layer
	_mascara_original = collision_mask
	arrastre = _calcular_arrastre()

	_visual = SlimeVisual.new(self, sprite, particulas_rastro, color_burbujas, burbujas_cantidad, _radio)
	_impacto = SlimeImpacto.new(self)
	_quemador = SlimeQuemador.new(self, _mascara_original)

func _physics_process(delta):
	_visual.actualizar_rastro(linear_velocity)

	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	_tiempo_vuelo += delta
	if _tiempo_vuelo >= tiempo_vuelo_max:
		_descartar()
		return

	if _quema_bloques:
		_quemador.quemar(global_position, v_motor, delta, _radio + margen_quema)

	if estado == Estado.SALIENDO:
		_actualizar_salida(delta)

func _process(_delta: float) -> void:
	_visual.actualizar_pulso()


func _calcular_radio() -> float:
	var circulo := forma_colision.shape as CircleShape2D
	if circulo == null:
		return _radio
	var escala := forma_colision.global_scale
	return circulo.radius * maxf(absf(escala.x), absf(escala.y))

## Amortiguamiento real: el propio + el global del proyecto (según el modo).
func _calcular_arrastre() -> float:
	var damp_global: float = ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0)
	return linear_damp + damp_global if linear_damp_mode == DAMP_MODE_COMBINE else linear_damp


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

	vel_sim = velocidad_inicial
	v_motor = vel_sim
	linear_velocity = vel_sim

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
	SlimeSonidos.pegado(get_tree(), sonido_pegado, volumen_pegado_db, velocidad_pegado, variacion_tono, bus_efectos)
	slime_pegado.emit(posicion, superficie)
	queue_free()


## t: 0..1. Solo controla brillo y burbujas.
func set_tension(t: float, direccion_tiron: Vector2 = Vector2.ZERO) -> void:
	if _visual != null:
		_visual.set_tension(t, direccion_tiron)


func _integrate_forces(state: PhysicsDirectBodyState2D):
	if estado != Estado.SALIENDO and estado != Estado.EN_VUELO:
		return

	if estado == Estado.EN_VUELO and _intentar_pegarse(state):
		return

	var dt: float = state.step
	var gravedad := FisicaDisparo.gravedad()

	if state.linear_velocity.distance_to(v_motor) > 0.01:
		vel_sim = state.linear_velocity

	var pos: Vector2 = state.transform.origin
	var r: Array = SolverNumerico.paso(pos, vel_sim, dt, gravedad, arrastre)
	var nueva_pos: Vector2 = r[0]
	var nueva_vel: Vector2 = r[1]

	if limites.has_area():
		var rebote := SlimeLimites.rebotar(nueva_pos, nueva_vel, limites, _radio, rebote_limites, velocidad_minima_suelo)
		if rebote["perdido"]:
			_descartar()
			return
		nueva_pos = rebote["pos"]
		nueva_vel = rebote["vel"]

	vel_sim = nueva_vel
	v_motor = (nueva_pos - pos) / dt
	state.linear_velocity = v_motor

## Consulta a SlimeImpacto; si el choque lo pega, se pega y devuelve true.
func _intentar_pegarse(state: PhysicsDirectBodyState2D) -> bool:
	var impacto := _impacto.buscar_pegado(state, v_motor, umbral_impacto)
	if impacto.is_empty():
		return false
	_pegarse(impacto["plataforma"], state.transform.origin)
	return true
