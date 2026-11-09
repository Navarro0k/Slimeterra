class_name PantallaFin
extends CanvasLayer
## Pantalla de pausa / victoria / derrota, construida por código.

enum Modo { OCULTA, PAUSA, VICTORIA, DERROTA }

## Paleta de la cartilla (cuaderno de papel).
const C_PAPEL := HudTema.PAPEL
const C_PAPEL_HOVER := HudTema.PAPEL_CLARO
const C_PAPEL_PRESS := HudTema.PAPEL_OSCURO
const C_TINTA_CUADERNO := HudTema.TINTA
const C_TINTA_FUERTE := HudTema.TINTA_FUERTE
const C_TINTA_SUAVE := HudTema.TINTA_SUAVE
const C_CREMA := HudTema.CREMA
const C_BORDE_CUADERNO := HudTema.BORDE
const C_SEPARADOR := HudTema.SEPARADOR
const C_DESHABILITADO := HudTema.DESHABILITADO
const C_DESHABILITADO_TEXTO := HudTema.DESHABILITADO_TEXTO
const C_SOMBRA := HudTema.SOMBRA

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
var _fuente: FontFile

## true mientras la pausa está bloqueada (por ejemplo, leyendo la cartilla).
var pausa_bloqueada: bool = false

func _ready() -> void:
	layer = 50
	# Debe seguir funcionando con el árbol en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fuente = HudTema.fuente_pixel()
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
	_btn_reiniciar.text = "Repetir Nivel" if victoria else "Reintentar"
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
	_btn_pausa = Button.new()
	_btn_pausa.text = ""
	_btn_pausa.custom_minimum_size = Vector2(34, 24)
	_btn_pausa.focus_mode = Control.FOCUS_NONE
	_btn_pausa.add_theme_stylebox_override("normal", _estilo_cuaderno(C_PAPEL))
	_btn_pausa.add_theme_stylebox_override("hover", _estilo_cuaderno(C_PAPEL_HOVER))
	_btn_pausa.add_theme_stylebox_override("pressed", _estilo_cuaderno(C_PAPEL_PRESS))
	_btn_pausa.pressed.connect(alternar_pausa)
	add_child(_btn_pausa)
	_btn_pausa.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_pausa.offset_left = -40
	_btn_pausa.offset_top = 6
	_btn_pausa.offset_right = -6
	_btn_pausa.offset_bottom = 30

	# Filo de papel: línea clara bajo el borde superior.
	var filo := ColorRect.new()
	filo.color = Color(1.0, 1.0, 1.0, 0.45)
	filo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	filo.offset_left = 3
	filo.offset_right = -3
	filo.offset_top = 2
	filo.offset_bottom = 3
	_btn_pausa.add_child(filo)

	# Icono | | dibujado: dos barras verticales centradas.
	var barras := HBoxContainer.new()
	barras.alignment = BoxContainer.ALIGNMENT_CENTER
	barras.add_theme_constant_override("separation", 4)
	barras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btn_pausa.add_child(barras)
	for i in 2:
		var barra := ColorRect.new()
		barra.color = C_TINTA_CUADERNO
		barra.custom_minimum_size = Vector2(3, 11)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barras.add_child(barra)

func _construir_overlay() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.035, 0.06, 0.84)
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
	_titulo.add_theme_font_size_override("font_size", 17)
	_titulo.add_theme_color_override("font_color", C_TINTA_FUERTE)
	if _fuente != null:
		_titulo.add_theme_font_override("font", _fuente)
	caja.add_child(_titulo)

	var linea := ColorRect.new()
	linea.color = C_SEPARADOR
	linea.custom_minimum_size = Vector2(0, 1)
	caja.add_child(linea)

	_estrellas = PantallaFinEstrellas.new()
	caja.add_child(_estrellas)

	_mensaje = Label.new()
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje.add_theme_font_size_override("font_size", 10)
	_mensaje.add_theme_color_override("font_color", C_TINTA_SUAVE)
	if _fuente != null:
		_mensaje.add_theme_font_override("font", _fuente)
	caja.add_child(_mensaje)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 2)
	caja.add_child(espacio)

	_btn_continuar = _crear_boton("Continuar", continuar, true)
	caja.add_child(_btn_continuar)

	_btn_siguiente = _crear_boton("Siguiente Nivel  →", ir_al_siguiente_nivel, true)
	caja.add_child(_btn_siguiente)

	_btn_reiniciar = _crear_boton("Reintentar", reiniciar, false)
	caja.add_child(_btn_reiniciar)

	_btn_inicio = _crear_boton("Volver Al Inicio", ir_al_primer_nivel, true)
	caja.add_child(_btn_inicio)

func _crear_boton(texto: String, accion: Callable, primario: bool) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(172, 26)
	boton.add_theme_font_size_override("font_size", 11)
	if _fuente != null:
		boton.add_theme_font_override("font", _fuente)
	_aplicar_estilo_boton(boton, primario)
	boton.pressed.connect(accion)
	return boton

func _aplicar_estilo_boton(boton: Button, primario: bool) -> void:
	var color_texto := C_CREMA if primario else C_TINTA_CUADERNO
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		boton.add_theme_color_override(estado, color_texto)
	boton.add_theme_color_override("font_disabled_color", C_DESHABILITADO_TEXTO)

	if primario:
		boton.add_theme_stylebox_override("normal", _estilo_base(C_TINTA_CUADERNO, C_BORDE_CUADERNO))
		boton.add_theme_stylebox_override("hover", _estilo_base(HudTema.HOVER, C_BORDE_CUADERNO))
		boton.add_theme_stylebox_override("pressed", _estilo_base(HudTema.PRESSED, HudTema.BORDE_OSCURO))
	else:
		boton.add_theme_stylebox_override("normal", _estilo_base(C_PAPEL, C_BORDE_CUADERNO))
		boton.add_theme_stylebox_override("hover", _estilo_base(C_PAPEL_HOVER, C_BORDE_CUADERNO))
		boton.add_theme_stylebox_override("pressed", _estilo_base(C_PAPEL_PRESS, C_BORDE_CUADERNO))

	boton.add_theme_stylebox_override("disabled", _estilo_base(C_DESHABILITADO, HudTema.PAPEL_APAGADO))
	boton.add_theme_stylebox_override("focus", _estilo_focus())

func _estilo_base(bg: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borde
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func _estilo_focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = HudTema.AZUL
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.expand_margin_left = 1
	s.expand_margin_right = 1
	s.expand_margin_top = 1
	s.expand_margin_bottom = 1
	return s

func _estilo_cuaderno(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_BORDE_CUADERNO
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s

func _estilo_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PAPEL
	s.border_color = C_BORDE_CUADERNO
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = C_SOMBRA
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

func _animar_entrada() -> void:
	_raiz.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_raiz, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
