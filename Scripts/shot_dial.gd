extends Control
## Dial interactivo de ángulo. Ángulos en grados, 0° horizontal y 90° vertical.

signal angle_changed(value: float)

@export_range(5.0, 80.0, 1.0) var min_angle: float = 5.0
@export_range(5.0, 85.0, 1.0) var max_angle: float = 80.0
@export_range(5.0, 80.0, 1.0) var angle: float = 45.0:
	set(value):
		angle = clampf(value, min_angle, max_angle)
		queue_redraw()

var _dragging := false
const ACCENT := Color("#65E6B5")
const RING := Color("#41616C")
const TEXT_COLOR := Color("#EAF7F5")
const MUTED := Color("#8EABB5")

func _ready() -> void:
	custom_minimum_size = Vector2(270, 175)
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
	var centro := Vector2(size.x * 0.5, size.y - 15.0)
	var delta := punto - centro
	if delta.length() < 8.0:
		return
	var nuevo := clampf(rad_to_deg(atan2(-delta.y, delta.x)), min_angle, max_angle)
	if not is_equal_approx(nuevo, angle):
		angle = nuevo
		angle_changed.emit(angle)

func _draw() -> void:
	var centro := Vector2(size.x * 0.5, size.y - 15.0)
	var radio: float = minf(size.x * 0.42, size.y - 25.0)
	draw_arc(centro, radio, PI, TAU, 48, RING, 5.0, true)
	draw_arc(centro, radio, PI, PI + PI * 0.42, 24, Color("#263F49"), 2.0, true)
	for grados in range(0, 91, 15):
		var theta := deg_to_rad(float(grados))
		var direccion := Vector2(cos(theta), -sin(theta))
		var p1 := centro + direccion * (radio - 7.0)
		var p2 := centro + direccion * (radio + 1.0)
		draw_line(p1, p2, MUTED, 1.5, true)
		var etiqueta_pos := centro + direccion * (radio + 14.0) - Vector2(9, 6)
		draw_string(ThemeDB.fallback_font, etiqueta_pos, str(grados), HORIZONTAL_ALIGNMENT_CENTER, 13, 10, MUTED)
	var theta_aguja := deg_to_rad(angle)
	var direccion_aguja := Vector2(cos(theta_aguja), -sin(theta_aguja))
	draw_line(centro, centro + direccion_aguja * (radio - 9.0), ACCENT, 3.0, true)
	draw_circle(centro, 5.0, TEXT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(centro.x - 20.0, 18.0), "%d°" % roundi(angle), HORIZONTAL_ALIGNMENT_CENTER, 25, 20, TEXT_COLOR)
