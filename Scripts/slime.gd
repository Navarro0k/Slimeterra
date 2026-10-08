extends RigidBody2D

@export var metodo: SolverNumerico.Metodo = SolverNumerico.Metodo.RK4

@onready var particulas_rastro: CPUParticles2D = $CPUParticles2D

var arrastre: float
var vel_sim: Vector2 = Vector2.ZERO
var v_motor: Vector2 = Vector2.ZERO
var volando: bool = false

func _ready():
	custom_integrator = true
	var damp_global: float = ProjectSettings.get_setting("physics/2d/default_linear_damp")
	arrastre = linear_damp + damp_global if linear_damp_mode == DAMP_MODE_COMBINE else linear_damp

func _physics_process(_delta):
	particulas_rastro.emitting = linear_velocity.length() > 5.0

func lanzar(velocidad_inicial: Vector2):
	vel_sim = velocidad_inicial
	v_motor = vel_sim
	linear_velocity = vel_sim
	volando = true

func _integrate_forces(state: PhysicsDirectBodyState2D):
	if not volando:
		return
		
	var dt: float = state.step
	var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")

	# Re-sincronizar si ocurrió una colisión en el paso físico anterior
	if state.linear_velocity.distance_to(v_motor) > 0.01:
		vel_sim = state.linear_velocity

	var pos: Vector2 = state.transform.origin
	var r: Array = SolverNumerico.paso(metodo, pos, vel_sim, dt, gravedad, arrastre)

	vel_sim = r[1]
	v_motor = (r[0] - pos) / dt
	state.linear_velocity = v_motor
