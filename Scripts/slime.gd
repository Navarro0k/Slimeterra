extends RigidBody2D

@export var metodo: SolverNumerico.Metodo = SolverNumerico.Metodo.RK4
@export var tipo_slime: String = "base" # Opciones: "base" o "fuego"
## Segundos máximos en vuelo. Si no choca con nada (cae al vacío) se descarta y el turno termina.
@export var tiempo_vuelo_max: float = 8.0

@onready var particulas_rastro: CPUParticles2D = $CPUParticles2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var forma_colision: CollisionShape2D = $CollisionShape2D

# Señales arquitectónicas para comunicarse de vuelta con la honda
signal slime_pegado(nueva_posicion)
signal turno_terminado

var arrastre: float
var vel_sim: Vector2 = Vector2.ZERO
var v_motor: Vector2 = Vector2.ZERO
var volando: bool = false
var ya_choco: bool = false
var _tiempo_vuelo: float = 0.0

# --- Colisiones y área de respeto -------------------------------------------
# Mientras el slime está en la resortera (cargado / estirándose) no colisiona.
# Al lanzarlo entra en "respeto": sigue sin colisionar SOLO mientras su forma
# se solape con algo sólido (nació dentro de una plataforma, por ejemplo).
# En cuanto queda libre se reactivan las colisiones. Si tras un tiempo máximo
# sigue atrapado, se descarta para no bloquear el turno.
var _capa_original: int
var _mascara_original: int
var _en_respeto: bool = false
var _tiempo_respeto: float = 0.0

func _ready():
	custom_integrator = true
	contact_monitor = true
	max_contacts_reported = 3
	body_entered.connect(_on_body_entered)

	_capa_original = collision_layer
	_mascara_original = collision_mask

	var damp_global: float = ProjectSettings.get_setting("physics/2d/default_linear_damp")
	arrastre = linear_damp + damp_global if linear_damp_mode == DAMP_MODE_COMBINE else linear_damp


func _physics_process(delta):
	particulas_rastro.emitting = linear_velocity.length() > 5.0

	if volando and not ya_choco:
		_tiempo_vuelo += delta
		if _tiempo_vuelo >= tiempo_vuelo_max:
			_descartar()
			return

	if _en_respeto:
		_tiempo_respeto -= delta
		if _esta_libre():
			_en_respeto = false
			_activar_colisiones(true)
		elif _tiempo_respeto <= 0.0:
			_descartar()

## Slime cargado en la resortera: congelado, movido por código y SIN colisiones.
func preparar():
	volando = false
	ya_choco = false
	_en_respeto = false
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	_activar_colisiones(false)

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
	_en_respeto = false
	ya_choco = true
	volando = false
	turno_terminado.emit()
	queue_free()

func lanzar(velocidad_inicial: Vector2, tiempo_respeto: float = 1.5):
	# Colisiones apagadas hasta que _physics_process confirme que está libre
	# (si nació en espacio abierto se reactivan antes del primer paso de física).
	_en_respeto = true
	_tiempo_respeto = tiempo_respeto

	vel_sim = velocidad_inicial
	v_motor = vel_sim
	linear_velocity = vel_sim
	volando = true

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if not volando or ya_choco:
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

func _on_body_entered(body):
	if ya_choco or _en_respeto: return

	if body.has_method("local_to_map"):
		var direccion = v_motor.normalized()
		if direccion == Vector2.ZERO:
			direccion = linear_velocity.normalized()

		# 1. Proyectamos con mayor profundidad (24 px en lugar de 14)
		var punto_impacto = global_position + (direccion * 24.0)
		var cell_pos = body.local_to_map(body.to_local(punto_impacto))
		var tile_data = body.get_cell_tile_data(cell_pos)

		# 2. EL ESCÁNER INFALIBLE: Si el tiro proyectado cae en un borde vacío,
		# revisamos las celdas inmediatamente pegadas al slime.
		if tile_data == null:
			var celda_central = body.local_to_map(body.to_local(global_position))

			# Coordenadas de las 8 celdas alrededor del slime
			var vecinos = [
				celda_central + Vector2i(0, 1), celda_central + Vector2i(0, -1),
				celda_central + Vector2i(1, 0), celda_central + Vector2i(-1, 0),
				celda_central + Vector2i(1, 1), celda_central + Vector2i(-1, -1),
				celda_central + Vector2i(1, -1), celda_central + Vector2i(-1, 1)
			]

			for vecino in vecinos:
				var data_vecino = body.get_cell_tile_data(vecino)
				if data_vecino:
					# Si un vecino existe y tiene la propiedad que buscamos, ¡es ese!
					var es_pegajoso = data_vecino.get_custom_data("es_pegajoso")
					var es_rompible = data_vecino.get_custom_data("rompible_por_fuego")

					if (tipo_slime == "fuego" and es_rompible) or (tipo_slime == "base" and es_pegajoso):
						cell_pos = vecino
						tile_data = data_vecino
						break

		# 3. Aplicamos la lógica según el tile encontrado
		if tile_data:
			if tipo_slime == "fuego" and tile_data.get_custom_data("rompible_por_fuego"):
				body.erase_cell(cell_pos)
				ya_choco = true
				volando = false
				turno_terminado.emit()
				queue_free()

			elif tipo_slime == "base" and tile_data.get_custom_data("es_pegajoso"):
				ya_choco = true
				volando = false
				# Dentro de un callback de colisión no se puede cambiar el modo del cuerpo.
				set_deferred("freeze", true)
				slime_pegado.emit(global_position)
				queue_free()
