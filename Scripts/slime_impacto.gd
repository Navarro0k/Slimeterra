class_name SlimeImpacto
extends RefCounted
## Decide si un choque frontal del slime lo hace pegarse.

var _slime: RigidBody2D


func _init(slime: RigidBody2D) -> void:
	_slime = slime


## Devuelve {} si no se pegó; si se pegó, { "plataforma": Node } (null si fue a un tile).
func buscar_pegado(state: PhysicsDirectBodyState2D, v_motor: Vector2, umbral_impacto: float) -> Dictionary:
	var velocidad := v_motor if v_motor.length_squared() > 0.000001 else state.linear_velocity
	if velocidad.length_squared() < 0.000001:
		return {}
	var dir_vuelo := velocidad.normalized()
	var origen := state.transform.origin

	for i in state.get_contact_count():
		var punto := state.get_contact_collider_position(i)
		var hacia_contacto := punto - origen
		if hacia_contacto.length_squared() < 0.0001:
			continue
		hacia_contacto = hacia_contacto.normalized()

		# Umbral suavizado para impactos laterales durante curvas pronunciadas.
		if dir_vuelo.dot(hacia_contacto) < umbral_impacto - 0.2:
			continue

		var superficie := state.get_contact_collider_object(i) as Node
		if superficie == null:
			continue

		if superficie is TileMapLayer:
			if _tile_pegajoso_en(superficie, punto, hacia_contacto):
				return {"plataforma": null}
		else:
			var plataforma := _buscar_superficie_pegajosa(superficie)
			if plataforma != null:
				return {"plataforma": plataforma}
	return {}


func _tile_pegajoso_en(capa: TileMapLayer, punto: Vector2, hacia_contacto: Vector2) -> bool:
	# Proyección directa un poco más profunda.
	for profundidad in [2.0, 5.0]:
		var celda := capa.local_to_map(capa.to_local(punto + hacia_contacto * profundidad))
		var datos := capa.get_cell_tile_data(celda)
		if datos != null and datos.get_custom_data("es_pegajoso"):
			return true

	# Escáner de vecinos para esquinas y horizontales.
	var celda_impacto := capa.local_to_map(capa.to_local(punto))
	var vecinos = [
		celda_impacto,
		celda_impacto + Vector2i(0, 1), celda_impacto + Vector2i(0, -1),
		celda_impacto + Vector2i(1, 0), celda_impacto + Vector2i(-1, 0),
		celda_impacto + Vector2i(1, 1), celda_impacto + Vector2i(-1, -1),
		celda_impacto + Vector2i(1, -1), celda_impacto + Vector2i(-1, 1)
	]

	for vecino in vecinos:
		var datos := capa.get_cell_tile_data(vecino)
		if datos != null and datos.get_custom_data("es_pegajoso"):
			return true

	return false


## Sube por el árbol hasta encontrar un nodo pegajoso.
func _buscar_superficie_pegajosa(nodo: Node) -> Node:
	var raiz := _slime.get_tree().root
	var actual: Node = nodo
	while actual != null and actual != raiz:
		if actual.get("es_pegajoso") == true or actual.is_in_group("plataforma_pegajosa"):
			return actual
		actual = actual.get_parent()
	return null
