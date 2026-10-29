extends CanvasLayer
class_name ShotHUD
## HUD construido por código: ángulo, potencia, ecuaciones y botón de lanzamiento.

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
var _math_panel: PanelContainer

const BG := Color("#172B36")
const BG_DARK := Color("#12242D")
const BORDER := Color("#41616C")
const ACCENT := Color("#65E6B5")
const FG := Color("#EAF7F5")
const MUTED := Color("#8EABB5")

func _ready() -> void:
	layer = 10
	_construir_interfaz()
	_actualizar_lecturas()

func _panel_style(color: Color, radius: int = 16) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = BORDER
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(radius)
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	estilo.shadow_color = Color(0, 0, 0, 0.25)
	estilo.shadow_size = 0
	return estilo

func _construir_interfaz() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "AimPanel"
	panel.add_theme_stylebox_override("panel", _panel_style(BG))
	panel.position = Vector2(5, 18)
	panel.custom_minimum_size = Vector2(118, 0)
	panel.size = Vector2(118, 0)
	root.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = "DISPARO"
	titulo.add_theme_color_override("font_color", FG)
	titulo.add_theme_font_size_override("font_size", 9)
	columna.add_child(titulo)

	var fila_angulo := HBoxContainer.new()
	columna.add_child(fila_angulo)
	var lbl := Label.new()
	lbl.text = "Ángulo"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", MUTED)
	lbl.add_theme_font_size_override("font_size", 9)
	fila_angulo.add_child(lbl)
	_angle_label = Label.new()
	_angle_label.add_theme_color_override("font_color", ACCENT)
	_angle_label.add_theme_font_size_override("font_size", 10)
	fila_angulo.add_child(_angle_label)

	var dial_frame := PanelContainer.new()
	dial_frame.add_theme_stylebox_override("panel", _panel_style(BG_DARK, 12))
	dial_frame.custom_minimum_size = Vector2(108, 64)
	columna.add_child(dial_frame)
	_angle_dial = preload("res://Scripts/shot_dial.gd").new()
	_angle_dial.name = "AngleDial"
	dial_frame.add_child(_angle_dial)
	_angle_dial.angle_changed.connect(_on_angle_changed)

	var fila_potencia := HBoxContainer.new()
	columna.add_child(fila_potencia)
	var lbl_potencia := Label.new()
	lbl_potencia.text = "Potencia"
	lbl_potencia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_potencia.add_theme_color_override("font_color", MUTED)
	lbl_potencia.add_theme_font_size_override("font_size", 9)
	fila_potencia.add_child(lbl_potencia)
	_power_label = Label.new()
	_power_label.add_theme_color_override("font_color", ACCENT)
	_power_label.add_theme_font_size_override("font_size", 9)
	fila_potencia.add_child(_power_label)

	_power_slider = HSlider.new()
	_power_slider.min_value = 0
	_power_slider.max_value = 100
	_power_slider.step = 1
	_power_slider.value = power_percent
	_power_slider.custom_minimum_size.y = 10
	_power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_slider.value_changed.connect(_on_power_changed)
	columna.add_child(_power_slider)

	var nota := Label.new()
	nota.text = "Ángulo y fuerza"
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_color_override("font_color", MUTED)
	nota.add_theme_font_size_override("font_size", 8)
	columna.add_child(nota)

	_launch_button = Button.new()
	_launch_button.text = "LANZAR  ↗"
	_launch_button.custom_minimum_size.y = 20
	_launch_button.add_theme_color_override("font_color", Color("#10272A"))
	_launch_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	_launch_button.add_theme_stylebox_override("hover", _button_style(Color("#8AF3CD")))
	_launch_button.add_theme_stylebox_override("pressed", _button_style(Color("#43B995")))
	_launch_button.pressed.connect(_on_launch_pressed)
	columna.add_child(_launch_button)

	var math_button := Button.new()
	math_button.text = "Modelo +"
	math_button.flat = true
	math_button.add_theme_color_override("font_color", FG)
	math_button.add_theme_font_size_override("font_size", 8)
	math_button.pressed.connect(_toggle_math)
	columna.add_child(math_button)

	_math_panel = PanelContainer.new()
	_math_panel.name = "MathPanel"
	_math_panel.position = Vector2(132, 18)
	_math_panel.custom_minimum_size = Vector2(150, 0)
	_math_panel.add_theme_stylebox_override("panel", _panel_style(BG_DARK, 12))
	root.add_child(_math_panel)
	var math_col := VBoxContainer.new()
	_math_panel.add_child(math_col)
	var math_title := Label.new()
	math_title.text = "MODELO"
	math_title.add_theme_font_size_override("font_size", 8)
	math_title.add_theme_color_override("font_color", ACCENT)
	math_col.add_child(math_title)
	_math_label = RichTextLabel.new()
	_math_label.fit_content = false
	_math_label.bbcode_enabled = true
	_math_label.scroll_active = true
	_math_label.custom_minimum_size = Vector2(140, 92)
	_math_label.add_theme_font_size_override("normal_font_size", 7)
	_math_label.add_theme_font_size_override("bold_font_size", 7)
	_math_label.add_theme_color_override("default_color", FG)
	math_col.add_child(_math_label)
	_math_panel.visible = false

func _button_style(color: Color) -> StyleBoxFlat:
	var estilo := _panel_style(color, 10)
	estilo.border_color = color
	estilo.shadow_size = 0
	return estilo

func _on_angle_changed(valor: float) -> void:
	angle_degrees = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_power_changed(valor: float) -> void:
	power_percent = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_launch_pressed() -> void:
	if not _can_launch or power_percent <= 0.0:
		return
	launch_requested.emit(angle_degrees, power_percent)

func _toggle_math() -> void:
	_math_panel.visible = not _math_panel.visible
	_actualizar_lecturas()

func set_launch_enabled(enabled: bool) -> void:
	_can_launch = enabled
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not enabled or power_percent <= 0.0
		_launch_button.text = "LANZAR  ↗" if enabled else "ESPERANDO…"

func set_model_values(position_initial: Vector2, velocity_initial: Vector2, gravity: float, damping: float) -> void:
	if not is_instance_valid(_math_label):
		return
	var speed := velocity_initial.length()
	var theta := deg_to_rad(angle_degrees)
	var vx := velocity_initial.x
	var vy := velocity_initial.y
	var texto := "[b]Datos[/b]\n"
	texto += "θ: %.0f°  P: %.0f%%\n" % [angle_degrees, power_percent]
	texto += "v₀: %.1f px/s\n" % speed
	texto += "vₓ: %.1f  vᵧ: %.1f\n" % [vx, vy]
	texto += "g: %.1f  k: %.3f\n\n" % [gravity, damping]
	if absf(damping) < 0.00001:
		texto += "[b]Parábola[/b]\n"
		texto += "x = x₀ + vₓ·t\n"
		texto += "y = y₀ + vᵧ·t + ½gt²\n"
		texto += "y positiva hacia abajo.\n"
	else:
		texto += "[b]Con rozamiento[/b]\n"
		texto += "dx/dt = vₓ\n"
		texto += "dy/dt = vᵧ\n"
		texto += "dv/dt = (0,g) − k·v\n"
		texto += "Método RK4.\n"
	_math_label.text = texto

func _actualizar_lecturas() -> void:
	if is_instance_valid(_angle_label):
		_angle_label.text = "%d°" % roundi(angle_degrees)
	if is_instance_valid(_power_label):
		_power_label.text = "%d%%" % roundi(power_percent)
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not _can_launch or power_percent <= 0.0
