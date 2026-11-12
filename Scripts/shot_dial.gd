extends Control
## Dial de giro completo: 0° derecha, 90° arriba, 180° izquierda, 270° abajo.

signal angle_changed(value: float)

@export_range(0.0, 359.0, 1.0) var angle: float = 45.0:
	set(value):
		angle = fposmod(value, 360.0)
		queue_redraw()

var _dragging := false

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_actualizar_desde_punto(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_actualizar_desde_punto(event.position)
		accept_event()

func _actualizar_desde_punto(punto: Vector2) -> void:
	var centro := size * 0.5
	var delta := punto - centro
	if delta.length() < 4.0:
		return
	var nuevo := fposmod(rad_to_deg(atan2(-delta.y, delta.x)), 360.0)
	if not is_equal_approx(nuevo, angle):
		angle = nuevo
		angle_changed.emit(angle)

func _draw() -> void:
	var centro := size * 0.5
	var radio: float = minf(size.x, size.y) * 0.39
	# Disco de papel con borde de tinta.
	draw_circle(centro + Vector2(0.0, 1.5), radio + 4.0, Color(0, 0, 0, 0.25))
	draw_circle(centro, radio + 4.0, HudTema.BORDE)
	draw_circle(centro, radio + 3.0, HudTema.PAPEL)
	draw_arc(centro, radio, 0.0, TAU, 64, HudTema.BORDE, 1.2, true)
	for grados in range(0, 360, 30):
		var theta := deg_to_rad(float(grados))
		var direccion := Vector2(cos(theta), -sin(theta))
		draw_line(centro + direccion * (radio - 3.0), centro + direccion * (radio + 1.0), HudTema.TINTA_SUAVE, 1.0, true)
	var theta_aguja := deg_to_rad(angle)
	var direccion_aguja := Vector2(cos(theta_aguja), -sin(theta_aguja))
	draw_line(centro, centro + direccion_aguja * (radio - 4.0), HudTema.TINTA_FUERTE, 1.8, true)
	draw_circle(centro, 2.0, HudTema.BORDE)
