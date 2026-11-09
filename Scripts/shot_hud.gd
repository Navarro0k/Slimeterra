extends CanvasLayer
class_name ShotHUD
## HUD compacto (480x270) con ecuaciones, dial de ángulo, potencia y cartilla.

signal launch_requested(angle_degrees: float, power_percent: float)
signal aim_changed(angle_degrees: float, power_percent: float)
signal cartilla_cerrada()

var angle_degrees: float = 45.0
var power_percent: float = 65.0
## "parabola" (nivel 1) o "matrices" (nivel 2).
var modo_ecuacion: String = "parabola"
## true mientras la cartilla está abierta: bloquea el juego.
var cartilla_activa: bool = true

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
var _fuente_ecuaciones: FontFile
var _fuente_pixel: FontFile
var _cartilla: Control
var _modelo_pos: Vector2 = Vector2.ZERO
var _modelo_vel: Vector2 = Vector2.ZERO
var _modelo_gravedad: float = 980.0
var _modelo_amortiguamiento: float = 0.0
var _hay_modelo: bool = false

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fuente_ecuaciones = load("res://Assets/fonts/JetBrainsMono-Regular.ttf") as FontFile
	_fuente_pixel = HudTema.fuente_pixel()
	_construir_interfaz()
	_construir_cartilla()
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)


func _construir_interfaz() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Ecuación arriba-izquierda, ángulo abajo-centro, potencia/disparo abajo-derecha.
	_construir_panel_ecuacion(root)
	_construir_dial(root)
	_construir_panel_potencia(root)

func _construir_panel_ecuacion(root: Control) -> void:
	_equation_panel = HudTema.panel_contenedor(root, "EquationPanel", Vector2(5, 20), Vector2(158, 91))
	var ecuacion_col := VBoxContainer.new()
	ecuacion_col.position = Vector2(4, 18)
	ecuacion_col.size = Vector2(150, 69)
	ecuacion_col.add_theme_constant_override("separation", 1)
	_equation_panel.add_child(ecuacion_col)
	_equation_title = HudTema.etiqueta("TRAYECTORIA", _fuente_ecuaciones, 7, HudTema.TINTA_SUAVE)
	ecuacion_col.add_child(_equation_title)

	_math_label = _crear_texto_ecuaciones()
	ecuacion_col.add_child(_math_label)

	# El botón es hermano del panel: permanece visible para volver a abrirlo.
	_equation_toggle = _crear_boton_ecuacion()
	root.add_child(_equation_toggle)

func _crear_texto_ecuaciones() -> RichTextLabel:
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = false
	texto.scroll_active = false
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto.custom_minimum_size = Vector2(150, 68)
	texto.add_theme_font_size_override("normal_font_size", 8)
	texto.add_theme_font_size_override("bold_font_size", 8)
	texto.add_theme_font_size_override("mono_font_size", 8)
	if _fuente_ecuaciones != null:
		texto.add_theme_font_override("normal_font", _fuente_ecuaciones)
		texto.add_theme_font_override("bold_font", _fuente_ecuaciones)
		texto.add_theme_font_override("mono_font", _fuente_ecuaciones)
	texto.add_theme_color_override("default_color", HudTema.TINTA_FUERTE)
	return texto

func _crear_boton_ecuacion() -> Button:
	var boton := Button.new()
	boton.name = "EquationToggle"
	boton.position = Vector2(5, 5)
	boton.custom_minimum_size = Vector2(42, 12)
	boton.text = "OCULTAR"
	boton.add_theme_font_size_override("font_size", 5)
	boton.add_theme_color_override("font_color", HudTema.CREMA)
	boton.add_theme_color_override("font_hover_color", HudTema.CREMA)
	boton.add_theme_color_override("font_pressed_color", HudTema.CREMA)
	if _fuente_ecuaciones != null:
		boton.add_theme_font_override("font", _fuente_ecuaciones)
	boton.add_theme_stylebox_override("normal", HudTema.estilo_boton(HudTema.TINTA))
	boton.add_theme_stylebox_override("hover", HudTema.estilo_boton(HudTema.HOVER))
	boton.add_theme_stylebox_override("pressed", HudTema.estilo_boton(HudTema.PRESSED))
	boton.pressed.connect(_on_equation_toggle_pressed)
	return boton

func _construir_dial(root: Control) -> void:
	var dial_col := VBoxContainer.new()
	dial_col.name = "AngleControls"
	dial_col.position = Vector2(216, 207)
	dial_col.size = Vector2(48, 61)
	dial_col.add_theme_constant_override("separation", 0)
	root.add_child(dial_col)
	_angle_label = HudTema.etiqueta("45°", _fuente_pixel, 9)
	_angle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_angle_label.add_theme_stylebox_override("normal", HudTema.estilo_chip())
	dial_col.add_child(_angle_label)
	_angle_dial = preload("res://Scripts/shot_dial.gd").new()
	_angle_dial.name = "AngleDial"
	_angle_dial.custom_minimum_size = Vector2(44, 44)
	dial_col.add_child(_angle_dial)
	_angle_dial.angle_changed.connect(_on_angle_changed)

func _construir_panel_potencia(root: Control) -> void:
	var power_panel := HudTema.panel_contenedor(root, "PowerPanel", Vector2(365, 202), Vector2(110, 40))
	var power_col := VBoxContainer.new()
	power_col.add_theme_constant_override("separation", 0)
	power_panel.add_child(power_col)
	var power_header := HBoxContainer.new()
	power_col.add_child(power_header)
	power_header.add_child(HudTema.etiqueta("VELOCIDAD INICIAL v0", _fuente_pixel, 6))
	_power_label = HudTema.etiqueta("65%", _fuente_pixel, 8)
	power_header.add_child(_power_label)
	power_col.add_child(HudTema.etiqueta("v0 modifica a y el alcance", _fuente_pixel, 5, HudTema.TINTA_SUAVE))
	_power_slider = _crear_slider_potencia()
	power_col.add_child(_power_slider)

func _crear_slider_potencia() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = power_percent
	slider.custom_minimum_size = Vector2(94, 9)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.editable = false
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider.add_theme_stylebox_override("slider", HudTema.estilo_slider_fondo())
	slider.add_theme_stylebox_override("grabber_area", HudTema.estilo_slider_relleno())
	slider.add_theme_stylebox_override("grabber_area_highlight", HudTema.estilo_slider_relleno())
	slider.add_theme_icon_override("grabber", HudTema.icono_circulo(HudTema.TINTA, 9))
	slider.add_theme_icon_override("grabber_highlight", HudTema.icono_circulo(HudTema.PROGRESO_RELLENO, 9))
	slider.value_changed.connect(_on_power_changed)
	return slider

func _construir_cartilla() -> void:
	var escena := load("res://Scenes/UI/Cartilla.tscn") as PackedScene
	if escena == null:
		_omitir_cartilla()
		return
	_cartilla = escena.instantiate() as Control
	if _cartilla == null:
		_omitir_cartilla()
		return
	_cartilla.set("modo_ecuacion", modo_ecuacion)
	if _cartilla.has_signal("cerrada"):
		_cartilla.connect("cerrada", _on_cartilla_cerrada)
	else:
		_omitir_cartilla()
		_cartilla.queue_free()
		_cartilla = null
		return
	add_child(_cartilla)
	if _hay_modelo and _cartilla.has_method("set_model_values"):
		_cartilla.call("set_model_values", _modelo_pos, _modelo_vel, _modelo_gravedad, _modelo_amortiguamiento)

## Sin cartilla el nivel no debe quedar bloqueado.
func _omitir_cartilla() -> void:
	cartilla_activa = false
	_emitir_cartilla_cerrada.call_deferred()

func _emitir_cartilla_cerrada() -> void:
	cartilla_cerrada.emit()

func _on_cartilla_cerrada() -> void:
	cartilla_activa = false
	_cartilla = null
	cartilla_cerrada.emit()


func _on_equation_toggle_pressed() -> void:
	_equation_visible = not _equation_visible
	_equation_panel.visible = _equation_visible
	_equation_toggle.text = "OCULTAR" if _equation_visible else "VER EQ."

func _on_angle_changed(valor: float) -> void:
	angle_degrees = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func _on_power_changed(valor: float) -> void:
	power_percent = valor
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func set_aim_from_drag(angulo: float, potencia: float) -> void:
	# Sincroniza dial y slider sin crear bucles de señales.
	angle_degrees = fposmod(angulo, 360.0)
	power_percent = clampf(potencia, 0.0, 100.0)
	if is_instance_valid(_angle_dial):
		_angle_dial.angle = angle_degrees
	if is_instance_valid(_power_slider):
		_power_slider.set_value_no_signal(power_percent)
	_actualizar_lecturas()
	aim_changed.emit(angle_degrees, power_percent)

func set_launch_enabled(enabled: bool) -> void:
	_can_launch = enabled
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not enabled or power_percent <= 0.0
		_launch_button.text = "CLIC PARA DISPARAR" if enabled else "ESPERANDO SLIME..."

func set_model_values(position_initial: Vector2, velocity_initial: Vector2, gravity: float, damping: float) -> void:
	_modelo_pos = position_initial
	_modelo_vel = velocity_initial
	_modelo_gravedad = gravity
	_modelo_amortiguamiento = damping
	_hay_modelo = true
	if is_instance_valid(_cartilla) and _cartilla.has_method("set_model_values"):
		_cartilla.call("set_model_values", position_initial, velocity_initial, gravity, damping)
	if not is_instance_valid(_math_label):
		return
	_math_label.text = HudEcuaciones.texto(modo_ecuacion, position_initial, velocity_initial, gravity, damping)

func _actualizar_lecturas() -> void:
	if is_instance_valid(_angle_label):
		_angle_label.text = "%d°" % roundi(angle_degrees)
	if is_instance_valid(_power_label):
		_power_label.text = "%d%%" % roundi(power_percent)
	if is_instance_valid(_launch_button):
		_launch_button.disabled = not _can_launch or power_percent <= 0.0
