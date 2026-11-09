class_name PantallaFinEstrellas
extends Control
## Dibuja 3 estrellas; las obtenidas en dorado y el resto apagadas.

const TAM := 22.0
const SEP := 8.0

var obtenidas: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(TAM * 3.0 + SEP * 2.0, TAM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func poner(n: int) -> void:
	obtenidas = n
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var centro := Vector2(TAM * 0.5 + i * (TAM + SEP), TAM * 0.5)
		var color := Color(1.0, 0.85, 0.2) if i < obtenidas else Color(0.25, 0.25, 0.32)
		draw_colored_polygon(_puntos(centro, TAM * 0.5, TAM * 0.22), color)


func _puntos(c: Vector2, r_ext: float, r_int: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := r_ext if k % 2 == 0 else r_int
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
