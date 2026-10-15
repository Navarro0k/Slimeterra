class_name PantallaFin
extends CanvasLayer
## Pantalla de pausa / victoria / derrota. Congela el juego (get_tree().paused) y ofrece
## Reiniciar (y Continuar cuando es solo una pausa). Se construye por código: no necesita escena.
## Además dibuja un botón "Pausa" siempre visible en la esquina superior derecha de la pantalla
## de juego; Esc (ui_cancel) hace lo mismo.

enum Modo { OCULTA, PAUSA, VICTORIA, DERROTA }

var modo: Modo = Modo.OCULTA

## Si no está vacío, la victoria ofrece pasar a este nivel (ruta res://...tscn). Lo asigna el nivel.
var siguiente_nivel: String = ""
## true en el último nivel del juego: la victoria pasa a ser la del juego completo.
var es_final_del_juego: bool = false
## Primer nivel del juego, al que se vuelve desde la pantalla final.
var primer_nivel: String = ""

var _btn_pausa: Button
var _raiz: Control
var _titulo: Label
var _mensaje: Label
var _btn_continuar: Button
var _btn_reiniciar: Button
var _btn_siguiente: Button
var _btn_inicio: Button

func _ready() -> void:
	layer = 50
	# Tiene que seguir funcionando con el árbol en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	_raiz.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (modo == Modo.OCULTA or modo == Modo.PAUSA):
		get_viewport().set_input_as_handled()
		alternar_pausa()

# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func alternar_pausa() -> void:
	if modo == Modo.PAUSA:
		continuar()
	elif modo == Modo.OCULTA:
		_mostrar(Modo.PAUSA, "Pausa", "")

func mostrar_victoria(mensaje: String = "") -> void:
	var titulo := "¡Juego completado!" if es_final_del_juego else "¡Nivel completado!"
	_mostrar(Modo.VICTORIA, titulo, mensaje)

func mostrar_derrota(mensaje: String = "") -> void:
	_mostrar(Modo.DERROTA, "Sin slimes", mensaje)

func continuar() -> void:
	modo = Modo.OCULTA
	_raiz.visible = false
	_btn_pausa.visible = true
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
	# Se quita la pausa ANTES: si no, el nivel nuevo arrancaría congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)

# ---------------------------------------------------------------------------
# Interno
# ---------------------------------------------------------------------------

func _mostrar(nuevo_modo: Modo, titulo: String, mensaje: String) -> void:
	modo = nuevo_modo
	_titulo.text = titulo
	_mensaje.text = mensaje
	_mensaje.visible = mensaje != ""
	var victoria := nuevo_modo == Modo.VICTORIA
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
	# Botón de pausa de la pantalla de juego (esquina superior derecha).
	_btn_pausa = _crear_boton("Pausa", alternar_pausa)
	_btn_pausa.custom_minimum_size = Vector2(0, 0)
	_btn_pausa.focus_mode = Control.FOCUS_NONE # Que Espacio/Enter no lo activen por accidente.
	add_child(_btn_pausa)
	_btn_pausa.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)

	# Overlay de pausa / victoria / derrota.
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP # Bloquea clics al juego mientras está abierta.
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

	_titulo = Label.new()
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 20)
	caja.add_child(_titulo)

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
