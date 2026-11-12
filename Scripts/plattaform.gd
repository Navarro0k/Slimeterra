extends AnimatableBody2D
## Plataforma móvil que oscila de forma senoidal alrededor de su posición inicial.

enum Axis { HORIZONTAL, VERTICAL }

@export_category("Configuración de Movimiento")
@export var movement_axis: Axis = Axis.HORIZONTAL
@export var distance: float = 200.0
@export var travel_time: float = 2.0
@export var es_pegajoso: bool = true

var start_position: Vector2
var direction: Vector2 = Vector2.ZERO
var current_time: float = 0.0

var _periodo: float = 1.0


func _ready() -> void:
	start_position = global_position
	direction = Vector2.RIGHT if movement_axis == Axis.HORIZONTAL else Vector2.DOWN
	# Un recorrido de ida y vuelta por ciclo; nunca se permite un periodo nulo.
	_periodo = maxf(travel_time, 0.1) * 2.0


func _physics_process(delta: float) -> void:
	current_time += delta
	var desplazamiento := sin((current_time * TAU) / _periodo)
	global_position = start_position + direction * (desplazamiento * distance)
