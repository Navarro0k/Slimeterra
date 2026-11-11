class_name NivelLimites
extends RefCounted
## Rectángulo de límites del nivel a partir de LimitesCamara/CollisionShape2D.


## Rectángulo global del nivel, o Rect2() sin área si falta o es inválido.
static func calcular(nivel: Node) -> Rect2:
	var colision := nivel.get_node_or_null(
		"LimitesCamara/CollisionShape2D"
	) as CollisionShape2D

	if colision == null:
		push_error(
			"Falta LimitesCamara/CollisionShape2D en el nivel: " + nivel.name
		)
		return Rect2()

	if not (colision.shape is RectangleShape2D):
		push_error(
			"LimitesCamara debe usar RectangleShape2D en el nivel: " + nivel.name
		)
		return Rect2()

	var rectangulo := colision.shape as RectangleShape2D
	var tamano: Vector2 = rectangulo.size * colision.global_scale.abs()

	if tamano.x <= 0.0 or tamano.y <= 0.0:
		push_error("El rectángulo de límites tiene tamaño inválido.")
		return Rect2()

	var origen: Vector2 = colision.global_position - tamano / 2.0

	return Rect2(origen, tamano)


## Rectángulo ampliado solo para la cámara. No modifica los límites de la física.
static func ampliar(rect: Rect2, margen_h: float, margen_v: float) -> Rect2:
	if not rect.has_area():
		return rect
	return rect.grow_individual(margen_h, margen_v, margen_h, margen_v)


## Dibuja un marco rojo con los límites (solo depuración).
static func crear_marco(nivel: Node2D, limites: Rect2) -> void:
	if not limites.has_area():
		return
	var marco := Line2D.new()
	marco.width = 1.0
	marco.default_color = Color(1.0, 0.2, 0.2, 0.9)
	marco.z_index = 100
	marco.points = PackedVector2Array([
		nivel.to_local(limites.position),
		nivel.to_local(Vector2(limites.end.x, limites.position.y)),
		nivel.to_local(limites.end),
		nivel.to_local(Vector2(limites.position.x, limites.end.y)),
		nivel.to_local(limites.position),
	])
	nivel.add_child(marco)
