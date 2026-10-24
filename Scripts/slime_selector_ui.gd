class_name SlimeSelectorUI
extends CanvasLayer
## Barra inferior izquierda: un botón por tipo de slime con su cantidad restante.
## No conoce a la resortera: solo emite slime_elegido y se refresca con actualizar().

## El jugador eligió el tipo en la posición `indice` del inventario.
signal slime_elegido(indice: int)

@export var tamano_slot: Vector2 = Vector2(40, 40)
@export var tamano_fuente: int = 10

@onready var _slots_box: HBoxContainer = %Slots

## Un diccionario por slot: { "boton": Button, "cantidad": Label }
var _slots: Array[Dictionary] = []

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
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 3)
	boton.add_child(etiqueta)

	_slots_box.add_child(boton)
	_slots.append({"boton": boton, "cantidad": etiqueta})


func _on_slot_pressed(indice: int) -> void:
	slime_elegido.emit(indice)
