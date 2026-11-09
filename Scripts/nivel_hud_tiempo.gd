class_name NivelHudTiempo
extends RefCounted
## Cronómetro en pantalla (arriba al centro). Vive en su propia CanvasLayer,
## hija del nodo que se le pase (el nivel).

var _etiqueta: Label


func _init(padre: Node) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 20
	padre.add_child(capa)
	_etiqueta = Label.new()
	_etiqueta.text = "0:00.0"
	_etiqueta.custom_minimum_size = Vector2(80, 0)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_font_size_override("font_size", 14)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 4)
	capa.add_child(_etiqueta)
	_etiqueta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	_etiqueta.grow_horizontal = Control.GROW_DIRECTION_BOTH


func mostrar(segundos: float) -> void:
	_etiqueta.text = formatear(segundos)


## "m:ss.d" — por ejemplo 75.3 s -> "1:15.3".
static func formatear(t: float) -> String:
	var minutos := floori(t / 60.0)
	var segundos := fmod(t, 60.0)
	return "%d:%04.1f" % [minutos, segundos]
