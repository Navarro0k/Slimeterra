class_name Meta
extends Area2D
## Bandera de meta. Cuando un slime la toca, el nivel se gana.
## Se registra sola en el grupo "meta": el script del nivel (level.gd) la encuentra por ahí.
##
## Detecta al slime de DOS formas independientes (basta con que funcione una):
##   1. La señal body_entered del Area2D (necesita que la capa/máscara de física coincidan).
##   2. Un chequeo geométrico cada frame: ¿la posición del slime está dentro de la forma de
##      colisión de la meta? No depende de capas, máscaras ni de cómo esté configurado el Area2D.

signal meta_alcanzada

## Capa de física en la que están los slimes (por defecto la 1, la misma de slime.tscn).
@export_flags_2d_physics var mascara_slime: int = 1
## Margen (px) extra alrededor de la forma de la meta para el chequeo geométrico (≈ radio del slime).
@export var margen: float = 6.0
## Imprime en la consola de Godot qué hace la meta (útil para depurar).
@export var depurar: bool = false

var _alcanzada: bool = false

func _ready() -> void:
	add_to_group("meta")
	collision_layer = 0
	collision_mask = mascara_slime
	monitoring = true
	body_entered.connect(_on_body_entered)
	if _formas().is_empty():
		push_warning("Meta '%s' no tiene ninguna CollisionShape2D con forma (Rectangle, Circle o Capsule): no detectará nada." % name)
	if depurar:
		print("[Meta] lista en ", global_position, " con ", _formas().size(), " forma(s)")

func _physics_process(_delta: float) -> void:
	if _alcanzada:
		return
	var escena := get_tree().current_scene
	if escena == null:
		return
	# Los slimes lanzados cuelgan de la escena actual (la honda los reubica ahí al disparar).
	for nodo in escena.get_children():
		if nodo is RigidBody2D and nodo.has_method("lanzar") and _toca(nodo):
			_alcanzar("chequeo geométrico")
			return

func _on_body_entered(cuerpo: Node2D) -> void:
	# Los tiles y las plataformas móviles también pueden entrar al área: solo cuentan los slimes.
	if cuerpo.has_method("lanzar"):
		_alcanzar("body_entered")

func _alcanzar(origen: String) -> void:
	if _alcanzada:
		return
	_alcanzada = true
	if depurar:
		print("[Meta] alcanzada (", origen, ")")
	meta_alcanzada.emit()

func _formas() -> Array[CollisionShape2D]:
	var formas: Array[CollisionShape2D] = []
	for hijo in get_children():
		if hijo is CollisionShape2D and hijo.shape != null and not hijo.disabled:
			formas.append(hijo)
	return formas

## ¿El centro del slime (con margen) está dentro de alguna forma de la meta?
func _toca(slime: Node2D) -> bool:
	for forma_nodo in _formas():
		# to_local tiene en cuenta posición, rotación y escala del nodo de la forma.
		var p: Vector2 = forma_nodo.to_local(slime.global_position)
		var forma: Shape2D = forma_nodo.shape
		if forma is RectangleShape2D:
			var tam: Vector2 = (forma as RectangleShape2D).size
			if Rect2(-tam * 0.5, tam).grow(margen).has_point(p):
				return true
		elif forma is CircleShape2D:
			if p.length() <= (forma as CircleShape2D).radius + margen:
				return true
		elif forma is CapsuleShape2D:
			var capsula := forma as CapsuleShape2D
			var caja := Vector2(capsula.radius * 2.0, maxf(capsula.height, capsula.radius * 2.0))
			if Rect2(-caja * 0.5, caja).grow(margen).has_point(p):
				return true
	return false
