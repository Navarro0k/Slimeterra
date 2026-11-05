extends Control
## Cartilla explicativa independiente (reutilizable en nivel 1 y 2).
## Se muestra como overlay de pantalla completa con musica de fondo.

signal cerrada

@export var modo_ecuacion: String = "parabola"

var _fuente: FontFile
var _musica: AudioStreamPlayer
var _lbl: RichTextLabel
var _btn: Button
var _pagina: int = 0

func _ready() -> void:
	_fuente = load("res://Assets/fonts/JetBrainsMono-Regular.ttf") as FontFile
	# Construir UI en codigo (no depende de .tscn).
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2
	mouse_filter = 0

	var panel := PanelContainer.new()
	panel.anchors_preset = 15
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = -20
	panel.offset_bottom = -20
	panel.grow_horizontal = 2
	panel.grow_vertical = 2
	panel.mouse_filter = 0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1.0, 0.95, 0.55, 0.95)
	estilo.border_color = Color(0.7, 0.6, 0.2)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", estilo)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_lbl = RichTextLabel.new()
	_lbl.bbcode_enabled = true
	_lbl.fit_content = false
	_lbl.scroll_active = true
	_lbl.autowrap_mode = 3
	_lbl.size_flags_vertical = 3
	_lbl.size_flags_horizontal = 3
	_lbl.add_theme_font_size_override("normal_font_size", 11)
	_lbl.add_theme_font_size_override("bold_font_size", 11)
	_lbl.add_theme_font_size_override("mono_font_size", 11)
	_lbl.add_theme_color_override("default_color", Color(0.12, 0.08, 0.0))
	if _fuente != null:
		_lbl.add_theme_font_override("normal_font", _fuente)
		_lbl.add_theme_font_override("bold_font", _fuente)
		_lbl.add_theme_font_override("mono_font", _fuente)
	vbox.add_child(_lbl)

	_btn = Button.new()
	_btn.text = "Continuar"
	_btn.custom_minimum_size = Vector2(120, 28)
	_btn.add_theme_font_size_override("font_size", 11)
	_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	if _fuente != null:
		_btn.add_theme_font_override("font", _fuente)
	_btn.pressed.connect(_on_continuar)
	vbox.add_child(_btn)

	_musica = AudioStreamPlayer.new()
	_musica.stream = load("res://Assets/Audio/sound_effects/CartillaBg.mp3")
	_musica.volume_db = -10.0
	_musica.bus = &"Master"
	add_child(_musica)

	# Pausar la musica del nivel mientras se muestra la cartilla.
	for m in get_tree().get_nodes_in_group("musica_nivel"):
		if m is AudioStreamPlayer:
			(m as AudioStreamPlayer).stream_paused = true
	# Reproducir musica de fondo explicativa.
	if _musica.stream != null:
		_musica.play()
		_musica.finished.connect(func(): if is_instance_valid(_musica) and visible: _musica.play())

	# Mostrar pagina 1.
	_pagina = 0
	_actualizar()

func _actualizar() -> void:
	if modo_ecuacion == "matrices":
		if _pagina == 0:
			_lbl.text = "[b]Por que matrices?[/b]\n\nEn el nivel 1 la trayectoria es una parabola perfecta porque no hay amortiguamiento. Aqui el aire frena al slime, asi la curva se deforma y ya no es y = a x² + b x + c.\n\nUsamos un sistema lineal: [b]s' = A*s + b[/b], donde s = [x, y, vx, vy].\n\nEl estado del slime se actualiza con matrices, lo que permite modelar el rozamiento del aire de forma dinamica.\n\nLa matriz A encode la gravedad y el amortiguamiento; b encode la gravedad constante. La solucion es s(t) = e^(A t) * s0 + integral(e^(A tau) b dtau)."
			_btn.text = "Continuar"
		else:
			_lbl.text = "[b]Formula y aplicacion:[/b]\n\ns0 = [ x0  y0  vx0  vy0 ]^T\n\nA =\n[  0   0   1   0  ]\n[  0   0   0   1  ]\n[  0   0  -k   0  ]\n[  0   0   0  -k  ]\n\nb = [ 0  0  0  g ]^T\n\nk = 0.10     g = 980\n\nAjusta angulo y potencia: s0 cambia en tiempo real y la trayectoria se recalcula.\n\n[b]Ahora juega y observa como la matriz cambia la trayectoria![/b]"
			_btn.text = "Cerrar"
	else:
		if _pagina == 0:
			_lbl.text = "[b]Por que una parabola?[/b]\n\nSin amortiguamiento, el tiro sigue [b]y(x) = a x² + b x + c[/b]. La gravedad es constante y no hay rozamiento, asi la curva es simetrica.\n\nLos coeficientes son:\na = g / (2 * vx²)  (curvatura, depende de la velocidad horizontal)\nb = vy / vx - 2 * a * x0  (pendiente inicial)\nc = y0 - b * x0 + a * x0²  (posicion inicial)\n\nAjusta angulo y potencia para alcanzar la meta."
			_btn.text = "Continuar"
		else:
			_lbl.text = "[b]Formula y aplicacion:[/b]\n\na = g / (2 * vx^2)\nb = vy / vx - 2 * a * x0\nc = y0 - b * x0 + a * x0^2\n\nCon vx, vy de la velocidad inicial.\n\nCambia angulo y potencia: a, b, c se actualizan en tiempo real en el panel superior.\n\n[b]Ahora juega y observa como cambian los coeficientes![/b]"
			_btn.text = "Cerrar"

func _on_continuar() -> void:
	if _pagina == 0:
		_pagina = 1
		_actualizar()
	else:
		_cerrar()

func _cerrar() -> void:
	visible = false
	if _musica != null:
		_musica.stop()
	for m in get_tree().get_nodes_in_group("musica_nivel"):
		if m is AudioStreamPlayer:
			(m as AudioStreamPlayer).stream_paused = false
	cerrada.emit()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cerrar()

func _input(event: InputEvent) -> void:
	# Bloquear la rueda del raton para que no cierre la cartilla.
	pass
