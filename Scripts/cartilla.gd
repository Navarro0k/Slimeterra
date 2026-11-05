extends CanvasLayer
## Cartilla explicativa independiente (escena reutilizable en nivel 1 y 2).
## Se muestra como overlay de pantalla completa con musica de fondo.

signal cerrada

@export var modo_ecuacion: String = "parabola"

@onready var lbl: RichTextLabel = $Panel/VBox/Label
@onready var btn: Button = $Panel/VBox/BtnContinuar
@onready var musica: AudioStreamPlayer = $Musica

var _fuente: FontFile
var _pagina: int = 0

func _ready() -> void:
	_fuente = load("res://Assets/fonts/JetBrainsMono-Regular.ttf") as FontFile
	if _fuente != null:
		lbl.add_theme_font_override("normal_font", _fuente)
		lbl.add_theme_font_override("bold_font", _fuente)
		lbl.add_theme_font_override("mono_font", _fuente)
		btn.add_theme_font_override("font", _fuente)
	# Pausar la musica del nivel mientras se muestra la cartilla.
	for m in get_tree().get_nodes_in_group("musica_nivel"):
		if m is AudioStreamPlayer:
			(m as AudioStreamPlayer).stream_paused = true
	# Reproducir musica de fondo explicativa.
	if musica != null and musica.stream != null:
		musica.play()
		musica.finished.connect(func(): if is_instance_valid(musica) and visible: musica.play())
	_actualizar()

func _actualizar() -> void:
	if modo_ecuacion == "matrices":
		if _pagina == 0:
			lbl.text = "[b]Por que matrices?[/b]\n\nEn el nivel 1 la trayectoria es una parabola perfecta porque no hay amortiguamiento. Aqui el aire frena al slime, asi la curva se deforma y ya no es y = a x^2 + b x + c.\n\nUsamos un sistema lineal: [b]s' = A*s + b[/b], donde s = [x, y, vx, vy].\n\nEl estado del slime se actualiza con matrices, lo que permite modelar el rozamiento del aire de forma dinamica.\n\nLa matriz A encode la gravedad y el amortiguamiento; b encode la gravedad constante. La solucion es s(t) = e^(A t) * s0 + integral(e^(A tau) b dtau)."
			btn.text = "Continuar"
		else:
			lbl.text = "[b]Formula y aplicacion:[/b]\n\ns0 = [ x0  y0  vx0  vy0 ]^T\n\nA =\n[  0   0   1   0  ]\n[  0   0   0   1  ]\n[  0   0  -k   0  ]\n[  0   0   0  -k  ]\n\nb = [ 0  0  0  g ]^T\n\nk = 0.10     g = 980\n\nAjusta angulo y potencia: s0 cambia en tiempo real y la trayectoria se recalcula.\n\n[b]Ahora juega y observa como la matriz cambia la trayectoria![/b]"
			btn.text = "Cerrar"
	else:
		if _pagina == 0:
			lbl.text = "[b]Por que una parabola?[/b]\n\nSin amortiguamiento, el tiro sigue [b]y(x) = a x^2 + b x + c[/b]. La gravedad es constante y no hay rozamiento, asi la curva es simetrica.\n\nLos coeficientes son:\na = g / (2 * vx^2)  (curvatura, depende de la velocidad horizontal)\nb = vy / vx - 2 * a * x0  (pendiente inicial)\nc = y0 - b * x0 + a * x0^2  (posicion inicial)\n\nAjusta angulo y potencia para alcanzar la meta."
			btn.text = "Continuar"
		else:
			lbl.text = "[b]Formula y aplicacion:[/b]\n\na = g / (2 * vx^2)\nb = vy / vx - 2 * a * x0\nc = y0 - b * x0 + a * x0^2\n\nCon vx, vy de la velocidad inicial.\n\nCambia angulo y potencia: a, b, c se actualizan en tiempo real en el panel superior.\n\n[b]Ahora juega y observa como cambian los coeficientes![/b]"
			btn.text = "Cerrar"

func _on_continuar() -> void:
	if _pagina == 0:
		_pagina = 1
		_actualizar()
	else:
		_cerrar()

func _cerrar() -> void:
	visible = false
	if musica != null:
		musica.stop()
	for m in get_tree().get_nodes_in_group("musica_nivel"):
		if m is AudioStreamPlayer:
			(m as AudioStreamPlayer).stream_paused = false
	cerrada.emit()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cerrar()
