class_name WindowMision
extends CanvasLayer

@onready var mensaje_label: Label = $Center/PanelContainer/Margin/VBox/mensaje
@onready var boton_play: Button = $Center/PanelContainer/Margin/VBox/ButtonPlay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = true #pausar  el juego
	boton_play.pressed.connect(_on_button_play_pressed)
	boton_play.grab_focus()
	


## Esta función permite que el nivel le cambie el texto del objetivo según corresponda
func configurar_objetivo(texto: String) -> void:
	mensaje_label.text = texto
	
func _on_button_play_pressed() -> void:
		# 1. Reanudamos el juego
	get_tree().paused = false
		# 2. Eliminamos la ventana de la escena para liberar memoria
	queue_free()
