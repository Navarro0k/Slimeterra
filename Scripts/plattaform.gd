extends AnimatableBody2D

enum Axis { HORIZONTAL, VERTICAL }

@export_category("Configuración de Movimiento")
@export var movement_axis: Axis = Axis.HORIZONTAL
@export var distance: float = 200.0
@export var travel_time: float = 2.0
@export var es_pegajoso: bool = true

var start_position: Vector2
var direction: Vector2 = Vector2.ZERO
var current_time: float = 0.0

func _ready() -> void:
	start_position = global_position
	if movement_axis == Axis.HORIZONTAL:
		direction = Vector2.RIGHT
	else:
		direction = Vector2.DOWN
		
	if travel_time <= 0.0:
		travel_time = 0.1

func _physics_process(delta: float) -> void:
	current_time += delta
	var period = travel_time * 2.0
	var sine_val = sin((current_time * TAU) / period) 
	
	# Posición exacta a la que debe moverse este frame
	var target_position = start_position + (direction * (sine_val * distance))
	
	# AnimatableBody2D tiene una función especial 'move_and_collide' o se actualiza 
	# cambiando su posición mediante 'global_position' de forma segura para las físicas,
	# o usando Tween / AnimationPlayer. 
	# La forma más directa por código en _physics_process es actualizar la posición:
	global_position = target_position
