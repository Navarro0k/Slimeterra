class_name CamaraSeguimiento
extends Camera2D
## Cámara del nivel: sigue a un nodo con suavizado exponencial (independiente del framerate).
## Cambiar de objetivo NO teletransporta la cámara: se desliza hacia el nuevo.

## Mayor = sigue más pegada al objetivo; menor = más suave y con más retraso.
@export_range(0.5, 30.0, 0.5) var suavizado: float = 6.0
## Desplazamiento fijo respecto al objetivo (por ejemplo para dejar más espacio hacia adelante).
@export var desplazamiento: Vector2 = Vector2.ZERO
## Si el nivel es más pequeño que lo que muestra la pantalla, sube el zoom lo justo para que
## la cámara nunca enseñe nada fuera de los límites. Desactivado, la cámara se centra y
## se ve vacío alrededor del nivel.
@export var ajustar_zoom_a_limites: bool = true

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

## Limita la cámara a un rectángulo en coordenadas globales (sin área = sin límites).
## Los límites son EXACTAMENTE el rectángulo: nunca se agrandan para llenar la pantalla.
func aplicar_limites(rect: Rect2) -> void:
	if not rect.has_area():
		quitar_limites()
		return

	var pantalla := get_viewport_rect().size
	if ajustar_zoom_a_limites:
		var necesario := maxf(pantalla.x / rect.size.x, pantalla.y / rect.size.y)
		if zoom.x < necesario:
			zoom = Vector2(necesario, necesario)

	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)

func quitar_limites() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
