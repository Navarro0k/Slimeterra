class_name PantallaFin
extends CanvasLayer
## Pantalla de pausa / victoria / derrota, construida por código.

enum Modo { OCULTA, PAUSA, VICTORIA, DERROTA }

const C_PANEL := Color("#17263B")
const C_PANEL_CLARO := Color("#243B55")
const C_PANEL_HOVER := Color("#2F4C6B")
const C_PANEL_PRESS := Color("#1B2C42")
const C_ACENTO := Color("#62D9C7")
const C_ACENTO_HOVER := Color("#8AEBDD")
const C_ACENTO_PRESS := Color("#3CAFA6")
const C_TEXTO := Color("#F0F6FF")
const C_TEXTO_OSCURO := Color("#102338")
const C_BORDE := Color("#3C6680")
const C_APAGADO := Color("#39506B")

var modo: Modo = Modo.OCULTA

## Ruta del siguiente nivel (res://...tscn). Lo asigna el nivel.
var siguiente_nivel: String = ""
## true en el último nivel del juego.
var es_final_del_juego: bool = false
var primer_nivel: String = ""

var _btn_pausa: Button
var _raiz: Control
var _panel: PanelContainer
var _titulo: Label
var _estrellas: PantallaFinEstrellas
var _mensaje: Label
var _btn_continuar: Button
var _btn_reiniciar: Button
var _btn_siguiente: Button
var _btn_inicio: Button

## true mientras la pausa está bloqueada (por ejemplo, leyendo la cartilla).
var pausa_bloqueada: bool = false

func _ready() -> void:
	layer = 50
	# Debe seguir funcionando con el árbol en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_raiz.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if pausa_bloqueada:
		return
	if event.is_action_pressed("ui_cancel") and (modo == Modo.OCULTA or modo == Modo.PAUSA):
		get_viewport().set_input_as_handled()
		alternar_pausa()

## Permite al nivel impedir abrir la pausa.
func bloquear_pausa(bloqueada: bool) -> void:
	pausa_bloqueada = bloqueada
	if is_instance_valid(_btn_pausa):
		_btn_pausa.visible = not bloqueada and modo == Modo.OCULTA


func alternar_pausa() -> void:
	if modo == Modo.PAUSA:
		continuar()
	elif modo == Modo.OCULTA:
		_mostrar(Modo.PAUSA, "Pausa", "")

func mostrar_victoria(mensaje: String = "", estrellas: int = 0) -> void:
	var titulo := "¡Juego completado!" if es_final_del_juego else "¡Nivel completado!"
	_mostrar(Modo.VICTORIA, titulo, mensaje, estrellas)

func mostrar_derrota(mensaje: String = "") -> void:
	_mostrar(Modo.DERROTA, "Sin slimes", mensaje)

func continuar() -> void:
	modo = Modo.OCULTA
	_raiz.visible = false
	_btn_pausa.visible = not pausa_bloqueada
	get_tree().paused = false

func reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func ir_al_siguiente_nivel() -> void:
	_cambiar_de_nivel(siguiente_nivel)

func ir_al_primer_nivel() -> void:
	_cambiar_de_nivel(primer_nivel)

func _cambiar_de_nivel(ruta: String) -> void:
	if ruta.is_empty():
		return
	# Quitar la pausa antes de cambiar de escena.
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)


func _mostrar(nuevo_modo: Modo, titulo: String, mensaje: String, estrellas: int = 0) -> void:
	modo = nuevo_modo
	_titulo.text = titulo
	_mensaje.text = mensaje
	_mensaje.visible = mensaje != ""
	var victoria := nuevo_modo == Modo.VICTORIA
	_estrellas.visible = victoria
	_estrellas.poner(estrellas)
	_btn_continuar.visible = nuevo_modo == Modo.PAUSA
	_btn_siguiente.visible = victoria and siguiente_nivel != ""
	_btn_inicio.visible = victoria and es_final_del_juego and primer_nivel != ""
	_btn_reiniciar.text = "REPETIR NIVEL" if victoria else "REINTENTAR"
	_btn_pausa.visible = false
	_raiz.visible = true
	get_tree().paused = true
	_animar_entrada()
	if nuevo_modo == Modo.PAUSA:
		_btn_continuar.grab_focus()
	elif _btn_siguiente.visible:
		_btn_siguiente.grab_focus()
	else:
		_btn_reiniciar.grab_focus()


func _construir() -> void:
	_construir_boton_pausa()
	_construir_overlay()

func _construir_boton_pausa() -> void:
	_btn_pausa = _crear_boton("Ⅱ PAUSA", alternar_pausa, false)
	_btn_pausa.custom_minimum_size = Vector2(74, 18)
	_btn_pausa.add_theme_font_size_override("font_size", 9)
	_btn_pausa.focus_mode = Control.FOCUS_NONE
	add_child(_btn_pausa)
	_btn_pausa.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
	_btn_pausa.offset_left -= 4
	_btn_pausa.offset_top += 1

func _construir_overlay() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.04, 0.07, 0.72)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _estilo_panel())
	centro.add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 22)
	margen.add_theme_constant_override("margin_right", 22)
	margen.add_theme_constant_override("margin_top", 16)
	margen.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margen)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 7)
	margen.add_child(caja)
	_construir_contenido(caja)

func _construir_contenido(caja: VBoxContainer) -> void:
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 22)
	_titulo.add_theme_color_override("font_color", C_ACENTO)
	caja.add_child(_titulo)

	var linea := ColorRect.new()
	linea.color = Color(C_ACENTO, 0.5)
	linea.custom_minimum_size = Vector2(0, 1)
	caja.add_child(linea)

	_estrellas = PantallaFinEstrellas.new()
	caja.add_child(_estrellas)

	_mensaje = Label.new()
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.add_theme_font_size_override("font_size", 10)
	_mensaje.add_theme_color_override("font_color", C_TEXTO)
	caja.add_child(_mensaje)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 2)
	caja.add_child(espacio)

	_btn_continuar = _crear_boton("CONTINUAR", continuar, true)
	caja.add_child(_btn_continuar)

	_btn_siguiente = _crear_boton("SIGUIENTE NIVEL  →", ir_al_siguiente_nivel, true)
	caja.add_child(_btn_siguiente)

	_btn_reiniciar = _crear_boton("REINTENTAR", reiniciar, false)
	caja.add_child(_btn_reiniciar)

	_btn_inicio = _crear_boton("VOLVER AL INICIO", ir_al_primer_nivel, true)
	caja.add_child(_btn_inicio)

func _crear_boton(texto: String, accion: Callable, primario: bool) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(172, 26)
	boton.add_theme_font_size_override("font_size", 11)
	_aplicar_estilo_boton(boton, primario)
	boton.pressed.connect(accion)
	return boton

func _aplicar_estilo_boton(boton: Button, primario: bool) -> void:
	var color_texto := C_TEXTO_OSCURO if primario else C_TEXTO
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		boton.add_theme_color_override(estado, color_texto)

	if primario:
		boton.add_theme_stylebox_override("normal", _estilo_base(C_ACENTO, C_ACENTO))
		boton.add_theme_stylebox_override("hover", _estilo_base(C_ACENTO_HOVER, C_ACENTO_HOVER))
		boton.add_theme_stylebox_override("pressed", _estilo_base(C_ACENTO_PRESS, C_ACENTO_PRESS))
	else:
		boton.add_theme_stylebox_override("normal", _estilo_base(C_PANEL_CLARO, C_BORDE))
		boton.add_theme_stylebox_override("hover", _estilo_base(C_PANEL_HOVER, C_ACENTO))
		boton.add_theme_stylebox_override("pressed", _estilo_base(C_PANEL_PRESS, C_ACENTO))

	boton.add_theme_stylebox_override("disabled", _estilo_base(C_PANEL, C_APAGADO))
	boton.add_theme_stylebox_override("focus", _estilo_focus())

func _estilo_base(bg: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borde
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func _estilo_focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = C_TEXTO
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.expand_margin_left = 1
	s.expand_margin_right = 1
	s.expand_margin_top = 1
	s.expand_margin_bottom = 1
	return s

func _estilo_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PANEL
	s.border_color = C_BORDE
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s

func _animar_entrada() -> void:
	_raiz.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_raiz, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
