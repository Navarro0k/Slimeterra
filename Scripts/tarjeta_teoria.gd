class_name TarjetaTeoria
extends CanvasLayer
## Tarjetas "¿Sabías que…?" con la teoría del salto. Muestra una lista de páginas
## { "titulo", "texto" (BBCode) } con botones Anterior / Siguiente / Entendido, y pausa el
## juego mientras está abierta (el cronómetro de estrellas no corre mientras se lee).
##
## También dibuja dos botones fijos bajo el botón de Pausa:
##   - "Teoría": vuelve a abrir la introducción del nivel.
##   - "¿Cómo se calculó?": explica el último salto con sus números (aparece tras el primer tiro).
## Se construye por código: no necesita escena.

signal cerrada

## Introducciones ya vistas en esta sesión de juego (sobrevive a reiniciar el nivel),
## para no repetir la tarjeta de inicio cada vez que el jugador reinicia.
static var _intros_vistas: Dictionary = {}

var _paginas: Array[Dictionary] = []
var _indice: int = 0
var _pause_propia: bool = false
var _intro: Array[Dictionary] = []
var _explicacion: Array[Dictionary] = []

var _raiz: Control
var _etiqueta: Label
var _titulo: Label
var _texto: RichTextLabel
var _contador: Label
var _btn_anterior: Button
var _btn_siguiente: Button
var _botones_hud: VBoxContainer
var _btn_teoria: Button
var _btn_explicacion: Button

func _ready() -> void:
	layer = 40 # Debajo de la pantalla de pausa/victoria (50).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_raiz.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _raiz.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cerrar()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_siguiente()
	elif event.is_action_pressed("ui_left"):
		_anterior()
	else:
		return
	get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Define la introducción del nivel y la muestra si no se ha visto en esta sesión.
func configurar_intro(id: String, paginas: Array[Dictionary]) -> void:
	_intro = paginas
	_btn_teoria.visible = not _intro.is_empty()
	if not _intros_vistas.has(id) and not _intro.is_empty():
		_intros_vistas[id] = true
		mostrar(_intro, "¿Sabías que…?")

## Guarda la explicación del último salto y muestra su botón.
func poner_explicacion(paginas: Array[Dictionary]) -> void:
	_explicacion = paginas
	_btn_explicacion.visible = not paginas.is_empty()

func mostrar(paginas: Array[Dictionary], etiqueta: String = "") -> void:
	if paginas.is_empty():
		return
	_paginas = paginas
	_indice = 0
	_etiqueta.text = etiqueta
	_etiqueta.visible = etiqueta != ""
	_actualizar_pagina()
	_raiz.visible = true
	_botones_hud.visible = false
	# Solo pausa (y luego despausa) si el juego estaba corriendo: así no interfiere con la
	# pantalla de pausa/victoria, que maneja su propia pausa.
	_pause_propia = not get_tree().paused
	if _pause_propia:
		get_tree().paused = true

func cerrar() -> void:
	if not _raiz.visible:
		return
	_raiz.visible = false
	_botones_hud.visible = true
	if _pause_propia:
		get_tree().paused = false
	_pause_propia = false
	cerrada.emit()

func esta_abierta() -> bool:
	return _raiz.visible

# ---------------------------------------------------------------------------
# Interno
# ---------------------------------------------------------------------------

func _actualizar_pagina() -> void:
	var p: Dictionary = _paginas[_indice]
	_titulo.text = p.get("titulo", "")
	_texto.text = p.get("texto", "")
	_texto.scroll_to_line(0)
	_contador.text = "%d / %d" % [_indice + 1, _paginas.size()]
	_contador.visible = _paginas.size() > 1
	_btn_anterior.disabled = _indice == 0
	var ultima := _indice == _paginas.size() - 1
	_btn_siguiente.text = "Entendido" if ultima else "Siguiente  >"

func _siguiente() -> void:
	if _indice < _paginas.size() - 1:
		_indice += 1
		_actualizar_pagina()
	else:
		cerrar()

func _anterior() -> void:
	if _indice > 0:
		_indice -= 1
		_actualizar_pagina()

func _construir() -> void:
	# --- Botones fijos (debajo del botón "Pausa" de la esquina superior derecha) ---
	_botones_hud = VBoxContainer.new()
	_botones_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botones_hud.add_theme_constant_override("separation", 3)
	add_child(_botones_hud)
	_botones_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	_botones_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_botones_hud.offset_top = 30

	_btn_teoria = _boton_hud("Teoría", func(): mostrar(_intro, "¿Sabías que…?"))
	_btn_teoria.visible = false
	_btn_explicacion = _boton_hud("¿Cómo se calculó?", func(): mostrar(_explicacion, "Tu último salto"))
	_btn_explicacion.visible = false

	# --- Tarjeta ---
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.1, 0.16, 0.97)
	estilo.border_color = Color(1.0, 0.85, 0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)

	_etiqueta = Label.new()
	_etiqueta.add_theme_font_size_override("font_size", 8)
	_etiqueta.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	caja.add_child(_etiqueta)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 12)
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.custom_minimum_size = Vector2(340, 0)
	caja.add_child(_titulo)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.scroll_active = true
	_texto.fit_content = false
	_texto.custom_minimum_size = Vector2(340, 150)
	_texto.add_theme_font_size_override("normal_font_size", 9)
	_texto.add_theme_font_size_override("bold_font_size", 9)
	_texto.add_theme_font_size_override("italics_font_size", 9)
	_texto.add_theme_constant_override("line_separation", 1)
	caja.add_child(_texto)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	caja.add_child(fila)

	_btn_anterior = _boton("<  Anterior", _anterior)
	fila.add_child(_btn_anterior)

	_contador = Label.new()
	_contador.add_theme_font_size_override("font_size", 8)
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(_contador)

	_btn_siguiente = _boton("Siguiente  >", _siguiente)
	fila.add_child(_btn_siguiente)

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 0)
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(accion)
	return b

func _boton_hud(texto: String, accion: Callable) -> Button:
	var b := _boton(texto, accion)
	b.custom_minimum_size = Vector2(0, 0)
	b.add_theme_font_size_override("font_size", 8)
	_botones_hud.add_child(b)
	return b
