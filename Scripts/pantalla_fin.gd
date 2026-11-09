class_name PantallaFin
extends CanvasLayer
## Pantalla de pausa / victoria / derrota, construida por código.

enum Modo { OCULTA, PAUSA, VICTORIA, DERROTA }

var modo: Modo = Modo.OCULTA

## Ruta del siguiente nivel (res://...tscn). Lo asigna el nivel.
var siguiente_nivel: String = ""
## true en el último nivel del juego.
var es_final_del_juego: bool = false
var primer_nivel: String = ""

var _btn_pausa: Button
var _raiz: Control
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
	_btn_reiniciar.text = "Repetir nivel" if victoria else "Reiniciar"
	_btn_pausa.visible = false
	_raiz.visible = true
	get_tree().paused = true
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
	_btn_pausa = _crear_boton("Ⅱ PAUSA", alternar_pausa)
	_btn_pausa.custom_minimum_size = Vector2(70, 20)
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
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)

	var panel := PanelContainer.new()
	centro.add_child(panel)

	var margen := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 14)
	panel.add_child(margen)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	margen.add_child(caja)
	_construir_contenido(caja)

func _construir_contenido(caja: VBoxContainer) -> void:
	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 20)
	caja.add_child(_titulo)

	_estrellas = PantallaFinEstrellas.new()
	caja.add_child(_estrellas)

	_mensaje = Label.new()
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.add_theme_font_size_override("font_size", 10)
	caja.add_child(_mensaje)

	_btn_continuar = _crear_boton("Continuar", continuar)
	caja.add_child(_btn_continuar)

	_btn_siguiente = _crear_boton("Siguiente nivel", ir_al_siguiente_nivel)
	caja.add_child(_btn_siguiente)

	_btn_reiniciar = _crear_boton("Reiniciar", reiniciar)
	caja.add_child(_btn_reiniciar)

	_btn_inicio = _crear_boton("Volver al inicio", ir_al_primer_nivel)
	caja.add_child(_btn_inicio)

func _crear_boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(110, 0)
	boton.add_theme_font_size_override("font_size", 12)
	boton.pressed.connect(accion)
	return boton
