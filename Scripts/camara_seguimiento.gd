class_name CamaraSeguimiento
extends Camera2D
## Cámara del nivel: sigue a un nodo con suavizado exponencial (independiente del framerate).
## Cambiar de objetivo NO teletransporta la cámara: se desliza hacia el nuevo.

## Mayor = sigue más pegada al objetivo; menor = más suave y con más retraso.
@export_range(0.5, 30.0, 0.5) var suavizado: float = 6.0
## Desplazamiento fijo respecto al objetivo (por ejemplo para dejar más espacio hacia adelante).
@export var desplazamiento: Vector2 = Vector2.ZERO

var _objetivo: Node2D

## Pasa a seguir a `objetivo`. Con `instantaneo` la cámara salta ahí (útil al iniciar el nivel).
func seguir(objetivo: Node2D, instantaneo: bool = false) -> void:
	_objetivo = objetivo
	if instantaneo and is_instance_valid(_objetivo):
		global_position = _objetivo.global_position + desplazamiento

func _process(delta: float) -> void:
	# Si el objetivo se liberó (slime que se pegó o cayó) la cámara se queda quieta
	# hasta que el nivel le asigne uno nuevo.
	if _objetivo == null or not is_instance_valid(_objetivo):
		return
	var destino := _objetivo.global_position + desplazamiento
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
