extends CanvasLayer
class_name ShotHUD
## HUD compacto para viewport 480x270. Mantiene las señales públicas usadas por Slingshoot.

signal launch_requested(angle_degrees: float, power_percent: float)
signal aim_changed(angle_degrees: float, power_percent: float)

var angle_degrees: float = 45.0
var power_percent: float = 65.0
var _can_launch := true
var _angle_dial: Control
var _power_slider: HSlider
var _angle_label: Label
var _power_label: Label
var _math_label: RichTextLabel
var _equation_panel: PanelContainer
var _equation_toggle: Button
var _equation_title: Label
var _equation_visible := true
var _launch_button: Button
var _pause_button: Button

const PANEL := Color("#17263B")
const PANEL_LIGHT := Color("#243B55")
const RED := Color("#62D9C7")
const TEXT := Color("#F0F6FF")
const EDGE := Color("#3C6680")

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_interfaz()
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _panel_style(color: Color = PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = EDGE
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s

func _label(texto: String, size: int = 9, color: Color = RED) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	return l

func _panel_contenedor(parent: Control, nombre: String, pos: Vector2, tam: Vector2, color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = nombre
	p.position = pos
	p.size = tam
	p.custom_minimum_size = tam
	p.add_theme_stylebox_override("panel", _panel_style(color))
	parent.add_child(p)
	return p

func _construir_interfaz() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Grid de HUD para viewport 480x270:
	# ecuación arriba-izquierda, ángulo abajo-centro y potencia/disparo abajo-derecha.
	# El botón de ecuación vive en la cabecera del propio panel.
	_equation_panel = _panel_contenedor(root, "EquationPanel", Vector2(5, 20), Vector2(158, 91), Color(0.09, 0.15, 0.23, 0.38))
	var ecuacion_col := VBoxContainer.new()
	ecuacion_col.position = Vector2(4, 18)
	ecuacion_col.size = Vector2(150, 69)
	ecuacion_col.add_theme_constant_override("separation", 1)
	_equation_panel.add_child(ecuacion_col)
	_equation_title = _label("TRAYECTORIA", 7)
	ecuacion_col.add_child(_equation_title)

	_math_label = RichTextLabel.new()
	_math_label.bbcode_enabled = true
	_math_label.fit_content = false
	_math_label.scroll_active = false
	_math_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_math_label.custom_minimum_size = Vector2(150, 68)
	_math_label.add_theme_font_size_override("normal_font_size", 7)
	_math_label.add_theme_font_size_override("bold_font_size", 7)
	_math_label.add_theme_color_override("default_color", Color("#F0F6FF"))
	_math_label.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.06, 1.0))
	_math_label.add_theme_constant_override("outline_size", 2)
	ecuacion_col.add_child(_math_label)

	# El botón es hermano del panel, no hijo: permanece visible para volver a abrirlo.
	_equation_toggle = Button.new()
	_equation_toggle.name = "EquationToggle"
	_equation_toggle.position = Vector2(5, 5)
	_equation_toggle.custom_minimum_size = Vector2(42, 12)
	_equation_toggle.text = "OCULTAR"
	_equation_toggle.add_theme_font_size_override("font_size", 5)
	_equation_toggle.add_theme_color_override("font_color", RED)
	_equation_toggle.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.06, 1.0))
	_equation_toggle.add_theme_constant_override("outline_size", 2)
	_equation_toggle.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.15, 0.23, 0.58)))
	_equation_toggle.add_theme_stylebox_override("hover", _button_style(Color(0.14, 0.23, 0.33, 0.92)))
	_equation_toggle.pressed.connect(_on_equation_toggle_pressed)
	root.add_child(_equation_toggle)

	# Brújula sin panel de fondo; lectura única del ángulo y dial 20% mayor.
	var dial_col := VBoxContainer.new()
	dial_col.name = "AngleControls"
	dial_col.position = Vector2(216, 207)
	dial_col.size = Vector2(48, 61)
	dial_col.add_theme_constant_override("separation", 0)
	root.add_child(dial_col)
	_angle_label = _label("45°", 9)
	_angle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dial_col.add_child(_angle_label)
	_angle_dial = preload("res://Scripts/shot_dial.gd").new()
	_angle_dial.name = "AngleDial"
	_angle_dial.custom_minimum_size = Vector2(44, 44)
	dial_col.add_child(_angle_dial)
	_angle_dial.angle_changed.connect(_on_angle_changed)

	# El control representa la velocidad inicial v₀, ajustada mediante el porcentaje
	# de potencia. v₀ cambia el coeficiente a (curvatura) y el alcance del disparo.
	var power_panel := _panel_contenedor(root, "PowerPanel", Vector2(365, 202), Vector2(110, 63), Color("#17263B"))
	var power_col := VBoxContainer.new()
	power_col.add_theme_constant_override("separation", 0)
	power_panel.add_child(power_col)
	var power_header := HBoxContainer.new()
	power_col.add_child(power_header)
	power_header.add_child(_label("VELOCIDAD INICIAL v₀", 6))
	_power_label = _label("65%", 8)
	power_header.add_child(_power_label)
	var power_hint := _label("v₀ modifica a y el alcance", 5, TEXT)
	power_col.add_child(power_hint)
	_power_slider = HSlider.new()
	_power_slider.min_value = 0
	_power_slider.max_value = 100
	_power_slider.step = 1
	_power_slider.value = power_percent
	_power_slider.custom_minimum_size = Vector2(94, 7)
	_power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_slider.value_changed.connect(_on_power_changed)
	power_col.add_child(_power_slider)
	_launch_button = Button.new()
	_launch_button.text = "DISPARAR ↗"
	_launch_button.custom_minimum_size = Vector2(94, 14)
	_launch_button.add_theme_font_size_override("font_size", 7)
	_launch_button.add_theme_color_override("font_color", Color("#102338"))
	_launch_button.add_theme_stylebox_override("normal", _button_style(Color("#62D9C7")))
	_launch_button.add_theme_stylebox_override("hover", _button_style(Color("#8AEBDD")))
	_launch_button.add_theme_stylebox_override("pressed", _button_style(Color("#3CAFA6")))
	_launch_button.pressed.connect(_on_launch_pressed)
	power_col.add_child(_launch_button)

func _on_equation_toggle_pressed() -> void:
	_equation_visible = not _equation_visible
	_equation_panel.visible = _equation_visible
	_equation_toggle.text = "OCULTAR" if _equation_visible else "VER EQ."

func _button_style(color: Color) -> StyleBoxFlat:
	var s := _panel_style(color)
	s.border_color = color
	return s

func set_aim_from_drag(angulo: float, potencia: float) -> void:
	# Sincroniza dial, porcentaje y etiquetas sin crear bucles de señales.
	angle_degrees = fposmod(angulo, 360.0)
	power_percent = clampf(potencia, 0.0, 100.0)
	if is_instance_valid(_angle_dial):
		_angle_dial.angle = angle_degrees
	if is_instance_valid(_power_slider):
		_power_slider.set_value_no_signal(power_percent)
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_angle_changed(valor: float) -> void:
	angle_degrees = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_power_changed(valor: float) -> void:
	power_percent = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_launch_pressed() -> void:
	if _can_launch and power_percent > 0.0:
		launch_requested.emit(angle_degrees, power_percent)

func set_launch_enabled(enabled: bool) -> void:
	_can_launch = enabled
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not enabled or power_percent <= 0.0
		_launch_button.text = "CLIC PARA DISPARAR" if enabled else "ESPERANDO SLIME..."

func set_model_values(position_initial: Vector2, velocity_initial: Vector2, gravity: float, damping: float) -> void:
	if not is_instance_valid(_math_label):
		return

	# Mostrar únicamente la ecuación y sus coeficientes actuales.
	# Slingshoot llama esta función al cambiar el ángulo o la potencia.
	var modelo: Dictionary = ModeloDisparo.ecuacion_parabolica(position_initial, velocity_initial, gravity)
	var texto := ""
	texto += "[color=#FFFFFF]y(x) = ax² + bx + c[/color]\n"
	if bool(modelo.get("valida", false)):
		var a: float = float(modelo["a"])
		var b: float = float(modelo["b"])
		var c: float = float(modelo["c"])
		texto += "[color=#62D9C7]a = %.4f\nb = %.4f\nc = %.2f[/color]\n" % [a, b, c]
		texto += "[color=#FFFFFF]y(x) = %.4fx² %s %.4fx %s %.2f[/color]" % [a, "+" if b >= 0.0 else "−", absf(b), "+" if c >= 0.0 else "−", absf(c)]
	else:
		texto += "[color=#A6B8D0]Trayectoria casi vertical; no se expresa como y(x).[/color]"
	_math_label.text = texto

func _actualizar_lecturas() -> void:
	if is_instance_valid(_angle_label):
		_angle_label.text = "%d°" % roundi(angle_degrees)
	if is_instance_valid(_power_label):
		_power_label.text = "%d%%" % roundi(power_percent)
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not _can_launch or power_percent <= 0.0
