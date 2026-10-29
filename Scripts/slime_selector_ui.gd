class_name SlimeSelectorUI
extends CanvasLayer
## Barra inferior izquierda: un botón por tipo de slime con su cantidad restante.
## No conoce a la resortera: solo emite slime_elegido y se refresca con actualizar().

## El jugador eligió el tipo en la posición `indice` del inventario.
signal slime_elegido(indice: int)

@export var tamano_slot: Vector2 = Vector2(38, 38)
@export var tamano_fuente: int = 8

@onready var _slots_box: HBoxContainer = %Slots

## Un diccionario por slot: { "boton": Button, "cantidad": Label }
var _slots: Array[Dictionary] = []

func _ready() -> void:
	# El selector se dibuja por encima de los HUD creados dinámicamente.
	layer = 40
	follow_viewport_enabled = false
	var panel := get_node_or_null("Margen/Panel") as PanelContainer
	if panel:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color("#17263B")
		estilo.border_color = Color("#3C6680")
		estilo.set_border_width_all(1)
		estilo.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", estilo)

## Construye un slot por cada tipo del diccionario { SlimeCatalogo.Tipo: cantidad }
## (mismo orden que la resortera).
func configurar(slimes: Dictionary) -> void:
	_limpiar()
	var inventario := SlimeInventario.desde_diccionario(slimes)
	for i in inventario.size():
		_crear_slot(i, inventario[i]["tipo"], inventario[i]["cantidad"])

## Refresca cantidades y resalta el slot seleccionado (-1 = ninguno).
func actualizar(inventario: Array, indice_seleccionado: int) -> void:
	for i in _slots.size():
		var cantidad := int(inventario[i]["cantidad"]) if i < inventario.size() else 0
		var boton: Button = _slots[i]["boton"]
		var etiqueta: Label = _slots[i]["cantidad"]
		etiqueta.text = "x%d" % cantidad
		boton.disabled = cantidad <= 0
		boton.modulate.a = 1.0 if cantidad > 0 else 0.45
		boton.set_pressed_no_signal(i == indice_seleccionado)



func _limpiar() -> void:
	for hijo in _slots_box.get_children():
		_slots_box.remove_child(hijo)
		hijo.queue_free()
	_slots.clear()

func _crear_slot(indice: int, tipo: int, cantidad: int) -> void:
	var boton := Button.new()
	boton.toggle_mode = true
	boton.custom_minimum_size = tamano_slot
	boton.focus_mode = Control.FOCUS_NONE # Evita que Espacio/Enter lo activen.
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	boton.z_index = 5
	boton.add_theme_color_override("font_color", Color("#EAF4FF"))
	boton.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	boton.add_theme_color_override("font_pressed_color", Color("#102338"))
	boton.add_theme_stylebox_override("normal", _slot_style(Color("#263B55")))
	boton.add_theme_stylebox_override("hover", _slot_style(Color("#365978")))
	boton.add_theme_stylebox_override("pressed", _slot_style(Color("#62D9C7")))
	boton.add_theme_stylebox_override("focus", _slot_style(Color("#62D9C7")))
	boton.icon = SlimeCatalogo.icono(tipo)
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.pressed.connect(_on_slot_pressed.bind(indice))

	var etiqueta := Label.new()
	etiqueta.text = "x%d" % cantidad
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	etiqueta.offset_right = -3
	etiqueta.offset_bottom = -1
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	etiqueta.add_theme_color_override("font_color", Color("#F2F7FF"))
	etiqueta.add_theme_color_override("font_outline_color", Color("#142338"))
	etiqueta.add_theme_constant_override("outline_size", 3)
	boton.add_child(etiqueta)

	_slots_box.add_child(boton)
	_slots.append({"boton": boton, "cantidad": etiqueta})


func _slot_style(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = Color("#62D9C7")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 2
	estilo.content_margin_right = 2
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 2
	return estilo

func _on_slot_pressed(indice: int) -> void:
	# Confirmar selección en UI inmediatamente; la resortera devuelve el estado real.
	slime_elegido.emit(indice)
