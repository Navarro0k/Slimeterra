class_name Meta
extends Area2D
## Bandera de meta. Cuando un slime la toca, el nivel se gana.
## Se registra sola en el grupo "meta": el script del nivel (level.gd) la encuentra por ahí,
## no hace falta conectar nada a mano.

signal meta_alcanzada

## Capa de física en la que están los slimes (por defecto la 1, la misma de slime.tscn).
@export_flags_2d_physics var mascara_slime: int = 1

var _alcanzada: bool = false

func _ready() -> void:
	add_to_group("meta")
	collision_layer = 0
	collision_mask = mascara_slime
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D) -> void:
	# Los tiles y las plataformas móviles también pueden entrar al área: solo cuentan los slimes.
	if _alcanzada or not cuerpo.has_method("lanzar"):
		return
	_alcanzada = true
	meta_alcanzada.emit()
