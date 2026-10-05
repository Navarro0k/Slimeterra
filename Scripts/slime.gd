extends RigidBody2D

@onready var particulas_rastro = $CPUParticles2D

func _physics_process(_delta):
	if linear_velocity.length() > 5.0:
		particulas_rastro.emitting = true
	else:
		particulas_rastro.emitting = false

func lanzar(vector_impulso: Vector2):
	apply_central_impulse(vector_impulso)
