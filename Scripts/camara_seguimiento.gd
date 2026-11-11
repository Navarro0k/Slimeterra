class_name CamaraSeguimiento
extends Camera2D
## Cámara que sigue a un nodo con suavizado exponencial.
## También puede reproducir la cinemática de entrada del nivel.

signal intro_terminada

@export_range(0.5, 30.0, 0.5) var suavizado: float = 6.0
@export var desplazamiento: Vector2 = Vector2.ZERO
@export var ajustar_zoom_a_limites: bool = true

@export_group("Intro")
## Duración total del paneo (subida + pausa + bajada). Más segundos = más lento.
@export_range(1.0, 15.0, 0.5) var duracion_intro: float = 5.5
## Pausa en el extremo superior antes de volver.
@export_range(0.0, 3.0, 0.1) var pausa_extremos_intro: float = 0.5

var _objetivo: Node2D
var _en_intro: bool = false
var _tween_intro: Tween
var _destino_intro: Vector2 = Vector2.ZERO


func seguir(objetivo: Node2D, instantaneo: bool = false) -> void:
	_objetivo = objetivo
	if instantaneo and is_instance_valid(_objetivo):
		global_position = _objetivo.global_position + desplazamiento

func _process(delta: float) -> void:
	if _en_intro:
		return
	if _objetivo == null or not is_instance_valid(_objetivo):
		return
	var destino := _objetivo.global_position + desplazamiento
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))

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


## true mientras la cinemática de entrada está en curso.
func esta_en_intro() -> bool:
	return _en_intro


## Recorre el mapa desde la posición actual hasta el borde superior y vuelve.
## `duracion` y `pausa_extremos` en negativo usan los valores exportados.
func reproducir_intro(rect: Rect2, duracion: float = -1.0, pausa_extremos: float = -1.0) -> void:
	if _en_intro:
		return

	var dur := duracion if duracion > 0.0 else duracion_intro
	var pausa := pausa_extremos if pausa_extremos >= 0.0 else pausa_extremos_intro

	_en_intro = true
	_objetivo = null
	_destino_intro = global_position

	if not rect.has_area():
		_finalizar_intro.call_deferred()
		return

	var pantalla := get_viewport_rect().size
	var mitad := pantalla / (2.0 * zoom)
	var x := _centro_en_rango(
		rect.get_center().x, rect.position.x + mitad.x, rect.end.x - mitad.x
	)
	var y_arriba := _centro_en_rango(
		rect.position.y + mitad.y, rect.position.y + mitad.y, rect.end.y - mitad.y
	)
	var destino_arriba := Vector2(x, y_arriba)
	# La pausa va incluida en la duración total.
	var movimiento := maxf(dur - pausa, 0.1)

	_tween_intro = create_tween()
	_tween_intro.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_intro.tween_property(self, "global_position", destino_arriba, movimiento * 0.5)
	_tween_intro.tween_interval(pausa)
	_tween_intro.tween_property(self, "global_position", _destino_intro, movimiento * 0.5)
	_tween_intro.finished.connect(_finalizar_intro)


## Cancela la cinemática y salta al estado final.
func saltar_intro() -> void:
	if not _en_intro:
		return
	if _tween_intro != null and _tween_intro.is_valid():
		_tween_intro.kill()
	global_position = _destino_intro
	_finalizar_intro()


func _finalizar_intro() -> void:
	if not _en_intro:
		return
	_en_intro = false
	_tween_intro = null
	intro_terminada.emit()


## Clamp que tolera mínimos mayores que máximos (rect más pequeño que la vista).
func _centro_en_rango(valor: float, minimo: float, maximo: float) -> float:
	if minimo > maximo:
		return (minimo + maximo) * 0.5
	return clampf(valor, minimo, maximo)
