extends Control
## Dial interactivo de ángulo. Ángulos en grados, 0° horizontal y 90° vertical.

signal angle_changed(value: float)

@export_range(0.0, 180.0, 1.0) var min_angle: float = 0.0
@export_range(0.0, 180.0, 1.0) var max_angle: float = 180.0
@export_range(0.0, 180.0, 1.0) var angle: float = 45.0:
	set(value):
		angle = clampf(value, min_angle, max_angle)
		queue_redraw()

var _dragging := false
const ACCENT := Color("#62D9C7")
const RING := Color("#4B6C91")
const TEXT_COLOR := Color("#F0F6FF")
const MUTED := Color("#A6B8D0")

func _ready() -> void:
	custom_minimum_size = Vector2(96, 43)
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
	var centro := Vector2(size.x * 0.5, size.y - 5.0)
	var delta := punto - centro
	if delta.length() < 8.0:
		return
	var nuevo := clampf(rad_to_deg(atan2(-delta.y, delta.x)), min_angle, max_angle)
	if not is_equal_approx(nuevo, angle):
		angle = nuevo
		angle_changed.emit(angle)

func _draw() -> void:
	var centro := Vector2(size.x * 0.5, size.y - 5.0)
	var radio: float = minf(size.x * 0.43, size.y - 17.0)
	draw_arc(centro, radio, PI, TAU, 48, RING, 1.5, true)
	draw_arc(centro, radio, PI, PI + PI * 0.42, 24, Color("#2A4563"), 1.0, true)
	for grados in range(0, 181, 30):
		var theta := deg_to_rad(float(grados))
		var direccion := Vector2(cos(theta), -sin(theta))
		var p1 := centro + direccion * (radio - 4.0)
		var p2 := centro + direccion * (radio + 1.0)
		draw_line(p1, p2, MUTED, 1.0, true)
		var etiqueta_pos := centro + direccion * (radio + 5.0) - Vector2(4, 2)
		draw_string(ThemeDB.fallback_font, etiqueta_pos, str(grados), HORIZONTAL_ALIGNMENT_CENTER, 9, 6, MUTED)
	var theta_aguja := deg_to_rad(angle)
	var direccion_aguja := Vector2(cos(theta_aguja), -sin(theta_aguja))
	draw_line(centro, centro + direccion_aguja * (radio - 4.0), ACCENT, 1.5, true)
	draw_circle(centro, 2.0, TEXT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(centro.x - 10.0, 9.0), "%d°" % roundi(angle), HORIZONTAL_ALIGNMENT_CENTER, 20, 8, TEXT_COLOR)
