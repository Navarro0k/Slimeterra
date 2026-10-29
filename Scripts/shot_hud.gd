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
	l.add_theme_constant_override("outline_size", 1)
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

	# Ecuación siempre visible en una tarjeta pequeña, como en el mockup.
	var ecuacion_panel := _panel_contenedor(root, "EquationPanel", Vector2(5, 5), Vector2(214, 82), Color("#17263B"))
	var ecuacion_col := VBoxContainer.new()
	ecuacion_col.add_theme_constant_override("separation", 0)
	ecuacion_panel.add_child(ecuacion_col)
	ecuacion_col.add_child(_label("TRAYECTORIA EN TIEMPO REAL", 8))
	_math_label = RichTextLabel.new()
	_math_label.bbcode_enabled = true
	_math_label.fit_content = false
	_math_label.scroll_active = false
	_math_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_math_label.custom_minimum_size = Vector2(204, 62)
	_math_label.add_theme_font_size_override("normal_font_size", 9)
	_math_label.add_theme_font_size_override("bold_font_size", 9)
	_math_label.add_theme_color_override("default_color", Color("#F0F6FF"))
	ecuacion_col.add_child(_math_label)

	# Perilla inferior central: el área de interacción permanece compacta.
	var dial_panel := _panel_contenedor(root, "AnglePanel", Vector2(157, 202), Vector2(104, 63), Color("#17263B"))
	var dial_col := VBoxContainer.new()
	dial_col.add_theme_constant_override("separation", 0)
	dial_panel.add_child(dial_col)
	var dial_header := HBoxContainer.new()
	dial_col.add_child(dial_header)
	dial_header.add_child(_label("ÁNGULO", 8))
	_angle_label = _label("45°", 10)
	dial_header.add_child(_angle_label)
	_angle_dial = preload("res://Scripts/shot_dial.gd").new()
	_angle_dial.name = "AngleDial"
	_angle_dial.custom_minimum_size = Vector2(96, 43)
	dial_col.add_child(_angle_dial)
	_angle_dial.angle_changed.connect(_on_angle_changed)

	# Potencia y acción de disparo se integran en una sola tarjeta.
	var power_panel := _panel_contenedor(root, "PowerPanel", Vector2(329, 211), Vector2(146, 54), Color("#17263B"))
	var power_col := VBoxContainer.new()
	power_col.add_theme_constant_override("separation", 1)
	power_panel.add_child(power_col)
	var power_header := HBoxContainer.new()
	power_col.add_child(power_header)
	power_header.add_child(_label("POTENCIA", 8))
	_power_label = _label("65%", 9)
	power_header.add_child(_power_label)
	_power_slider = HSlider.new()
	_power_slider.min_value = 0
	_power_slider.max_value = 100
	_power_slider.step = 1
	_power_slider.value = power_percent
	_power_slider.custom_minimum_size = Vector2(126, 10)
	_power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_slider.value_changed.connect(_on_power_changed)
	power_col.add_child(_power_slider)
	_launch_button = Button.new()
	_launch_button.text = "CLIC PARA DISPARAR  ↗"
	_launch_button.custom_minimum_size = Vector2(130, 19)
	_launch_button.add_theme_font_size_override("font_size", 8)
	_launch_button.add_theme_color_override("font_color", Color("#102338"))
	_launch_button.add_theme_stylebox_override("normal", _button_style(Color("#62D9C7")))
	_launch_button.add_theme_stylebox_override("hover", _button_style(Color("#8AEBDD")))
	_launch_button.add_theme_stylebox_override("pressed", _button_style(Color("#3CAFA6")))
	_launch_button.pressed.connect(_on_launch_pressed)
	power_col.add_child(_launch_button)

func _button_style(color: Color) -> StyleBoxFlat:
	var s := _panel_style(color)
	s.border_color = color
	return s

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

	# La forma parabólica se calcula a partir del estado actual del disparo.
	# Con rozamiento la simulación es numérica (RK4); se muestra también la
	# parábola balística ideal, cuyos coeficientes cambian con ángulo y potencia.
	var modelo: Dictionary = ModeloDisparo.ecuacion_parabolica(position_initial, velocity_initial, gravity)
	var texto := "[color=#62D9C7][b]TRAYECTORIA · TIEMPO REAL[/b][/color]\\n"
	texto += "[color=#F0F6FF]θ=%d°   P=%d%%   v₀=%.1f[/color]\\n" % [roundi(angle_degrees), roundi(power_percent), velocity_initial.length()]
	if bool(modelo.get("valida", false)):
		var a: float = float(modelo["a"])
		var b: float = float(modelo["b"])
		var c: float = float(modelo["c"])
		texto += "[b]y(x) = ax[sup]2[/sup] + bx + c[/b]\\n"
		texto += "a=%.4f   b=%.3f   c=%.2f\\n" % [a, b, c]
		texto += "[color=#62D9C7]y(x)=%.4fx[sup]2[/sup] %s %.3fx %s %.2f[/color]" % [a, "+" if b >= 0.0 else "−", absf(b), "+" if c >= 0.0 else "−", absf(c)]
	else:
		texto += "[b]Tiro casi vertical[/b]\\n"
		texto += "x(t)=%.2f + %.2ft\\n" % [position_initial.x, velocity_initial.x]
		texto += "y(t)=%.2f %s %.2ft + %.2ft[sup]2[/sup]" % [position_initial.y, "+" if velocity_initial.y >= 0.0 else "−", absf(velocity_initial.y), gravity * 0.5]
	texto += "\\n[color=#A6B8D0]%s[/color]" % ("Simulación con rozamiento: RK4" if damping > 0.00001 else "Modelo balístico parabólico")
	_math_label.text = texto

func _actualizar_lecturas() -> void:
	if is_instance_valid(_angle_label):
		_angle_label.text = "%d°" % roundi(angle_degrees)
	if is_instance_valid(_power_label):
		_power_label.text = "%d%%" % roundi(power_percent)
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not _can_launch or power_percent <= 0.0
